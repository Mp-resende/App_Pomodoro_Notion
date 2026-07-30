import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../logic/providers/timer_provider.dart';

class ApiServer {
  final TimerProvider timerProvider;
  HttpServer? _server;
  bool _running = false;

  final List<WebSocket> _wsClients = [];
  RawDatagramSocket? _udpBeacon;
  Timer? _beaconTimer;
  String? _localIp;

  ApiServer({required this.timerProvider});

  Future<void> iniciar() async {
    if (_running) return;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8082);
      _running = true;
      _localIp = await _detectarIpLocal();
      stderr.writeln('✓ Servidor HTTP/WebSocket ativo em $_localIp:8082');

      timerProvider.addListener(_onTimerStateChanged);
      _iniciarBeaconUdp();

      _server!.listen((HttpRequest request) async {
        request.response.headers.add("Access-Control-Allow-Origin", "*");
        request.response.headers.add("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        request.response.headers.add("Access-Control-Allow-Headers", "Content-Type");

        if (WebSocketTransformer.isUpgradeRequest(request)) {
          await _handleWebSocket(request);
          return;
        }

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
      stderr.writeln('Erro ao iniciar servidor: $e');
    }
  }

  Future<void> parar() async {
    if (!_running) return;
    try {
      timerProvider.removeListener(_onTimerStateChanged);
      _beaconTimer?.cancel();
      _udpBeacon?.close();
      for (final ws in List<WebSocket>.from(_wsClients)) {
        await ws.close();
      }
      _wsClients.clear();
      await _server?.close(force: true);
      _running = false;
    } catch (e) {
      stderr.writeln('Erro ao finalizar servidor: $e');
    }
  }

  // --- WebSocket ---

  Future<void> _handleWebSocket(HttpRequest request) async {
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      _wsClients.add(socket);
      socket.add(jsonEncode(_buildState()));
      socket.listen(
        (msg) => _handleWsMessage(msg.toString()),
        onDone: () => _wsClients.remove(socket),
        onError: (_) => _wsClients.remove(socket),
        cancelOnError: true,
      );
    } catch (e) {
      stderr.writeln('Erro ao aceitar WebSocket: $e');
    }
  }

  void _onTimerStateChanged() {
    if (_wsClients.isEmpty) return;
    final payload = jsonEncode(_buildState());
    final dead = <WebSocket>[];
    for (final ws in _wsClients) {
      try {
        if (ws.readyState == WebSocket.open) {
          ws.add(payload);
        } else {
          dead.add(ws);
        }
      } catch (_) {
        dead.add(ws);
      }
    }
    _wsClients.removeWhere(dead.contains);
  }

  void _handleWsMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      switch (data['action']?.toString()) {
        case 'pause': timerProvider.pausarRetomar(); break;
        case 'reset': timerProvider.resetar(); break;
        case 'skip': timerProvider.pularDescanso(); break;
        case 'finish': timerProvider.finalizarSessaoManualmente(); break;
        case 'start':
          timerProvider.iniciarViaApi(
            tarefa: data['tarefa']?.toString(),
            categoria: data['categoria']?.toString(),
          );
          break;
      }
    } catch (_) {}
  }

  Map<String, dynamic> _buildState() => {
    "rodando": timerProvider.rodando,
    "pausado": timerProvider.pausado,
    "modo_descanso": timerProvider.modoDescanso,
    "tempo_restante_fmt": timerProvider.obterTempoFormatado(),
    "tempo_restante_segundos": timerProvider.tempoRestante,
    "tarefa_atual": timerProvider.tarefaAtual,
    "categoria_atual": timerProvider.categoriaAtual,
    "pomodoros_hoje": timerProvider.pomodorosHoje,
    "pomodoros_completados": timerProvider.pomodorosCompletados,
    "progresso": timerProvider.progresso,
    "label_status": timerProvider.labelStatus,
  };

  // --- UDP Beacon (autodescoberta do PC na rede) ---

  Future<void> _iniciarBeaconUdp() async {
    if (_localIp == null) return;
    try {
      _udpBeacon = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpBeacon!.broadcastEnabled = true;
      final payload = jsonEncode({"service": "pomodoro_notion", "ip": _localIp, "port": 8082})
          .codeUnits;
      _beaconTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        try {
          _udpBeacon?.send(payload, InternetAddress('255.255.255.255'), 8083);
        } catch (_) {}
      });
    } catch (e) {
      stderr.writeln('Aviso: beacon UDP indisponível: $e');
    }
  }

  Future<String?> _detectarIpLocal() async {
    try {
      for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  // --- REST endpoints (inalterados) ---

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
      "pomodoros_completados": timerProvider.pomodorosCompletados,
    };
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(state));
    await request.response.close();
  }

  Future<void> _handleStart(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      final body = content.isNotEmpty ? jsonDecode(content) as Map<String, dynamic> : {};
      timerProvider.iniciarViaApi(
        tarefa: body['tarefa']?.toString().trim(),
        categoria: body['categoria']?.toString().trim(),
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({"status": "ok", "message": "Timer started"}));
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({"error": e.toString()}));
    }
    await request.response.close();
  }

  Future<void> _handlePause(HttpRequest request) async {
    timerProvider.pausarRetomar();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({"status": "ok", "message": "Timer paused/resumed"}));
    await request.response.close();
  }

  Future<void> _handleReset(HttpRequest request) async {
    timerProvider.resetar();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({"status": "ok", "message": "Timer reset"}));
    await request.response.close();
  }

  Future<void> _handleFinish(HttpRequest request) async {
    timerProvider.finalizarSessaoManualmente();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({"status": "ok", "message": "Session finished"}));
    await request.response.close();
  }

  Future<void> _sendNotFound(HttpRequest request) async {
    request.response.statusCode = HttpStatus.notFound;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({"error": "Endpoint not found"}));
    await request.response.close();
  }
}
