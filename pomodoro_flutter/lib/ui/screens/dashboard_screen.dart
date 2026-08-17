import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../logic/providers/dashboard_provider.dart';
import '../../logic/providers/timer_provider.dart';
import '../styles/app_theme.dart';
import '../widgets/weekly_focus_timeline.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotateController;
  int _pieTouchedIndex = -1;
  String _metasFiltro = "Todas";
  String _metasOrdenacao = "Progresso (%)";

  AppThemeData get theme => Provider.of<TimerProvider>(context, listen: false).theme;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Carrega dados novos do Notion silenciosamente ao abrir a tela se estiver online
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      if (provider.timerProvider.notionService?.connected == true) {
        provider.atualizarDadosNotion();
      }
    });
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  // Gera cores bonitas e consistentes baseadas no texto da Matéria
  Color _obterCorMateria(String nome) {
    final hash = nome.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    return HSLColor.fromColor(Color.fromARGB(255, r, g, b))
        .withSaturation(0.75)
        .withLightness(0.60)
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);
    final timerProvider = Provider.of<TimerProvider>(context);

    // Controla a rotação do botão de atualizar baseado no carregamento
    if (dashboard.carregando) {
      _rotateController.repeat();
    } else {
      _rotateController.stop();
    }

    return Scaffold(
      backgroundColor: theme.backgroundStart,
      appBar: AppBar(
        backgroundColor: theme.backgroundStart,
        elevation: 0,
        title: const Text(
          'Estatísticas de Estudo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.dashboard_customize_rounded, color: theme.secondaryAccent),
            tooltip: "Editar Layout",
            onPressed: _abrirConfiguracaoLayout,
          ),
          RotationTransition(
            turns: _rotateController,
            child: IconButton(
              icon: Icon(Icons.sync_rounded, color: theme.primaryAccent),
              onPressed: dashboard.carregando
                  ? null
                  : () async {
                      final sucesso = await dashboard.atualizarDadosNotion();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(sucesso
                                ? 'Estatísticas atualizadas com sucesso!'
                                : dashboard.erroMessage ?? 'Erro ao atualizar dados.'),
                            backgroundColor: sucesso ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        );
                      }
                    },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (dashboard.carregando && !dashboard.temDados) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.primaryAccent),
                  SizedBox(height: 16),
                  Text('Baixando dados do Notion...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }

          if (dashboard.erroMessage != null && !dashboard.temDados) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 64, color: Colors.orange.shade400),
                    const SizedBox(height: 16),
                    Text(
                      dashboard.erroMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar Novamente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => dashboard.atualizarDadosNotion(),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!dashboard.temDados) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dashboard_customize_rounded, size: 64, color: Colors.white38),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum dado encontrado.',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Clique no botão de sincronizar no topo para buscar dados do Notion pela primeira vez.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de Filtros
                _buildFilterBar(context, dashboard),
                const SizedBox(height: 4),

                ...timerProvider.dashboardOrdem.map((key) {
                  if (timerProvider.dashboardOcultos.contains(key)) {
                    return const SizedBox.shrink();
                  }

                  switch (key) {
                    case 'kpis':
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildKPIs(dashboard),
                          const SizedBox(height: 20),
                        ],
                      );
                    case 'insights':
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dashboard.temDados) ...[
                            _buildWeeklyInsights(dashboard),
                            const SizedBox(height: 24),
                          ],
                        ],
                      );
                    case 'pizza':
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(dashboard.materiaSelecionada != null ? 'Detalhamento da Matéria' : 'Distribuição de Estudos por Matéria'),
                          dashboard.materiaSelecionada != null
                              ? _buildMateriaDetalheCard(dashboard)
                              : _buildPieChartCard(dashboard),
                          const SizedBox(height: 24),
                        ],
                      );
                    case 'barras':
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(dashboard.materiaSelecionada != null ? 'Evolução de Foco: ${dashboard.materiaSelecionada}' : 'Evolução de Foco'),
                          _buildBarChartCard(dashboard),
                          const SizedBox(height: 24),
                        ],
                      );
                    case 'metas':
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Metas Semanais (Segunda a Domingo)'),
                          _buildMetasCard(dashboard),
                          const SizedBox(height: 24),
                        ],
                      );
                    case 'linha_tempo':
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Foco Durante a Semana (Segunda a Domingo)'),
                          WeeklyFocusTimeline(
                            sessoes: dashboard.sessoesFiltradas,
                            theme: theme,
                          ),
                           const SizedBox(height: 24),
                         ],
                       );
                    default:
                      return const SizedBox.shrink();
                  }
                }).toList(),



                // Rodapé de Atualização
                Center(
                  child: Text(
                    'Dados atualizados em: ${_formatDataCompleta(dashboard.dadosDashboard['atualizado_em'])}',
                    style: const TextStyle(fontSize: 11, color: Colors.white30),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyInsights(DashboardProvider dashboard) {
    final insights = dashboard.insightsSemanais;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorder.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: theme.secondaryAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                "Insights Semanais de Foco",
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInsightRow(
            icon: Icons.local_fire_department_rounded,
            color: Colors.orangeAccent,
            titulo: "Dia mais produtivo",
            valor: insights["dia_produtivo"] ?? "Nenhum",
          ),
          const SizedBox(height: 12),
          _buildInsightRow(
            icon: Icons.lightbulb_rounded,
            color: theme.primaryAccent,
            titulo: "Foco principal da semana",
            valor: insights["foco_principal"] ?? "Nenhum",
          ),
          const SizedBox(height: 12),
          _buildInsightRow(
            icon: Icons.trending_up_rounded,
            color: Colors.greenAccent,
            titulo: "Média diária de estudos",
            valor: insights["media_diaria"] ?? "0 min",
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow({
    required IconData icon,
    required Color color,
    required String titulo,
    required String valor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: theme.textSecondary.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Seção: KPI Cards
  Widget _buildKPIs(DashboardProvider dashboard) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildKPICard(
              width: cardWidth,
              titulo: 'Total Focado',
              valor: '${dashboard.totalHorasFocadas.toStringAsFixed(1)}h',
              icon: Icons.hourglass_empty_rounded,
              color: Colors.cyanAccent,
            ),
            _buildKPICard(
              width: cardWidth,
              titulo: 'Sessões Feitas',
              valor: '${dashboard.sessoesFiltradas.length}',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.greenAccent,
            ),
            _buildKPICard(
              width: cardWidth,
              titulo: 'Matéria Líder',
              valor: dashboard.materiaLider,
              icon: Icons.workspace_premium_rounded,
              color: Colors.amberAccent,
            ),
            _buildKPICard(
              width: cardWidth,
              titulo: 'Média / Sessão',
              valor: '${dashboard.mediaMinutosPorSessao.toStringAsFixed(0)} min',
              icon: Icons.speed_rounded,
              color: Colors.purpleAccent,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKPICard({
    required double width,
    required String titulo,
    required String valor,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w500),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Título da Seção
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  // Gráfico de Pizza (Horas por Matéria)
  Widget _buildPieChartCard(DashboardProvider dashboard) {
    final Map<String, double> dados = dashboard.tempoPorMateria;

    if (dados.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<PieChartSectionData> secoes = [];
    final List<Widget> legendas = [];
    int index = 0;

    dados.forEach((materia, tempo) {
      final isTouched = index == _pieTouchedIndex;
      final double radius = isTouched ? 50.0 : 40.0;
      final double fontSize = isTouched ? 16.0 : 12.0;
      final cor = _obterCorMateria(materia);

      secoes.add(
        PieChartSectionData(
          color: cor,
          value: tempo,
          title: '${tempo.toStringAsFixed(1)}h',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      );

      legendas.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  materia,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${tempo.toStringAsFixed(1)}h',
                style: const TextStyle(fontSize: 13, color: Colors.white38, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );

      index++;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _pieTouchedIndex = -1;
                        return;
                      }
                      _pieTouchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 3,
                centerSpaceRadius: 45,
                sections: secoes,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Column(children: legendas),
        ],
      ),
    );
  }

  // Gráfico de Barras (Evolução Semanal ou Personalizada)
  Widget _buildBarChartCard(DashboardProvider dashboard) {
    final valores = dashboard.tempoPorDiaNoPeriodo;
    final dias = dashboard.diasStrNoPeriodo;

    // Encontra o valor máximo para dimensionar o eixo Y de forma limpa
    double maxValor = 4.0; // Padrão mínimo
    for (final v in valores) {
      if (v > maxValor) maxValor = v;
    }
    maxValor = (maxValor + 1).ceilToDouble();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValor,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: const Color(0xFF334155),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${dias[group.x.toInt()]}\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: <TextSpan>[
                    TextSpan(
                      text: '${rod.toY.toStringAsFixed(1)}h focadas',
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 13),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < dias.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        dias[idx],
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == value.toInt()) {
                    return Text(
                      '${value.toInt()}h',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return const FlLine(color: Colors.white10, strokeWidth: 1);
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(valores.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: valores[i],
                  color: Colors.cyanAccent,
                  width: valores.length > 10 ? 8 : 14,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxValor,
                    color: Colors.white.withOpacity(0.03),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // Painel de Metas Semanais
  Widget _buildMetasCard(DashboardProvider dashboard) {
    final rawMetas = dashboard.metasProgresso;

    if (rawMetas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorder.withOpacity(0.5)),
        ),
        child: Center(
          child: Text(
            'Nenhuma meta ou matéria encontrada.',
            style: TextStyle(color: theme.textSecondary.withOpacity(0.4), fontSize: 13),
          ),
        ),
      );
    }

    List<Map<String, dynamic>> metas = List<Map<String, dynamic>>.from(rawMetas);

    // 1. Aplicação de Filtros
    if (_metasFiltro == "Concluídas") {
      metas = metas.where((m) => m['meta_horas'] > 0 && m['realizado_horas'] >= m['meta_horas']).toList();
    } else if (_metasFiltro == "Em Andamento") {
      metas = metas.where((m) => m['meta_horas'] > 0 && m['realizado_horas'] < m['meta_horas']).toList();
    }

    // 2. Aplicação de Ordenações
    if (_metasOrdenacao == "Nome") {
      metas.sort((a, b) => (a['materia_nome'] as String).compareTo(b['materia_nome'] as String));
    } else if (_metasOrdenacao == "Progresso (%)") {
      metas.sort((a, b) => (b['porcentagem'] as double).compareTo(a['porcentagem'] as double));
    } else if (_metasOrdenacao == "Realizado (h)") {
      metas.sort((a, b) => (b['realizado_horas'] as double).compareTo(a['realizado_horas'] as double));
    } else if (_metasOrdenacao == "Meta (h)") {
      metas.sort((a, b) => (b['meta_horas'] as double).compareTo(a['meta_horas'] as double));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorder.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de Filtros e Ordenações
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_list_rounded, size: 14, color: theme.textSecondary.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: _metasFiltro == "Sem Meta" ? "Todas" : _metasFiltro,
                    dropdownColor: theme.surface,
                    style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                    underline: const SizedBox(),
                    icon: Icon(Icons.arrow_drop_down_rounded, color: theme.textSecondary.withOpacity(0.6), size: 16),
                    items: ["Todas", "Concluídas", "Em Andamento"].map((f) {
                      return DropdownMenuItem(value: f, child: Text(f));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _metasFiltro = val);
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.sort_rounded, size: 14, color: theme.textSecondary.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: _metasOrdenacao,
                    dropdownColor: theme.surface,
                    style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                    underline: const SizedBox(),
                    icon: Icon(Icons.arrow_drop_down_rounded, color: theme.textSecondary.withOpacity(0.6), size: 16),
                    items: ["Progresso (%)", "Realizado (h)", "Meta (h)", "Nome"].map((o) {
                      return DropdownMenuItem(value: o, child: Text(o));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _metasOrdenacao = val);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: theme.cardBorder.withOpacity(0.3), height: 1),
          const SizedBox(height: 12),
          if (metas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'Nenhuma meta corresponde ao filtro.',
                  style: TextStyle(color: theme.textSecondary.withOpacity(0.4), fontSize: 12),
                ),
              ),
            )
          else
            ...metas.map((meta) {
              final String nome = meta['materia_nome'];
              final double metaH = meta['meta_horas'];
              final double realH = meta['realizado_horas'];
              final double pct = meta['porcentagem'];
              final corMateria = _obterCorMateria(nome);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          nome,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textPrimary),
                        ),
                        Text(
                          '${realH.toStringAsFixed(1)}h de ${metaH.toStringAsFixed(1)}h (${(pct * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: realH >= metaH ? Colors.greenAccent : theme.textSecondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (pct > 1.0 ? 1.0 : (pct < 0.0 ? 0.0 : pct)),
                        minHeight: 8,
                        backgroundColor: theme.textSecondary.withOpacity(0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(corMateria),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // Gráfico de Metodologias / Tipo de Estudo
  Widget _buildTipoEstudoCard(DashboardProvider dashboard) {
    final Map<String, double> tipos = dashboard.tempoPorTipoEstudo;

    if (tipos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: tipos.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: dashboard.totalHorasFocadas > 0 ? entry.value / dashboard.totalHorasFocadas : 0,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${entry.value.toStringAsFixed(1)}h',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _abrirConfiguracaoLayout() {
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    List<String> localOrdem = List<String>.from(timerProvider.dashboardOrdem);
    List<String> localOcultos = List<String>.from(timerProvider.dashboardOcultos);

    final Map<String, String> nomesBlocos = {
      "kpis": "Resumo Geral (KPIs)",
      "insights": "Insights Semanais",
      "pizza": "Distribuição por Matéria (Pizza)",
      "barras": "Evolução de Estudos (Barras)",
      "metas": "Metas Semanais",
      "linha_tempo": "Linha do Tempo Semanal",
    };

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.cardBorder.withOpacity(0.5)),
              ),
              title: Row(
                children: [
                  Icon(Icons.dashboard_customize_rounded, color: theme.secondaryAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Layout do Dashboard",
                    style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                height: 380,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Arraste para reordenar ou use as chaves para ocultar/exibir seções:",
                      style: TextStyle(color: theme.textSecondary.withOpacity(0.6), fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: theme.surface,
                        ),
                        child: ReorderableListView(
                          onReorder: (oldIndex, newIndex) {
                            setDialogState(() {
                              if (oldIndex < newIndex) {
                                newIndex -= 1;
                              }
                              final String item = localOrdem.removeAt(oldIndex);
                              localOrdem.insert(newIndex, item);
                            });
                          },
                          children: localOrdem.map((key) {
                            final nome = nomesBlocos[key] ?? key;
                            final visivel = !localOcultos.contains(key);

                            return ListTile(
                              key: ValueKey(key),
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.drag_indicator_rounded, color: theme.textSecondary.withOpacity(0.4)),
                              title: Text(
                                  nome,
                                  style: TextStyle(
                                    color: visivel ? theme.textPrimary : theme.textSecondary.withOpacity(0.4),
                                    fontSize: 13,
                                    fontWeight: visivel ? FontWeight.bold : FontWeight.normal,
                                    decoration: visivel ? TextDecoration.none : TextDecoration.lineThrough,
                                  ),
                                ),
                              trailing: Transform.scale(
                                scale: 0.8,
                                child: Switch(
                                  value: visivel,
                                  activeColor: theme.primaryAccent,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val) {
                                        localOcultos.remove(key);
                                      } else {
                                        if (!localOcultos.contains(key)) {
                                          localOcultos.add(key);
                                        }
                                      }
                                    });
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancelar", style: TextStyle(color: theme.textSecondary.withOpacity(0.6))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryAccent.withOpacity(0.1),
                    foregroundColor: theme.primaryAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.primaryAccent.withOpacity(0.5)),
                    ),
                  ),
                  onPressed: () async {
                    await timerProvider.salvarLayoutDashboard(localOrdem, localOcultos);
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: const Text("Salvar", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Barra de Filtros (Matéria e Período)
  Widget _buildFilterBar(BuildContext context, DashboardProvider dashboard) {
    // Extrai matérias únicas das sessões para alimentar o filtro
    final materias = dashboard.sessoes
        .map((s) => s['materia_nome'] as String? ?? 'Sem Matéria')
        .toSet()
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_rounded, color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Filtros de Análise',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              const Spacer(),
              if (dashboard.temFiltrosAtivos)
                TextButton.icon(
                  onPressed: dashboard.limparFiltros,
                  icon: const Icon(Icons.clear_all_rounded, size: 14, color: Colors.redAccent),
                  label: const Text('Limpar', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Seletor de Contexto (Todos | Estudos | Trabalho)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                _buildContextFilterTab("todos", "🌐 Todos", dashboard),
                _buildContextFilterTab("estudos", "📚 Estudos", dashboard),
                _buildContextFilterTab("trabalho", "💼 Trabalho", dashboard),
              ],
            ),
          ),
          Row(
            children: [
              // Dropdown de Matérias
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: dashboard.materiaSelecionada,
                      hint: const Text("Todas as Matérias", style: TextStyle(color: Colors.white38, fontSize: 12)),
                      dropdownColor: const Color(0xFF1E293B),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white38),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text("Todas as Matérias"),
                        ),
                        ...materias.map((m) => DropdownMenuItem<String>(
                              value: m,
                              child: Text(m),
                            )),
                      ],
                      onChanged: dashboard.filtrarPorMateria,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Seletor de Período
              Expanded(
                child: InkWell(
                  onTap: () => _mostrarMenuPeriodo(context, dashboard),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _obterTextoPeriodo(dashboard.periodoSelecionado),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.date_range_rounded, color: Colors.white38, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextFilterTab(String key, String label, DashboardProvider dashboard) {
    final selected = dashboard.contextoFiltro == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => dashboard.filtrarPorContexto(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (key == "trabalho"
                    ? const Color(0xFFF59E0B).withOpacity(0.25)
                    : (key == "estudos" ? theme.primaryAccent.withOpacity(0.25) : Colors.white.withOpacity(0.12)))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected
                  ? (key == "trabalho"
                      ? const Color(0xFFF59E0B)
                      : (key == "estudos" ? theme.primaryAccent : Colors.white24))
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _obterTextoPeriodo(DateTimeRange? range) {
    if (range == null) return "Todo o Histórico";
    final hoje = DateTime.now();
    
    // Verifica se coincide com "Últimos 7 Dias"
    final seteDiasAtras = hoje.subtract(const Duration(days: 6));
    if (range.start.year == seteDiasAtras.year &&
        range.start.month == seteDiasAtras.month &&
        range.start.day == seteDiasAtras.day &&
        range.end.year == hoje.year &&
        range.end.month == hoje.month &&
        range.end.day == hoje.day) {
      return "Últimos 7 Dias";
    }
    
    // Verifica se coincide com "Esta Semana"
    final inicioEstaSemana = DateTime(hoje.year, hoje.month, hoje.day).subtract(Duration(days: hoje.weekday - 1));
    if (range.start.year == inicioEstaSemana.year &&
        range.start.month == inicioEstaSemana.month &&
        range.start.day == inicioEstaSemana.day &&
        range.end.year == hoje.year &&
        range.end.month == hoje.month &&
        range.end.day == hoje.day) {
      return "Esta Semana";
    }

    // Verifica se coincide com "Semana Passada"
    final inicioSemanaPassada = inicioEstaSemana.subtract(const Duration(days: 7));
    final fimSemanaPassada = inicioEstaSemana.subtract(const Duration(seconds: 1));
    if (range.start.year == inicioSemanaPassada.year &&
        range.start.month == inicioSemanaPassada.month &&
        range.start.day == inicioSemanaPassada.day &&
        range.end.year == fimSemanaPassada.year &&
        range.end.month == fimSemanaPassada.month &&
        range.end.day == fimSemanaPassada.day) {
      return "Semana Passada";
    }

    final d1 = "${range.start.day.toString().padLeft(2, '0')}/${range.start.month.toString().padLeft(2, '0')}";
    final d2 = "${range.end.day.toString().padLeft(2, '0')}/${range.end.month.toString().padLeft(2, '0')}";
    return "$d1 a $d2";
  }

  void _mostrarMenuPeriodo(BuildContext context, DashboardProvider dashboard) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final hoje = DateTime.now();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Selecionar Período',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: const Icon(Icons.all_inclusive_rounded, color: Colors.cyanAccent, size: 20),
                title: const Text('Todo o Histórico', style: TextStyle(color: Colors.white70, fontSize: 13)),
                onTap: () {
                  dashboard.filtrarPorPeriodo(null);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.today_rounded, color: Colors.cyanAccent, size: 20),
                title: const Text('Últimos 7 Dias', style: TextStyle(color: Colors.white70, fontSize: 13)),
                onTap: () {
                  final inicio = hoje.subtract(const Duration(days: 6));
                  dashboard.filtrarPorPeriodo(DateTimeRange(start: inicio, end: hoje));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_week_rounded, color: Colors.cyanAccent, size: 20),
                title: const Text('Esta Semana (Seg a Dom)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                onTap: () {
                  final inicio = DateTime(hoje.year, hoje.month, hoje.day).subtract(Duration(days: hoje.weekday - 1));
                  dashboard.filtrarPorPeriodo(DateTimeRange(start: inicio, end: hoje));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_rounded, color: Colors.cyanAccent, size: 20),
                title: const Text('Semana Passada', style: TextStyle(color: Colors.white70, fontSize: 13)),
                onTap: () {
                  final inicioEstaSemana = DateTime(hoje.year, hoje.month, hoje.day).subtract(Duration(days: hoje.weekday - 1));
                  final inicio = inicioEstaSemana.subtract(const Duration(days: 7));
                  final fim = inicioEstaSemana.subtract(const Duration(seconds: 1));
                  dashboard.filtrarPorPeriodo(DateTimeRange(start: inicio, end: fim));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range_rounded, color: Colors.cyanAccent, size: 20),
                title: const Text('Período Personalizado...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                onTap: () async {
                  Navigator.pop(context);
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2026),
                    lastDate: hoje.add(const Duration(days: 1)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.cyanAccent,
                            onPrimary: Colors.black,
                            surface: Color(0xFF1E293B),
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (range != null) {
                    dashboard.filtrarPorPeriodo(range);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Card de Detalhamento quando uma matéria específica é selecionada
  Widget _buildMateriaDetalheCard(DashboardProvider dashboard) {
    final materia = dashboard.materiaSelecionada!;
    final totalHoras = dashboard.totalHorasFocadas;
    final sessoesMateria = dashboard.sessoesFiltradas.length;
    final mediaSessao = dashboard.mediaMinutosPorSessao;

    final metaInfo = dashboard.metasProgresso.firstWhere(
      (m) => m['materia_nome'] == materia,
      orElse: () => <String, dynamic>{},
    );
    final double metaH = metaInfo['meta_horas'] ?? 0.0;
    final double pct = metaInfo['porcentagem'] ?? 0.0;

    final cor = _obterCorMateria(materia);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  materia,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetalheItem('Tempo Focado', '${totalHoras.toStringAsFixed(1)}h', Colors.cyanAccent),
              _buildDetalheItem('Sessões', '$sessoesMateria', Colors.greenAccent),
              _buildDetalheItem('Média / Sessão', '${mediaSessao.toStringAsFixed(0)} min', Colors.purpleAccent),
            ],
          ),
          if (metaH > 0) ...[
            const SizedBox(height: 16),
            const Text(
              'Progresso da Meta Semanal',
              style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct > 1.0 ? 1.0 : pct,
                      minHeight: 8,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(cor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Você completou ${totalHoras.toStringAsFixed(1)}h de uma meta de ${metaH.toStringAsFixed(1)}h.',
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Text(
              'Esta matéria não possui meta semanal configurada no Notion.',
              style: TextStyle(fontSize: 10, color: Colors.white38, fontStyle: FontStyle.italic),
            ),
          ],
          
          // Tópicos Estudados (Registro de Sessões)
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),
          const Text(
            'Tópicos Estudados (Registro de Sessões)',
            style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (dashboard.topicosDaMateriaSelecionada.isEmpty)
            const Text(
              'Nenhum tópico registrado para esta matéria.',
              style: TextStyle(fontSize: 11, color: Colors.white38, fontStyle: FontStyle.italic),
            )
          else
            ...dashboard.topicosDaMateriaSelecionada.map((topico) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topico['nome'],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (topico['tipo'] != 'Não Definido')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                topico['tipo'],
                                style: const TextStyle(fontSize: 9, color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(topico['total_horas'] as double).toStringAsFixed(1)}h',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cor),
                        ),
                        Text(
                          '${topico['sessoes_count']} ${topico['sessoes_count'] == 1 ? 'sessão' : 'sessões'}',
                          style: const TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildDetalheItem(String label, String valor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  // Formata o timestamp de atualização de forma legível
  String _formatDataCompleta(dynamic timestamp) {
    if (timestamp == null) return 'Desconhecida';
    try {
      final dt = DateTime.parse(timestamp.toString()).toLocal();
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final ano = dt.year;
      final hora = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dia/$mes/$ano às $hora:$min';
    } catch (_) {
      return 'Desconhecida';
    }
  }
}
