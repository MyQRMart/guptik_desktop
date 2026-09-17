import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_chrome.dart';

class WindowHeader extends StatefulWidget {
  final String title;
  const WindowHeader({this.title = 'GupTik', super.key});

  @override
  State<WindowHeader> createState() => _WindowHeaderState();
}

class _WindowHeaderState extends State<WindowHeader> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _isMaximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Chrome.titleBarH,
      color: Chrome.titleBar,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Image.asset(
            'lib/assets/logonobg.png',
            width: 16,
            height: 16,
            errorBuilder: (_, _, _) => Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: Chrome.accent, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: const TextStyle(fontSize: 12, color: Chrome.fg, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          _WinBtn(icon: LucideIcons.minus, onPressed: () => windowManager.minimize(), tooltip: 'Minimize'),
          _WinBtn(
            icon: _isMaximized ? LucideIcons.copy : LucideIcons.square,
            onPressed: () => _isMaximized ? windowManager.unmaximize() : windowManager.maximize(),
            tooltip: _isMaximized ? 'Restore' : 'Maximize',
          ),
          _WinBtn(icon: LucideIcons.x, onPressed: () => windowManager.close(), tooltip: 'Close', isClose: true),
        ],
      ),
    );
  }
}

class _WinBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isClose;
  const _WinBtn({required this.icon, required this.onPressed, required this.tooltip, this.isClose = false});

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Tooltip(
          message: widget.tooltip,
          child: Container(
            width: 46,
            height: Chrome.titleBarH,
            color: _hover ? (widget.isClose ? Chrome.closeHover : Colors.white.withValues(alpha: 0.08)) : Colors.transparent,
            child: Icon(widget.icon, size: 12, color: _hover && widget.isClose ? Colors.white : Chrome.fg),
          ),
        ),
      ),
    );
  }
}
