import 'dart:io';
import 'package:flutter/material.dart';
import 'timer_provider.dart';

class DashboardProvider with ChangeNotifier {
  final TimerProvider timerProvider;
  Map<String, dynamic> dadosDashboard = {};
  bool carregando = false;
  String? erroMessage;

  // Filtros ativos
  DateTimeRange? _periodoSelecionado;
  String? _materiaSelecionada;
  
  DashboardProvider({required this.timerProvider}) {
    final hoje = DateTime.now();
    _periodoSelecionado = DateTimeRange(
      start: hoje.subtract(const Duration(days: 6)),
      end: hoje,
    );
    carregarCache();
    timerProvider.onSessionRecorded = () {
      atualizarDadosNotion();
    };
  }

  // Getters e Setters de Filtros
  String? get materiaSelecionada => _materiaSelecionada;
  DateTimeRange? get periodoSelecionado => _periodoSelecionado;

  void filtrarPorMateria(String? materia) {
    _materiaSelecionada = materia;
    notifyListeners();
  }

  void filtrarPorPeriodo(DateTimeRange? periodo) {
    _periodoSelecionado = periodo;
    notifyListeners();
  }

  void limparFiltros() {
    _materiaSelecionada = null;
    _periodoSelecionado = null;
    notifyListeners();
  }

  bool get temFiltrosAtivos => _materiaSelecionada != null || _periodoSelecionado != null;

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

