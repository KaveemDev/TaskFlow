import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Shared building blocks for the redesigned screens (see the TaskFlow Redesign canvas).

const kScreenPadding = EdgeInsets.symmetric(horizontal: 20);

/// "Thursday, 5 November" over a 30 px title, with optional actions on the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) ...[
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  style: theme.textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 4), a],
        ],
      ),
    );
  }
}

/// 44 px bordered square icon button used in screen headers.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Monday-to-Sunday strip; the selected day is filled with the accent.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selected,
    required this.onSelected,
    this.hasItems,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final bool Function(DateTime day)?
  hasItems; // shows a dot under busy days when set

  static DateTime mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monday = mondayOf(selected);
    return Padding(
      padding: kScreenPadding,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _day(theme, addDays(monday, i)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _day(ThemeData theme, DateTime day) {
    final isSelected = DateUtils.isSameDay(day, selected);
    final fg = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final showDot = hasItems != null;
    return Semantics(
      button: true,
      selected: isSelected,
      label: DateFormat('EEEE d MMMM').format(day),
      excludeSemantics: true,
      child: Material(
        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(day);
          },
          child: SizedBox(
            height: showDot ? 62 : 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('E').format(day),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: fg.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                if (showDot) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasItems!(day)
                          ? (isSelected
                                ? fg
                                : theme.colorScheme.onSurfaceVariant)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 13 px section label above a card ("Overdue · 1").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// White card with hairlines between its rows.
class GroupedCard extends StatelessWidget {
  const GroupedCard({super.key, required this.children, this.padding});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Round checkbox: ring when open, accent fill with a tick when done.
class RoundCheck extends StatelessWidget {
  const RoundCheck({
    super.key,
    required this.checked,
    required this.onChanged,
    this.size = 24,
    this.square = false,
  });
  final bool checked;
  final VoidCallback onChanged;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      checked: checked,
      label: checked ? 'Mark not done' : 'Mark done',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onChanged,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(
            10,
          ), // 44 px hit area around the 24 px circle
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: square ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: square ? BorderRadius.circular(6) : null,
              color: checked ? theme.colorScheme.primary : Colors.transparent,
              border: Border.all(
                color: checked
                    ? theme.colorScheme.primary
                    : AppColors.of(context).ring,
                width: 1.5,
              ),
            ),
            child: checked
                ? Icon(
                    Icons.check_rounded,
                    size: size * 0.6,
                    color: theme.colorScheme.onPrimary,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Calendar-day arithmetic; unlike Duration(days:) it is not thrown off by daylight-saving changes.
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// "1 h 15 min" style durations.
String formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
