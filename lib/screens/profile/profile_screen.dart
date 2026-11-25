import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/friend_record.dart';
import '../../models/player_profile.dart';
import '../../navigators/app_router.dart';
import '../../navigators/room_flow.dart';
import '../../providers/friends_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/social/friends_backend.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/generic/chunky_button.dart';
import '../../widgets/generic/crossed_swords_icon.dart';
import '../../widgets/generic/screen_header.dart';
import '../../widgets/profile/profile_sections.dart';

/// Who to show on the [ProfileScreen]. Name, tag and record come from
/// where the player was tapped, so the page has something to show while
/// (or if) their full profile can't be loaded.
class ProfileArgs {
  const ProfileArgs({
    this.uid,
    required this.name,
    this.tag,
    this.wins = 0,
    this.losses = 0,
  });

  /// Null (or your own id) shows your own profile.
  final String? uid;
  final String name;
  final String? tag;
  final int wins;
  final int losses;
}

/// A player's profile with all their stats: level, record, spells,
/// highlights, badges and, for someone else, your record against them.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.args});

  final ProfileArgs args;

  static Future<void> open(
    BuildContext context, {
    String? uid,
    required String name,
    String? tag,
    int wins = 0,
    int losses = 0,
  }) => Navigator.of(context).pushNamed(
    AppRoutes.profile,
    arguments: ProfileArgs(
      uid: uid,
      name: name,
      tag: tag,
      wins: wins,
      losses: losses,
    ),
  );

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<PublicProfile?>? _player;

  bool _isMe(FriendsProvider social) {
    final uid = widget.args.uid;
    return uid == null || uid == social.myUid;
  }

  @override
  void initState() {
    super.initState();
    final social = context.read<FriendsProvider>();
    if (!_isMe(social)) {
      _player = social.backend
          .loadPlayer(widget.args.uid!)
          .then<PublicProfile?>((p) => p, onError: (_) => null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<FriendsProvider>();
    if (_isMe(social)) {
      return _ProfileBody(
        profile: context.watch<ProfileProvider>().profile,
        tag: social.myTag,
        isMe: true,
      );
    }
    return FutureBuilder<PublicProfile?>(
      future: _player,
      builder: (context, snap) {
        final a = widget.args;
        final loaded = snap.data;
        final loading = snap.connectionState != ConnectionState.done;
        return _ProfileBody(
          uid: a.uid,
          profile:
              loaded?.profile ??
              PlayerProfile(name: a.name, wins: a.wins, losses: a.losses),
          tag: loaded?.tag ?? a.tag,
          loading: loading,
          limited: loaded == null,
        );
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    this.uid,
    this.tag,
    this.isMe = false,
    this.loading = false,
    this.limited = false,
  });

  final PlayerProfile profile;
  final String? uid;
  final String? tag;
  final bool isMe;
  final bool loading;

  /// Only name and scorebord record are known: no XP, stats or badges.
  final bool limited;

  @override
  Widget build(BuildContext context) {
    final social = context.watch<FriendsProvider>();
    final friend = uid == null
        ? null
        : social.friends.where((f) => f.uid == uid).firstOrNull;
    final FriendRecord? h2h = isMe || uid == null
        ? null
        : context
              .watch<ProfileProvider>()
              .friends
              .where((r) => r.uid == uid)
              .firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            ScreenHeader(title: isMe ? 'Jouw profiel' : 'Profiel'),
            const SizedBox(height: 16),
            ProfileHero(
              profile: profile,
              tag: tag,
              isMe: isMe,
              isFriend: friend != null,
              showLevel: !limited,
            ),
            if (!isMe) ...[
              const SizedBox(height: 14),
              _Actions(uid: uid, name: profile.name, friend: friend),
            ],
            if (h2h != null) ...[
              const SizedBox(height: 14),
              HeadToHeadCard(record: h2h),
            ],
            _section('RECORD'),
            ProfileRecord(profile: profile, showStreaks: !limited),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (limited)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Meer statistieken van ${profile.name} zijn niet '
                  'beschikbaar.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    14,
                    weight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              )
            else ...[
              _section('SPREUKEN'),
              SpellWinsCard(profile: profile),
              _section('HOOGTEPUNTEN'),
              HighlightsCard(profile: profile),
              _section('BADGES'),
              ProfileBadges(
                profile: profile,
                onOpen: isMe
                    ? () => Navigator.of(context).pushNamed(AppRoutes.badges)
                    : null,
              ),
              _section('GESCHIEDENIS'),
              DuelHistoryCard(
                history: profile.history,
                onOpen: (d) {
                  // Already on their page (e.g. their duel against you).
                  if (d.opponentUid == uid) return;
                  ProfileScreen.open(
                    context,
                    uid: d.opponentUid,
                    name: d.opponentName,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(title, style: AppTextStyles.overline()),
  );
}

/// Duel / remove for a friend, add friend for anyone else.
class _Actions extends StatelessWidget {
  const _Actions({required this.uid, required this.name, this.friend});

  final String? uid;
  final String name;
  final Friend? friend;

  Future<void> _run(
    BuildContext context,
    Future<FriendActionResult> action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final r = await action;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(r.message)));
  }

  Future<void> _confirmRemove(BuildContext context, Friend friend) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${friend.name} verwijderen?'),
        content: const Text(
          'Jullie staan dan niet meer op elkaars vriendenscorebord.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.redSoft),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final nav = Navigator.of(context);
    await _run(context, context.read<FriendsProvider>().remove(friend));
    if (nav.mounted) nav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<FriendsProvider>();
    final busy = context.select<GameProvider, bool>((g) => g.busy);
    final f = friend;
    if (f != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChunkyButton(
            label: 'DUEL ${f.name.toUpperCase()}',
            iconBuilder: (color, size) =>
                CrossedSwordsIcon(color: color, size: size + 4),
            height: 58,
            fontSize: 20,
            loading: social.isWorking(f.uid),
            onPressed: busy ? null : () => RoomFlow.challenge(context, f),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: social.isWorking(f.uid)
                ? null
                : () => _confirmRemove(context, f),
            style: TextButton.styleFrom(foregroundColor: AppColors.redSoft),
            icon: const Icon(Icons.person_remove_rounded, size: 18),
            label: const Text('Verwijder als vriend'),
          ),
        ],
      );
    }
    final id = uid;
    if (id == null || !social.isReady) return const SizedBox.shrink();
    final sent = social.requestSent(id);
    final incoming = social.requests.any((q) => q.fromUid == id);
    return ChunkyButton(
      label: sent
          ? 'VERZOEK VERSTUURD'
          : incoming
          ? 'VERZOEK ACCEPTEREN'
          : 'VRIEND TOEVOEGEN',
      icon: sent ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
      style: ChunkyButtonStyle.secondary,
      height: 52,
      fontSize: 18,
      loading: social.isWorking(id),
      onPressed: sent ? null : () => _run(context, social.addByUid(id, name)),
    );
  }
}
