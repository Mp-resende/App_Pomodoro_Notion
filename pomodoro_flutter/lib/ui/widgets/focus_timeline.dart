import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

class FocusTimeline extends StatefulWidget {
  final List<Map<String, dynamic>> sessoes;
  final AppThemeData theme;
  final String modoContextoInicial;
  final bool Function(String? materia, [String? area])? isMateriaTrabalho;

  const FocusTimeline({
    Key? key,
    required this.sessoes,
    required this.theme,
    this.modoContextoInicial = "todos",
    this.isMateriaTrabalho,
  }) : super(key: key);

  @override
  State<FocusTimeline> createState() => _FocusTimelineState();
}

class _FocusTimelineState extends State<FocusTimeline> {
  late String _filtro;

  @override
  void initState() {
    super.initState();
    _filtro = widget.modoContextoInicial;
  }

  @override
  void didUpdateWidget(covariant FocusTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o modo global mudou na tela inicial, sincroniza o filtro inicial
    if (oldWidget.modoContextoInicial != widget.modoContextoInicial) {
      setState(() {
        _filtro = widget.modoContextoInicial;
      });
    }
  }

  bool _isSessaoTrabalho(Map<String, dynamic> sessao) {
    final modo = sessao['modo']?.toString();
    if (modo == 'trabalho') return true;
    if (modo == 'estudos') return false;

    final tech = sessao['tecnologia']?.toString();
    if (tech != null && tech.toLowerCase() == 'trabalho') return true;

    final materia = sessao['materia_nome']?.toString();
    final area = sessao['materia_area']?.toString();
    if (widget.isMateriaTrabalho != null) {
      if (widget.isMateriaTrabalho!(materia, area)) return true;
      if (widget.isMateriaTrabalho!(sessao['tarefa']?.toString())) return true;
      if (widget.isMateriaTrabalho!(tech)) return true;
    }

    if (area != null && area.toLowerCase() == 'trabalho') return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    // Filtra as sessões conforme a aba selecionada
    final sessoesFiltradas = widget.sessoes.where((s) {
      final isTrab = _isSessaoTrabalho(s);
      if (_filtro == "trabalho" && !isTrab) return false;
      if (_filtro == "estudos" && isTrab) return false;
      return true;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.015),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com Título e Seletor Segmentado [ Todos | Estudos | Trabalho ]
          Row(
            children: [
              Text(
                "📅 Foco ao Longo do Dia",
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Seletor de visualização rápida
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterChip("todos", "Todos"),
                    _buildFilterChip("estudos", "📚"),
                    _buildFilterChip("trabalho", "💼"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Subtítulo com contador filtrado
          Text(
            "${sessoesFiltradas.length} ${sessoesFiltradas.length == 1 ? 'sessão registrada' : 'sessões registradas'} hoje",
            style: TextStyle(
              color: _filtro == "trabalho"
                  ? const Color(0xFFF59E0B)
                  : (_filtro == "estudos" ? theme.primaryAccent : Colors.white54),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              const double barHeight = 10.0;

              // Parse e calcula a posição de cada sessão
              final List<Widget> sessaoWidgets = [];
              for (final s in sessoesFiltradas) {
                final inicioStr = s['inicio'] as String?;
                final fimStr = s['fim'] as String?;
                final tarefa = s['tarefa'] as String? ?? s['materia_nome'] as String? ?? 'Foco';
                final isTrab = _isSessaoTrabalho(s);

                if (inicioStr == null || fimStr == null) continue;

                final DateTime? ini = DateTime.tryParse(inicioStr)?.toLocal();
                final DateTime? fim = DateTime.tryParse(fimStr)?.toLocal();

                if (ini == null || fim == null) continue;

                // Fração decimal do dia (0.0 a 1.0)
                final double startFraction = (ini.hour * 60 + ini.minute) / (24 * 60);
                final double endFraction = (fim.hour * 60 + fim.minute) / (24 * 60);
                final double durationFraction = (endFraction - startFraction).clamp(0.006, 1.0);

                final double left = startFraction * totalWidth;
                final double width = durationFraction * totalWidth;
                final Color color = isTrab ? const Color(0xFFF59E0B) : theme.primaryAccent;
                final String tipoLabel = isTrab ? "💼 Trabalho" : "📚 Estudo";

                sessaoWidgets.add(
                  Positioned(
                    left: left,
                    width: width,
                    top: 0,
                    height: barHeight,
                    child: Tooltip(
                      message: "$tipoLabel: $tarefa\n${ini.hour.toString().padLeft(2, '0')}:${ini.minute.toString().padLeft(2, '0')} - ${fim.hour.toString().padLeft(2, '0')}:${fim.minute.toString().padLeft(2, '0')}",
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.45),
                              blurRadius: 4,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              // Calcula a posição do horário atual ("Agora")
              final agora = DateTime.now();
              final double agoraFraction = (agora.hour * 60 + agora.minute) / (24 * 60);
              final double agoraLeft = agoraFraction * totalWidth;

              return Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Barra de Fundo Cinza
                      Container(
                        height: barHeight,
                        width: totalWidth,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
                        ),
                      ),
                      // Sessões posicionadas
                      ...sessaoWidgets,
                      // Marcador de "Agora" (neon vermelho piscante)
                      Positioned(
                        left: agoraLeft - 1.5,
                        top: -3,
                        height: barHeight + 6,
                        width: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.8),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Marcadores de Horas (00, 06, 12, 18, 24)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimeLabel("00:00", theme),
                      _buildTimeLabel("06:00", theme),
                      _buildTimeLabel("12:00", theme),
                      _buildTimeLabel("18:00", theme),
                      _buildTimeLabel("24:00", theme),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _filtro == key;
    return GestureDetector(
      onTap: () => setState(() => _filtro = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? (key == "trabalho"
                  ? const Color(0xFFF59E0B).withOpacity(0.3)
                  : (key == "estudos"
                      ? widget.theme.primaryAccent.withOpacity(0.3)
                      : Colors.white.withOpacity(0.12)))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeLabel(String text, AppThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        color: theme.textSecondary.withOpacity(0.3),
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
