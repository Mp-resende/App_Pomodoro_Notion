import 'dart:io';
import 'package:flutter/foundation.dart';
import 'timer_provider.dart';

class DashboardProvider with ChangeNotifier {
  final TimerProvider timerProvider;
  Map<String, dynamic> dadosDashboard = {};
  bool carregando = false;
  String? erroMessage;

  DashboardProvider({required this.timerProvider}) {
    carregarCache();
    timerProvider.onSessionRecorded = () {
      atualizarDadosNotion();
    };
  }

  // Carrega os dados persistidos no cache local para exibição instantânea
  Future<void> carregarCache() async {
    try {
      final cache = await timerProvider.storageService.readJson('dashboard_cache.json');
      if (cache != null && cache is Map<String, dynamic>) {
        dadosDashboard = cache;
        notifyListeners();
      }
    } catch (_) {}
  }

  // Busca dados novos do Notion e atualiza o cache
  Future<bool> atualizarDadosNotion() async {
    final service = timerProvider.notionService;
    if (service == null) {
      erroMessage = "Notion não configurado";
      notifyListeners();
      return false;
    }

    if (!service.connected) {
      // Tenta reconectar rapidamente
      final conectado = await service.verificarConexao(retries: 1);
      if (!conectado) {
        erroMessage = "Sem conexão com o Notion";
        notifyListeners();
        return false;
      }
    }

    carregando = true;
    erroMessage = null;
    notifyListeners();

    try {
      final dados = await service.obterDadosEstatisticas();
      if (dados.isNotEmpty) {
        dadosDashboard = dados;
        await timerProvider.storageService.writeJson('dashboard_cache.json', dados);
        erroMessage = null;
      } else {
        erroMessage = "Nenhum dado retornado do Notion";
      }
    } catch (e) {
      erroMessage = "Erro ao carregar dados: $e";
    } finally {
      carregando = false;
      notifyListeners();
    }
    return erroMessage == null;
  }

  // Getters para UI consumidora

  List<dynamic> get sessoes => dadosDashboard['sessoes'] as List<dynamic>? ?? [];

  bool get temDados => sessoes.isNotEmpty;

  // Total de horas focadas no total acumulado
  double get totalHorasFocadas {
    double totalMinutos = 0;
    for (final s in sessoes) {
      final inicio = DateTime.tryParse(s['inicio'] ?? '');
      final fim = DateTime.tryParse(s['fim'] ?? '');
      if (inicio != null && fim != null) {
        totalMinutos += fim.difference(inicio).inMinutes;
      }
    }
    return totalMinutos / 60.0;
  }

  // Matéria mais estudada (Materia líder de tempo)
  String get materiaLider {
    final map = tempoPorMateria;
    if (map.isEmpty) return "Nenhuma";
    String lider = "Nenhuma";
    double maiorTempo = -1.0;
    map.forEach((materia, tempo) {
      if (tempo > maiorTempo) {
        maiorTempo = tempo;
        lider = materia;
      }
    });
    return lider;
  }

  // Média de tempo focado por sessão (em minutos)
  double get mediaMinutosPorSessao {
    if (sessoes.isEmpty) return 0.0;
    double totalMinutos = 0;
    for (final s in sessoes) {
      final inicio = DateTime.tryParse(s['inicio'] ?? '');
      final fim = DateTime.tryParse(s['fim'] ?? '');
      if (inicio != null && fim != null) {
        totalMinutos += fim.difference(inicio).inMinutes;
      }
    }
    return totalMinutos / sessoes.length;
  }

  // Agrupamento: Tempo de estudo em Horas por Matéria
  Map<String, double> get tempoPorMateria {
    final Map<String, double> map = {};
    for (final s in sessoes) {
      final materia = s['materia_nome'] as String? ?? 'Sem Matéria';
      final inicio = DateTime.tryParse(s['inicio'] ?? '');
      final fim = DateTime.tryParse(s['fim'] ?? '');
      if (inicio != null && fim != null) {
        final horas = fim.difference(inicio).inMinutes / 60.0;
        map[materia] = (map[materia] ?? 0.0) + horas;
      }
    }
    return map;
  }

