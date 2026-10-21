/// The one place where Android and iOS part ways (DESIGN.md PL3): helpers
/// such as `showMiserendDialog` that pick the platform's own element from
/// `Theme.of(context).platform`, so that no screen branches by platform. The
/// page transitions, the touch feedback and the back button's icon are the
/// theme's (`miserendTheme`).
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';

/// Whether [context] is on iOS (or macOS), where the Cupertino side of PL2
/// applies.
bool _isCupertino(BuildContext context) => switch (Theme.of(context).platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => true,
  _ => false,
};

/// The tap of a switch, a radio button or a picker (DESIGN.md PL2): a light
/// haptic tap on iOS; nothing on Android, whose controls give their own
/// where the system does.
void miserendSelectionHaptic(BuildContext context) {
  if (_isCupertino(context)) unawaited(HapticFeedback.lightImpact());
}

/// A radio button row inside a [RadioGroup] (DESIGN.md PL2): the M3
/// [RadioListTile] on Android; on iOS, the [CupertinoRadio] raised and
/// enlarged, since at its own 14 dp with a hairline edge it hardly shows on
/// a light page (MÉ2). It is on in the selection colour on both (SZ4).
class MiserendRadioTile<T> extends StatelessWidget {
  const MiserendRadioTile({
    super.key,
    required this.value,
    required this.title,
    this.contentPadding,
  });

  final T value;
  final Widget title;
  final EdgeInsetsGeometry? contentPadding;

  /// The iOS radio's diameter: an icon's size (IK3), where its own is 14.
  static const double _cupertinoDiameter = 24;

  /// The diameter [CupertinoRadio] draws itself at.
  static const double _cupertinoOwnDiameter = 14;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_isCupertino(context)) {
      return RadioListTile<T>(
        value: value,
        title: title,
        activeColor: scheme.primary,
        contentPadding: contentPadding,
      );
    }
    return ListTile(
      contentPadding: contentPadding,
      leading: Material(
        type: MaterialType.circle,
        elevation: 1,
        color: scheme.surface,
        child: SizedBox.square(
          dimension: _cupertinoDiameter,
          child: Transform.scale(
            scale: _cupertinoDiameter / _cupertinoOwnDiameter,
            child: CupertinoRadio<T>(value: value, activeColor: scheme.primary),
          ),
        ),
      ),
      title: title,
      onTap: () => RadioGroup.maybeOf<T>(context)?.onChanged(value),
    );
  }
}

/// The system icons of PL2: Material's rounded one on Android (IK1), the
/// [CupertinoIcons] one on iOS. The back button takes its icon from the theme.
enum SystemIcon {
  back(Icons.arrow_back_rounded, CupertinoIcons.back),
  share(Icons.share_rounded, CupertinoIcons.share),
  more(Icons.more_vert_rounded, CupertinoIcons.ellipsis),
  close(Icons.close_rounded, CupertinoIcons.xmark);

  const SystemIcon(this._material, this._cupertino);

  final IconData _material;
  final IconData _cupertino;

  /// This icon on [context]'s platform.
  IconData of(BuildContext context) =>
      _isCupertino(context) ? _cupertino : _material;
}

/// A button of [showMiserendDialog]: its [label] is a verb (KO14), and
/// tapping it closes the dialog with [value].
class MiserendDialogAction<T> {
  const MiserendDialogAction(this.label, this.value);

  final String label;
  final T value;
}

/// A dialog has at most two buttons (DESIGN.md KO14).
const int _maxDialogActions = 2;

