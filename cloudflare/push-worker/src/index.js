// Spell Duel push worker (Cloudflare Workers, free plan).
//
// The app writes a challenge to /invites/{toUid}/{fromUid} and then calls
//   POST /challenge   Authorization: Bearer <Firebase ID token>
//   {"toUid": "..."}
// The worker checks who is calling, checks that this invite really exists
// (the database rules only allow invites between friends), and sends a
// push with Firebase Cloud Messaging to all tokens in /fcmTokens/{toUid}.
//
// Secrets/vars (see wrangler.toml and docs/BACKEND.md):
//   FIREBASE_SERVICE_ACCOUNT  secret: the service account JSON
//   FIREBASE_PROJECT_ID, FIREBASE_DB_URL  vars

const INVITE_MAX_AGE_MS = 3 * 60 * 1000;
const JWK_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, {status: 204});
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/challenge") {
      return json({error: "not found"}, 404);
    }
    try {
      return await handleChallenge(request, env);
    } catch (e) {
      console.error(e);
      return json({error: "internal"}, 500);
    }
  },
};

async function handleChallenge(request, env) {
  const auth = request.headers.get("Authorization") || "";
  const idToken = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!idToken) return json({error: "missing token"}, 401);

  let fromUid;
  try {
    fromUid = await verifyIdToken(idToken, env.FIREBASE_PROJECT_ID);
  } catch (e) {
    return json({error: "bad token"}, 401);
  }

  const body = await request.json().catch(() => ({}));
  const toUid = typeof body.toUid === "string" ? body.toUid : "";
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(toUid) || toUid === fromUid) {
    return json({error: "bad toUid"}, 400);
  }

  const access = await getAccessToken(env);
  const db = new Db(env.FIREBASE_DB_URL, access);

  // Only push for a real, fresh invite from this caller.
  const invite = await db.get(`invites/${toUid}/${fromUid}`);
  if (!invite || typeof invite.at !== "number") {
    return json({error: "no invite"}, 404);
  }
  if (Date.now() - invite.at > INVITE_MAX_AGE_MS) {
    return json({error: "invite expired"}, 410);
  }
  // One push per invite, even if the app calls twice.
  const logPath = `pushLog/${toUid}/${fromUid}`;
  if ((await db.get(logPath)) === invite.at) return json({sent: 0, dup: true});
  await db.put(logPath, invite.at);

  const tokens = Object.keys((await db.get(`fcmTokens/${toUid}`)) || {});
  const name = String(invite.name || "Een vriend").slice(0, 24);
  const tag = /^[0-9]{4}$/.test(invite.tag || "") ? ` #${invite.tag}` : "";

  let sent = 0;
  for (const token of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${access}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title: "⚡ Je wordt uitgedaagd!",
              body: `${name}${tag} daagt je uit voor een Spell Duel. Tik om te spelen.`,
            },
            data: {
              type: "challenge",
              fromUid,
              roomCode: String(invite.roomCode || ""),
            },
            android: {priority: "HIGH", ttl: "180s"},
            apns: {
              headers: {"apns-expiration": String(Math.floor(Date.now() / 1000) + 180)},
            },
          },
        }),
      },
    );
    if (res.ok) {
      sent++;
    } else {
      const err = await res.text();
      // App uninstalled or token rotated: forget it.
      if (res.status === 404 || err.includes("UNREGISTERED") ||
          err.includes("INVALID_ARGUMENT")) {
        await db.delete(`fcmTokens/${toUid}/${token}`);
      } else {
        console.error("FCM", res.status, err);
      }
    }
  }
  return json({sent});
}

// --- Firebase ID token (RS256 JWT) -----------------------------------------

let jwkCache = {keys: null, until: 0};

async function verifyIdToken(token, projectId) {
  const [h, p, s] = token.split(".");
  const header = JSON.parse(b64urlDecodeText(h));
  const payload = JSON.parse(b64urlDecodeText(p));
  const now = Math.floor(Date.now() / 1000);

  if (header.alg !== "RS256") throw new Error("alg");
  if (payload.aud !== projectId) throw new Error("aud");
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) throw new Error("iss");
  if (!payload.sub || payload.exp < now || payload.iat > now + 300) throw new Error("time/sub");

  if (!jwkCache.keys || Date.now() > jwkCache.until) {
    const res = await fetch(JWK_URL);
    const maxAge = /max-age=(\d+)/.exec(res.headers.get("Cache-Control") || "");
    jwkCache = {
      keys: (await res.json()).keys,
      until: Date.now() + (maxAge ? Number(maxAge[1]) * 1000 : 3600_000),
    };
  }
  const jwk = jwkCache.keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new Error("kid");

  const key = await crypto.subtle.importKey(
    "jwk", jwk, {name: "RSASSA-PKCS1-v1_5", hash: "SHA-256"}, false, ["verify"],
  );
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5", key, b64urlDecode(s), new TextEncoder().encode(`${h}.${p}`),
  );
  if (!ok) throw new Error("signature");
  return payload.sub;
}

// --- Google OAuth access token from the service account -------------------

let accessCache = {token: null, until: 0};

async function getAccessToken(env) {
  if (accessCache.token && Date.now() < accessCache.until) return accessCache.token;
  const sa = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
  const now = Math.floor(Date.now() / 1000);
  const claims = {
    iss: sa.client_email,
    scope: [
      "https://www.googleapis.com/auth/firebase.messaging",
      "https://www.googleapis.com/auth/firebase.database",
      "https://www.googleapis.com/auth/userinfo.email",
    ].join(" "),
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned =
    `${b64urlText(JSON.stringify({alg: "RS256", typ: "JWT"}))}.${b64urlText(JSON.stringify(claims))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8", pemToDer(sa.private_key),
    {name: "RSASSA-PKCS1-v1_5", hash: "SHA-256"}, false, ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${b64url(new Uint8Array(sig))}`,
    }),
  });
  const data = await res.json();
  if (!data.access_token) throw new Error(`oauth: ${JSON.stringify(data)}`);
  accessCache = {token: data.access_token, until: Date.now() + (data.expires_in - 120) * 1000};
  return data.access_token;
}

// --- Realtime Database REST (admin, bypasses rules) ------------------------

class Db {
  constructor(base, access) {
    this.base = base.replace(/\/$/, "");
    this.access = access;
  }
  url(path) {
    return `${this.base}/${path.split("/").map(encodeURIComponent).join("/")}.json`;
  }
  async req(method, path, body) {
    const res = await fetch(this.url(path), {
      method,
      headers: {"Authorization": `Bearer ${this.access}`},
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`db ${method} ${path}: ${res.status} ${await res.text()}`);
    return res.json();
  }
  get(path) { return this.req("GET", path); }
  put(path, value) { return this.req("PUT", path, value); }
  delete(path) { return this.req("DELETE", path); }
}

// --- helpers ---------------------------------------------------------------

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {"Content-Type": "application/json"},
  });
}

function b64url(bytes) {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlText(text) {
  return b64url(new TextEncoder().encode(text));
}

function b64urlDecode(s) {
  const pad = s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4);
  return Uint8Array.from(atob(pad), (c) => c.charCodeAt(0));
}

function b64urlDecodeText(s) {
  return new TextDecoder().decode(b64urlDecode(s));
}

function pemToDer(pem) {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)).buffer;
}
