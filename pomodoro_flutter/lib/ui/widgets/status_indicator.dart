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
        // Alerta dinâmico de sessões offline pendentes
        FutureBuilder<int>(
          future: timerProvider.notionService?.contarSessoesOffline() ?? Future.value(0),
          builder: (context, snapshot) {
            final pendentes = snapshot.data ?? 0;
            if (pendentes > 0) {
              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      Icons.warning_amber_rounded,
                      color: Colors.orangeAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "⚠️ $pendentes sessão(ões) pendente(s) aguardando sincronização com o Notion.",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
