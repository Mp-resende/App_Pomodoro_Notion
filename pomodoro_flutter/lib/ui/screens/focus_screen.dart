import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import '../../logic/providers/timer_provider.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({Key? key}) : super(key: key);

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  @override
  void initState() {
    super.initState();
    // Impede o dispositivo de dormir ou a tela de apagar
    WakelockPlus.enable();

    // Ativa o Modo Fullscreen Imersivo
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.setFullScreen(true);
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Oculta a barra de status e a barra de navegação virtual
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    // Permite que o sistema gerencie a energia e desligue a tela novamente
    WakelockPlus.disable();

    // Restaura as barras nativas da UI normal
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.setFullScreen(false);
    } else if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold com fundo 100% preto para painéis OLED
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Consumer<TimerProvider>(
              builder: (context, timer, child) {
                // Ao terminar a sessão, fechar o modo foco automaticamente
                // para que a tela inicial exiba o popup original lindamente.
                // Verifica tempoInicio para não fechar antes de qualquer sessão iniciar.
                if (timer.tempoRestante == 0 && !timer.rodando && timer.tempoInicio != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  });
                }

                // Formatação do tempo em MM:SS
                final minutos = (timer.tempoRestante ~/ 60).toString().padLeft(2, '0');
                final segundos = (timer.tempoRestante % 60).toString().padLeft(2, '0');
                final formatoTempo = '$minutos:$segundos';
                
                final modoTexto = timer.modoDescanso ? "Descanso" : "Foco Profundo";
                final corDestaque = timer.modoDescanso ? Colors.greenAccent : Colors.cyanAccent;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      modoTexto.toUpperCase(),
                      style: TextStyle(
                        color: corDestaque.withOpacity(0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      formatoTempo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 110,
                        fontWeight: FontWeight.w200,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Controle transparente e sutil para não distrair
                    IconButton(
                      onPressed: () => timer.pausarRetomar(),
                      iconSize: 42,
                      color: Colors.white54,
                      icon: Icon(
                        timer.rodando ? Icons.pause_circle_outline : Icons.play_circle_outline,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Botão discreto no canto superior esquerdo para sair
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_fullscreen_rounded),
              color: Colors.white38,
              iconSize: 28,
              tooltip: "Sair do modo foco",
            ),
          ),
        ],
      ),
    );
  }
}
