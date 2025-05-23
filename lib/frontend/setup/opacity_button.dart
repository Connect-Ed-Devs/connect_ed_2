import 'package:flutter/material.dart';

class OpacityIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final double size;

  const OpacityIconButton({Key? key, required this.icon, required this.onPressed, this.color, this.size = 24.0})
    : super(key: key);

  @override
  State<OpacityIconButton> createState() => _OpacityIconButtonState();
}

class _OpacityIconButtonState extends State<OpacityIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    bool isDisabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp:
          isDisabled
              ? null
              : (_) {
                setState(() => _isPressed = false);
                widget.onPressed!();
              },
      behavior: HitTestBehavior.opaque,
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 25),
          opacity: _isPressed && !isDisabled ? 0.4 : 1.0,
          child: Icon(widget.icon, color: widget.color ?? Theme.of(context).iconTheme.color, size: widget.size),
        ),
      ),
    );
  }
}

class OpacityTextButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final double fontSize;
  final FontWeight fontWeight;

  const OpacityTextButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.color,
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.w500,
  }) : super(key: key);

  @override
  State<OpacityTextButton> createState() => _OpacityTextButtonState();
}

class _OpacityTextButtonState extends State<OpacityTextButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    bool isDisabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp:
          isDisabled
              ? null
              : (_) {
                setState(() => _isPressed = false);
                widget.onPressed!(); // widget.onPressed will not be null here due to isDisabled check
              },
      behavior: HitTestBehavior.opaque,
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: _isPressed && !isDisabled ? 0.4 : 1.0,
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.color ?? Theme.of(context).colorScheme.primary,
              fontWeight: widget.fontWeight,
              fontSize: widget.fontSize,
            ),
          ),
        ),
      ),
    );
  }
}
