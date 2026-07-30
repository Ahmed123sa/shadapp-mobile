import 'package:flutter/material.dart';
import '../theme.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final bool showStrength;
  final bool showRequirements;
  final bool required;
  final String? Function(String?)? validator;
  final bool enabled;

  const PasswordField({
    super.key,
    required this.controller,
    this.labelText = 'كلمة المرور',
    this.hintText = 'أدخل كلمة المرور',
    this.showStrength = true,
    this.showRequirements = true,
    this.required = true,
    this.validator,
    this.enabled = true,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;
  late int _strength;
  late bool _hasMinChars;
  late bool _hasLetter;
  late bool _hasDigit;

  @override
  void initState() {
    super.initState();
    _strength = 0;
    _hasMinChars = false;
    _hasLetter = false;
    _hasDigit = false;
    widget.controller.addListener(_updateRequirements);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateRequirements);
    super.dispose();
  }

  void _updateRequirements() {
    final text = widget.controller.text;
    final minChars = text.length >= 8;
    final letter = RegExp(r'[A-Za-z]').hasMatch(text);
    final digit = RegExp(r'[0-9]').hasMatch(text);
    final strength = [minChars, letter, digit].where((e) => e).length;

    if (minChars != _hasMinChars || letter != _hasLetter || digit != _hasDigit || strength != _strength) {
      setState(() {
        _hasMinChars = minChars;
        _hasLetter = letter;
        _hasDigit = digit;
        _strength = strength;
      });
    }
  }

  Color _strengthColor() {
    if (_strength <= 1) return ShadColors.error;
    if (_strength == 2) return ShadColors.warning;
    return ShadColors.success;
  }

  String _strengthLabel() {
    if (_strength <= 1) return 'ضعيف';
    if (_strength == 2) return 'متوسط';
    return 'قوي';
  }

  double _strengthFraction() {
    if (_strength == 0) return 0.0;
    return _strength / 3.0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      TextFormField(
        controller: widget.controller,
        obscureText: _obscured,
        enabled: widget.enabled,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          suffixIcon: IconButton(
            icon: Icon(_obscured ? Icons.visibility_off : Icons.visibility, size: 18),
            onPressed: () => setState(() => _obscured = !_obscured),
          ),
        ),
        validator: widget.validator ??
            ((v) {
              if (v == null || v.trim().isEmpty) {
                return widget.required ? 'كلمة المرور مطلوبة' : null;
              }
              if (v.trim().length < 8) return '8 أحرف على الأقل';
              if (!RegExp(r'[A-Za-z]').hasMatch(v)) return 'يجب أن يحتوي على حرف إنجليزي';
              if (!RegExp(r'[0-9]').hasMatch(v)) return 'يجب أن يحتوي على رقم';
              return null;
            }),
      ),
      if (widget.showStrength && widget.controller.text.isNotEmpty) ...[
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _strengthFraction(),
            backgroundColor: ShadColors.cardBorder,
            valueColor: AlwaysStoppedAnimation(_strengthColor()),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(_strengthLabel(), style: TextStyle(fontSize: 11, color: _strengthColor())),
      ],
      const SizedBox(height: 8),
      _RequirementItem(label: '8 أحرف على الأقل', met: _hasMinChars),
      _RequirementItem(label: 'حرف إنجليزي واحد', met: _hasLetter),
      _RequirementItem(label: 'رقم واحد', met: _hasDigit),
    ]);
  }
}

class _RequirementItem extends StatelessWidget {
  final String label;
  final bool met;
  const _RequirementItem({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(met ? Icons.check_circle : Icons.cancel, size: 14, color: met ? ShadColors.success : ShadColors.error),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: met ? ShadColors.success : ShadColors.error)),
      ]),
    );
  }
}