/// A dialog (DESIGN.md KO14): the M3 [AlertDialog] on Android, a
/// [CupertinoAlertDialog] on iOS. It closes with the value of the tapped
/// action, or null when dismissed without one. The last action is the
/// default one, the way both platforms put the confirming button last.
Future<T?> showMiserendDialog<T>(
  BuildContext context, {
  String? title,
  required String content,
  required List<MiserendDialogAction<T>> actions,
  bool? barrierDismissible,
}) {
  assert(
    actions.isNotEmpty && actions.length <= _maxDialogActions,
    'A dialog has one or two buttons (DESIGN.md KO14).',
  );
  return showAdaptiveDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder:
        (context) => AlertDialog.adaptive(
          title: title == null ? null : Text(title),
          content: Text(content),
          // A long explanation at a large text size scrolls rather than
          // overflowing (EH4); the Cupertino dialog scrolls by itself.
          scrollable: true,
          actions: [
            for (final (index, action) in actions.indexed)
              _isCupertino(context)
                  ? CupertinoDialogAction(
                    isDefaultAction: index == actions.length - 1,
                    onPressed: () => Navigator.of(context).pop(action.value),
                    child: Text(action.label),
                  )
                  : TextButton(
                    onPressed: () => Navigator.of(context).pop(action.value),
                    child: Text(action.label),
                  ),
          ],
        ),
  );
}

/// A choice of [showMiserendActionSheet]: [leading] (an icon or a flag)
/// before the [label], and the [value] the sheet closes with.
class MiserendSheetAction<T> {
  const MiserendSheetAction({
    required this.label,
    required this.value,
    this.leading,
  });

  final String label;
  final T value;
  final Widget? leading;
}

/// A sheet over the navigation bar (DESIGN.md KO13, NA1) with an optional
/// [title] and [message] above its [actions]: the M3 modal bottom sheet with
/// a drag handle and `Radii.xl` corners on Android, a [CupertinoActionSheet]
/// with a „Mégse" button on iOS. It closes with the value of the chosen
/// action, or null when dismissed without one. With no actions, it only
/// shows the [title] and the [message]. The [title] comes in the caller's
/// text role (TI2).
Future<T?> showMiserendActionSheet<T>(
  BuildContext context, {
  Widget? title,
  Widget? message,
  List<MiserendSheetAction<T>> actions = const [],
}) async {
  if (!_isCupertino(context)) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (title != null || message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.l,
                      0,
                      Spacing.l,
                      Spacing.l,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null) title,
                        if (title != null && message != null)
                          const SizedBox(height: Spacing.s),
                        if (message != null) message,
                      ],
                    ),
                  ),
                for (final action in actions)
                  ListTile(
                    leading: action.leading,
                    title: Text(action.label),
                    onTap: () => Navigator.of(context).pop(action.value),
                  ),
              ],
            ),
          ),
    );
  }
  return _tapOnPick(
    showCupertinoModalPopup<T>(
      context: context,
      builder:
          (context) => CupertinoActionSheet(
            title: title,
            message: message,
            actions: [
              for (final action in actions)
                CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(action.value),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (action.leading case final leading?) ...[
                        leading,
                        const SizedBox(width: Spacing.s),
                      ],
                      Flexible(child: Text(action.label)),
                    ],
                  ),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(actions.isEmpty ? 'Bezárás' : 'Mégse'),
            ),
          ),
    ),
  );
}

/// Closes a picker on iOS (DESIGN.md PL2): a light haptic tap once the user
/// has picked something, none when they cancel.
Future<T?> _tapOnPick<T>(Future<T?> pick) async {
  final picked = await pick;
  if (picked != null) await HapticFeedback.lightImpact();
  return picked;
}

/// A day between [firstDate] and [lastDate] (DESIGN.md PL2): the M3 date
/// picker on Android, a [CupertinoDatePicker] in a sheet on iOS. Null when
/// the user cancels. [helpText] names what the day is for.
Future<DateTime?> pickMiserendDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  if (!_isCupertino(context)) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      cancelText: 'Mégse',
      confirmText: 'Kész',
    );
  }
  return _showCupertinoPicker<DateTime>(
    context,
    title: helpText,
    initialValue: initialDate,
    picker:
        (onChanged) => CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: initialDate,
          minimumDate: firstDate,
          maximumDate: lastDate,
          onDateTimeChanged: onChanged,
        ),
  );
}

