import 'package:flutter/material.dart';

/// Standardized spacing widget for consistent layout
class CESpacing extends StatelessWidget {
  final double size;
  final Axis direction;

  const CESpacing(
    this.size, {
    super.key,
    this.direction = Axis.vertical,
  });

  // Standard spacing sizes
  static const CESpacing tiny = CESpacing(4);
  static const CESpacing small = CESpacing(8);
  static const CESpacing medium = CESpacing(16);
  static const CESpacing large = CESpacing(24);
  static const CESpacing extraLarge = CESpacing(32);

  // Horizontal spacing variants
  static const CESpacing tinyHorizontal =
      CESpacing(4, direction: Axis.horizontal);
  static const CESpacing smallHorizontal =
      CESpacing(8, direction: Axis.horizontal);
  static const CESpacing mediumHorizontal =
      CESpacing(16, direction: Axis.horizontal);
  static const CESpacing largeHorizontal =
      CESpacing(24, direction: Axis.horizontal);
  static const CESpacing extraLargeHorizontal =
      CESpacing(32, direction: Axis.horizontal);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: direction == Axis.horizontal ? size : null,
      height: direction == Axis.vertical ? size : null,
    );
  }
}

/// Styled divider component
class CEDivider extends StatelessWidget {
  final double? height;
  final double? thickness;
  final Color? color;
  final double? indent;
  final double? endIndent;
  final bool isVertical;

  const CEDivider({
    super.key,
    this.height,
    this.thickness,
    this.color,
    this.indent,
    this.endIndent,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.dividerTheme.color;

    if (isVertical) {
      return Container(
        width: thickness ?? 1,
        height: height,
        margin: EdgeInsets.symmetric(
          vertical: indent ?? 0,
        ),
        color: effectiveColor,
      );
    }

    return Divider(
      height: height,
      thickness: thickness,
      color: effectiveColor,
      indent: indent,
      endIndent: endIndent,
    );
  }
}

/// Badge component for notifications and status indicators
class CEBadge extends StatelessWidget {
  final Widget child;
  final String? label;
  final Color? color;
  final Color? textColor;
  final double? size;
  final EdgeInsetsGeometry? padding;
  final bool showBadge;
  final Alignment alignment;

  const CEBadge({
    super.key,
    required this.child,
    this.label,
    this.color,
    this.textColor,
    this.size,
    this.padding,
    this.showBadge = true,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBadge) return child;

    final theme = Theme.of(context);
    final badgeColor = color ?? theme.colorScheme.error;
    final badgeTextColor = textColor ?? theme.colorScheme.onError;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: alignment == Alignment.topRight ? -4 : null,
          top: alignment == Alignment.topRight || alignment == Alignment.topLeft
              ? -4
              : null,
          left: alignment == Alignment.topLeft ? -4 : null,
          bottom: alignment == Alignment.bottomRight ||
                  alignment == Alignment.bottomLeft
              ? -4
              : null,
          child: Container(
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: BoxConstraints(
              minWidth: size ?? 20,
              minHeight: size ?? 20,
            ),
            child: Center(
              child: label != null
                  ? Text(
                      label!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : SizedBox(
                      width: size ?? 8,
                      height: size ?? 8,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar component with fallback support
class CEAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? child;
  final VoidCallback? onTap;

  const CEAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.primary;
    final effectiveForegroundColor =
        foregroundColor ?? theme.colorScheme.onPrimary;

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: effectiveBackgroundColor,
      foregroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      child: child ??
          (name != null
              ? Text(
                  _getInitials(name!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: effectiveForegroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Icon(
                  Icons.person,
                  color: effectiveForegroundColor,
                  size: radius * 0.8,
                )),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '';
  }
}

/// Chip component for tags and filters
class CEChip extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onDeleted;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final double? elevation;
  final EdgeInsetsGeometry? padding;
  final bool isSelected;

  const CEChip({
    super.key,
    required this.label,
    this.onPressed,
    this.onDeleted,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.elevation,
    this.padding,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor = backgroundColor ??
        (isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.2)
            : theme.colorScheme.surfaceContainerHighest);
    final effectiveForegroundColor = foregroundColor ??
        (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface);

    return Material(
      color: effectiveBackgroundColor,
      elevation: elevation ?? (isSelected ? 2 : 0),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: effectiveForegroundColor,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: effectiveForegroundColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (onDeleted != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDeleted,
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: effectiveForegroundColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress indicator component
class CEProgressIndicator extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final Color? backgroundColor;
  final Color? valueColor;
  final double height;
  final double borderRadius;
  final String? label;
  final bool showPercentage;

  const CEProgressIndicator({
    super.key,
    required this.value,
    this.backgroundColor,
    this.valueColor,
    this.height = 8,
    this.borderRadius = 4,
    this.label,
    this.showPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.2);
    final effectiveValueColor = valueColor ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showPercentage)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: theme.textTheme.labelMedium,
                ),
              if (showPercentage)
                Text(
                  '${(value * 100).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        if (label != null || showPercentage) const SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: effectiveBackgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: effectiveValueColor,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Empty state component
class CEEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final double iconSize;

  const CEEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