  // Agrupamento: Tempo de estudo em Horas por Tipo de Estudo (Teoria, Exercícios, etc.)
  Map<String, double> get tempoPorTipoEstudo {
    final Map<String, double> map = {};
    for (final s in sessoes) {
      final tipo = s['tipo_estudo'] as String? ?? 'Não Definido';
      final inicio = DateTime.tryParse(s['inicio'] ?? '');
      final fim = DateTime.tryParse(s['fim'] ?? '');
      if (inicio != null && fim != null) {
        final horas = fim.difference(inicio).inMinutes / 60.0;
        map[tipo] = (map[tipo] ?? 0.0) + horas;
      }
    }
    return map;
  }

  // Agrupamento: Tempo de estudo em Horas por Tecnologia
  Map<String, double> get tempoPorTecnologia {
    final Map<String, double> map = {};
    for (final s in sessoes) {
      final tech = s['tecnologia'] as String? ?? 'Outro';
      final inicio = DateTime.tryParse(s['inicio'] ?? '');
      final fim = DateTime.tryParse(s['fim'] ?? '');
      if (inicio != null && fim != null) {
        final horas = fim.difference(inicio).inMinutes / 60.0;
        map[tech] = (map[tech] ?? 0.0) + horas;
      }
    }
    return map;
  }

  // Vetor das horas estudadas nos últimos 7 dias (para o gráfico de barras)
  List<double> get tempoUltimos7Dias {
    final List<double> valores = List.filled(7, 0.0);
    final hoje = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final dia = hoje.subtract(Duration(days: 6 - i));
      double minutosNoDia = 0;
      for (final s in sessoes) {
        final inicio = DateTime.tryParse(s['inicio'] ?? '');
        if (inicio != null) {
          final localInicio = inicio.toLocal();
          if (localInicio.year == dia.year && localInicio.month == dia.month && localInicio.day == dia.day) {
            final fim = DateTime.tryParse(s['fim'] ?? '');
            if (fim != null) {
              minutosNoDia += fim.difference(inicio).inMinutes;
            }
          }
        }
      }
      valores[i] = minutosNoDia / 60.0;
    }
    return valores;
  }

  // Nomes dos dias da semana correspondentes aos últimos 7 dias
  List<String> get diasUltimos7Dias {
    final List<String> dias = [];
    final hoje = DateTime.now();
    final semanaStr = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];
    for (int i = 0; i < 7; i++) {
      final dia = hoje.subtract(Duration(days: 6 - i));
      dias.add(semanaStr[dia.weekday % 7]);
    }
    return dias;
  }

  // Progresso das metas semanais por matéria (Segunda-Feira até hoje)
  List<Map<String, dynamic>> get metasProgresso {
    final List<Map<String, dynamic>> list = [];
    final materias = dadosDashboard['materias'] as List<dynamic>? ?? [];

    final agora = DateTime.now();
    // Encontra a última segunda-feira à meia-noite
    final segundaFeira = agora.subtract(Duration(days: agora.weekday - 1)).subtract(Duration(
          hours: agora.hour,
          minutes: agora.minute,
          seconds: agora.second,
          milliseconds: agora.millisecond,
          microseconds: agora.microsecond,
        ));

    for (final m in materias) {
      final nome = m['nome'] as String? ?? 'Sem Nome';
      final metaSemanal = (m['meta_semanal'] as num?)?.toDouble() ?? 0.0;

      double minutosFocados = 0;
      for (final s in sessoes) {
        if (s['materia_nome'] == nome) {
          final inicio = DateTime.tryParse(s['inicio'] ?? '');
          if (inicio != null && inicio.isAfter(segundaFeira)) {
            final fim = DateTime.tryParse(s['fim'] ?? '');
            if (fim != null) {
              minutosFocados += fim.difference(inicio).inMinutes;
            }
          }
        }
      }

      final realizadoHoras = minutosFocados / 60.0;
      list.add({
        'materia_nome': nome,
        'meta_horas': metaSemanal,
        'realizado_horas': realizadoHoras,
        'porcentagem': metaSemanal > 0 ? (realizadoHoras / metaSemanal) : 0.0,
      });
    }
    return list;
  }
}
