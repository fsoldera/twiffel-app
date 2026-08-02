import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../state/app_settings_controller.dart';
import '../theme/tokens.dart';

/// Top-left hamburger that opens Sound / Vibration / Theme and Buy a license.
/// Structure matches Stikkteller and Joppling [HomeMenuButton].
class HomeMenuButton extends StatefulWidget {
  const HomeMenuButton({
    super.key,
    required this.settings,
  });

  final AppSettingsController settings;

  @override
  State<HomeMenuButton> createState() => _HomeMenuButtonState();
}

class _HomeMenuButtonState extends State<HomeMenuButton> {
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  bool get _isOpen => _overlayEntry != null;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _closeMenu() {
    _removeOverlay();
  }

  void _showOverlay() {
    final anchorContext = _anchorKey.currentContext;
    if (anchorContext == null) return;
    final box = anchorContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return ListenableBuilder(
          listenable: widget.settings,
          builder: (context, _) {
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeMenu,
                  ),
                ),
                Positioned(
                  top: origin.dy + box.size.height + 6,
                  left: origin.dx,
                  child: _SettingsMenuPanel(
                    settings: widget.settings,
                    onSoundChanged: (enabled) async {
                      await widget.settings.setSoundEnabled(enabled);
                    },
                    onVibrationChanged: (enabled) async {
                      await widget.settings.setVibrationEnabled(enabled);
                    },
                    onThemeModeChanged: (mode) async {
                      await widget.settings.setThemeMode(mode);
                    },
                    onBuyLicense: () {
                      _closeMenu();
                      GoRouter.of(anchorContext).pushNamed('shop');
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    Overlay.of(anchorContext).insert(_overlayEntry!);
    if (mounted) setState(() {});
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    return Material(
      key: _anchorKey,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _toggleMenu,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            _isOpen ? Icons.close : Icons.menu,
            size: 32,
            color: colors.textPrimary.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _SettingsMenuPanel extends StatelessWidget {
  const _SettingsMenuPanel({
    required this.settings,
    required this.onSoundChanged,
    required this.onVibrationChanged,
    required this.onThemeModeChanged,
    required this.onBuyLicense,
  });

  final AppSettingsController settings;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onVibrationChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onBuyLicense;

  static const double _width = 300;
  static const double _rowHorizontalPadding = 20;
  static const double _switchTrackEndInset = 4;

  static const Color _panelBg = Color(0xFF1E1E28);
  static const Color _label = Color(0xF2FFFFFF);
  static const Color _divider = Color(0x1FFFFFFF);
  static const Color _muted = Color(0xB3FFFFFF);

  @override
  Widget build(BuildContext context) {
    const accent = TwiffelTokens.primaryDefault;

    return Material(
      elevation: 10,
      color: _panelBg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: _width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: _rowHorizontalPadding,
                vertical: 4,
              ),
              title: const Text(
                'Sound',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _label,
                ),
              ),
              value: settings.soundEnabled,
              activeThumbColor: accent,
              activeTrackColor: accent.withValues(alpha: 0.45),
              onChanged: onSoundChanged,
            ),
            const Divider(height: 1, color: _divider),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: _rowHorizontalPadding,
                vertical: 4,
              ),
              title: const Text(
                'Vibration',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _label,
                ),
              ),
              value: settings.vibrationEnabled,
              activeThumbColor: accent,
              activeTrackColor: accent.withValues(alpha: 0.45),
              onChanged: onVibrationChanged,
            ),
            const Divider(height: 1, color: _divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _rowHorizontalPadding,
                12,
                _rowHorizontalPadding,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _label,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Light, Dark, or match the phone',
                    style: TextStyle(
                      fontSize: 12,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('Auto'),
                      ),
                    ],
                    selected: <ThemeMode>{settings.themeMode},
                    onSelectionChanged: (selected) {
                      if (selected.isEmpty) return;
                      onThemeModeChanged(selected.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      foregroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return _muted;
                      }),
                      backgroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return accent;
                        }
                        return const Color(0x14FFFFFF);
                      }),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: _divider),
                      ),
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _rowHorizontalPadding,
                4,
                _rowHorizontalPadding + _switchTrackEndInset,
                4,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: onBuyLicense,
                  style: FilledButton.styleFrom(
                    backgroundColor: appLicenseConfig.theme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(appLicenseConfig.unlockButtonText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
