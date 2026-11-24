import 'package:flutter/material.dart';

import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../validators/player_name_validator.dart';

/// Text field for the player name, validated with [PlayerNameValidator].
class NameField extends StatelessWidget {
  const NameField({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      maxLength: AppConstants.playerNameMaxLength,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      validator: PlayerNameValidator.validate,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      style: AppTextStyles.body(18, weight: FontWeight.w900),
      decoration: const InputDecoration(hintText: 'Je naam', labelText: 'Naam'),
    );
  }
}
