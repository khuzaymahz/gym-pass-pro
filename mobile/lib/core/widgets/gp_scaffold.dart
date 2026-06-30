import 'package:flutter/material.dart';

import 'help_button.dart';

/// Single composition point for the draggable help button.
///
/// Pass [tips] and [GpScaffold] automatically overlays a [DraggableHelpButton]
/// on top of [body] — screens never touch Stack layout or positioning.
/// Omit [tips] for a plain [Scaffold] with no help affordance.
///
/// The button's position and hide-state are shared across screens via
/// Riverpod providers in `help_button.dart`, so it persists wherever the
/// user left it.
class GpScaffold extends StatelessWidget {
  const GpScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.tips,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final List<HelpTip>? tips;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    final Widget effectiveBody = tips != null && tips!.isNotEmpty
        ? Stack(children: [body, DraggableHelpButton(tips: tips!)])
        : body;

    return Scaffold(
      appBar: appBar,
      body: effectiveBody,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      extendBody: extendBody,
    );
  }
}
