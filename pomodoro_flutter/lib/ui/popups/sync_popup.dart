import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/sync_service.dart';

class SyncPopup extends StatefulWidget {
  const SyncPopup({Key? key}) : super(key: key);

  static void mostrar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SyncPopup(),
    );
  }

  @override
  State<SyncPopup> createState() => _SyncPopupState();
}

class _SyncPopupState extends State<SyncPopup> {
  final _sync = SyncService();
  final _ipController = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _stateSub;
  bool _buscando = false;
  bool _conectando = false;
  String? _erro;
  Map<String, dynamic>? _ultimoEstado;

  @override
  void initState() {
    super.initState();
    if (_sync.connected) {
      _stateSub = _sync.stateStream.listen((s) {
        if (mounted) setState(() => _ultimoEstado = s);
      });
    }
    if (_sync.pcIp != null) _ipController.text = _sync.pcIp!;
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _buscarAutomatico() async {
    setState(() { _buscando = true; _erro = null; });
    final ip = await _sync.descobrirPc();
    if (!mounted) return;
    if (ip != null) {
      _ipController.text = ip;
      await _conectar(ip);
    } else {
      setState(() { _buscando = false; _erro = 'PC não encontrado. Verifique se estão na mesma rede Wi-Fi e se o app está aberto no PC.'; });
    }
  }

  Future<void> _conectar(String ip) async {
    setState(() { _buscando = false; _conectando = true; _erro = null; });
    final ok = await _sync.conectar(ip.trim());
    if (!mounted) return;
    if (ok) {
      _stateSub?.cancel();
      _stateSub = _sync.stateStream.listen((s) {
        if (mounted) setState(() => _ultimoEstado = s);
      });
      setState(() => _conectando = false);
    } else {
      setState(() { _conectando = false; _erro = 'Falha ao conectar em $ip:8082. Verifique o IP e tente novamente.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_rounded, color: _sync.connected ? Colors.greenAccent : Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                _sync.connected ? 'Conectado ao PC' : 'Sincronizar com PC',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_sync.connected) ...[
                const SizedBox(width: 6),
                Text('(${_sync.pcIp})', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: 16),

          if (_sync.connected) ...[
            _buildEstadoRemoto(),
            const SizedBox(height: 16),
            _buildControlesRemoto(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await _sync.desconectar();
                _stateSub?.cancel();
                setState(() => _ultimoEstado = null);
              },
              icon: const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.redAccent),
              label: const Text('Desconectar', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: (_buscando || _conectando) ? null : _buscarAutomatico,
              icon: (_buscando || _conectando)
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black))
                  : const Icon(Icons.search_rounded, size: 16),
              label: Text(
                _buscando ? 'Buscando...' : (_conectando ? 'Conectando...' : 'Buscar PC automaticamente'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            Text('ou', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Ex: 192.168.1.100',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: (_buscando || _conectando) ? null : () => _conectar(_ipController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Conectar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(_erro!, style: const TextStyle(color: Colors.redAccent, fontSize: 11.5)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEstadoRemoto() {
    final s = _ultimoEstado;
    if (s == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2));
    }
    final rodando = s['rodando'] as bool? ?? false;
    final pausado = s['pausado'] as bool? ?? false;
    final descanso = s['modo_descanso'] as bool? ?? false;
    final tempo = s['tempo_restante_fmt'] as String? ?? '--:--';
    final tarefa = s['tarefa_atual'] as String? ?? '';
    final progresso = (s['progresso'] as num?)?.toDouble() ?? 0.0;
    final cor = pausado ? Colors.amber : (descanso ? Colors.orangeAccent : Colors.cyanAccent);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progresso,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(cor),
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 14),
          Text(
            tempo,
            style: TextStyle(color: cor, fontSize: 44, fontWeight: FontWeight.w200, fontFamily: 'monospace', letterSpacing: 2),
          ),
          if (tarefa.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(tarefa, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12), overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 6),
          Text(
            !rodando ? 'PARADO' : (pausado ? 'PAUSADO' : (descanso ? 'DESCANSO' : 'FOCO')),
            style: TextStyle(color: cor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildControlesRemoto() {
    final s = _ultimoEstado;
    final rodando = s?['rodando'] as bool? ?? false;
    final pausado = s?['pausado'] as bool? ?? false;
    final descanso = s?['modo_descanso'] as bool? ?? false;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: rodando ? () => _sync.enviarComando('pause') : null,
            icon: Icon(pausado ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 16),
            label: Text(pausado ? 'Retomar' : 'Pausar', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              disabledBackgroundColor: Colors.white.withOpacity(0.04),
              disabledForegroundColor: Colors.white.withOpacity(0.2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (descanso)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _sync.enviarComando('skip'),
              icon: const Icon(Icons.skip_next_rounded, size: 16),
              label: const Text('Pular Descanso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          )
        else
          Expanded(
            child: ElevatedButton.icon(
              onPressed: rodando ? () => _sync.enviarComando('finish') : null,
              icon: const Icon(Icons.flag_rounded, size: 16),
              label: const Text('Encerrar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                disabledBackgroundColor: Colors.white.withOpacity(0.04),
                disabledForegroundColor: Colors.white.withOpacity(0.2),
              ),
            ),
          ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _sync.enviarComando('reset'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.06),
            foregroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Icon(Icons.stop_rounded, size: 18),
        ),
      ],
    );
  }
}
