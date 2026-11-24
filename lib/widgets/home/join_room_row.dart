import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../validators/room_code_validator.dart';
import '../generic/chunky_button.dart';

/// Room code field + "Join" button.
class JoinRoomRow extends StatefulWidget {
  const JoinRoomRow({super.key, required this.onJoin, this.busy = false});

  /// Called with a valid, normalised code.
  final ValueChanged<String> onJoin;
  final bool busy;

  @override
  State<JoinRoomRow> createState() => _JoinRoomRowState();
}

class _JoinRoomRowState extends State<JoinRoomRow> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    widget.onJoin(RoomCodeValidator.normalize(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _controller,
              maxLength: AppConstants.roomCodeLength,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                _UpperCaseFormatter(),
              ],
              validator: RoomCodeValidator.validate,
              onFieldSubmitted: (_) => _submit(),
              style: AppTextStyles.body(
                16,
                weight: FontWeight.w900,
                letterSpacing: 4,
              ),
              decoration: const InputDecoration(
                hintText: 'Kamercode',
                counterText: '',
                semanticCounterText: '',
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: ChunkyButton(
              label: 'Join',
              display: false,
              height: 52,
              style: ChunkyButtonStyle.secondary,
              loading: widget.busy,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
