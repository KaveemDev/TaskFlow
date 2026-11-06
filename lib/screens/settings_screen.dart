import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../widgets/segmented_control.dart';
import '../widgets/ui.dart';
import 'widget_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final status = await Permission.notification.status;
    setState(() {
      _notificationsEnabled = status.isGranted;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    HapticFeedback.lightImpact();
    if (value) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        setState(() => _notificationsEnabled = true);
      } else if (status.isPermanentlyDenied) {
        openAppSettings();
      } else {
        setState(() => _notificationsEnabled = false);
      }
    } else {
      openAppSettings();
      setState(() => _notificationsEnabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final accent = ref.watch(accentProvider);
    final user = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);
    final theme = Theme.of(context);
    final name = user?.displayName ?? 'Kaveem Uddin';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          children:
              [
                    const ScreenHeader(title: 'Settings'),
                    const SizedBox(height: 20),
                    _card(
                      theme,
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                name.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  if (user?.email != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      user!.email!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    _sectionLabel(theme, 'Appearance'),
                    _card(
                      theme,
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Mode', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 10),
                            SegmentedControl<ThemeMode>(
                              value: themeMode,
                              options: const {
                                ThemeMode.system: 'System',
                                ThemeMode.light: 'Light',
                                ThemeMode.dark: 'Dark',
                              },
                              onChanged: (m) =>
                                  ref.read(themeProvider.notifier).setTheme(m),
                            ),
                            const SizedBox(height: 18),
                            Text('Theme', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                for (final a in AccentTheme.values) ...[
                                  if (a != AccentTheme.values.first)
                                    const SizedBox(width: 8),
                                  Expanded(
                                    child: _accentOption(theme, a, a == accent),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    _sectionLabel(theme, 'Home screen'),
                    _card(
                      theme,
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        leading: Icon(
                          LucideIcons.layoutGrid,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        minLeadingWidth: 20,
                        title: Text(
                          'Widgets',
                          style: theme.textTheme.titleMedium,
                        ),
                        trailing: Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WidgetSettingsScreen(),
                          ),
                        ),
                      ),
                    ),
                    _sectionLabel(theme, 'Notifications'),
                    _card(
                      theme,
                      Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            title: Text(
                              'Task and timer reminders',
                              style: theme.textTheme.titleMedium,
                            ),
                            value: _notificationsEnabled,
                            onChanged: _toggleNotifications,
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            title: Text(
                              'Send a test notification',
                              style: theme.textTheme.titleMedium,
                            ),
                            trailing: Icon(
                              LucideIcons.chevronRight,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              await NotificationService()
                                  .showTestNotification();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test notification sent'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(color: theme.colorScheme.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: theme.textTheme.labelLarge,
                        ),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          await authNotifier.signOut();
                        },
                        child: const Text('Log out'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Kronom 1.0.0',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ]
                  .map(
                    (w) => w is ScreenHeader
                        ? w
                        : Padding(padding: kScreenPadding, child: w),
                  )
                  .toList(),
        ),
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
    child: Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _card(ThemeData theme, Widget child) =>
      Card(clipBehavior: Clip.antiAlias, child: child);

  Widget _accentOption(ThemeData theme, AccentTheme a, bool selected) {
    final color = theme.brightness == Brightness.dark ? a.dark : a.light;
    return Semantics(
      selected: selected,
      button: true,
      label: '${a.label} theme',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(accentProvider.notifier).setAccent(a);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color,
                child: selected
                    ? Icon(
                        LucideIcons.check,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                a.label,
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
