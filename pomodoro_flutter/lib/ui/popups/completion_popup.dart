import 'dart:ui';
import 'package:flutter/material.dart';
import '../../logic/providers/timer_provider.dart';

class CompletionPopup extends StatelessWidget {
  final TimerProvider timerProvider;

  const CompletionPopup({
    Key? key,
    required this.timerProvider,
  }) : super(key: key);

  // Método estático auxiliar para disparar a exibição do diálogo de forma simples
  static void mostrar(BuildContext context, TimerProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false, // Impede o fechamento ao tocar fora da janela
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: CompletionPopup(timerProvider: provider),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tarefa = timerProvider.tarefaAtual;
    final categoria = timerProvider.categoriaAtual;
    final tempoTrabalho = timerProvider.config.tempoTrabalho;
    final tempoDescansoCurto = timerProvider.config.tempoDescansoCurto;
    final tempoDescansoLongo = timerProvider.config.tempoDescansoLongo;
    final precisaLBreak = timerProvider.precisaLongBreak();

    final String textoBtn = precisaLBreak
        ? "☕ Descanso Longo ($tempoDescansoLongo min)"
        : "☕ Descanso ($tempoDescansoCurto min)";

    final String msgDescanso = precisaLBreak
        ? "🎊 Excelente sequência! Hora de um descanso longo de $tempoDescansoLongo minutos!"
        : "Foco concluído! Que tal descansar por $tempoDescansoCurto minutos?";

    final Color corDestaque = precisaLBreak ? Colors.orangeAccent : Colors.amber;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.92), // Dark Slate profundo
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 25,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "🎉",
              style: TextStyle(fontSize: 50),
            ),
            const SizedBox(height: 12),
            const Text(
              "Sessão Concluída!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.greenAccent,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),
            // Cartão interno com dados resumidos do pomodoro finalizado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.03),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    tarefa,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoria,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "•",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$tempoTrabalho minuto${tempoTrabalho != 1 ? 's' : ''}",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              msgDescanso,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: precisaLBreak ? Colors.orangeAccent : Colors.white70,
                fontWeight: precisaLBreak ? FontWeight.bold : FontWeight.normal,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Ação: Começar pausa de descanso
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      timerProvider.iniciarDescanso(precisaLBreak);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: corDestaque,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      textoBtn,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Ação: Pular pausa e retornar para a tela inicial
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    timerProvider.pularDescanso();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.06),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Pular",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
