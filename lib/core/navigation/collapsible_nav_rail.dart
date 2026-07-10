import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'shell_nav_item.dart';

const double _kCollapsedWidth = 84;

// Matches ShellNavDrawer's fixed Drawer(width: 290) exactly, so the rail's
// expanded state and the phone drawer are dimensionally the same component.
const double _kExpandedWidth = 290;
const double _kHeaderLabelWidth = 150;

// The width left for [gap + label/subtitle + trailing badge] once the item
// row's fixed chrome is subtracted from the expanded rail width — the same
// number ShellNavDrawer's item Row ends up with after its own icon box:
// expanded width (290) minus the ListView's horizontal padding (12*2)
// minus the item's own horizontal padding (14*2) minus the 38px icon box
// = 200, minus a further ~8px safety margin. That margin isn't slack for
// its own sake: `BoxDecoration.border` makes `Container` implicitly inset
// its child by the border's stroke width, on top of any explicit padding
// — the rail's own outer 1.5px right border, plus a selected item's own
// 1.2px `Border.all`, eat 1.5 + 2*1.2 = 3.9px that a naive "290 - paddings
// - icon" budget doesn't see. An exact-fit (zero slack) budget is exactly
// as fragile as that 3.9px implies: it did overflow, by exactly 3.9px, on
// a selected item.
const double _kExpandedContentWidth = 200 - AppSpacing.xs;
const double _kCollapsedItemPadding = AppSpacing.xxs;
const double _kExpandedItemPadding = AppSpacing.sm + 2;

const Duration _kAnimationDuration = Duration(milliseconds: 200);

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Tablet/desktop navigation chrome: an icons-only rail that expands into
/// icons + labels on demand, per the "collapsible NavigationRail" spec.
///
/// Deliberately hand-rolled instead of wrapping Material's [NavigationRail]
/// — that widget snaps between its `extended` states instead of animating
/// the width smoothly, which is exactly the requirement here.
///
/// Expanded, this is dimensionally and stylistically identical to
/// [ShellNavDrawer] (the phone equivalent): same width, same item/header/
/// footer measurements, same rounded outer corner — just with a collapse
/// animation the drawer doesn't need.
///
/// Every animated dimension (rail width, item padding, label reveal width,
/// label opacity) is driven off a single [AnimationController] and computed
/// in one [AnimatedBuilder] pass, rather than each living in its own
/// separate `AnimatedContainer`/`AnimatedOpacity`. That's not a style
/// choice — several independent implicit animations, even with matching
/// duration and curve, turned out not to stay perfectly synchronized frame
/// to frame (Flutter schedules each one's internal controller separately);
/// the resulting few-pixel mismatches mid-transition were enough to
/// overflow a Row that has zero slack at full width by design (it's sized
/// to match the drawer exactly). Deriving every value from the same `t`
/// in the same build call makes that class of drift structurally
/// impossible.
class CollapsibleNavRail extends StatefulWidget {
  final List<ShellNavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onLogout;

  const CollapsibleNavRail({
    super.key,
    required this.navItems,
    required this.selectedIndex,
    required this.onSelect,
    required this.expanded,
    required this.onToggle,
    required this.onLogout,
  });

  @override
  State<CollapsibleNavRail> createState() => _CollapsibleNavRailState();
}

