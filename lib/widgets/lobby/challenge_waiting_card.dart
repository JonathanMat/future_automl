import 'dart:async';

import 'package:flutter/material.dart';

import '../../providers/challenge_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/extensions.dart';
import '../generic/app_card.dart';
import '../generic/avatar_tile.dart';
import '../generic/chunky_button.dart';
import '../generic/player_name.dart';

/// Lobby card while waiting for a challenged friend: their avatar with a
/// pulsing ring, "Wachten op Lotte #4821…" and the time left before the
/// invite expires. The room code stays available below, small.
///
/// Declined or expired: "Opnieuw uitdagen" and "Naar home".
class ChallengeWaitingCard extends StatefulWidget {
  const ChallengeWaitingCard({
    super.key,
    required this.challenge,
    required this.expiresAt,
    this.roomCode,
    this.onRetry,
    this.onHome,
    this.retrying = false,
  });

  final OutgoingChallenge challenge;
  final DateTime expiresAt;
  final String? roomCode;

  /// Challenge the friend again (same room).
  final VoidCallback? onRetry;

  /// Leave the room and go home.
  final VoidCallback? onHome;
  final bool retrying;

  @override
  State<ChallengeWaitingCard> createState() => _ChallengeWaitingCardState();
}

class _ChallengeWaitingCardState extends State<ChallengeWaitingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final left = widget.expiresAt.difference(DateTime.now());
    final declined = c.declined;
    // Either way the friend is not coming: show the choices.
    final expired = declined || left <= Duration.zero;
    final color = c.name.avatarColor;
    final mm = left.inMinutes;
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
      borderColor: expired ? AppColors.border : color.withValues(alpha: 0.7),
      borderWidth: 2,
      child: Column(
        children: [
          SizedBox.square(
            dimension: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!expired)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final t = _pulse.value;
                      return Container(
                        width: 72 + 40 * t,
                        height: 72 + 40 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: 0.6 * (1 - t)),
                            width: 3,
                          ),
                        ),
                      );
                    },
                  ),
                Opacity(
                  opacity: expired ? 0.5 : 1,
                  child: AvatarTile(name: c.name, size: 72, circle: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: expired
                ? Text(
                    declined
                        ? '${c.name} heeft geweigerd'
                        : '${c.name} reageerde niet',
                    style: AppTextStyles.display(22),
                    textAlign: TextAlign.center,
                  )
                : PlayerName(
                    name: 'Wachten op ${c.name}',
                    tag: c.tag,
                    suffix: '…',
                    style: AppTextStyles.display(22),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            declined
                ? 'Daag ${c.name} opnieuw uit, deel de kamercode of ga terug.'
                : expired
                ? 'De uitdaging is verlopen. Daag ${c.name} opnieuw uit of ga terug.'
                : '${c.name} heeft een melding gekregen. '
                      'Nog $mm:$ss om te reageren.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(13, color: AppColors.textSoft),
          ),
          if (expired && (widget.onRetry != null || widget.onHome != null)) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.onHome != null)
                  Expanded(
                    child: ChunkyButton(
                      label: 'Naar home',
                      icon: Icons.home_rounded,
                      display: false,
                      height: 46,
                      style: ChunkyButtonStyle.secondary,
                      onPressed: widget.onHome,
                    ),
                  ),
                if (widget.onHome != null && widget.onRetry != null)
                  const SizedBox(width: 10),
                if (widget.onRetry != null)
                  Expanded(
                    child: ChunkyButton(
                      label: 'Opnieuw',
                      icon: Icons.replay_rounded,
                      display: false,
                      height: 46,
                      loading: widget.retrying,
                      semanticLabel: 'Daag ${c.name} opnieuw uit',
                      onPressed: widget.onRetry,
                    ),
                  ),
              ],
            ),
          ],
          if (widget.roomCode != null) ...[
            const SizedBox(height: 14),
            Text(
              'KAMERCODE  ${widget.roomCode!.split('').join(' ')}',
              style: AppTextStyles.overline(),
            ),
          ],
        ],
      ),
    );
  }
}
