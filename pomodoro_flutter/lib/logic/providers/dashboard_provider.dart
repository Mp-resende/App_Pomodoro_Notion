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
  String _contextoFiltro = "todos"; // "todos", "estudos", "trabalho"

  // Cache da lista filtrada para evitar recomputação em cada getter
  List<dynamic>? _sessoesFiltradaCache;
  String? _sessoesCacheKey;

  String get _filtroCacheKey =>
      '${_contextoFiltro}|${_materiaSelecionada}|${_periodoSelecionado?.start?.millisecondsSinceEpoch}|${_periodoSelecionado?.end?.millisecondsSinceEpoch}|${sessoes.length}';

  void _invalidarCache() => _sessoesFiltradaCache = null;
  
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
  String get contextoFiltro => _contextoFiltro;

  void filtrarPorContexto(String contexto) {
    if (_contextoFiltro == contexto) return;
    _contextoFiltro = contexto;
    _invalidarCache();
    notifyListeners();
  }

  void filtrarPorMateria(String? materia) {
    _materiaSelecionada = materia;
    _invalidarCache();
    notifyListeners();
  }

  void filtrarPorPeriodo(DateTimeRange? periodo) {
    _periodoSelecionado = periodo;
    _invalidarCache();
    notifyListeners();
  }

  void limparFiltros() {
    _materiaSelecionada = null;
    _periodoSelecionado = null;
    _contextoFiltro = "todos";
    _invalidarCache();
    notifyListeners();
  }

  bool get temFiltrosAtivos => _materiaSelecionada != null || _periodoSelecionado != null || _contextoFiltro != "todos";

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
        _invalidarCache();
        await timerProvider.storageService.writeJson('dashboard_cache.json', dados);
        erroMessage = null;
        // Força sincronização da linha do tempo diária para garantir que sessões novas apareçam na tela inicial
        await timerProvider.sincronizarSessoesHojeDoNotion();
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

  Map<String, String> get insightsSemanais {
    if (sessoes.isEmpty) {
      return {
        "dia_produtivo": "Nenhum",
        "foco_principal": "Nenhum",
        "media_diaria": "0 min",
      };
    }

    final agora = DateTime.now();
    final diaSemanaAtual = agora.weekday; // 1 = Segunda, 7 = Domingo
    final segundaFeira = agora.subtract(Duration(days: diaSemanaAtual - 1));
    final inicioSemana = DateTime(segundaFeira.year, segundaFeira.month, segundaFeira.day, 0, 0, 0);
    final fimSemana = inicioSemana.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));

    // Agrupadores
    final Map<int, int> minutosPorDia = {for (int i = 1; i <= 7; i++) i: 0};
    final Map<String, int> minutosPorTecnologia = {};
    int totalMinutosSemana = 0;
    int diasComFoco = 0;

    for (final s in sessoes) {
      if (s is! Map<String, dynamic>) continue;

      if (_contextoFiltro != "todos") {
        final isTrab = timerProvider.isMateriaTrabalho(s['materia_nome']?.toString(), s['materia_area']?.toString()) ||
            timerProvider.isMateriaTrabalho(s['tecnologia']?.toString());
        if (_contextoFiltro == "trabalho" && !isTrab) continue;
        if (_contextoFiltro == "estudos" && isTrab) continue;
      }

      final inicioStr = s['inicio'] as String?;
      final fimStr = s['fim'] as String?;
      final tech = s['tecnologia'] as String? ?? 'Outros';

      if (inicioStr == null || fimStr == null) continue;
      final DateTime? dateIni = DateTime.tryParse(inicioStr)?.toLocal();
      final DateTime? dateFim = DateTime.tryParse(fimStr)?.toLocal();
      if (dateIni == null || dateFim == null) continue;

      // Verifica se a sessão pertence à semana atual
      if (dateIni.isAfter(inicioSemana.subtract(const Duration(seconds: 1))) &&
          dateIni.isBefore(fimSemana.add(const Duration(seconds: 1)))) {
        final duracaoMinutos = dateFim.difference(dateIni).inMinutes;
        final weekday = dateIni.weekday;

        minutosPorDia[weekday] = (minutosPorDia[weekday] ?? 0) + duracaoMinutos;
        minutosPorTecnologia[tech] = (minutosPorTecnologia[tech] ?? 0) + duracaoMinutos;
        totalMinutosSemana += duracaoMinutos;
      }
    }

    // Calcula dia mais produtivo
    int diaLider = -1;
    int maxMinutosDia = -1;
    final nomesDias = ["Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado", "Domingo"];
    minutosPorDia.forEach((day, mins) {
      if (mins > 0) diasComFoco++;
      if (mins > maxMinutosDia) {
        maxMinutosDia = mins;
        diaLider = day;
      }
    });

    String diaLiderStr = "Nenhum";
    if (diaLider != -1 && maxMinutosDia > 0) {
      final h = maxMinutosDia ~/ 60;
      final m = maxMinutosDia % 60;
      diaLiderStr = "${nomesDias[diaLider - 1]} (${h > 0 ? '${h}h' : ''}${m}m)";
    }

    // Calcula tecnologia líder (foco principal)
    String techLider = "Nenhum";
    int maxMinutosTech = -1;
    minutosPorTecnologia.forEach((tech, mins) {
      if (mins > maxMinutosTech) {
        maxMinutosTech = mins;
        techLider = tech;
      }
    });

    String techLiderStr = "Nenhum";
    if (techLider != "Nenhum" && maxMinutosTech > 0) {
      final h = maxMinutosTech ~/ 60;
      final m = maxMinutosTech % 60;
      final pct = totalMinutosSemana > 0 ? ((maxMinutosTech / totalMinutosSemana) * 100).toStringAsFixed(0) : "0";
      techLiderStr = "$techLider (${h > 0 ? '${h}h' : ''}${m}m | $pct%)";
    }

    // Média diária de estudos
    String mediaDiariaStr = "0 min";
    if (diasComFoco > 0) {
      final media = totalMinutosSemana ~/ 7; // Média pela semana fechada de 7 dias
      final h = media ~/ 60;
      final m = media % 60;
      mediaDiariaStr = "${h > 0 ? '${h}h' : ''}${m}m / dia";
    }

    return {
      "dia_produtivo": diaLiderStr,
      "foco_principal": techLiderStr,
      "media_diaria": mediaDiariaStr,
    };
  }

  List<dynamic> get sessoes => dadosDashboard['sessoes'] as List<dynamic>? ?? [];

  bool get temDados => sessoes.isNotEmpty;

  // Getter principal filtrado (com cache)
  List<dynamic> get sessoesFiltradas {
    final key = _filtroCacheKey;
    if (key == _sessoesCacheKey && _sessoesFiltradaCache != null) {
      return _sessoesFiltradaCache!;
    }
    _sessoesCacheKey = key;
    _sessoesFiltradaCache = _computeSessoesFiltradas();
    return _sessoesFiltradaCache!;
  }

  List<dynamic> _computeSessoesFiltradas() {
    return sessoes.where((s) {
      if (_contextoFiltro != "todos") {
        final isTrab = timerProvider.isMateriaTrabalho(s['materia_nome']?.toString(), s['materia_area']?.toString()) ||
            timerProvider.isMateriaTrabalho(s['tecnologia']?.toString());
        if (_contextoFiltro == "trabalho" && !isTrab) return false;
        if (_contextoFiltro == "estudos" && isTrab) return false;
      }
      if (_materiaSelecionada != null && s['materia_nome'] != _materiaSelecionada) {
        return false;
      }
      if (_periodoSelecionado != null) {
        final inicioStr = s['inicio'] as String?;
        if (inicioStr == null) return false;

        final inicio = DateTime.tryParse(inicioStr)?.toLocal();
        if (inicio == null) return false;

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
      final area = m['area'] as String?;
      if (_contextoFiltro != "todos") {
        final isTrab = timerProvider.isMateriaTrabalho(nome, area);
        if (_contextoFiltro == "trabalho" && !isTrab) continue;
        if (_contextoFiltro == "estudos" && isTrab) continue;
      }
      if (_materiaSelecionada != null && nome != _materiaSelecionada) {
        continue;
      }
      final metaSemanal = (m['meta_semanal'] as num?)?.toDouble() ?? 0.0;
      if (metaSemanal <= 0) {
        continue; // Não exibe matérias que não possuem meta cadastrada
      }

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