  // Getter principal filtrado
  List<dynamic> get sessoesFiltradas {
    return sessoes.where((s) {
      // 1. Filtro por matéria
      if (_materiaSelecionada != null && s['materia_nome'] != _materiaSelecionada) {
        return false;
      }
      // 2. Filtro por período de datas (inclusivo)
      if (_periodoSelecionado != null) {
        final inicioStr = s['inicio'] as String?;
        if (inicioStr == null) return false;
        
        final inicio = DateTime.tryParse(inicioStr)?.toLocal();
        if (inicio == null) return false;

        // Compara ignorando horas/minutos para incluir todo o dia de início e fim
        final dataInicioFiltro = DateTime(_periodoSelecionado!.start.year, _periodoSelecionado!.start.month, _periodoSelecionado!.start.day);
        final dataFimFiltro = DateTime(_periodoSelecionado!.end.year, _periodoSelecionado!.end.month, _periodoSelecionado!.end.day, 23, 59, 59);

        if (inicio.isBefore(dataInicioFiltro) || inicio.isAfter(dataFimFiltro)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // Total de horas focadas filtrado
  double get totalHorasFocadas {
    double totalMinutos = 0;
    for (final s in sessoesFiltradas) {
      final inicio = DateTime.tryParse(s['inicio'] ?? '');
      final fim = DateTime.tryParse(s['fim'] ?? '');
      if (inicio != null && fim != null) {
        totalMinutos += fim.difference(inicio).inMinutes;
      }
    }
    return totalMinutos / 60.0;
  }

  // Matéria mais estudada (Materia líder de tempo) baseada no filtro
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

  // Média de tempo focado por sessão (em minutos) baseada no filtro
  double get mediaMinutosPorSessao {
    if (sessoesFiltradas.isEmpty) return 0.0;
    double totalMinutos = 0;
    for (final s in sessoesFiltradas) {
      final inicio = DateTime.tryParse(s['inicio'] ?? '');
      final fim = DateTime.tryParse(s['fim'] ?? '');
      if (inicio != null && fim != null) {
        totalMinutos += fim.difference(inicio).inMinutes;
      }
    }
    return totalMinutos / sessoesFiltradas.length;
  }

  // Agrupamento: Tempo de estudo em Horas por Matéria
  Map<String, double> get tempoPorMateria {
    final Map<String, double> map = {};
    for (final s in sessoesFiltradas) {
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
    for (final s in sessoesFiltradas) {
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
    for (final s in sessoesFiltradas) {
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

  // Lista de dias no período para gerar o gráfico de barras
  List<DateTime> get diasNoPeriodo {
    final hoje = DateTime.now();
    final range = _periodoSelecionado ?? DateTimeRange(
      start: hoje.subtract(const Duration(days: 13)),
      end: hoje,
    );

    // Ajusta as datas de início e fim ignorando horas
    final inicio = DateTime(range.start.year, range.start.month, range.start.day);
    final fim = DateTime(range.end.year, range.end.month, range.end.day);

    final List<DateTime> list = [];
    var current = inicio;
    
    // Limita o gráfico de barras a no máximo 14 dias para evitar quebra de layout na UI
    final limiteFim = fim.isAfter(inicio.add(const Duration(days: 13)))
        ? inicio.add(const Duration(days: 13))
        : fim;

    while (current.isBefore(limiteFim) || current.isAtSameMomentAs(limiteFim)) {
      list.add(current);
      current = current.add(const Duration(days: 1));
    }
    return list;
  }

  // Vetor das horas estudadas por dia dentro do período selecionado
  List<double> get tempoPorDiaNoPeriodo {
    final dias = diasNoPeriodo;
    final List<double> valores = List.filled(dias.length, 0.0);

    for (int i = 0; i < dias.length; i++) {
      final dia = dias[i];
      double minutosNoDia = 0;
      for (final s in sessoesFiltradas) {
        final inicioStr = s['inicio'] as String?;
        if (inicioStr != null) {
          final inicio = DateTime.tryParse(inicioStr)?.toLocal();
          if (inicio != null && inicio.year == dia.year && inicio.month == dia.month && inicio.day == dia.day) {
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

  // Nomes formatados dos dias da semana (Sáb 15, Dom 16, etc.) para o gráfico de barras
  List<String> get diasStrNoPeriodo {
    final semanaStr = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];
    return diasNoPeriodo.map((d) => "${semanaStr[d.weekday % 7]} ${d.day}").toList();
  }

  // Progresso das metas semanais por matéria (Segunda-Feira até hoje ou semana selecionada)
  List<Map<String, dynamic>> get metasProgresso {
    final List<Map<String, dynamic>> list = [];
    final materias = dadosDashboard['materias'] as List<dynamic>? ?? [];

    final DateTime inicioSemana;
    if (_periodoSelecionado != null) {
      // Se tiver período selecionado, usa o início dele como marco inicial
      inicioSemana = DateTime(_periodoSelecionado!.start.year, _periodoSelecionado!.start.month, _periodoSelecionado!.start.day);
    } else {
      // Senão, pega a segunda-feira da semana atual à meia-noite
      final agora = DateTime.now();
      inicioSemana = DateTime(agora.year, agora.month, agora.day).subtract(Duration(days: agora.weekday - 1));
    }

    for (final m in materias) {
      final nome = m['nome'] as String? ?? 'Sem Nome';
      if (_materiaSelecionada != null && nome != _materiaSelecionada) {
        continue;
      }
      final metaSemanal = (m['meta_semanal'] as num?)?.toDouble() ?? 0.0;

      double minutosFocados = 0;
      for (final s in sessoes) { // Analisa as sessões completas para calcular progresso da meta
        if (s['materia_nome'] == nome) {
          final inicioStr = s['inicio'] as String?;
          if (inicioStr != null) {
            final inicio = DateTime.tryParse(inicioStr)?.toLocal();
            // Conta as horas da matéria se for no período da semana selecionada (inclusivo)
            if (inicio != null && !inicio.isBefore(inicioSemana)) {
              if (_periodoSelecionado != null) {
                final fimFiltro = DateTime(_periodoSelecionado!.end.year, _periodoSelecionado!.end.month, _periodoSelecionado!.end.day, 23, 59, 59);
                if (inicio.isAfter(fimFiltro)) continue;
              }
              final fim = DateTime.tryParse(s['fim'] ?? '');
              if (fim != null) {
                minutosFocados += fim.difference(inicio).inMinutes;
              }
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

  // Retorna os tópicos (Registro de Sessões) estudados da matéria filtrada agrupados
  List<Map<String, dynamic>> get topicosDaMateriaSelecionada {
    if (_materiaSelecionada == null) return [];
    
    final Map<String, Map<String, dynamic>> map = {};
    for (final s in sessoesFiltradas) {
      final topico = s['topico_nome'] as String? ?? 'Sem Tópico';
      final tipo = s['tipo_estudo'] as String? ?? 'Não Definido';
      final inicio = DateTime.tryParse(s['inicio'] ?? '');
      final fim = DateTime.tryParse(s['fim'] ?? '');
      
      if (inicio != null && fim != null) {
        final horas = fim.difference(inicio).inMinutes / 60.0;
        if (!map.containsKey(topico)) {
          map[topico] = {
            'nome': topico,
            'tipo': tipo,
            'total_horas': 0.0,
            'sessoes_count': 0,
          };
        }
        map[topico]!['total_horas'] = (map[topico]!['total_horas'] as double) + horas;
        map[topico]!['sessoes_count'] = (map[topico]!['sessoes_count'] as int) + 1;
      }
    }
    
    final list = map.values.toList();
    // Ordena pelo tópico mais estudado
    list.sort((a, b) => (b['total_horas'] as double).compareTo(a['total_horas'] as double));
    return list;
  }
}
