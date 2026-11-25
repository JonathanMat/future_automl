import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../validators/tournament_code_validator.dart';
import '../generic/app_card.dart';
import '../generic/chunky_button.dart';

/// Not in a tournament yet: make one, or join with a code.
class TournamentEntry extends StatefulWidget {
  const TournamentEntry({
    super.key,
    required this.busy,
    required this.onCreate,
    required this.onJoin,
  });

  final bool busy;
  final VoidCallback onCreate;

  /// Called with a valid, normalised code.
  final ValueChanged<String> onJoin;

  @override
  State<TournamentEntry> createState() => _TournamentEntryState();
}

class _TournamentEntryState extends State<TournamentEntry>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    _float.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    widget.onJoin(TournamentCodeValidator.normalize(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _float,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, 6 * sin(_float.value * 2 * pi)),
            child: child,
          ),
          child: const _Hero(),
        ),
        const SizedBox(height: 18),
        Text(
          'Speel met de hele klas',
          textAlign: TextAlign.center,
          style: AppTextStyles.display(28),
        ),
        const SizedBox(height: 6),
        Text(
          'Knock-out tot 16 spelers. Bij een oneven aantal krijgt iemand een '
          'vrijloting en gaat meteen door.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            14,
            weight: FontWeight.w700,
            color: AppColors.textSoft,
          ),
        ),
        const SizedBox(height: 22),
        ChunkyButton(
          label: 'TOERNOOI MAKEN',
          icon: Icons.account_tree_rounded,
          loading: widget.busy,
          onPressed: widget.busy ? null : widget.onCreate,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.borderStrong)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OF DOE MEE', style: AppTextStyles.overline()),
            ),
            const Expanded(child: Divider(color: AppColors.borderStrong)),
          ],
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _controller,
                  maxLength: TournamentCodeValidator.length,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.go,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    _UpperCase(),
                  ],
                  validator: TournamentCodeValidator.validate,
                  onFieldSubmitted: (_) => _submit(),
                  style: AppTextStyles.body(
                    18,
                    weight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Toernooicode',
                    counterText: '',
                    semanticCounterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: ChunkyButton(
                  label: 'Meedoen',
                  display: false,
                  height: 52,
                  style: ChunkyButtonStyle.secondary,
                  loading: widget.busy,
                  onPressed: widget.busy ? null : _submit,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Step(
                n: 1,
                text:
                    'De leerkracht (of iemand) maakt het toernooi en zet de '
                    'code op het bord.',
              ),
              _Step(n: 2, text: 'Iedereen doet mee met die code.'),
              _Step(
                n: 3,
                text:
                    'START: de loting maakt het schema. Je telefoon roept '
                    'je op als jouw duel klaar is.',
              ),
              _Step(
                n: 4,
                text:
                    'Winnen = door naar de volgende ronde, tot er één '
                    'kampioen is.',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 118,
        height: 118,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [AppColors.goldLight, AppColors.gold, AppColors.goldShadow],
            stops: [0, 0.6, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.45),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(
          Icons.emoji_events_rounded,
          size: 70,
          color: AppColors.goldInk,
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text, this.last = false});

  final int n;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$n',
              style: AppTextStyles.body(13, color: AppColors.gold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body(
                14,
                weight: FontWeight.w700,
                color: AppColors.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
