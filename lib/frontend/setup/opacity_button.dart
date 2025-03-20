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
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      behavior: HitTestBehavior.opaque,
      onTapCancel: () => setState(() => _isPressed = false),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 25),
          opacity: _isPressed ? 0.4 : 1.0,
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

  const OpacityTextButton({Key? key, required this.text, required this.onPressed, this.color, this.fontSize = 16.0})
    : super(key: key);

  @override
  State<OpacityTextButton> createState() => _OpacityTextButtonState();
}

class _OpacityTextButtonState extends State<OpacityTextButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      behavior: HitTestBehavior.opaque,
      onTapCancel: () => setState(() => _isPressed = false),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 10),
          opacity: _isPressed ? 0.4 : 1.0,
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.color ?? Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
              fontSize: widget.fontSize,
            ),
          ),
        ),
      ),
    );
  }
}
