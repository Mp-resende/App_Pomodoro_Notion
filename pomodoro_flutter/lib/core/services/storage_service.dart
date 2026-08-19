import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  // Nomes de arquivos idênticos aos definidos em Python
  static const String configFile = "config.json";
  Directory? _cachedBaseDir;
  Directory? _cachedAppDataDir;
  static const String contadorFile = "pomodoros_contador.json";
  static const String offlineFile = "sessoes_offline.json";
  static const String logFile = "pomodoro.log";
  static const String historicoFile = "historico_tarefas.json";

  // Retorna o diretório base adequado para cada plataforma (resultado cacheado após primeira chamada)
  Future<Directory> getBaseDir() async {
    if (_cachedBaseDir != null) return _cachedBaseDir!;
    if (Platform.isWindows) {
      try {
        final dir = File(Platform.resolvedExecutable).parent;
        final testFile = File('${dir.path}/.write_test');
        await testFile.writeAsString('test');
        await testFile.delete();
        _cachedBaseDir = dir;
      } catch (_) {
        _cachedBaseDir = await getApplicationSupportDirectory();
      }
    } else {
      _cachedBaseDir = await getApplicationSupportDirectory();
    }
    return _cachedBaseDir!;
  }

  // Retorna o diretório permanente do sistema (AppData) para backup e persistência entre builds
  Future<Directory> getAppDataDir() async {
    if (_cachedAppDataDir != null) return _cachedAppDataDir!;
    try {
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null && appData.isNotEmpty) {
          final dir = Directory('$appData/PomodoroNotion');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          _cachedAppDataDir = dir;
          return _cachedAppDataDir!;
        }
      }
      _cachedAppDataDir = await getApplicationSupportDirectory();
    } catch (_) {
      _cachedAppDataDir = await getApplicationSupportDirectory();
    }
    return _cachedAppDataDir!;
  }

  // Retorna o arquivo com o caminho correto centralizado
  Future<File> getFile(String filename) async {
    final baseDir = await getBaseDir();
    return File('${baseDir.path}/$filename');
  }

  // Escreve dados em formato JSON (salva localmente e espelha no AppData permanente)
  Future<void> writeJson(String filename, dynamic data) async {
    final jsonStr = const JsonEncoder.withIndent('    ').convert(data);
    try {
      final file = await getFile(filename);
      await file.writeAsString(jsonStr, encoding: utf8);
    } catch (e) {
      stderr.writeln('Erro ao gravar arquivo JSON local ($filename): $e');
    }

    // Espelha no AppData para garantir persistência mesmo após compilações ou deleção da pasta de build
    try {
      final appDataDir = await getAppDataDir();
      final appDataFile = File('${appDataDir.path}/$filename');
      await appDataFile.writeAsString(jsonStr, encoding: utf8);
    } catch (e) {
      stderr.writeln('Erro ao espelhar arquivo JSON no AppData ($filename): $e');
    }
  }

  // Lê dados em formato JSON de um arquivo (com fallback para o AppData permanente)
  Future<dynamic> readJson(String filename) async {
    try {
      // 1. Tenta ler o arquivo local junto ao executável
      final file = await getFile(filename);
      if (await file.exists()) {
        final content = await file.readAsString(encoding: utf8);
        final decoded = jsonDecode(content);
        if (decoded != null) {
          // Se for config.json, verifica se contém chaves preenchidas
          if (filename == configFile && decoded is Map<String, dynamic>) {
            final key = decoded['notion_api_key']?.toString() ?? '';
            // Se o arquivo local estiver com chaves vazias, tenta buscar no AppData
            if (key.isEmpty) {
              final appDataDir = await getAppDataDir();
              final appDataFile = File('${appDataDir.path}/$filename');
              if (await appDataFile.exists()) {
                final appDataContent = await appDataFile.readAsString(encoding: utf8);
                final appDataDecoded = jsonDecode(appDataContent);
                if (appDataDecoded is Map<String, dynamic> &&
                    (appDataDecoded['notion_api_key']?.toString().isNotEmpty ?? false)) {
                  // Restaura o arquivo local com a chave do AppData
                  await file.writeAsString(appDataContent, encoding: utf8);
                  return appDataDecoded;
                }
              }
            }
          }

          // Espelha no AppData preventivamente
          try {
            final appDataDir = await getAppDataDir();
            final appDataFile = File('${appDataDir.path}/$filename');
            if (!await appDataFile.exists()) {
              await appDataFile.writeAsString(content, encoding: utf8);
            }
          } catch (_) {}

          return decoded;
        }
      }

      // 2. Fallback: Se não existe localmente, busca no AppData permanente
      final appDataDir = await getAppDataDir();
      final appDataFile = File('${appDataDir.path}/$filename');
      if (await appDataFile.exists()) {
        final content = await appDataFile.readAsString(encoding: utf8);
        final decoded = jsonDecode(content);
        if (decoded != null) {
          // Restaura automaticamente a cópia local junto ao executável
          try {
            await file.writeAsString(content, encoding: utf8);
          } catch (_) {}
          return decoded;
        }
      }
    } catch (e) {
      stderr.writeln('Erro ao ler arquivo JSON ($filename): $e');
    }
    return null;
  }

  // Escreve mensagens de log com rotação automática ao atingir 1 MB
  Future<void> logMessage(String message) async {
    try {
      final file = await getFile(logFile);
      if (await file.exists() && await file.length() > 1 * 1024 * 1024) {
        await file.writeAsString('', encoding: utf8);
      }
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString(
        '$timestamp - INFO - $message\n',
        mode: FileMode.append,
        encoding: utf8,
      );
    } catch (e) {
      stderr.writeln('Erro ao escrever log local: $e');
    }
  }
}
