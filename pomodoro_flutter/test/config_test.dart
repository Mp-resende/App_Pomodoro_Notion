import 'package:flutter_test/flutter_test.dart';
import '../lib/data/models/pomodoro_config.dart';

void main() {
  group('Teste de Configurações - PomodoroConfig', () {
    test('Validação de valores padrão iniciais', () {
      final config = PomodoroConfig();
      expect(config.tempoTrabalho, 25);
      expect(config.tempoDescansoCurto, 5);
      expect(config.tempoDescansoLongo, 15);
      expect(config.pomodorosAteLongBreak, 4);
      expect(config.somAlarmeAtivado, true);
      expect(config.notificacoesSistema, true);
      expect(config.categorias, isNotNull);
      expect(config.categorias.contains("Python"), true);
    });

    test('Adicionar nova categoria com sucesso', () {
      final config = PomodoroConfig();
      final sucesso = config.adicionarCategoria("Flutter");
      expect(sucesso, true);
      expect(config.categorias.contains("Flutter"), true);
    });

    test('Adicionar categoria vazia ou duplicada deve falhar', () {
      final config = PomodoroConfig();

      // Duplicada
      final sucessoDuplicada = config.adicionarCategoria("Python");
      expect(sucessoDuplicada, false);

      // Vazia
      final sucessoVazia = config.adicionarCategoria("  ");
      expect(sucessoVazia, false);
    });

    test('Serialização e Desserialização JSON', () {
      final config = PomodoroConfig(
        tempoTrabalho: 30,
        tempoDescansoCurto: 10,
        tempoDescansoLongo: 20,
        pomodorosAteLongBreak: 5,
        somAlarmeAtivado: false,
        notificacoesSistema: false,
        categorias: ["Dart", "Go"],
      );

      final jsonMap = config.toJson();
      expect(jsonMap['tempo_trabalho'], 30);
      expect(jsonMap['tempo_descanso_curto'], 10);
      expect(jsonMap['tempo_descanso_longo'], 20);
      expect(jsonMap['pomodoros_ate_long_break'], 5);
      expect(jsonMap['som_alarme_ativado'], false);
      expect(jsonMap['notificacoes_sistema'], false);
      expect(jsonMap['categorias'], ["Dart", "Go"]);

      final configFrom = PomodoroConfig.fromJson(jsonMap);
      expect(configFrom.tempoTrabalho, 30);
      expect(configFrom.tempoDescansoCurto, 10);
      expect(configFrom.tempoDescansoLongo, 20);
      expect(configFrom.pomodorosAteLongBreak, 5);
      expect(configFrom.somAlarmeAtivado, false);
      expect(configFrom.notificacoesSistema, false);
      expect(configFrom.categorias.contains("Dart"), true);
      expect(configFrom.categorias.contains("Go"), true);
    });
  });
}
