import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../logic/providers/timer_provider.dart';
import '../../core/services/tray_service.dart';
import '../popups/completion_popup.dart';
import '../widgets/autocomplete_input.dart';
import '../widgets/circular_timer.dart';
import '../widgets/relation_selector.dart';
import '../widgets/status_indicator.dart';
import 'focus_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, WindowListener {
  final TextEditingController _tarefaController = TextEditingController();
  final FocusNode _tarefaFocusNode = FocusNode();
  String _categoriaSelecionada = "Python";
  bool _isMiniPlayer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    if (Platform.isWindows) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timerProvider = Provider.of<TimerProvider>(context, listen: false);

      // Registra o callback para abrir o popup de comemoração com segurança pós-frame
      timerProvider.onSessionFinished = () {
        if (mounted) {
          // Pequeno delay para garantir que a FocusScreen (tela sempre ativa)
          // se feche completamente antes de tentarmos empilhar o popup de conclusão.
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              try {
                CompletionPopup.mostrar(context, timerProvider);
              } catch (e) {
                debugPrint("Erro ao abrir popup de término: $e");
              }
            }
          });
        }
      };

      // Registra o callback para quando o descanso terminar
      timerProvider.onBreakFinished = () {
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("☕ Descanso concluído! Pronto para outra sessão?"),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          } catch (_) {}
        }
      };

      // Carrega a primeira categoria cadastrada como valor padrão
      if (timerProvider.config.categorias.isNotEmpty) {
        setState(() {
          _categoriaSelecionada = timerProvider.config.categorias.first;
        });
      }
    });
  }

  // Converte string hex (#RRGGBB) para Color de forma segura, com fallback
  Color _hexParaColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return Colors.white70;
    }
  }

  // Alterna o modo Mini-Player (apenas no Windows)
  Future<void> _alternarMiniPlayer() async {
    if (!Platform.isWindows) return;

    setState(() {
      _isMiniPlayer = !_isMiniPlayer;
    });

    if (_isMiniPlayer) {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSize(const Size(285, 155));
      await windowManager.setResizable(false);
    } else {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSize(const Size(800, 680));
      await windowManager.setResizable(true);
    }
  }

  // Intercepta o fechamento da janela no Windows e envia para a bandeja
  @override
  void onWindowClose() async {
    if (Platform.isWindows) {
      final isPreventClose = await windowManager.isPreventClose();
      if (isPreventClose) {
        await TrayService().ocultarNaBandeja();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerProvider = Provider.of<TimerProvider>(context);

    // Valida se a categoria selecionada localmente ainda existe no cadastro de configurações
    final categorias = timerProvider.config.categorias;
    if (!categorias.contains(_categoriaSelecionada) && categorias.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _categoriaSelecionada = categorias.first);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _isMiniPlayer
                ? _buildMiniPlayer(timerProvider)
                : _buildFullPlayer(timerProvider, categorias),
          ),
        ),
      ),
    );
  }

  // Layout 1: Mini-Player Minimalista
  Widget _buildMiniPlayer(TimerProvider timerProvider) {
    final minutos = (timerProvider.tempoRestante ~/ 60).toString().padLeft(2, '0');
    final segundos = (timerProvider.tempoRestante % 60).toString().padLeft(2, '0');
    final tempoStr = '$minutos:$segundos';

    final modoTexto = timerProvider.modoDescanso ? "Descanso" : "Foco";
    final corDestaque = timerProvider.modoDescanso ? Colors.greenAccent : Colors.cyanAccent;

    return Container(
      key: const ValueKey("mini_player"),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              // Mini Timer circular
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: timerProvider.progresso,
                      strokeWidth: 3.5,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(corDestaque),
                    ),
                    Text(
                      tempoStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Nome da tarefa e status focado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      timerProvider.tarefaAtual.isEmpty
                          ? "Sem Tarefa Ativa"
                          : timerProvider.tarefaAtual,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      modoTexto.toUpperCase(),
                      style: TextStyle(
                        color: corDestaque.withOpacity(0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Controles de rodapé do Mini-Player
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botão de restaurar
              IconButton(
                onPressed: _alternarMiniPlayer,
                iconSize: 18,
                color: Colors.white38,
                icon: const Icon(Icons.open_in_full_rounded),
                tooltip: "Restaurar aplicativo",
              ),
              // Play/Pause
              IconButton(
                onPressed: timerProvider.rodando ? () => timerProvider.pausarRetomar() : null,
                iconSize: 22,
                color: Colors.white70,
                disabledColor: Colors.white10,
                icon: Icon(
                  timerProvider.pausado || !timerProvider.rodando
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                ),
              ),
              // Ocultar na bandeja
              IconButton(
                onPressed: () => TrayService().ocultarNaBandeja(),
                iconSize: 18,
                color: Colors.white38,
                icon: const Icon(Icons.close_rounded),
                tooltip: "Minimizar para a bandeja",
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Layout 2: Player Completo Original
  Widget _buildFullPlayer(TimerProvider timerProvider, List<String> categorias) {
    return Padding(
      key: const ValueKey("full_player"),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView(
        children: [
          const SizedBox(height: 16),
          // Banner de atualização disponível
          if (timerProvider.novaVersaoDisponivel)
            GestureDetector(
              onTap: () => timerProvider.executarAtualizacao(),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F766E), // Ciano
                      Color(0xFF1D4ED8), // Azul Royal
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.cyanAccent.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.system_update_alt_rounded,
                      color: Colors.cyanAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Nova versão ${timerProvider.tagNovaVersao} disponível! Toque para instalar.",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.cyanAccent,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          // 1. Cabeçalho & Status do Notion
          const StatusIndicator(),
          const SizedBox(height: 20),

          // 2. Card de Entrada de Informações (Glassmorphism sutil)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.015),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Input de texto com autocomplete
                AutocompleteInput(
                  controller: _tarefaController,
                  focusNode: _tarefaFocusNode,
                  enabled: !timerProvider.rodando,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Tecnologia / Categoria:",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                // Dropdown de categorias de tecnologia
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _categoriaSelecionada,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.white.withOpacity(0.5)),
                      isExpanded: true,
                      items: categorias.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: timerProvider.rodando
                          ? null // Bloqueia edições se estiver rodando
                          : (val) {
                              if (val != null) {
                                setState(() {
                                  _categoriaSelecionada = val;
                                });
                              }
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Relação de tabelas Notion (se configurada e online)
                const RelationSelector(),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // 3. Indicador de quantidade de Pomodoros concluídos
          Center(
            child: Text(
              "🍅 Hoje: ${timerProvider.pomodorosHoje} | Sessão: ${timerProvider.pomodorosCompletados}",
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 4. Exibição do Timer Circular Animado
          CircularTimer(
            progress: timerProvider.progresso,
            timeStr: timerProvider.obterTempoFormatado(),
            modoDescanso: timerProvider.modoDescanso,
            pausado: timerProvider.pausado,
          ),
          const SizedBox(height: 14),

          // 5. Rótulo de tempo decorrido focado ("⏱ Focado há...")
          if (timerProvider.labelDecorrido.isNotEmpty)
            Center(
              child: Text(
                timerProvider.labelDecorrido,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 8),

          // Rótulo textual do status geral
          Center(
            child: Text(
              timerProvider.labelStatus,
              style: TextStyle(
                color: _hexParaColor(timerProvider.textStatusColor),
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // 6. Painel de Ações de controle (Iniciar, Pausar/Retomar, Limpar/Resetar)
          Row(
            children: [
              // Ação: Iniciar Pomodoro
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: timerProvider.rodando
                      ? null
                      : () {
                          timerProvider.iniciar(_tarefaController.text, _categoriaSelecionada);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: Colors.white.withOpacity(0.04),
                    disabledForegroundColor: Colors.white.withOpacity(0.15),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 18),
                      SizedBox(width: 4),
                      Text("Iniciar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Ação: Pausar/Retomar contagem
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: !timerProvider.rodando
                      ? null
                      : () => timerProvider.pausarRetomar(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: Colors.white.withOpacity(0.04),
                    disabledForegroundColor: Colors.white.withOpacity(0.15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(timerProvider.pausado ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        timerProvider.pausado ? "Retomar" : "Pausar",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Ação: Limpar campos e resetar cronômetro
              Material(
                color: Colors.white.withOpacity(0.035),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    _tarefaController.clear();
                    timerProvider.resetar();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.stop_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ação: Concluir sessão manualmente antecipada
          ElevatedButton(
            onPressed: !timerProvider.rodando || timerProvider.modoDescanso
                ? null
                : () => timerProvider.finalizarSessaoManualmente(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: Colors.white.withOpacity(0.02),
              disabledForegroundColor: Colors.white.withOpacity(0.12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_rounded, size: 15),
                SizedBox(width: 6),
                Text("Encerrar Sessão", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ],
            ),
          ),

          const SizedBox(height: 14),
          // Botões de rodapé: Modo Foco, Mini-Player e Configurações
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  );
                },
                icon: Icon(Icons.bar_chart_rounded, size: 14, color: Colors.cyanAccent.withOpacity(0.6)),
                label: Text(
                  "Gráficos",
                  style: TextStyle(
                    color: Colors.cyanAccent.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const FocusScreen()),
                  );
                },
                icon: Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.cyanAccent.withOpacity(0.6)),
                label: Text(
                  "Always Awake",
                  style: TextStyle(
                    color: Colors.cyanAccent.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (Platform.isWindows) ...[
                TextButton.icon(
                  onPressed: _alternarMiniPlayer,
                  icon: Icon(Icons.picture_in_picture_alt_rounded, size: 14, color: Colors.cyanAccent.withOpacity(0.6)),
                  label: Text(
                    "Mini Player",
                    style: TextStyle(
                      color: Colors.cyanAccent.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
                icon: Icon(Icons.settings_rounded, size: 14, color: Colors.white.withOpacity(0.4)),
                label: Text(
                  "Configurações",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _tarefaController.dispose();
    _tarefaFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    if (state == AppLifecycleState.paused) {
      // O app foi minimizado ou a tela apagou: cria a notificação do cronômetro nativo
      timerProvider.mostrarNotificacaoMinimizada();
    } else if (state == AppLifecycleState.resumed) {
      // O app retornou para a tela: remove a notificação da barra
      timerProvider.ocultarNotificacaoMinimizada();
    }
  }
}
