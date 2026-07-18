import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/timer_provider.dart';

class StatusIndicator extends StatelessWidget {
  const StatusIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timerProvider = Provider.of<TimerProvider>(context);
    final conectado = timerProvider.notionService != null && timerProvider.notionService!.connected;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Ponto indicador com brilho neon
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: conectado ? Colors.greenAccent : Colors.redAccent,
                    boxShadow: [
                      BoxShadow(
                        color: (conectado ? Colors.greenAccent : Colors.redAccent).withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  conectado ? "Notion Conectado" : "Modo Offline",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: conectado ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ],
            ),
            // Botão "Reconectar" estilo Glassmorphism sutil (exibido apenas quando desconectado)
            if (!conectado)
              Material(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => timerProvider.reconectarNotion(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.06),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 13,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Reconectar",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Alerta dinâmico de sessões offline pendentes (atualizado de forma reativa pelo provider)
        if (timerProvider.sessoesOfflineCount > 0)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.orangeAccent.withOpacity(0.18),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.orangeAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${timerProvider.sessoesOfflineCount} sessão(ões) pendente(s) offline.",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ),
                // Botão de Sincronização Manual
                Material(
                  color: Colors.orangeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Sincronizando tarefas pendentes com o Notion..."),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      final qtd = await timerProvider.forcarSincronizacaoOffline();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        if (qtd > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("🎉 $qtd sessão(ões) sincronizada(s) com sucesso!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("⚠️ Não foi possível sincronizar. Verifique sua conexão."),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Sincronizar",
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
