import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../data/models/session_offline.dart';
import 'storage_service.dart';

class NotionService {
  final String apiKey;
  final String databaseId;
  final StorageService storageService;
  final String? materiasDatabaseId;
  final String? estudosDiariosDatabaseId;
  bool connected = false;

  NotionService({
    required this.apiKey,
    required this.databaseId,
    required this.storageService,
    this.materiasDatabaseId,
    this.estudosDiariosDatabaseId,
  });

  // Cabeçalhos HTTP obrigatórios pela API do Notion
  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Notion-Version': '2022-06-28',
        'Content-Type': 'application/json',
      };

  // Verifica se a conexão com o Notion está ativa
  Future<bool> verificarConexao({int retries = 3}) async {
    final url = Uri.parse('https://api.notion.com/v1/databases/$databaseId');

    for (int tentativa = 0; tentativa < retries; tentativa++) {
      try {
        final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          connected = true;
          return true;
        }
      } catch (_) {}
      if (tentativa < retries - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    connected = false;
    return false;
  }

  // Tenta restabelecer conexão
  Future<bool> reconectar({int retries = 3}) async {
    return await verificarConexao(retries: retries);
  }

  // Registra uma sessão no Notion
  Future<bool> registrarSessao({
    required String intervalo,
    required DateTime inicio,
    required DateTime fim,
    required String tecnologia,
    String? campoRelacao,
    String? idRelacao,
    int retries = 3,
  }) async {
    if (intervalo.trim().isEmpty) return false;

    // Converte datas locais do cronômetro para String ISO 8601 em formato UTC
    // garantindo timezone preciso independente do dispositivo
    final inicioIso = inicio.toUtc().toIso8601String();
    final fimIso = fim.toUtc().toIso8601String();

    if (!connected) {
      await _salvarSessaoOffline(intervalo, inicio, fim, tecnologia, campoRelacao, idRelacao);
      return false;
    }

    final url = Uri.parse('https://api.notion.com/v1/pages');

    final Map<String, dynamic> properties = {
      "Intervalo": {
        "title": [
          {
            "text": {"content": intervalo.length > 2000 ? intervalo.substring(0, 2000) : intervalo}
          }
        ]
      },
      "Início": {
        "date": {"start": inicioIso}
      },
      "Fim": {
        "date": {"start": fimIso}
      },
      "Tecnologia": {
        "select": {"name": tecnologia}
      }
    };

    // Insere campo relacional caso esteja configurado
    if (campoRelacao != null && idRelacao != null && campoRelacao.isNotEmpty && idRelacao.isNotEmpty) {
      properties[campoRelacao] = {
        "relation": [
          {"id": idRelacao}
        ]
      };
    }

    final body = jsonEncode({
      "parent": {"database_id": databaseId},
      "properties": properties
    });

    for (int tentativa = 0; tentativa < retries; tentativa++) {
      try {
        final response = await http.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        }
      } catch (_) {}
      if (tentativa < retries - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // Se todas as tentativas falharem, salva no cache local para sincronização futura
    await _salvarSessaoOffline(intervalo, inicio, fim, tecnologia, campoRelacao, idRelacao);
    return false;
  }

  // Salva a sessão localmente em sessoes_offline.json
  Future<void> _salvarSessaoOffline(
    String intervalo,
    DateTime inicio,
    DateTime fim,
    String tecnologia,
    String? campoRelacao,
    String? idRelacao,
  ) async {
    try {
      List<SessionOffline> sessoes = [];
      final cacheData = await storageService.readJson(StorageService.offlineFile);
      if (cacheData is List) {
        sessoes = cacheData.map((e) => SessionOffline.fromJson(e as Map<String, dynamic>)).toList();
      }

      sessoes.add(SessionOffline(
        intervalo: intervalo,
        inicio: inicio,
        fim: fim,
        tecnologia: tecnologia,
        timestamp: DateTime.now(),
        campoRelacao: campoRelacao,
        idRelacao: idRelacao,
      ));

      final jsonList = sessoes.map((e) => e.toJson()).toList();
      await storageService.writeJson(StorageService.offlineFile, jsonList);
    } catch (_) {}
  }

  // Tenta sincronizar todas as sessões pendentes no cache local
  Future<int> sincronizarSessoesOffline() async {
    if (!connected) return 0;

    final cacheData = await storageService.readJson(StorageService.offlineFile);
    if (cacheData == null || cacheData is! List || cacheData.isEmpty) return 0;

    final List<dynamic> listRaw = cacheData;
    final List<SessionOffline> sessoes = listRaw.map((e) => SessionOffline.fromJson(e as Map<String, dynamic>)).toList();

    List<SessionOffline> restantes = [];
    int sincronizadas = 0;

    for (final sessao in sessoes) {
      try {
        final sucesso = await registrarSessao(
          intervalo: sessao.intervalo,
          inicio: sessao.inicio,
          fim: sessao.fim,
          tecnologia: sessao.tecnologia,
          campoRelacao: sessao.campoRelacao,
          idRelacao: sessao.idRelacao,
          retries: 1, // Apenas 1 tentativa por item para não travar o loop
        );

        if (sucesso) {
          sincronizadas++;
        } else {
          restantes.add(sessao);
        }
      } catch (_) {
        restantes.add(sessao);
      }
    }

    final jsonList = restantes.map((e) => e.toJson()).toList();
    await storageService.writeJson(StorageService.offlineFile, jsonList);
    return sincronizadas;
  }

  // Retorna a quantidade de sessões offline salvas
  Future<int> contarSessoesOffline() async {
    final cacheData = await storageService.readJson(StorageService.offlineFile);
    if (cacheData is List) {
      return cacheData.length;
    }
    return 0;
  }

  // Mapeia os campos da database que são relações com outras bases no Notion
  Future<Map<String, dynamic>> detectarCamposRelacao({int retries = 3}) async {
    if (!connected) return {};
    final url = Uri.parse('https://api.notion.com/v1/databases/$databaseId');

    for (int tentativa = 0; tentativa < retries; tentativa++) {
      try {
        final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final properties = data['properties'] as Map<String, dynamic>? ?? {};
          final Map<String, dynamic> camposRelacao = {};

          for (final entry in properties.entries) {
            final propInfo = entry.value as Map<String, dynamic>;
            if (propInfo['type'] == 'relation') {
              final relatedDbId = propInfo['relation']['database_id'] as String;

              // Carrega os registros possíveis para essa relação
              final opcoes = await consultarOpcoesRelacao(relatedDbId);
              camposRelacao[entry.key] = {
                'database_id': relatedDbId,
                'type': propInfo['relation']['type'],
                'opcoes': opcoes
              };
            }
          }
          return camposRelacao;
        }
      } catch (_) {}
      if (tentativa < retries - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return {};
  }

  // Busca os registros disponíveis de uma database relacionada com paginação
  Future<List<Map<String, String>>> consultarOpcoesRelacao(String relatedDbId, {int retries = 3}) async {
    if (!connected) return [];
    final url = Uri.parse('https://api.notion.com/v1/databases/$relatedDbId/query');
    final List<Map<String, String>> opcoes = [];
    String? cursor;

    for (int tentativa = 0; tentativa < retries; tentativa++) {
      try {
        opcoes.clear();
        cursor = null;
        bool sucesso = true;

        do {
          final Map<String, dynamic> bodyMap = {"page_size": 100};
          if (cursor != null) bodyMap["start_cursor"] = cursor;

          final response = await http
              .post(url, headers: _headers, body: jsonEncode(bodyMap))
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final results = data['results'] as List<dynamic>? ?? [];

            for (final page in results) {
              final pageProperties = page['properties'] as Map<String, dynamic>? ?? {};

              // Encontra a coluna de título (Title property)
              String titleContent = '';
              for (final prop in pageProperties.values) {
                final propMap = prop as Map<String, dynamic>;
                if (propMap['type'] == 'title') {
                  final titleArray = propMap['title'] as List<dynamic>? ?? [];
                  titleContent = titleArray.map((e) => e['plain_text']?.toString() ?? '').join('');
                  break;
                }
              }

              opcoes.add({
                'id': page['id'] as String,
                'title': titleContent.trim()
              });
            }
            cursor = (data['has_more'] as bool? ?? false) ? data['next_cursor'] as String? : null;
          } else {
            sucesso = false;
            break;
          }
        } while (cursor != null);

        if (sucesso) {
          return opcoes;
        }
      } catch (_) {
        // Ignora erro e tenta novamente se possível
      }
      if (tentativa < retries - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return [];
  }

  // Cria uma nova página/opção em uma database relacionada
  Future<String?> criarOpcaoRelacao(String relatedDbId, String tituloRegistro, {int retries = 3}) async {
    if (!connected) return null;

    // 1. Descobre o nome exato da coluna principal (Title) da database filha
    String nomeColunaTitulo = "Name"; // Fallback genérico
    try {
      final dbUrl = Uri.parse('https://api.notion.com/v1/databases/$relatedDbId');
      final dbResponse = await http.get(dbUrl, headers: _headers);
      if (dbResponse.statusCode == 200) {
        final data = jsonDecode(dbResponse.body);
        final properties = data['properties'] as Map<String, dynamic>? ?? {};
        for (final entry in properties.entries) {
          final propInfo = entry.value as Map<String, dynamic>;
          if (propInfo['type'] == 'title') {
            nomeColunaTitulo = entry.key;
            break;
          }
        }
      }
    } catch (_) {}

    // 2. Faz o POST para criar a página
    final url = Uri.parse('https://api.notion.com/v1/pages');
    final body = jsonEncode({
      "parent": {"database_id": relatedDbId},
      "properties": {
        nomeColunaTitulo: {
          "title": [
            {
              "text": {"content": tituloRegistro}
            }
          ]
        }
      }
    });

    for (int tentativa = 0; tentativa < retries; tentativa++) {
      try {
        final response = await http.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          return responseData['id'];
        }
      } catch (_) {}
      if (tentativa < retries - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  // Busca todos os dados necessários para o dashboard (Matérias, Estudos Diários, Intervalos de Estudo)
  // e faz o relacionamento (Join) lógico em memória.
  Future<Map<String, dynamic>> obterDadosEstatisticas() async {
    if (!connected) return {};

    final materiaDbId = materiasDatabaseId;
    final estudosDiariosDbId = estudosDiariosDatabaseId;

    if (materiaDbId == null || materiaDbId.isEmpty ||
        estudosDiariosDbId == null || estudosDiariosDbId.isEmpty) {
      return {};
    }

    try {
      final intervalosDbId = databaseId;

      // 1. Busca os dados de cada tabela em paralelo
      final resultados = await Future.wait([
        _queryDatabase(materiaDbId),
        _queryDatabase(estudosDiariosDbId),
        _queryDatabase(intervalosDbId),
      ]).timeout(const Duration(seconds: 20));

      final materiasRaw = resultados[0];
      final estudosDiariosRaw = resultados[1];
      final intervalosRaw = resultados[2];

      // 2. Mapeia as Matérias: { id: { nome, meta, area } }
      final Map<String, Map<String, dynamic>> materiasMap = {};
      for (final page in materiasRaw) {
        final props = page['properties'] as Map<String, dynamic>? ?? {};
        String nome = '';
        for (final prop in props.values) {
          if (prop['type'] == 'title') {
            final titleArray = prop['title'] as List<dynamic>? ?? [];
            nome = titleArray.map((e) => e['plain_text']?.toString() ?? '').join('').trim();
            break;
          }
        }

        final areaProp = props['Área'] as Map<String, dynamic>?;
        final areaMap = areaProp != null ? areaProp['select'] as Map<String, dynamic>? : null;
        final area = areaMap != null ? areaMap['name']?.toString() : null;

        final metaProp = props['Meta Semanal (h)'] as Map<String, dynamic>?;
        final meta = metaProp != null && metaProp['type'] == 'number'
            ? (metaProp['number'] as num?)?.toDouble()
            : null;

        materiasMap[page['id']] = {
          'id': page['id'],
          'nome': nome,
          'area': area,
          'meta_semanal': meta,
        };
      }

      // 3. Mapeia os Estudos Diários (Tópicos): { id: { nome, tipo, materia_id } }
      final Map<String, Map<String, dynamic>> estudosDiariosMap = {};
      for (final page in estudosDiariosRaw) {
        final props = page['properties'] as Map<String, dynamic>? ?? {};
        String nome = '';
        for (final prop in props.values) {
          if (prop['type'] == 'title') {
            final titleArray = prop['title'] as List<dynamic>? ?? [];
            nome = titleArray.map((e) => e['plain_text']?.toString() ?? '').join('').trim();
            break;
          }
        }

        final tipoProp = props['Tipo de Estudo'] as Map<String, dynamic>?;
        final tipoMap = tipoProp != null ? tipoProp['select'] as Map<String, dynamic>? : null;
        final tipo = tipoMap != null ? tipoMap['name']?.toString() : null;

        final relationProp = props['Banco de Dados: Matérias'] as Map<String, dynamic>?;
        String? materiaId;
        if (relationProp != null && relationProp['type'] == 'relation') {
          final relArray = relationProp['relation'] as List<dynamic>? ?? [];
          if (relArray.isNotEmpty) {
            materiaId = relArray.first['id']?.toString();
          }
        }

        estudosDiariosMap[page['id']] = {
          'id': page['id'],
          'nome': nome,
          'tipo': tipo,
          'materia_id': materiaId,
        };
      }

      // 4. Constrói a lista final de sessões detalhadas
      final List<Map<String, dynamic>> sessoesList = [];
      for (final page in intervalosRaw) {
        final props = page['properties'] as Map<String, dynamic>? ?? {};
        String nome = '';
        for (final prop in props.values) {
          if (prop['type'] == 'title') {
            final titleArray = prop['title'] as List<dynamic>? ?? [];
            nome = titleArray.map((e) => e['plain_text']?.toString() ?? '').join('').trim();
            break;
          }
        }

        final inicioProp = props['Início'] as Map<String, dynamic>?;
        final dateMap = inicioProp != null ? inicioProp['date'] as Map<String, dynamic>? : null;
        final inicioStr = dateMap != null ? dateMap['start']?.toString() : null;

        final fimProp = props['Fim'] as Map<String, dynamic>?;
        final endDateMap = fimProp != null ? fimProp['date'] as Map<String, dynamic>? : null;
        final fimStr = endDateMap != null ? endDateMap['start']?.toString() : null;

        if (inicioStr == null || fimStr == null) continue;

        final techProp = props['Tecnologia'] as Map<String, dynamic>?;
        final techMap = techProp != null ? techProp['select'] as Map<String, dynamic>? : null;
        final tech = techMap != null ? techMap['name']?.toString() ?? 'Outro' : 'Outro';

        final relationProp = props['Sessão de Estudo'] as Map<String, dynamic>?;
        String? sessaoEstudoId;
        if (relationProp != null && relationProp['type'] == 'relation') {
          final relArray = relationProp['relation'] as List<dynamic>? ?? [];
          if (relArray.isNotEmpty) {
            sessaoEstudoId = relArray.first['id']?.toString();
          }
        }

        // Resoluções de relações em cascata
        String topicoNome = 'Sem Tópico';
        String tipoEstudo = 'Não Definido';
        String materiaNome = 'Sem Matéria';
        double? metaSemanal;
        String? areaMateria;

        if (sessaoEstudoId != null && estudosDiariosMap.containsKey(sessaoEstudoId)) {
          final topico = estudosDiariosMap[sessaoEstudoId]!;
          topicoNome = topico['nome'] ?? 'Sem Tópico';
          tipoEstudo = topico['tipo'] ?? 'Não Definido';
          final matId = topico['materia_id'];

          if (matId != null && materiasMap.containsKey(matId)) {
            final mat = materiasMap[matId]!;
            materiaNome = mat['nome'] ?? 'Sem Matéria';
            metaSemanal = mat['meta_semanal'];
            areaMateria = mat['area'];
          }
        }

        sessoesList.add({
          'id': page['id'],
          'intervalo': nome,
          'inicio': inicioStr,
          'fim': fimStr,
          'tecnologia': tech,
          'topico_id': sessaoEstudoId,
          'topico_nome': topicoNome,
          'tipo_estudo': tipoEstudo,
          'materia_nome': materiaNome,
          'materia_meta_semanal': metaSemanal,
          'materia_area': areaMateria,
        });
      }

      return {
        'materias': materiasMap.values.toList(),
        'sessoes': sessoesList,
        'atualizado_em': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      stderr.writeln('Erro ao buscar dados do dashboard: $e');
      rethrow;
    }
  }
  // Consulta genérica com paginação automática (cursor-based)
  Future<List<dynamic>> _queryDatabase(String dbId) async {
    final url = Uri.parse('https://api.notion.com/v1/databases/$dbId/query');
    final List<dynamic> allResults = [];
    String? cursor;

    do {
      final Map<String, dynamic> body = {"page_size": 100};
      if (dbId == databaseId) {
        body["sorts"] = [
          {"property": "Início", "direction": "descending"}
        ];
      }
      if (cursor != null) body["start_cursor"] = cursor;

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        allResults.addAll(data['results'] as List<dynamic>? ?? []);
        cursor = (data['has_more'] as bool? ?? false)
            ? data['next_cursor'] as String?
            : null;
      } else {
        throw Exception('Falha ao consultar database $dbId: ${response.statusCode}');
      }
    } while (cursor != null);

    return allResults;
  }

  // Consulta sessões da database principal dentro de um intervalo de datas com paginação
  Future<List<dynamic>> _querySessoesPeriodo(DateTime inicio, DateTime fim) async {
    final url = Uri.parse('https://api.notion.com/v1/databases/$databaseId/query');
    final List<dynamic> allResults = [];
    String? cursor;

    do {
      final Map<String, dynamic> body = {
        "filter": {
          "and": [
            {"property": "Início", "date": {"on_or_after": inicio.toUtc().toIso8601String()}},
            {"property": "Início", "date": {"on_or_before": fim.toUtc().toIso8601String()}},
          ]
        },
        "sorts": [{"property": "Início", "direction": "ascending"}],
        "page_size": 100,
      };
      if (cursor != null) body["start_cursor"] = cursor;

      final response = await http
          .post(url, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        allResults.addAll(data['results'] as List<dynamic>? ?? []);
        cursor = (data['has_more'] as bool? ?? false) ? data['next_cursor'] as String? : null;
      } else {
        throw Exception('Falha ao consultar sessões (Status ${response.statusCode}): ${response.body}');
      }
    } while (cursor != null);

    return allResults;
  }

  // Cria uma sub-página de relatório semanal no Notion sob a paginaPaiId fornecida
  Future<bool> criarRelatorioSemanal({
    required String paginaPaiId,
    required DateTime inicioSemana,
    required DateTime fimSemana,
  }) async {
    if (!connected || paginaPaiId.trim().isEmpty) return false;

    final sessoes = await _querySessoesPeriodo(inicioSemana, fimSemana);
    if (sessoes.isEmpty) return false;

    int totalMinutos = 0;
    final Map<String, int> minPorCategoria = {};
    final Set<String> tarefas = {};
    final Set<String> diasAtivos = {};

    for (final s in sessoes) {
      final props = s['properties'] as Map<String, dynamic>? ?? {};

      String titulo = '';
      for (final prop in props.values) {
        final p = prop as Map<String, dynamic>;
        if (p['type'] == 'title') {
          titulo = (p['title'] as List<dynamic>? ?? [])
              .map((e) => e['plain_text']?.toString() ?? '')
              .join('')
              .trim();
          break;
        }
      }

      final inicioStr = (props['Início'] as Map<String, dynamic>?)?['date']?['start'] as String?;
      final fimStr = (props['Fim'] as Map<String, dynamic>?)?['date']?['start'] as String?;

      int mins = 0;
      if (inicioStr != null && fimStr != null) {
        final ini = DateTime.tryParse(inicioStr);
        final fi = DateTime.tryParse(fimStr);
        if (ini != null && fi != null && fi.isAfter(ini)) {
          mins = fi.difference(ini).inMinutes;
          totalMinutos += mins;
          final local = ini.toLocal();
          diasAtivos.add('${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}');
        }
      }

      final categoria =
          (props['Tecnologia'] as Map<String, dynamic>?)?['select']?['name'] as String? ?? 'Outro';
      minPorCategoria[categoria] = (minPorCategoria[categoria] ?? 0) + mins;

      if (titulo.isNotEmpty && !titulo.startsWith('[Encerrado]') && !titulo.startsWith('📊')) {
        tarefas.add(titulo);
      }
    }

    const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final iniLabel = '${inicioSemana.day} ${meses[inicioSemana.month - 1]}';
    final fimLabel = '${fimSemana.day} ${meses[fimSemana.month - 1]} ${fimSemana.year}';
    final tituloRelatorio = '📊 Relatório Semanal — $iniLabel a $fimLabel';

    final h = totalMinutos ~/ 60;
    final m = totalMinutos % 60;
    final tempoStr = h > 0 ? '${h}h ${m}min' : '${m}min';

    final cats = minPorCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final now = DateTime.now();
    final geradoEm =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final catBlocks = cats.take(20).map((e) {
      final p = totalMinutos > 0 ? ((e.value / totalMinutos) * 100).round() : 0;
      final ch = e.value ~/ 60;
      final cm = e.value % 60;
      final ct = ch > 0 ? '${ch}h ${cm}min' : '${cm}min';
      return _bulletBlock('${e.key} — $ct ($p%)');
    }).toList();

    final taskBlocks = tarefas.isEmpty
        ? [_bulletBlock('Nenhuma tarefa registrada.')]
        : tarefas.take(25).map(_bulletBlock).toList();

    final blocks = <Map<String, dynamic>>[
      _calloutBlock('Gerado automaticamente pelo Pomodoro Dev Tracker em $geradoEm'),
      _dividerBlock(),
      _heading2Block('📈 Resumo'),
      _bulletBlock('🍅 Sessões registradas: ${sessoes.length}'),
      _bulletBlock('⏱ Tempo total focado: $tempoStr'),
      _bulletBlock('📅 Dias com foco: ${diasAtivos.length} de 7'),
      _dividerBlock(),
      _heading2Block('📂 Por Categoria'),
      ...catBlocks,
      _dividerBlock(),
      _heading2Block('📝 Tarefas Trabalhadas'),
      ...taskBlocks,
    ];

    final url = Uri.parse('https://api.notion.com/v1/pages');
    final reqBody = jsonEncode({
      "parent": {"page_id": paginaPaiId.trim()},
      "properties": {
        "title": {
          "title": [
            {"text": {"content": tituloRelatorio}}
          ]
        }
      },
      "children": blocks,
    });

    final response = await http
        .post(url, headers: _headers, body: reqBody)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      throw Exception('Falha ao criar relatorio no Notion (Status ${response.statusCode}): ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> obterSessoesHoje() async {
    final agora = DateTime.now();
    final inicioDia = DateTime(agora.year, agora.month, agora.day, 0, 0, 0);
    final fimDia = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);
    final results = await _querySessoesPeriodo(inicioDia, fimDia);
    
    final List<Map<String, dynamic>> sessoes = [];
    for (final r in results) {
      final props = r['properties'] as Map<String, dynamic>? ?? {};

      final inicioStr = (props['Início'] as Map<String, dynamic>?)?['date']?['start'] as String?;
      final fimStr = (props['Fim'] as Map<String, dynamic>?)?['date']?['start'] as String?;
      final tech = (props['Tecnologia'] as Map<String, dynamic>?)?['select']?['name'] as String? ?? 'Outros';
      
      if (inicioStr != null && fimStr != null) {
        sessoes.add({
          "inicio": inicioStr,
          "fim": fimStr,
          "tecnologia": tech,
        });
      }
    }
    return sessoes;
  }

  Map<String, dynamic> _calloutBlock(String text) => {
        "object": "block",
        "type": "callout",
        "callout": {
          "icon": {"type": "emoji", "emoji": "🤖"},
          "rich_text": [
            {"type": "text", "text": {"content": text}}
          ],
          "color": "gray_background",
        },
      };

  Map<String, dynamic> _dividerBlock() => {"object": "block", "type": "divider", "divider": {}};

  Map<String, dynamic> _heading2Block(String text) => {
        "object": "block",
        "type": "heading_2",
        "heading_2": {
          "rich_text": [
            {"type": "text", "text": {"content": text}}
          ],
        },
      };

  Map<String, dynamic> _bulletBlock(String text) => {
        "object": "block",
        "type": "bulleted_list_item",
        "bulleted_list_item": {
          "rich_text": [
            {"type": "text", "text": {"content": text}}
          ],
        },
      };
}
