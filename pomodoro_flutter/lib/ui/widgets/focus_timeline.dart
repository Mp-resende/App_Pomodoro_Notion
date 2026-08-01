import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

class FocusTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> sessoes;
  final AppThemeData theme;

  const FocusTimeline({
    Key? key,
    required this.sessoes,
    required this.theme,
  }) : super(key: key);

  Color _obterCorSessao(String tech, AppThemeData theme) {
    final hash = tech.hashCode;
    if (hash % 3 == 0) return theme.primaryAccent;
    if (hash % 3 == 1) return theme.secondaryAccent;
    return theme.primaryAccent.withOpacity(0.6);
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "📅 Foco ao Longo do Dia",
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${sessoes.length} sessoes hoje",
                style: TextStyle(
                  color: theme.primaryAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              const double barHeight = 10.0;

              // Parse e calcula a posicao de cada sessao
              final List<Widget> sessaoWidgets = [];
              for (final s in sessoes) {
                final inicioStr = s['inicio'] as String?;
                final fimStr = s['fim'] as String?;
                final tech = s['tecnologia'] as String? ?? 'Outros';

                if (inicioStr == null || fimStr == null) continue;

                final DateTime? ini = DateTime.tryParse(inicioStr)?.toLocal();
                final DateTime? fim = DateTime.tryParse(fimStr)?.toLocal();

                if (ini == null || fim == null) continue;

                // Fracao decimal do dia (0.0 a 1.0)
                final double startFraction = (ini.hour * 60 + ini.minute) / (24 * 60);
                final double endFraction = (fim.hour * 60 + fim.minute) / (24 * 60);
                final double durationFraction = (endFraction - startFraction).clamp(0.005, 1.0);

                final double left = startFraction * totalWidth;
                final double width = durationFraction * totalWidth;
                final color = _obterCorSessao(tech, theme);

                sessaoWidgets.add(
                  Positioned(
                    left: left,
                    width: width,
                    top: 0,
                    height: barHeight,
                    child: Tooltip(
                      message: "$tech\n${ini.hour.toString().padLeft(2, '0')}:${ini.minute.toString().padLeft(2, '0')} - ${fim.hour.toString().padLeft(2, '0')}:${fim.minute.toString().padLeft(2, '0')}",
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
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

              // Calcula a posicao do horario atual ("Agora")
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
                      // Sessoes posicionadas
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
