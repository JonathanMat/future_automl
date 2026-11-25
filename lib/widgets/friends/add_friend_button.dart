import 'package:flutter/material.dart';

import '../../theme/app_transitions.dart';
import '../generic/chunky_button.dart';

/// Where adding someone as a friend stands.
enum AddFriendState {
  /// Not friends, nothing pending: tap to send a request.
  add,

  /// They already sent you a request: tap to accept it.
  accept,

  /// Sending or accepting right now.
  working,

  /// Your request is waiting for their answer.
  sent,

  /// Already friends.
  friends,
}

/// Small icon-only button to add a recent opponent as a friend. Same
/// chunky style as the "Duel" button next to a friend; it turns into
/// "sent" or "friends" once done.
class AddFriendButton extends StatelessWidget {
  const AddFriendButton({
    super.key,
    required this.state,
    required this.name,
    required this.onPressed,
  });

  final AddFriendState state;
  final String name;
  final VoidCallback onPressed;

  static const _width = 48.0;
  static const _height = 38.0;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      ChunkyButtonStyle style,
      String tip,
      bool tappable,
    ) = switch (state) {
      AddFriendState.add => (
        Icons.person_add_alt_1_rounded,
        ChunkyButtonStyle.primary,
        'Voeg $name toe als vriend',
        true,
      ),
      AddFriendState.accept => (
        Icons.how_to_reg_rounded,
        ChunkyButtonStyle.success,
        '$name wil je vriend worden: accepteer',
        true,
      ),
      AddFriendState.working => (
        Icons.person_add_alt_1_rounded,
        ChunkyButtonStyle.primary,
        'Bezig…',
        false,
      ),
      AddFriendState.sent => (
        Icons.schedule_send_rounded,
        ChunkyButtonStyle.secondary,
        'Verzoek verstuurd, wacht op $name',
        false,
      ),
      AddFriendState.friends => (
        Icons.check_rounded,
        ChunkyButtonStyle.success,
        'Jij en $name zijn vrienden',
        false,
      ),
    };
    return Tooltip(
      message: tip,
      child: SizedBox(
        width: _width,
        // ChunkyButton adds its 3D edge (4 px) under the face.
        height: _height + 4,
        child: AnimatedSwitcher(
          duration: AppTransitions.fast,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: Tween(begin: .7, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: ChunkyButton(
            // The spinner shows inside the same button: no pop while
            // working, only when the outcome changes the look.
            key: ValueKey(
              state == AddFriendState.working ? AddFriendState.add : state,
            ),
            label: '',
            icon: icon,
            fontSize: 20,
            display: false,
            height: _height,
            style: style,
            semanticLabel: tip,
            loading: state == AddFriendState.working,
            // "Sent" and "friends" are outcomes, not unavailable actions:
            // keep them fully visible (their colour says it all).
            dimWhenDisabled: false,
            onPressed: tappable ? onPressed : null,
          ),
        ),
      ),
    );
  }
}
