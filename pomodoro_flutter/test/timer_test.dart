import 'package:flutter_test/flutter_test.dart';
import '../lib/core/services/storage_service.dart';
import '../lib/core/services/notification_service.dart';
import '../lib/logic/providers/timer_provider.dart';

// Mocks leves e rápidos para testes isolados
class MockStorageService extends StorageService {
  Map<String, dynamic> cache = {};

  @override
  Future<void> writeJson(String filename, dynamic data) async {
    cache[filename] = data;
  }

  @override
  Future<dynamic> readJson(String filename) async {
    return cache[filename];
  }
}

class MockNotificationService extends NotificationService {
  bool alarmeTocado = false;
  String? tituloNotificacao;

  @override
  Future<void> inicializar() async {}

  @override
  Future<void> tocarAlarme() async {
    alarmeTocado = true;
  }

  @override
  Future<void> notificar(String titulo, String mensagem) async {
    tituloNotificacao = titulo;
  }
}

void main() {
  group('Teste do TimerProvider', () {
    late MockStorageService storage;
    late MockNotificationService notification;
    late TimerProvider provider;

    setUp(() {
      storage = MockStorageService();
      notification = MockNotificationService();
      provider = TimerProvider(
        storageService: storage,
        notificationService: notification,
      );
    });

    test('Inicialização correta com tempos padrões', () async {
      await provider.inicializar();
      expect(provider.tempoRestante, 25 * 60);
      expect(provider.rodando, false);
      expect(provider.pausado, false);
      expect(provider.modoDescanso, false);
    });

    test('Iniciar timer altera estados e valida tarefas', () async {
      await provider.inicializar();

      // Inicia com tarefa vazia (deve falhar)
      provider.iniciar("", "Python");
      expect(provider.rodando, false);
      expect(provider.labelStatus.contains("Digite uma tarefa"), true);

      // Inicia com tarefa muito curta (deve falhar)
      provider.iniciar("ab", "Python");
      expect(provider.rodando, false);
      expect(provider.labelStatus.contains("muito curta"), true);

      // Inicia correto
      provider.iniciar("Codar testes", "Python");
      expect(provider.rodando, true);
      expect(provider.pausado, false);
      expect(provider.tarefaAtual, "Codar testes");
      expect(provider.categoriaAtual, "Python");
    });

    test('Pausar e Retomar o timer', () async {
      await provider.inicializar();
      provider.iniciar("Codar testes", "Python");

      expect(provider.pausado, false);
      provider.pausarRetomar();
      expect(provider.pausado, true);

      provider.pausarRetomar();
      expect(provider.pausado, false);
    });

    test('Resetar limpa estados do timer', () async {
      await provider.inicializar();
      provider.iniciar("Codar testes", "Python");
      provider.resetar();

      expect(provider.rodando, false);
      expect(provider.pausado, false);
      expect(provider.tempoRestante, 25 * 60);
      expect(provider.tarefaAtual, "");
    });
  });
}
