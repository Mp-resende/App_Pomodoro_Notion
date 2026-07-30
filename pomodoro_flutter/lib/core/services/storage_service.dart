import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  // Nomes de arquivos idênticos aos definidos em Python
  static const String configFile = "config.json";
  Directory? _cachedBaseDir;
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

  // Retorna o arquivo com o caminho correto centralizado
  Future<File> getFile(String filename) async {
    final baseDir = await getBaseDir();
    return File('${baseDir.path}/$filename');
  }

  // Escreve dados em formato JSON em um arquivo
  Future<void> writeJson(String filename, dynamic data) async {
    try {
      final file = await getFile(filename);
      await file.writeAsString(const JsonEncoder.withIndent('    ').convert(data), encoding: utf8);
    } catch (e) {
      // Escreve em stdout para logs internos do Flutter
      stderr.writeln('Erro ao gravar arquivo JSON ($filename): $e');
    }
  }

  // Lê dados em formato JSON de um arquivo
  Future<dynamic> readJson(String filename) async {
    try {
      final file = await getFile(filename);
      if (await file.exists()) {
        final content = await file.readAsString(encoding: utf8);
        return jsonDecode(content);
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
