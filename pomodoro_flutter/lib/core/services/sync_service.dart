import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Cliente WebSocket para o Android se conectar ao PC via rede local.
// Descobre o IP do PC automaticamente via beacon UDP na porta 8083.
class SyncService {
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;
  SyncService._();

  WebSocket? _socket;
  RawDatagramSocket? _udpSocket;

  final _stateCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _connCtrl = StreamController<bool>.broadcast();

  bool _connected = false;
  String? _pcIp;

  bool get connected => _connected;
  String? get pcIp => _pcIp;
  Stream<Map<String, dynamic>> get stateStream => _stateCtrl.stream;
  Stream<bool> get connectionStream => _connCtrl.stream;

  // Escuta beacons UDP na porta 8083 para encontrar o IP do PC automaticamente
  Future<String?> descobrirPc({Duration timeout = const Duration(seconds: 6)}) async {
    try {
      _udpSocket?.close();
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8083);
      final completer = Completer<String?>();
      final timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(null);
      });
      _udpSocket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = _udpSocket!.receive();
        if (dg == null) return;
        try {
          final data = jsonDecode(String.fromCharCodes(dg.data)) as Map<String, dynamic>;
          if (data['service'] == 'pomodoro_notion' && !completer.isCompleted) {
            timer.cancel();
            completer.complete(data['ip']?.toString());
          }
        } catch (_) {}
      });
      return await completer.future;
    } catch (_) {
      return null;
    } finally {
      _udpSocket?.close();
      _udpSocket = null;
    }
  }

  Future<bool> conectar(String ip) async {
    await desconectar();
    try {
      _socket = await WebSocket.connect('ws://$ip:8082/ws')
          .timeout(const Duration(seconds: 5));
      _pcIp = ip;
      _connected = true;
      _connCtrl.add(true);
      _socket!.listen(
        (msg) {
          try {
            _stateCtrl.add(jsonDecode(msg.toString()) as Map<String, dynamic>);
          } catch (_) {}
        },
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: false,
      );
      return true;
    } catch (_) {
      _connected = false;
      return false;
    }
  }

  void enviarComando(String action) {
    if (_socket?.readyState != WebSocket.open) return;
    _socket!.add(jsonEncode({'action': action}));
  }

  Future<void> desconectar() async {
    await _socket?.close();
    _socket = null;
    _handleDisconnect();
  }

  void _handleDisconnect() {
    if (_connected) {
      _connected = false;
      _pcIp = null;
      _connCtrl.add(false);
    }
  }
}
