import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

class WeeklyFocusTimeline extends StatelessWidget {
  final List<dynamic> sessoes;
  final AppThemeData theme;

  const WeeklyFocusTimeline({
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
    // 1. Calcula a faixa da semana atual (Segunda a Domingo fechado)
    final agora = DateTime.now();
    final diaSemanaAtual = agora.weekday; // 1 = Segunda, 7 = Domingo
    final segundaFeira = agora.subtract(Duration(days: diaSemanaAtual - 1));
    final inicioSemana = DateTime(segundaFeira.year, segundaFeira.month, segundaFeira.day, 0, 0, 0);
    final fimSemana = inicioSemana.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));

    // Nomes dos dias da semana
    final nomesDias = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"];

    // 2. Agrupa as sessões da semana atual por dia (1 a 7)
    final Map<int, List<Map<String, dynamic>>> sessoesPorDia = {
      for (int i = 1; i <= 7; i++) i: []
    };

    for (final s in sessoes) {
      if (s is! Map<String, dynamic>) continue;
      final inicioStr = s['inicio'] as String?;
      if (inicioStr == null) continue;
      final DateTime? dateIni = DateTime.tryParse(inicioStr)?.toLocal();
      if (dateIni == null) continue;

      // Verifica se a sessão pertence à semana atual
      if (dateIni.isAfter(inicioSemana.subtract(const Duration(seconds: 1))) &&
          dateIni.isBefore(fimSemana.add(const Duration(seconds: 1)))) {
        final weekday = dateIni.weekday; // 1 (Seg) a 7 (Dom)
        sessoesPorDia[weekday]?.add(s);
      }
    }

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
          // Renderiza cada dia da semana (Segunda a Domingo)
          for (int day = 1; day <= 7; day++) ...[
            _buildDayRow(context, day, nomesDias[day - 1], sessoesPorDia[day] ?? [], day == diaSemanaAtual),
            if (day < 7) const SizedBox(height: 14),
          ],
          const SizedBox(height: 12),
          // Marcadores de Horas compartilhados (00, 06, 12, 18, 24)
          Padding(
            padding: const EdgeInsets.only(left: 70), // Alinha com o início das barras
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimeLabel("00:00"),
                _buildTimeLabel("06:00"),
                _buildTimeLabel("12:00"),
                _buildTimeLabel("18:00"),
                _buildTimeLabel("24:00"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(BuildContext context, int dayIndex, String nomeDia, List<Map<String, dynamic>> sessoesDia, bool isHoje) {
    const double barHeight = 8.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Rótulo do dia
        SizedBox(
          width: 60,
          child: Text(
            nomeDia.substring(0, 3), // Ex: Seg
            style: TextStyle(
              color: isHoje ? theme.primaryAccent : theme.textPrimary.withOpacity(0.7),
              fontSize: 12,
              fontWeight: isHoje ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Barra de 24h
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final List<Widget> sessaoWidgets = [];

              for (final s in sessoesDia) {
                final inicioStr = s['inicio'] as String?;
                final fimStr = s['fim'] as String?;
                final tech = s['tecnologia'] as String? ?? 'Outros';
                final materia = s['materia_nome'] as String? ?? 'Sem Matéria';

                if (inicioStr == null || fimStr == null) continue;

                final DateTime? ini = DateTime.tryParse(inicioStr)?.toLocal();
                final DateTime? fim = DateTime.tryParse(fimStr)?.toLocal();

                if (ini == null || fim == null) continue;

                // Fração decimal do dia (0.0 a 1.0)
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
                      message: "$materia ($tech)\n${ini.hour.toString().padLeft(2, '0')}:${ini.minute.toString().padLeft(2, '0')} - ${fim.hour.toString().padLeft(2, '0')}:${fim.minute.toString().padLeft(2, '0')}",
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 3,
                              spreadRadius: 0.2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              // Posicionador de "Agora" se for hoje
              double? agoraLeft;
              if (isHoje) {
                final agora = DateTime.now();
                final double agoraFraction = (agora.hour * 60 + agora.minute) / (24 * 60);
                agoraLeft = agoraFraction * totalWidth;
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Barra de Fundo
                  Container(
                    height: barHeight,
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Sessões desenhadas
                  ...sessaoWidgets,
                  // Marcador de "Agora"
                  if (agoraLeft != null)
                    Positioned(
                      left: agoraLeft - 1,
                      top: -2,
                      height: barHeight + 4,
                      width: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.8),
                              blurRadius: 4,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeLabel(String text) {
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
