import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Inicializa o serviço e solicita permissões se necessário
  Future<void> inicializar() async {
    if (_initialized) return;

    try {
      // Inicializa a base de fusos horários para agendamento preciso
      tz.initializeTimeZones();
      // Configura o local padrão para o fuso local do dispositivo
      // O Dart tenta resolver localmente de forma nativa
      final String timeZoneName = DateTime.now().timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        // Fallback genérico caso a localização específica não conste na tabela básica
      }

      // Configurações padrão para Android (usa o ícone padrão do aplicativo)
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configurações para plataformas Apple (se rodar futuramente em macOS/iOS)
      const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Ação executada ao clicar na notificação (opcional)
        },
      );

      // Solicita permissões de notificação explicitamente no Android (necessário no Android 13+)
      if (Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      _initialized = true;
    } catch (e) {
      stderr.writeln('Erro ao inicializar serviço de notificações: $e');
    }
  }

  // Dispara uma notificação toast/push nativa no sistema
  Future<void> notificar(String titulo, String mensagem) async {
    await inicializar();

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'pomodoro_channel',
      'Pomodoro Dev Tracker',
      channelDescription: 'Canal de notificações de término de sessão do Pomodoro',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      await _notificationsPlugin.show(
        DateTime.now().millisecond, // ID dinâmico para não sobrepor notificações
        titulo,
        mensagem,
        platformChannelSpecifics,
      );
    } catch (e) {
      stderr.writeln('Erro ao disparar notificação: $e');
    }
  }

  // Reproduz o toque de alarme adequado para a plataforma
  Future<void> tocarAlarme() async {
    try {
      if (Platform.isAndroid) {
        // Toca o alarme padrão configurado no celular do usuário
        await FlutterRingtonePlayer().playAlarm(
          looping: false,
          asAlarm: true,
        );

        // Desliga o som após 4 segundos para evitar toques infinitos incômodos
        Future.delayed(const Duration(seconds: 4), () {
          try {
            FlutterRingtonePlayer().stop();
          } catch (_) {}
        });
      } else if (Platform.isWindows) {
        // Reproduz o som padrão de Beep do sistema Windows (equivalente a winsound)
        stdout.write('\x07');
        await Future.delayed(const Duration(milliseconds: 300));
        stdout.write('\x07');
      }
    } catch (e) {
      stderr.writeln('Erro ao reproduzir alarme sonoro: $e');
    }
  }

  // Agenda uma notificação para disparar em um instante futuro exato do sistema operacional
  Future<void> agendarNotificacao(int id, String titulo, String mensagem, DateTime instante) async {
    await inicializar();
    try {
      // Converte DateTime para TZDateTime exigido pelo plugin
      final tzDateTime = tz.TZDateTime.from(instante, tz.local);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'pomodoro_channel',
        'Pomodoro Dev Tracker',
        channelDescription: 'Canal de notificações de término de sessão do Pomodoro',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        // Garante que o alarme toque no Android mesmo com a tela bloqueada ou em modo soneca
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        titulo,
        mensagem,
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      stderr.writeln('Erro ao agendar notificação futura: $e');
    }
  }

  // Cancela todos os agendamentos pendentes
  Future<void> cancelarNotificacoes() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      stderr.writeln('Erro ao cancelar notificações: $e');
    }
  }

  // Exibe uma notificação contínua na barra com o cronômetro nativo do Android
  Future<void> exibirNotificacaoCronometro(String titulo, String mensagem, DateTime tempoFim) async {
    await inicializar();

    if (!Platform.isAndroid) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'pomodoro_active_channel_v3', // Atualizado para v3 para aplicar regras de lockscreen e importância
      'Cronometro Ativo',
      channelDescription: 'Exibe o tempo restante do Pomodoro na barra de status e tela de bloqueio',
      importance: Importance.defaultImportance, // Exigido pelo Android para aparecer na tela de bloqueio (Lock Screen)
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false, // Início silencioso e confortável
      ongoing: true, // Notificação persistente (não pode ser excluída deslizando)
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: true,
      when: tempoFim.millisecondsSinceEpoch,
      autoCancel: false, // O clique reabre o app mas não cancela a notificação (nós controlamos isso)
      onlyAlertOnce: true, // Garante que atualizações na notificação não toquem som de novo
      visibility: NotificationVisibility.public, // Torna o conteúdo e cronômetro visíveis na Lock Screen
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      await _notificationsPlugin.show(
        1, // ID fixo para a notificação ativa (assim ela é sobrescrita)
        titulo,
        mensagem,
        platformChannelSpecifics,
      );
    } catch (e) {
      stderr.writeln('Erro ao exibir cronometro na notificacao: $e');
    }
  }

  // Remove a notificação persistente do cronômetro
  Future<void> removerNotificacaoCronometro() async {
    try {
      await _notificationsPlugin.cancel(1);
    } catch (_) {}
  }
}
