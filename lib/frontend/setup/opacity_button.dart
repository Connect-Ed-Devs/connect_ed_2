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
