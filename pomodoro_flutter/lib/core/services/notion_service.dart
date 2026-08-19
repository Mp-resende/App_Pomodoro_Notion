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

  String _formatarParaIso8601ComOffset(DateTime dt) {
    // Converte a data para UTC e depois desloca 3 horas para trás (GMT -3:00)
    // Garantindo consistência de fuso horário independente de configurações locais do aparelho
    final gmt3 = dt.toUtc().subtract(const Duration(hours: 3));
    final dateStr = gmt3.toIso8601String().split('.').first;
    return "$dateStr.000-03:00";
  }

  // Extrai o ID UUID limpo de 32 caracteres a partir de uma URL ou string do Notion
  static String extrairIdNotion(String raw) {
    var str = raw.trim();
    if (str.isEmpty) return '';
    if (str.contains('?')) str = str.split('?').first;
    if (str.contains('#')) str = str.split('#').first;

    while (str.endsWith('/')) {
      str = str.substring(0, str.length - 1);
    }

    // 1. Tenta encontrar UUID formatado com hífens (8-4-4-4-12)
    final uuidRegex = RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
    final matchUuid = uuidRegex.firstMatch(str);
    if (matchUuid != null) return matchUuid.group(0)!;

    // 2. Tenta encontrar 32 caracteres hexadecimais contínuos
    final hex32Regex = RegExp(r'[0-9a-fA-F]{32}');
    final matchHex = hex32Regex.firstMatch(str);
    if (matchHex != null) return matchHex.group(0)!;

    return str;
  }

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

    // Converte datas locais do cronômetro para String ISO 8601 no fuso GMT -3:00
    final inicioIso = _formatarParaIso8601ComOffset(inicio);
    final fimIso = _formatarParaIso8601ComOffset(fim);

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
            {"property": "Início", "date": {"on_or_after": _formatarParaIso8601ComOffset(inicio)}},
            {"property": "Início", "date": {"on_or_before": _formatarParaIso8601ComOffset(fim)}},
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

  // Cria uma sub-página de relatório semanal no Notion com gráficos e separação de contexto
  Future<bool> criarRelatorioSemanal({
    required String paginaPaiId,
    required DateTime inicioSemana,
    required DateTime fimSemana,
    bool Function(String nome, String? area)? isMateriaTrabalho,
  }) async {
    final pageIdLimpo = extrairIdNotion(paginaPaiId);
    if (!connected) {
      throw Exception("Aplicativo sem conexão ativa com o Notion.");
    }
    if (pageIdLimpo.isEmpty) {
      throw Exception("O ID ou link da Página Mãe de Relatórios está vazio.");
    }

    final sessoes = await _querySessoesPeriodo(inicioSemana, fimSemana);
    if (sessoes.isEmpty) {
      throw Exception("Nenhuma sessão foi encontrada no Notion entre ${inicioSemana.day}/${inicioSemana.month} e ${fimSemana.day}/${fimSemana.month}.");
    }

    // Consulta tabelas relacionais caso configuradas para obter nomes exatos de matérias
    final Map<String, Map<String, dynamic>> materiasMap = {};
    final Map<String, Map<String, dynamic>> estudosDiariosMap = {};

    if (materiasDatabaseId != null && materiasDatabaseId!.isNotEmpty) {
      try {
        final mats = await _queryDatabase(materiasDatabaseId!);
        for (final m in mats) {
          final props = m['properties'] as Map<String, dynamic>? ?? {};
          String nome = '';
          for (final prop in props.values) {
            if (prop is Map<String, dynamic> && prop['type'] == 'title') {
              final titleArray = prop['title'] as List<dynamic>? ?? [];
              nome = titleArray.map((e) => e['plain_text']?.toString() ?? '').join('').trim();
              break;
            }
          }
          final areaProp = props['Área'] as Map<String, dynamic>? ?? props['Area'] as Map<String, dynamic>?;
          final areaSelect = areaProp != null ? areaProp['select'] as Map<String, dynamic>? : null;
          final area = areaSelect != null ? areaSelect['name']?.toString() : null;
          final metaProp = props['Meta Semanal'] as Map<String, dynamic>? ?? props['Meta'] as Map<String, dynamic>?;
          final meta = metaProp != null ? (metaProp['number'] as num?)?.toDouble() : null;
          materiasMap[m['id']] = {'nome': nome, 'area': area, 'meta_semanal': meta};
        }
      } catch (_) {}
    }

    if (estudosDiariosDatabaseId != null && estudosDiariosDatabaseId!.isNotEmpty) {
      try {
        final tops = await _queryDatabase(estudosDiariosDatabaseId!);
        for (final t in tops) {
          final props = t['properties'] as Map<String, dynamic>? ?? {};
          String nome = '';
          for (final prop in props.values) {
            if (prop is Map<String, dynamic> && prop['type'] == 'title') {
              final titleArray = prop['title'] as List<dynamic>? ?? [];
              nome = titleArray.map((e) => e['plain_text']?.toString() ?? '').join('').trim();
              break;
            }
          }
          final relProp = props['Banco de Dados: Matérias'] as Map<String, dynamic>?;
          String? matId;
          if (relProp != null && relProp['type'] == 'relation') {
            final relArray = relProp['relation'] as List<dynamic>? ?? [];
            if (relArray.isNotEmpty) matId = relArray.first['id']?.toString();
          }
          estudosDiariosMap[t['id']] = {'nome': nome, 'materia_id': matId};
        }
      } catch (_) {}
    }

    // Métricas gerais e contextuais
    int totalMinutosGeral = 0;
    int totalMinutosEstudos = 0;
    int totalMinutosTrabalho = 0;
    int totalSessoesEstudos = 0;
    int totalSessoesTrabalho = 0;

    final Map<String, int> minPorMateriaEstudos = {};
    final Map<String, int> minPorProjetoTrabalho = {};
    final Set<String> tarefasEstudos = {};
    final Set<String> tarefasTrabalho = {};
    final Set<String> diasAtivosGeral = {};
    final Set<String> diasAtivosEstudos = {};
    final Set<String> diasAtivosTrabalho = {};

    // 7 dias da semana: Seg (0) a Dom (6)
    final List<double> horasEstudosPorDia = List.filled(7, 0.0);
    final List<double> horasTrabalhoPorDia = List.filled(7, 0.0);

    for (final s in sessoes) {
      final props = s['properties'] as Map<String, dynamic>? ?? {};

      String titulo = '';
      for (final prop in props.values) {
        if (prop is Map<String, dynamic> && prop['type'] == 'title') {
          final p = prop['title'] as List<dynamic>? ?? [];
          titulo = p.map((e) => e['plain_text']?.toString() ?? '').join('').trim();
          break;
        }
      }

      final inicioStr = (props['Início'] as Map<String, dynamic>?)?['date']?['start'] as String?;
      final fimStr = (props['Fim'] as Map<String, dynamic>?)?['date']?['start'] as String?;

      int mins = 0;
      DateTime? ini;
      if (inicioStr != null && fimStr != null) {
        ini = DateTime.tryParse(inicioStr)?.toLocal();
        final fi = DateTime.tryParse(fimStr)?.toLocal();
        if (ini != null && fi != null && fi.isAfter(ini)) {
          mins = fi.difference(ini).inMinutes;
        }
      }

      if (mins <= 0 || ini == null) continue;

      final tech = (props['Tecnologia'] as Map<String, dynamic>?)?['select']?['name'] as String? ?? '';

      // Tenta resolver matéria pela relação
      String materiaNome = tech.isNotEmpty ? tech : 'Geral';
      String? areaMateria;
      final relationProp = props['Sessão de Estudo'] as Map<String, dynamic>?;
      if (relationProp != null && relationProp['type'] == 'relation') {
        final relArray = relationProp['relation'] as List<dynamic>? ?? [];
        if (relArray.isNotEmpty) {
          final topicoId = relArray.first['id']?.toString();
          if (topicoId != null && estudosDiariosMap.containsKey(topicoId)) {
            final top = estudosDiariosMap[topicoId]!;
            final matId = top['materia_id'];
            if (matId != null && materiasMap.containsKey(matId)) {
              final mat = materiasMap[matId]!;
              materiaNome = mat['nome'] ?? materiaNome;
              areaMateria = mat['area'];
            }
          }
        }
      }

      // Classificação Trabalho vs Estudos
      bool isTrab = false;
      if (isMateriaTrabalho != null) {
        isTrab = isMateriaTrabalho(materiaNome, areaMateria);
      }
      if (!isTrab) {
        final tLower = tech.toLowerCase();
        final mLower = materiaNome.toLowerCase();
        if (tLower == 'trabalho' || tLower == 'implanta' || mLower.contains('trabalho') || mLower.contains('implanta')) {
          isTrab = true;
        }
      }

      final diaIndex = (ini.weekday - 1).clamp(0, 6);
      final diaKey = '${ini.year}-${ini.month.toString().padLeft(2, '0')}-${ini.day.toString().padLeft(2, '0')}';
      final horas = mins / 60.0;

      totalMinutosGeral += mins;
      diasAtivosGeral.add(diaKey);

      if (isTrab) {
        totalMinutosTrabalho += mins;
        totalSessoesTrabalho++;
        diasAtivosTrabalho.add(diaKey);
        horasTrabalhoPorDia[diaIndex] += horas;
        minPorProjetoTrabalho[materiaNome] = (minPorProjetoTrabalho[materiaNome] ?? 0) + mins;
        if (titulo.isNotEmpty && !titulo.startsWith('[Encerrado]') && !titulo.startsWith('📊')) {
          tarefasTrabalho.add(titulo);
        }
      } else {
        totalMinutosEstudos += mins;
        totalSessoesEstudos++;
        diasAtivosEstudos.add(diaKey);
        horasEstudosPorDia[diaIndex] += horas;
        minPorMateriaEstudos[materiaNome] = (minPorMateriaEstudos[materiaNome] ?? 0) + mins;
        if (titulo.isNotEmpty && !titulo.startsWith('[Encerrado]') && !titulo.startsWith('📊')) {
          tarefasEstudos.add(titulo);
        }
      }
    }

    const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final iniLabel = '${inicioSemana.day} ${meses[inicioSemana.month - 1]}';
    final fimLabel = '${fimSemana.day} ${meses[fimSemana.month - 1]} ${fimSemana.year}';
    final tituloRelatorio = '📊 Relatório Semanal — $iniLabel a $fimLabel';

    final tempoGeralStr = _formatarMinutos(totalMinutosGeral);
    final tempoEstudosStr = _formatarMinutos(totalMinutosEstudos);
    final tempoTrabalhoStr = _formatarMinutos(totalMinutosTrabalho);

    final pctEstudos = totalMinutosGeral > 0 ? ((totalMinutosEstudos / totalMinutosGeral) * 100).round() : 0;
    final pctTrabalho = totalMinutosGeral > 0 ? ((totalMinutosTrabalho / totalMinutosGeral) * 100).round() : 0;

    // Identifica dia mais produtivo
    const nomesDias = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];
    int melhorDiaIndex = 0;
    double maxHorasDia = 0.0;
    for (int i = 0; i < 7; i++) {
      final totalDia = horasEstudosPorDia[i] + horasTrabalhoPorDia[i];
      if (totalDia > maxHorasDia) {
        maxHorasDia = totalDia;
        melhorDiaIndex = i;
      }
    }
    final diaMaisProdutivo = maxHorasDia > 0
        ? '${nomesDias[melhorDiaIndex]} (${maxHorasDia.toStringAsFixed(1)}h)'
        : 'Sem registros';

    final mediaDiariaHoras = diasAtivosGeral.isNotEmpty ? ((totalMinutosGeral / 60.0) / diasAtivosGeral.length).toStringAsFixed(1) : '0.0';

    final now = DateTime.now();
    final geradoEm =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Gera blocos para lista de Matérias de Estudo
    final matsEstudosOrdenadas = minPorMateriaEstudos.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final catEstudosBlocks = matsEstudosOrdenadas.isEmpty
        ? [_bulletBlock('Nenhuma sessão de estudo registrada.')]
        : matsEstudosOrdenadas.take(15).map((e) {
            final p = totalMinutosEstudos > 0 ? (e.value / totalMinutosEstudos) : 0.0;
            final tempo = _formatarMinutos(e.value);
            final barra = _gerarBarraUnicode(p);
            return _bulletBlock('📚 ${e.key}: $tempo  [$barra]');
          }).toList();

    // Gera blocos para lista de Projetos de Trabalho
    final matsTrabalhoOrdenadas = minPorProjetoTrabalho.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final catTrabalhoBlocks = matsTrabalhoOrdenadas.isEmpty
        ? [_bulletBlock('Nenhuma sessão de trabalho registrada.')]
        : matsTrabalhoOrdenadas.take(15).map((e) {
            final p = totalMinutosTrabalho > 0 ? (e.value / totalMinutosTrabalho) : 0.0;
            final tempo = _formatarMinutos(e.value);
            final barra = _gerarBarraUnicode(p);
            return _bulletBlock('💼 ${e.key}: $tempo  [$barra]');
          }).toList();

    final taskEstudosBlocks = tarefasEstudos.isEmpty
        ? [_bulletBlock('Nenhuma tarefa de estudo catalogada.')]
        : tarefasEstudos.take(20).map((t) => _bulletBlock('• $t')).toList();

    final taskTrabalhoBlocks = tarefasTrabalho.isEmpty
        ? [_bulletBlock('Nenhuma tarefa de trabalho catalogada.')]
        : tarefasTrabalho.take(20).map((t) => _bulletBlock('• $t')).toList();

    // URLs dos gráficos do QuickChart
    final urlGraficoBarras = _gerarUrlGraficoBarrasDiarias(horasEstudosPorDia, horasTrabalhoPorDia);
    final urlGraficoRosca = _gerarUrlGraficoRosca(totalMinutosEstudos / 60.0, totalMinutosTrabalho / 60.0);

    final blocks = <Map<String, dynamic>>[
      _calloutWithEmoji('Gerado automaticamente pelo Pomodoro Dev Tracker em $geradoEm', '🤖', 'gray_background'),
      _dividerBlock(),
      _heading2Block('🎯 Resumo Executivo (KPIs Gerais)'),
      _bulletBlock('⏱ Tempo Total Focado: $tempoGeralStr (${sessoes.length} sessões)'),
      _bulletBlock('📅 Dias Ativos: ${diasAtivosGeral.length} de 7 dias (Média de ${mediaDiariaHoras}h/dia ativo)'),
      _bulletBlock('⚖️ Distribuição: 📚 $pctEstudos% Estudos ($tempoEstudosStr)  |  💼 $pctTrabalho% Trabalho ($tempoTrabalhoStr)'),
      _bulletBlock('🏆 Dia Mais Produtivo: $diaMaisProdutivo'),
      _dividerBlock(),
      _heading2Block('📊 Evolução Diária na Semana'),
      _imageBlock(urlGraficoBarras),
      _dividerBlock(),
      _heading2Block('📚 Área de Estudos & Aprendizado'),
      _calloutWithEmoji('Total em Estudos: $tempoEstudosStr ($totalSessoesEstudos sessões em ${diasAtivosEstudos.length} dias)', '📘', 'blue_background'),
      _heading3Block('📂 Disciplinas Estudadas'),
      ...catEstudosBlocks,
      _heading3Block('📝 Tarefas de Estudo Concluídas'),
      ...taskEstudosBlocks,
      _dividerBlock(),
      _heading2Block('💼 Área de Trabalho & Projetos'),
      _calloutWithEmoji('Total em Trabalho: $tempoTrabalhoStr ($totalSessoesTrabalho sessões em ${diasAtivosTrabalho.length} dias)', '💼', 'orange_background'),
      _heading3Block('📂 Demandas e Projetos'),
      ...catTrabalhoBlocks,
      _heading3Block('📝 Entregas e Tarefas de Trabalho'),
      ...taskTrabalhoBlocks,
      _dividerBlock(),
      _heading2Block('🥧 Proporção de Foco'),
      _imageBlock(urlGraficoRosca),
      _dividerBlock(),
      _heading2Block('💡 Insights & Recomendações'),
      _calloutWithEmoji(
        '• Consistência: ${diasAtivosGeral.length >= 5 ? "Excelente ritmo semanal! Mais de 5 dias ativos." : "Meta de consistência: tente manter pelo menos 5 dias com blocos de foco."}\n'
        '• Equilíbrio: ${pctEstudos >= 40 && pctTrabalho >= 30 ? "Ótimo equilíbrio saudável entre trabalho e evolução nos estudos." : "Atenção à distribuição de tempo entre trabalho e capacitação contínua."}\n'
        '• Pico de Rendimento: Maior concentração de energia em $diaMaisProdutivo.',
        '💡',
        'green_background',
      ),
    ];

    final url = Uri.parse('https://api.notion.com/v1/pages');
    final reqBody = jsonEncode({
      "parent": {"page_id": pageIdLimpo},
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
    } else if (response.statusCode == 404) {
      throw Exception("Página do Notion não encontrada (404). Verifique se o link/ID está correto e se a Integração foi conectada à página em 'Connections'.");
    } else if (response.statusCode == 401) {
      throw Exception("Token do Notion inválido ou não autorizado (401).");
    } else {
      throw Exception('Falha ao criar relatório no Notion (${response.statusCode}): ${response.body}');
    }
  }

  String _formatarMinutos(int totalMinutos) {
    final h = totalMinutos ~/ 60;
    final m = totalMinutos % 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '${m}min';
  }

  String _gerarBarraUnicode(double percentual, [int tamanho = 10]) {
    final clamped = percentual.clamp(0.0, 1.0);
    final preenchido = (clamped * tamanho).round();
    final vazio = tamanho - preenchido;
    return '${'█' * preenchido}${'░' * vazio} ${(percentual * 100).toStringAsFixed(0)}%';
  }

  String _gerarUrlGraficoBarrasDiarias(List<double> estudos, List<double> trabalho) {
    final chartConfig = {
      "type": "bar",
      "data": {
        "labels": ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"],
        "datasets": [
          {
            "label": "Estudos (h)",
            "data": estudos.map((h) => double.parse(h.toStringAsFixed(1))).toList(),
            "backgroundColor": "#06b6d4",
            "borderRadius": 4,
          },
          {
            "label": "Trabalho (h)",
            "data": trabalho.map((h) => double.parse(h.toStringAsFixed(1))).toList(),
            "backgroundColor": "#f59e0b",
            "borderRadius": 4,
          }
        ]
      },
      "options": {
        "scales": {
          "x": {
            "stacked": true,
            "ticks": {"color": "#94a3b8", "font": {"weight": "bold"}},
            "grid": {"color": "rgba(255,255,255,0.06)"}
          },
          "y": {
            "stacked": true,
            "ticks": {"color": "#94a3b8"},
            "grid": {"color": "rgba(255,255,255,0.06)"}
          }
        },
        "plugins": {
          "legend": {
            "labels": {"color": "#f8fafc", "font": {"weight": "bold", "size": 12}}
          },
          "title": {
            "display": true,
            "text": "Foco Diário na Semana (Horas)",
            "color": "#f8fafc",
            "font": {"size": 15, "weight": "bold"}
          }
        }
      }
    };
    final jsonStr = jsonEncode(chartConfig);
    return "https://quickchart.io/chart?w=600&h=300&bkg=%230f172a&c=${Uri.encodeComponent(jsonStr)}";
  }

  String _gerarUrlGraficoRosca(double horasEstudos, double horasTrabalho) {
    final chartConfig = {
      "type": "doughnut",
      "data": {
        "labels": ["📚 Estudos", "💼 Trabalho"],
        "datasets": [
          {
            "data": [
              double.parse(horasEstudos.toStringAsFixed(1)),
              double.parse(horasTrabalho.toStringAsFixed(1)),
            ],
            "backgroundColor": ["#06b6d4", "#f59e0b"],
            "borderWidth": 2,
            "borderColor": "#0f172a"
          }
        ]
      },
      "options": {
        "plugins": {
          "legend": {
            "position": "bottom",
            "labels": {"color": "#f8fafc", "font": {"weight": "bold", "size": 13}}
          },
          "title": {
            "display": true,
            "text": "Distribuição Geral de Foco",
            "color": "#f8fafc",
            "font": {"size": 15, "weight": "bold"}
          }
        }
      }
    };
    final jsonStr = jsonEncode(chartConfig);
    return "https://quickchart.io/chart?w=500&h=300&bkg=%230f172a&c=${Uri.encodeComponent(jsonStr)}";
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

      String tarefa = '';
      for (final prop in props.values) {
        if (prop is Map<String, dynamic> && prop['type'] == 'title') {
          final titleArray = prop['title'] as List<dynamic>? ?? [];
          tarefa = titleArray.map((e) => e['plain_text']?.toString() ?? '').join('').trim();
          break;
        }
      }
      
      if (inicioStr != null && fimStr != null) {
        sessoes.add({
          "inicio": inicioStr,
          "fim": fimStr,
          "tecnologia": tech,
          "tarefa": tarefa,
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

  Map<String, dynamic> _calloutWithEmoji(String text, String emoji, [String color = "gray_background"]) => {
        "object": "block",
        "type": "callout",
        "callout": {
          "icon": {"type": "emoji", "emoji": emoji},
          "rich_text": [
            {"type": "text", "text": {"content": text}}
          ],
          "color": color,
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

  Map<String, dynamic> _heading3Block(String text) => {
        "object": "block",
        "type": "heading_3",
        "heading_3": {
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

  Map<String, dynamic> _imageBlock(String url) => {
        "object": "block",
        "type": "image",
        "image": {
          "type": "external",
          "external": {"url": url},
        },
      };
}
