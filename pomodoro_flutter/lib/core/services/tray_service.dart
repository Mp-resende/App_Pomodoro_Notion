import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  bool _initialized = false;
  VoidCallback? onPlayPausePressed;

  Future<void> inicializar({VoidCallback? onPlayPause}) async {
    if (_initialized || !Platform.isWindows) return;
    onPlayPausePressed = onPlayPause;

    try {
      await trayManager.setIcon(
        'assets/app_icon.ico',
      );

      final Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Abrir Pomodoro',
          ),
          MenuItem(
            key: 'play_pause',
            label: 'Pausar / Iniciar',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Sair',
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
      trayManager.addListener(this);
      _initialized = true;
    } catch (e) {
      debugPrint("Erro ao inicializar TrayService: $e");
    }
  }

  // Escuta os cliques na bandeja
  @override
  void onTrayIconClick() {
    _restaurarJanela();
  }

  @override
  void onTrayIconRightClick() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        _restaurarJanela();
        break;
      case 'play_pause':
        if (onPlayPausePressed != null) {
          onPlayPausePressed!();
        }
        break;
      case 'exit_app':
        windowManager.destroy();
        break;
    }
  }

  Future<void> _restaurarJanela() async {
    try {
      final visivel = await windowManager.isVisible();
      if (!visivel) {
        await windowManager.show();
      }
      await windowManager.focus();
      // Remove do modo silencioso/escondido do Windows se necessário
      await windowManager.setSkipTaskbar(false);
    } catch (e) {
      debugPrint("Erro ao restaurar janela do tray: $e");
    }
  }

  // Oculta o aplicativo na bandeja (some da barra de tarefas)
  Future<void> ocultarNaBandeja() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true); // Oculta da barra de tarefas principal
    } catch (e) {
      debugPrint("Erro ao ocultar janela na bandeja: $e");
    }
  }
}
