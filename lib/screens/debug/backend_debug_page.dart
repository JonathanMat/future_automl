import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../services/game/game_backend.dart';

/// Bare-bones screen to test the backend on two phones: create/join a room,
/// see both videos, press spell buttons, watch the state. Not the real UI.
class BackendDebugPage extends StatefulWidget {
  const BackendDebugPage({super.key, required this.backend});

  final GameBackend backend;

  @override
  State<BackendDebugPage> createState() => _BackendDebugPageState();
}

class _BackendDebugPageState extends State<BackendDebugPage> {
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();
  final _name = TextEditingController(text: 'Speler');
  final _code = TextEditingController();
  final List<StreamSubscription<Object?>> _subs = [];
  late GameState _state = widget.backend.state;
  String? _message;
  bool _busy = false;

  GameBackend get _backend => widget.backend;

  @override
  void initState() {
    super.initState();
    _local.initialize();
    _remote.initialize();
    _subs.add(
      _backend.gameState.listen((s) {
        setState(() => _state = s);
        _local.srcObject = _backend.localStream;
      }),
    );
    _subs.add(
      _backend.remoteStream.listen(
        (stream) => setState(() => _remote.srcObject = stream),
      ),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _local.dispose();
    _remote.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      _local.srcObject = _backend.localStream;
    } catch (e) {
      _message = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final inRoom = s.phase != GamePhase.idle;
    final blurOpponent =
        s.phase == GamePhase.countdown ||
        s.phase == GamePhase.cast ||
        s.phase == GamePhase.resolving;

    return Scaffold(
      appBar: AppBar(
        title: Text('Backend test – ${s.roomCode ?? 'geen kamer'}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!inRoom) ...[
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Naam'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await _backend.createRoom(playerName: _name.text);
                    }),
              child: const Text('Kamer maken'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Kamercode'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => _backend.joinRoom(
                            _code.text,
                            playerName: _name.text,
                          ),
                        ),
                  child: const Text('Joinen'),
                ),
              ],
            ),
          ],
          if (inRoom) ...[
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(child: RTCVideoView(_local, mirror: true)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RTCVideoView(_remote),
                        if (blurOpponent)
                          const ColoredBox(
                            color: Colors.black87,
                            child: Center(child: Text('🔮 verborgen')),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Fase: ${s.phase.name}   Ronde: ${s.round}   '
              'Video: ${s.callStatus.name}',
            ),
            Text(
              'Ik: ${s.me?.name} ❤️${s.me?.lives} '
              'schild: ${s.myShieldAvailable ? 'ja' : 'nee'}',
            ),
            Text(
              'Tegenstander: ${s.opponent?.name ?? '-'} '
              '❤️${s.opponent?.lives ?? '-'} '
              '${s.opponent?.online == false ? '(offline)' : ''}',
            ),
            if (s.castAt != null && s.phase == GamePhase.countdown)
              _Countdown(castAt: s.castAt!),
            if (s.mySpell != null) Text('Gecast: ${s.mySpell!.wire}'),
            if (s.lastResult case final r?)
              Text(
                'Ronde ${r.round}: ${r.mySpell?.wire ?? '–'} vs '
                '${r.opponentSpell?.wire ?? '–'} → ${r.outcome.name} '
                '(${r.reason.name})',
              ),
            if (s.phase == GamePhase.finished)
              Text(
                s.iWon == true ? '🏆 Gewonnen!' : 'Afgelopen',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            if (s.error != null)
              Text(s.error!, style: const TextStyle(color: Colors.orange)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final spell in Spell.values)
                  FilledButton.tonal(
                    onPressed:
                        s.canCast &&
                            (spell != Spell.schild || s.myShieldAvailable)
                        ? () => _run(() => _backend.submitSpell(spell))
                        : null,
                    child: Text(spell.wire),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (s.phase == GamePhase.finished)
                  FilledButton(
                    onPressed: () => _run(_backend.playAgain),
                    child: const Text('Opnieuw'),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _run(_backend.leaveRoom),
                  child: const Text('Verlaten'),
                ),
              ],
            ),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!, style: const TextStyle(color: Colors.red)),
            ),
          const Divider(height: 32),
          const Text('Leaderboard'),
          StreamBuilder<List<LeaderboardEntry>>(
            stream: _backend.leaderboard(),
            builder: (context, snap) => Column(
              children: [
                for (final e in snap.data ?? const <LeaderboardEntry>[])
                  Text('${e.name}: ${e.wins} W / ${e.losses} V'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown({required this.castAt});

  final DateTime castAt;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Timer _timer = Timer.periodic(
    const Duration(milliseconds: 100),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = widget.castAt.difference(DateTime.now()).inMilliseconds;
    final seconds = (ms / 1000).ceil().clamp(0, 99);
    return Text(
      seconds > 3 ? 'Klaar…' : '$seconds…',
      style: Theme.of(context).textTheme.displaySmall,
    );
  }
}