/// A time of day, always on the 24-hour clock as Hungarian has it (DESIGN.md
/// PL2): the M3 time picker on Android, a [CupertinoDatePicker] in a sheet
/// on iOS. Null when the user cancels.
Future<TimeOfDay?> pickMiserendTime(
  BuildContext context, {
  required TimeOfDay initialTime,
}) async {
  if (!_isCupertino(context)) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      cancelText: 'Mégse',
      confirmText: 'Kész',
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
    );
  }
  final initial = DateTime(2000, 1, 1, initialTime.hour, initialTime.minute);
  final picked = await _showCupertinoPicker<DateTime>(
    context,
    initialValue: initial,
    picker:
        (onChanged) => CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          use24hFormat: true,
          initialDateTime: initial,
          onDateTimeChanged: onChanged,
        ),
  );
  return picked == null ? null : TimeOfDay.fromDateTime(picked);
}

/// The height of the wheels, the iOS picker's own.
const double _cupertinoPickerHeight = 216;

/// A Cupertino [picker] in a sheet from the bottom, with „Mégse" and „Kész"
/// above it, as iOS shows one. „Kész" closes it with the value last turned
/// to, starting from [initialValue].
Future<T?> _showCupertinoPicker<T>(
  BuildContext context, {
  String? title,
  required T initialValue,
  required Widget Function(ValueChanged<T> onChanged) picker,
}) async {
  var value = initialValue;
  return _tapOnPick(
    showCupertinoModalPopup<T>(
      context: context,
      builder:
          // The M3 bottom sheet's own surface, the same on both platforms.
          (context) => Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Mégse'),
                      ),
                      Expanded(
                        child: Text(
                          title ?? '',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.sectionTitle,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(value),
                        child: const Text('Kész'),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: _cupertinoPickerHeight,
                    child: picker((changed) => value = changed),
                  ),
                ],
              ),
            ),
          ),
    ),
  );
}

/// Opens a task flow such as the Hibajelentés (DESIGN.md NA2): a modal sheet
/// on iOS, a full-screen dialog on Android. Either covers the navigation bar,
/// so it goes on the root navigator rather than the tab's own (NA1).
Future<T?> pushMiserendTaskFlow<T>(
  BuildContext context,
  WidgetBuilder builder,
) {
  final PageRoute<T> route = switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => CupertinoSheetRoute<T>(
      // The sheet hands over its controller so that the page's list drags
      // the sheet down once scrolled to the top.
      scrollableBuilder:
          (context, controller) => PrimaryScrollController(
            controller: controller,
            child: builder(context),
          ),
    ),
    _ => MaterialPageRoute<T>(builder: builder, fullscreenDialog: true),
  };
  return Navigator.of(context, rootNavigator: true).push(route);
}

/// A tab of [MiserendNavigationBar]: the outlined [icon] (DESIGN.md IK2),
/// filled as [selectedIcon] while the tab is on screen. An icon with no
/// rounded outline has no [selectedIcon] and stays as it is.
class MiserendDestination {
  const MiserendDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });

  final Widget icon;
  final Widget? selectedIcon;
  final String label;
}

/// The bottom navigation (DESIGN.md KO16): the M3 [NavigationBar] in its own
/// colours on Android, a [CupertinoTabBar] on iOS. The labels always show
/// (NA6).
class MiserendNavigationBar extends StatelessWidget {
  const MiserendNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<MiserendDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Where the M3 [NavigationBar] stops growing its labels.
  static const double _maxLabelTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (theme.platform) {
      // The labels grow with the text up to the M3 bar's own limit (DESIGN.md
      // AM4): at 2.0, a quarter of a 320 dp screen broke „Templomok" in two,
      // and the bar's fixed height overflowed.
      TargetPlatform.iOS ||
      TargetPlatform.macOS => MediaQuery.withClampedTextScaling(
        maxScaleFactor: _maxLabelTextScale,
        child: CupertinoTabBar(
          items: [
            for (final destination in destinations)
              BottomNavigationBarItem(
                icon: destination.icon,
                activeIcon: destination.selectedIcon,
                label: destination.label,
              ),
          ],
          currentIndex: selectedIndex,
          onTap: onDestinationSelected,
          activeColor: theme.colorScheme.primary,
          inactiveColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      _ => NavigationBar(
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: destination.icon,
              selectedIcon: destination.selectedIcon,
              label: destination.label,
            ),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    };
  }
}
