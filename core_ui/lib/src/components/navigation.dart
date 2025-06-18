import 'dart:ui';
import 'package:flutter/material.dart';

/// Connect-Ed styled app bar with blur effects and animations
class CEAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final bool hasBlur;
  final PreferredSizeWidget? bottom;

  const CEAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = false,
    this.onBackPressed,
    this.centerTitle = false,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 0,
    this.hasBlur = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.surface;
    final effectiveForegroundColor =
        foregroundColor ?? theme.colorScheme.onSurface;

    Widget appBar = AppBar(
      title: Text(
        title,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: effectiveForegroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: hasBlur ? Colors.transparent : effectiveBackgroundColor,
      foregroundColor: effectiveForegroundColor,
      leading: leading ??
          (showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                )
              : null),
      actions: actions,
      bottom: bottom,
    );

    if (hasBlur) {
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: effectiveBackgroundColor.withValues(alpha: 0.8),
            ),
            child: appBar,
          ),
        ),
      );
    }

    return appBar;
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}

/// Bottom navigation bar with blur effect matching Connect-Ed design
class CEBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final List<CEBottomNavItem> items;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final bool hasBlur;

  const CEBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.items,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.hasBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.tertiary.withValues(alpha: 0.6);
    final effectiveSelectedColor =
        selectedItemColor ?? theme.colorScheme.primary;
    final effectiveUnselectedColor = unselectedItemColor ??
        theme.colorScheme.onSurface.withValues(alpha: 0.6);

    Widget navBar = Container(
      decoration: BoxDecoration(
        color: hasBlur ? Colors.transparent : effectiveBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == selectedIndex;

              return GestureDetector(
                onTap: () => onIndexChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? effectiveSelectedColor.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected
                            ? effectiveSelectedColor
                            : effectiveUnselectedColor,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? effectiveSelectedColor
                              : effectiveUnselectedColor,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );

    if (hasBlur) {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: effectiveBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
            ),
            child: navBar,
          ),
        ),
      );
    }

    return navBar;
  }
}

/// Bottom navigation item model
class CEBottomNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const CEBottomNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// Drawer with Connect-Ed styling
class CEDrawer extends StatelessWidget {
  final Widget? header;
  final List<CEDrawerItem> items;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  const CEDrawer({
    super.key,
    this.header,
    required this.items,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            if (header != null) ...[
              header!,
              const Divider(),
            ],
            Expanded(
              child: ListView(
                padding: padding,
                children: items
                    .map((item) => _buildDrawerItem(context, item))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, CEDrawerItem item) {
    final theme = Theme.of(context);

    return ListTile(
      leading: item.icon != null ? Icon(item.icon) : null,
      title: Text(
        item.title,
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
      trailing: item.trailing,
      onTap: item.onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

/// Drawer item model
class CEDrawerItem {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const CEDrawerItem({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
  });
}

/// Tab bar with Connect-Ed styling
class CETabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<String> tabs;
  final int selectedIndex;
  final Function(int) onTabChanged;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? backgroundColor;
  final bool isScrollable;

  const CETabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    this.selectedColor,
    this.unselectedColor,
    this.backgroundColor,
    this.isScrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveSelectedColor = selectedColor ?? theme.colorScheme.primary;
    final effectiveUnselectedColor =
        unselectedColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      color: backgroundColor ?? theme.colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final tab = entry.value;
            final isSelected = index == selectedIndex;

            return GestureDetector(
              onTap: () => onTabChanged(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? effectiveSelectedColor.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: effectiveSelectedColor, width: 1)
                      : null,
                ),
                child: Text(
                  tab,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? effectiveSelectedColor
                        : effectiveUnselectedColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}
