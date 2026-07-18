import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // VersÃ£o estÃ¡tica local instalada no aplicativo (devemos incrementar em futuras releases)
  static const String versaoAtual = "1.3.0";

  // URL do JSON de versÃ£o hospedado na branch main do repositÃ³rio no GitHub
  static const String _urlVersaoJson =
      "https://raw.githubusercontent.com/Mp-resende/App_Pomodoro_Notion/main/version.json";

  // Verifica se hÃ¡ novas atualizaÃ§Ãµes disponÃ­veis no GitHub
  static Future<Map<String, dynamic>?> verificarAtualizacao() async {
    try {
      final response = await http.get(Uri.parse(_urlVersaoJson)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey("version")) {
          final versaoRemota = data["version"].toString();
          if (_compararVersoes(versaoRemota, versaoAtual)) {
            return {
              "nova_versao": versaoRemota,
              "url": Platform.isWindows
                  ? (data["windows_url"]?.toString() ?? "")
                  : (data["android_url"]?.toString() ?? ""),
            };
          }
        }
      }
    } catch (_) {
      // Ignora falhas de rede de forma silenciosa para nÃ£o quebrar a experiÃªncia do usuÃ¡rio
    }
    return null;
  }

  // LanÃ§a a URL do novo APK ou ZIP direto no navegador do dispositivo
  static Future<void> iniciarAtualizacao(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // ForÃ§a a abertura no navegador do sistema
      );
    } catch (e) {
      stderr.writeln('Erro ao abrir navegador para atualizacao: $e');
    }
  }

  // UtilitÃ¡rio de comparaÃ§Ã£o semÃ¢ntica simples de versÃµes (ex: "1.0.2" > "1.0.1")
  static bool _compararVersoes(String remota, String local) {
    try {
      final partesRemota = remota.split('.').map(int.parse).toList();
      final partesLocal = local.split('.').map(int.parse).toList();

      for (var i = 0; i < partesRemota.length; i++) {
        if (i >= partesLocal.length) return true; // ex: 1.0.1.1 > 1.0.1
        if (partesRemota[i] > partesLocal[i]) return true;
        if (partesRemota[i] < partesLocal[i]) return false;
      }
    } catch (_) {}
    return false;
  }
}
