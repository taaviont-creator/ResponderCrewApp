import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared page bounds; scrolling and state remain owned by each screen.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.contentMaxWidth = 1120,
  });
  final PreferredSizeWidget? appBar;
  final Widget? body, floatingActionButton, bottomNavigationBar;
  final double contentMaxWidth;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: body == null
        ? null
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: body,
              ),
            ),
          ),
    floatingActionButton: floatingActionButton,
    bottomNavigationBar: bottomNavigationBar,
  );
}

/// One scroll surface: stacked on phones, two purposeful columns on desktop.
class ResponsiveSections extends StatelessWidget {
  const ResponsiveSections({
    super.key,
    this.header = const [],
    required this.primary,
    required this.secondary,
  });
  final List<Widget> header, primary, secondary;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide =
          bounds.maxWidth >= 1000 &&
          MediaQuery.textScalerOf(context).scale(16) < 24;
      return ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          ...header,
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: primary,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: secondary,
                  ),
                ),
              ],
            )
          else ...[
            ...primary,
            ...secondary,
          ],
          const SizedBox(height: 24),
        ],
      );
    },
  );
}

/// Disclosure of related settings without adding another navigation level.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.initiallyExpanded = false,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ExpansionTile(
        key: PageStorageKey(title),
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: children,
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.onOpen});
  final String title;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final titleWidget = Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      );
      final action = onOpen == null
          ? null
          : TextButton(onPressed: onOpen, child: const Text('Vaata kõiki'));
      if (bounds.maxWidth < 360 ||
          MediaQuery.textScalerOf(context).scale(16) >= 24) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [titleWidget, ?action],
        );
      }
      return Row(
        children: [
          Expanded(child: titleWidget),
          ?action,
        ],
      );
    },
  );
}

/// Wrap child sized from available content width, including large-text fallback.
class MetricValue extends StatelessWidget {
  const MetricValue({super.key, required this.title, required this.value});
  final String title, value;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns = MediaQuery.textScalerOf(context).scale(16) >= 24
          ? 1
          : bounds.maxWidth >= 900
          ? 4
          : 2;
      return SizedBox(
        width: (bounds.maxWidth - (columns - 1) * 8) / columns,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(title),
            ],
          ),
        ),
      );
    },
  );
}