class _CollapsibleNavRailState extends State<CollapsibleNavRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kAnimationDuration,
    value: widget.expanded ? 1 : 0,
  );

  @override
  void didUpdateWidget(CollapsibleNavRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      _controller.animateTo(
        widget.expanded ? 1 : 0,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double t = _controller.value;
        final double railWidth = _lerp(_kCollapsedWidth, _kExpandedWidth, t);
        final double itemPadding = _lerp(
          _kCollapsedItemPadding,
          _kExpandedItemPadding,
          t,
        );
        final double contentReveal = _lerp(0, _kExpandedContentWidth, t);
        final double headerReveal = _lerp(0, _kHeaderLabelWidth, t);

        return Container(
          width: railWidth,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.backgroundStart, AppColors.backgroundEnd],
            ),
            //borderRadius: const BorderRadius.horizontal(right: Radius.circular(AppRadius.xl)),
            border: Border(
              right: BorderSide(
                color: AppColors.surfaceBorder.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
          ),
          child: ClipRect(
            child: SafeArea(
              child: Column(
                children: [
                  _RailHeader(
                    expanded: widget.expanded,
                    horizontalPadding: _lerp(AppSpacing.xs, AppSpacing.lg, t),
                    revealedWidth: headerReveal,
                    opacity: t,
                  ),
                  _ToggleButton(
                    expanded: widget.expanded,
                    onToggle: widget.onToggle,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Divider(
                      height: 1,
                      color: AppColors.surfaceBorder.withValues(alpha: 0.8),
                    ),
                  ),
                  AnimatedSize(
                    duration: _kAnimationDuration,
                    curve: Curves.easeOutCubic,
                    child: widget.expanded
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                              vertical: AppSpacing.xxs,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'STRUMENTI',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      letterSpacing: 1.8,
                                      color: AppColors.textMuted.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                              ),
                            ),
                          )
                        : const SizedBox(height: AppSpacing.sm),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final item in widget.navItems)
                          _RailItem(
                            item: item,
                            selected:
                                !item.isComingSoon &&
                                item.destinationIndex == widget.selectedIndex,
                            itemPadding: itemPadding,
                            contentReveal: contentReveal,
                            opacity: t,
                            onTap: item.isComingSoon
                                ? null
                                : () => widget.onSelect(item.destinationIndex!),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: _RailLogoutButton(
                      itemPadding: itemPadding,
                      contentReveal: contentReveal,
                      opacity: t,
                      onTap: widget.onLogout,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reveals [child] by animating a clipping viewport ([revealedWidth], 0 up
/// to [naturalWidth]) rather than animating the child's own layout width.
/// [child] is always laid out at the full, constant [naturalWidth] via
/// [OverflowBox] — it never has to react to how much of the viewport has
/// opened so far, so it can never be squeezed below what it needs.
class _RevealPanel extends StatelessWidget {
  final double revealedWidth;
  final double naturalWidth;
  final double opacity;
  final Widget child;

  const _RevealPanel({
    required this.revealedWidth,
    required this.naturalWidth,
    required this.opacity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: revealedWidth,
        child: IntrinsicHeight(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: naturalWidth,
            maxWidth: naturalWidth,
            child: Opacity(opacity: opacity, child: child),
          ),
        ),
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  final bool expanded;
  final double horizontalPadding;
  final double revealedWidth;
  final double opacity;

  const _RailHeader({
    required this.expanded,
    required this.horizontalPadding,
    required this.revealedWidth,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          _RevealPanel(
            revealedWidth: revealedWidth,
            naturalWidth: _kHeaderLabelWidth,
            opacity: opacity,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm + 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Beatter',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'Rhythm Training',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _ToggleButton({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: expanded ? Alignment.centerRight : Alignment.center,
      child: Padding(
        padding: EdgeInsets.only(right: expanded ? AppSpacing.xs : 0),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: expanded ? 'Comprimi menu' : 'Espandi menu',
            onPressed: onToggle,
            icon: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: _kAnimationDuration,
              child: const Icon(
                Icons.menu_open_rounded,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rail's item, expanded, is dimensionally and stylistically identical
/// to [ShellNavDrawer]'s nav item (same 38x38 icon box, same label/subtitle
/// typography, same "Soon" badge / active dot) — only the collapse-to-
/// icon-only transition is rail-specific.
class _RailItem extends StatelessWidget {
  final ShellNavItem item;
  final bool selected;
  final double itemPadding;
  final double contentReveal;
  final double opacity;
  final VoidCallback? onTap;

  const _RailItem({
    required this.item,
    required this.selected,
    required this.itemPadding,
    required this.contentReveal,
    required this.opacity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Opacity(
        opacity: item.isComingSoon ? 0.6 : 1.0,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            onTap: onTap,
            splashColor: AppColors.primary.withValues(alpha: 0.1),
            highlightColor: AppColors.primary.withValues(alpha: 0.06),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: itemPadding,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md + 2),
                border: selected
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 1.2,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surfaceBorder.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                    ),
                    child: Icon(
                      selected ? (item.selectedIcon ?? item.icon) : item.icon,
                      size: 20,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  _RevealPanel(
                    revealedWidth: contentReveal,
                    naturalWidth: _kExpandedContentWidth,
                    opacity: opacity,
                    child: Row(
                      children: [
                        const SizedBox(width: AppSpacing.sm + 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (item.subtitle != null)
                                Text(
                                  item.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: selected
                                        ? AppColors.primary.withValues(
                                            alpha: 0.7,
                                          )
                                        : AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (item.isComingSoon)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBorder.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.sm - 2,
                              ),
                              border: Border.all(
                                color: AppColors.textMuted.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Text(
                              'Soon',
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                              ),
                            ),
                          )
                        else if (selected)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mirrors [ShellNavDrawer]'s boxed, tinted logout button exactly when
/// expanded (same 38x38 icon box, same padding/typography); collapses to
/// an icon-only tile like the other rail items.
class _RailLogoutButton extends StatelessWidget {
  final double itemPadding;
  final double contentReveal;
  final double opacity;
  final VoidCallback onTap;

  const _RailLogoutButton({
    required this.itemPadding,
    required this.contentReveal,
    required this.opacity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md + 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: itemPadding,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.15),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: AppColors.error,
                ),
              ),
              _RevealPanel(
                revealedWidth: contentReveal,
                naturalWidth: _kExpandedContentWidth,
                opacity: opacity,
                child: Row(
                  children: [
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Text(
                        'Logout',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
