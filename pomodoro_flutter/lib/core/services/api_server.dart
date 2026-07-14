import 'dart:convert';
import 'dart:io';
import '../../logic/providers/timer_provider.dart';

class ApiServer {
  final TimerProvider timerProvider;
  HttpServer? _server;
  bool _running = false;

  ApiServer({required this.timerProvider});

  // Inicializa o servidor HTTP
  Future<void> iniciar() async {
    if (_running) return;

    try {
      // Escuta em qualquer interface IPv4 (anyIPv4) na porta 8082
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8082);
      _running = true;
      stderr.writeln('✓ Servidor HTTP da API local ativo na porta 8082');

      _server!.listen((HttpRequest request) async {
        // Configura cabeçalhos de CORS para integração externa livre
        request.response.headers.add("Access-Control-Allow-Origin", "*");
        request.response.headers.add("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        request.response.headers.add("Access-Control-Allow-Headers", "Content-Type");

        if (request.method == 'OPTIONS') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }

        final path = request.uri.path;

        if (request.method == 'GET' && path == '/api/status') {
          await _handleStatus(request);
        } else if (request.method == 'POST') {
          if (path == '/api/start') {
            await _handleStart(request);
          } else if (path == '/api/pause') {
            await _handlePause(request);
          } else if (path == '/api/reset') {
            await _handleReset(request);
          } else if (path == '/api/finish') {
            await _handleFinish(request);
          } else {
            await _sendNotFound(request);
          }
        } else {
          await _sendNotFound(request);
        }
      });
    } catch (e) {
      stderr.writeln('Erro ao iniciar o servidor HTTP da API local: $e');
    }
  }

  // Encerra o servidor HTTP
  Future<void> parar() async {
    if (!_running) return;
    try {
      await _server?.close(force: true);
      _running = false;
      stderr.writeln('✓ Servidor HTTP da API local finalizado');
    } catch (e) {
      stderr.writeln('Erro ao finalizar o servidor da API: $e');
    }
  }

  // GET /api/status - Retorna o estado atualizado do cronômetro
  Future<void> _handleStatus(HttpRequest request) async {
    final state = {
      "rodando": timerProvider.rodando,
      "pausado": timerProvider.pausado,
      "modo_descanso": timerProvider.modoDescanso,
      "tempo_restante_fmt": timerProvider.obterTempoFormatado(),
      "tempo_restante_segundos": timerProvider.tempoRestante,
      "tarefa_atual": timerProvider.tarefaAtual,
      "categoria_atual": timerProvider.categoriaAtual,
      "pomodoros_hoje": timerProvider.pomodorosHoje,
      "pomodoros_completados": timerProvider.pomodorosCompletados
    };

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(state));
    await request.response.close();
  }

  // POST /api/start - Inicia um pomodoro com parâmetros opcionais de tarefa e tecnologia
  Future<void> _handleStart(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      final body = content.isNotEmpty ? jsonDecode(content) as Map<String, dynamic> : {};

      final String? tarefa = body['tarefa']?.toString().trim();
      final String? categoria = body['categoria']?.toString().trim();

      // Executa o início na main thread de forma thread-safe (gerenciado pelo Provider)
      timerProvider.iniciarViaApi(tarefa: tarefa, categoria: categoria);

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({"status": "ok", "message": "Timer started"}));
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({"error": e.toString()}));
    }
    await request.response.close();
  }

  // POST /api/pause - Alterna entre pausar e retomar
  Future<void> _handlePause(HttpRequest request) async {
    timerProvider.pausarRetomar();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({"status": "ok", "message": "Timer paused/resumed"}));
    await request.response.close();
  }

  // POST /api/reset - Reseta o cronômetro
  Future<void> _handleReset(HttpRequest request) async {
    timerProvider.resetar();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({"status": "ok", "message": "Timer reset"}));
    await request.response.close();
  }

  // POST /api/finish - Encerra a sessão de foco manualmente
  Future<void> _handleFinish(HttpRequest request) async {
    timerProvider.finalizarSessaoManualmente();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({"status": "ok", "message": "Session finished"}));
    await request.response.close();
  }

  // Retorna erro 404 para rotas desconhecidas
  Future<void> _sendNotFound(HttpRequest request) async {
    request.response.statusCode = HttpStatus.notFound;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({"error": "Endpoint not found"}));
    await request.response.close();
  }
}
