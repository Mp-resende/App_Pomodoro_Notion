import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../data/models/session_offline.dart';
import 'storage_service.dart';

class NotionService {
  final String apiKey;
  final String databaseId;
  final StorageService storageService;
  bool connected = false;

  NotionService({
    required this.apiKey,
    required this.databaseId,
    required this.storageService,
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

  // Busca os registros disponíveis de uma database relacionada
  Future<List<Map<String, String>>> consultarOpcoesRelacao(String relatedDbId, {int retries = 3}) async {
    if (!connected) return [];
    final url = Uri.parse('https://api.notion.com/v1/databases/$relatedDbId/query');
    final body = jsonEncode({}); // Query vazia para listar todas as linhas

    for (int tentativa = 0; tentativa < retries; tentativa++) {
      try {
        final response = await http.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List<dynamic>? ?? [];
          final List<Map<String, String>> opcoes = [];

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
          return opcoes;
        }
      } catch (_) {}
      if (tentativa < retries - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return [];
  }
}
