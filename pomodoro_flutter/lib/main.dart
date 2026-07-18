import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/api_server.dart';
import 'logic/providers/timer_provider.dart';
import 'logic/providers/relation_provider.dart';
import 'logic/providers/dashboard_provider.dart';
import 'ui/screens/home_screen.dart';

import 'core/services/tray_service.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  // Garante a inicialização das bindings nativas do Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow(const WindowOptions(
      size: Size(800, 680),
      minimumSize: Size(280, 150),
      center: true,
      title: "Pomodoro Notion",
    ), () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 1. Inicializa os serviços estruturais
  final storageService = StorageService();
  final notificationService = NotificationService();
  await notificationService.inicializar();

  // 2. Cria e inicializa o Provider do Timer (carregando configurações/JSONs)
  final timerProvider = TimerProvider(
    storageService: storageService,
    notificationService: notificationService,
  );
  await timerProvider.inicializar();

  // Inicializa o ícone da bandeja do sistema no Windows
  if (Platform.isWindows) {
    await TrayService().inicializar(
      onPlayPause: () => timerProvider.pausarRetomar(),
    );
  }

  // 3. Cria o Provider de relação do Notion referenciando o Timer
  final relationProvider = RelationProvider(timerProvider: timerProvider);

  // Cria o Provider do Dashboard
  final dashboardProvider = DashboardProvider(timerProvider: timerProvider);

  // 4. Inicializa o servidor HTTP da API Local (Porta 8082 - exclusivo Windows)
  if (Platform.isWindows) {
    final apiServer = ApiServer(timerProvider: timerProvider);
    // Roda em background de forma assíncrona
    apiServer.iniciar();
  }

  // 5. Executa a árvore de widgets aplicando injeção de estado
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TimerProvider>.value(value: timerProvider),
        ChangeNotifierProvider<RelationProvider>.value(value: relationProvider),
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboardProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomodoro Dev Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.orangeAccent,
          surface: Color(0xFF1E293B),
          error: Colors.redAccent,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
