import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/timer_provider.dart';
import '../popups/completion_popup.dart';
import '../widgets/autocomplete_input.dart';
import '../widgets/circular_timer.dart';
import '../widgets/relation_selector.dart';
import '../widgets/status_indicator.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _tarefaController = TextEditingController();
  final FocusNode _tarefaFocusNode = FocusNode();
  String _categoriaSelecionada = "Python";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timerProvider = Provider.of<TimerProvider>(context, listen: false);

      // Registra o callback para abrir o popup de comemoração de forma síncrona na UI
      timerProvider.onSessionFinished = () {
        if (mounted) {
          CompletionPopup.mostrar(context, timerProvider);
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

  @override
  Widget build(BuildContext context) {
    final timerProvider = Provider.of<TimerProvider>(context);

    // Valida se a categoria selecionada localmente ainda existe no cadastro de configurações
    // Usa addPostFrameCallback para não mutar estado durante o build
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
          child: Padding(
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
                // Botão de acesso à tela de Configurações
                Center(
                  child: TextButton.icon(
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
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tarefaController.dispose();
    _tarefaFocusNode.dispose();
    super.dispose();
  }
}
