import 'package:flutter/material.dart';

/// VS Code–density chrome. Shared by title bar, module tabs, inner toolbars.
class Chrome {
  Chrome._();

  static const titleBarH = 30.0;
  static const tabBarH = 35.0;
  static const toolbarH = 32.0;

  static const titleBar = Color(0xFF181818);
  static const tabBar = Color(0xFF252526);
  static const editor = Color(0xFF1E1E1E);
  static const sidebar = Color(0xFF181818);
  static const panel = Color(0xFF252526);
  static const border = Color(0xFF2B2B2B);
  static const fg = Color(0xFFCCCCCC);
  static const fgDim = Color(0xFF8A8A8A);
  static const accent = Color(0xFF00E5FF);
  static const closeHover = Color(0xFFE81123);

  static ThemeData dark(TextTheme textTheme) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: editor,
      canvasColor: sidebar,
      dividerColor: border,
      textTheme: textTheme.apply(bodyColor: fg, displayColor: fg),
      useMaterial3: false,
      appBarTheme: const AppBarTheme(
        toolbarHeight: toolbarH,
        backgroundColor: tabBar,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 8,
        titleTextStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
        iconTheme: IconThemeData(size: 16, color: fg),
        actionsIconTheme: IconThemeData(size: 16, color: fg),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: fgDim,
        labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          border: Border(top: BorderSide(color: accent, width: 2)),
          color: editor,
        ),
        dividerColor: border,
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      iconTheme: const IconThemeData(size: 16, color: fg),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
        textStyle: TextStyle(fontSize: 11, color: Colors.white),
      ),
    );
  }
}

PreferredSizeWidget compactAppBar({
  required Widget title,
  List<Widget>? actions,
  Widget? leading,
  Color? backgroundColor,
}) {
  return AppBar(
    toolbarHeight: Chrome.toolbarH,
    backgroundColor: backgroundColor ?? Chrome.tabBar,
    leading: leading,
    leadingWidth: leading == null ? 0 : 36,
    title: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Chrome.fg),
      child: title,
    ),
    titleSpacing: 8,
    actions: actions,
  );
}
