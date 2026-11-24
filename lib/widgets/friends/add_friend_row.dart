import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../validators/friend_code_validator.dart';
import '../generic/chunky_button.dart';

/// Friend code field + "Voeg toe" button.
class AddFriendRow extends StatefulWidget {
  const AddFriendRow({super.key, required this.onAdd, this.enabled = true});

  /// Called with a valid, normalised code. Return true to clear the field.
  final Future<bool> Function(String code) onAdd;
  final bool enabled;

  @override
  State<AddFriendRow> createState() => _AddFriendRowState();
}

class _AddFriendRowState extends State<AddFriendRow> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !widget.enabled) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final clear = await widget.onAdd(
      FriendCodeValidator.normalize(_controller.text),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (clear) _controller.clear();
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
              enabled: widget.enabled,
              maxLength: AppConstants.friendCodeLength,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                TextInputFormatter.withFunction(
                  (_, v) => v.copyWith(text: v.text.toUpperCase()),
                ),
              ],
              validator: FriendCodeValidator.validate,
              onFieldSubmitted: (_) => _submit(),
              style: AppTextStyles.body(
                16,
                weight: FontWeight.w900,
                letterSpacing: 3,
              ),
              decoration: const InputDecoration(
                hintText: 'Vriendcode',
                counterText: '',
                semanticCounterText: '',
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: ChunkyButton(
              label: 'Voeg toe',
              display: false,
              height: 52,
              style: ChunkyButtonStyle.secondary,
              loading: _busy,
              onPressed: widget.enabled ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}
