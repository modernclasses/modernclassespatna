import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Accessible Stepped Price Input Field with `+` and `-` increment buttons.
/// 
/// Enforces Google Play-aligned price constraints:
/// - For Course/Batch prices: strictly values ending in 9 (9, 19, 29, 39, ... 3199).
///   Tapping `+` when empty starts at 9. Tapping `-` when empty does nothing.
/// - For Coupon discounts: increments of 10 starting at 10 up to 3199 (or max course price).
///   Tapping `+` when empty starts at 10. Tapping `-` when empty does nothing.
class SteppedPriceInputField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final bool isCoursePrice;
  final bool isRequired;
  final int minPrice;
  final int maxPrice;
  final int step;
  final FocusNode? focusNode;
  final EdgeInsets? scrollPadding;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const SteppedPriceInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.isCoursePrice = true,
    this.isRequired = true,
    int? minPrice,
    int? maxPrice,
    this.step = 10,
    this.focusNode,
    this.scrollPadding,
    this.validator,
    this.onChanged,
    this.enabled = true,
  })  : minPrice = minPrice ?? (isCoursePrice ? 9 : 10),
        maxPrice = maxPrice ?? 3199;

  @override
  State<SteppedPriceInputField> createState() => _SteppedPriceInputFieldState();
}

class _SteppedPriceInputFieldState extends State<SteppedPriceInputField> {
  void _handlePlus() {
    if (!widget.enabled) return;
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      widget.controller.text = widget.minPrice.toString();
      widget.onChanged?.call(widget.controller.text);
      setState(() {});
      return;
    }

    final current = int.tryParse(text);
    if (current == null) {
      widget.controller.text = widget.minPrice.toString();
      widget.onChanged?.call(widget.controller.text);
      setState(() {});
      return;
    }

    if (current >= widget.maxPrice) {
      return; // Already at maxPrice
    }

    int nextVal;
    if (widget.isCoursePrice) {
      // Must end in 9 (9, 19, 29, 39, ...)
      if ((current - 9) % 10 == 0) {
        nextVal = current + widget.step;
      } else {
        nextVal = 9 + (((current - 9) / 10).floor() + 1) * 10;
      }
    } else {
      // Coupon: multiples of 10 (10, 20, 30, ...)
      if (current % 10 == 0) {
        nextVal = current + widget.step;
      } else {
        nextVal = ((current / 10).floor() + 1) * 10;
      }
    }

    if (nextVal > widget.maxPrice) {
      nextVal = widget.maxPrice;
    }

    widget.controller.text = nextVal.toString();
    widget.onChanged?.call(widget.controller.text);
    setState(() {});
  }

  void _handleMinus() {
    if (!widget.enabled) return;
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      // If admin clicks minus button without value, do nothing
      return;
    }

    final current = int.tryParse(text);
    if (current == null || current <= widget.minPrice) {
      // Already at minPrice, do nothing
      return;
    }

    int nextVal;
    if (widget.isCoursePrice) {
      if ((current - 9) % 10 == 0) {
        nextVal = current - widget.step;
      } else {
        nextVal = 9 + (((current - 9) / 10).ceil() - 1) * 10;
      }
    } else {
      if (current % 10 == 0) {
        nextVal = current - widget.step;
      } else {
        nextVal = ((current / 10).ceil() - 1) * 10;
      }
    }

    if (nextVal < widget.minPrice) {
      nextVal = widget.minPrice;
    }

    widget.controller.text = nextVal.toString();
    widget.onChanged?.call(widget.controller.text);
    setState(() {});
  }

  String? _validateInput(String? val) {
    if (widget.validator != null) {
      final customErr = widget.validator!(val);
      if (customErr != null) return customErr;
    }

    if (val == null || val.trim().isEmpty) {
      if (!widget.isRequired) return null;
      return "Required";
    }

    final clean = val.replaceAll('₹', '').trim();
    final n = int.tryParse(clean);
    if (n == null) {
      return "Please enter a valid whole number";
    }

    if (n < widget.minPrice) {
      return "Minimum amount is ₹${widget.minPrice}";
    }

    if (n > widget.maxPrice) {
      return "Maximum allowed amount is ₹${widget.maxPrice}";
    }

    if (widget.isCoursePrice) {
      if ((n - 9) % 10 != 0) {
        return "Must be in steps of 10 ending in 9 (e.g. 9, 29, 299, 599 up to 3199)";
      }
    } else {
      if (n % 10 != 0 && n != widget.maxPrice) {
        return "Discount must be in increments of 10 (e.g. 50, 100, 200)";
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      scrollPadding: widget.scrollPadding ?? const EdgeInsets.all(20),
      keyboardType: TextInputType.number,
      onChanged: (val) {
        widget.onChanged?.call(val);
        setState(() {});
      },
      validator: _validateInput,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText ?? (widget.isCoursePrice ? "e.g. 599, 1199" : "e.g. 100, 200"),
        helperText: widget.helperText,
        errorText: widget.errorText,
        prefixText: "₹ ",
        prefixStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(10, 12, 4, 12),
        border: const OutlineInputBorder(),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 68,
          maxWidth: 78,
          minHeight: 32,
          maxHeight: 40,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: Key('btn_minus_${widget.labelText.replaceAll(RegExp(r'\W+'), '_')}'),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                tooltip: "Decrease by ₹${widget.step}",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                onPressed: widget.enabled ? _handleMinus : null,
              ),
              IconButton(
                key: Key('btn_plus_${widget.labelText.replaceAll(RegExp(r'\W+'), '_')}'),
                icon: const Icon(Icons.add_circle, size: 20),
                tooltip: "Increase by ₹${widget.step}",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
                color: AppTheme.primary,
                onPressed: widget.enabled ? _handlePlus : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
