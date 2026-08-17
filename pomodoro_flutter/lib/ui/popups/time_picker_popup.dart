import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic/providers/timer_provider.dart';

class TimePickerPopup extends StatefulWidget {
  final TimerProvider timerProvider;

  const TimePickerPopup({
    Key? key,
    required this.timerProvider,
  }) : super(key: key);

  static Future<int?> mostrar(BuildContext context, TimerProvider provider) {
    return showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Fechar seletor de tempo",
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim1,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: child,
            ),
          ),
        );
      },
      pageBuilder: (context, _, __) {
        return TimePickerPopup(timerProvider: provider);
      },
    );
  }

  @override
  State<TimePickerPopup> createState() => _TimePickerPopupState();
}

class _TimePickerPopupState extends State<TimePickerPopup> with SingleTickerProviderStateMixin {
  late int _minutosSelecionados;
  late AnimationController _pulseController;
  final List<int> _presets = [15, 20, 25, 30, 45, 50, 60, 90];

  @override
  void initState() {
    super.initState();
    _minutosSelecionados = widget.timerProvider.config.tempoTrabalho;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _alterarMinutos(int novoValor) {
    final clampVal = novoValor.clamp(1, 180);
    if (clampVal != _minutosSelecionados) {
      HapticFeedback.selectionClick();
      _pulseController.forward(from: 0.92);
      setState(() {
        _minutosSelecionados = clampVal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.timerProvider.theme;
    final corDestaque = widget.timerProvider.modoContexto == "trabalho"
        ? const Color(0xFFF59E0B)
        : theme.primaryAccent;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: corDestaque.withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: corDestaque.withOpacity(0.12),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho com ícone animado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: corDestaque.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.timer_outlined, color: corDestaque, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Duração do Foco",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Toque ou deslize para ajustar o tempo",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Visor Central Animado com Botões de Ajuste Rápido
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botão -5
                  _buildQuickIncButton("-5", () => _alterarMinutos(_minutosSelecionados - 5), corDestaque),
                  const SizedBox(width: 6),
                  // Botão -1
                  _buildQuickIncButton("-1", () => _alterarMinutos(_minutosSelecionados - 1), corDestaque),
                  const SizedBox(width: 16),

                  // Display dos Números com animação de pulso e transição de dígitos
                  ScaleTransition(
                    scale: _pulseController,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: corDestaque.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: corDestaque.withOpacity(0.08),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.35),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: FadeTransition(opacity: animation, child: child),
                              );
                            },
                            child: Text(
                              _minutosSelecionados.toString().padLeft(2, '0'),
                              key: ValueKey<int>(_minutosSelecionados),
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                color: corDestaque,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "min",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),
                  // Botão +1
                  _buildQuickIncButton("+1", () => _alterarMinutos(_minutosSelecionados + 1), corDestaque),
                  const SizedBox(width: 6),
                  // Botão +5
                  _buildQuickIncButton("+5", () => _alterarMinutos(_minutosSelecionados + 5), corDestaque),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Slider Deslizante Suave
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: corDestaque,
                inactiveTrackColor: Colors.white.withOpacity(0.08),
                thumbColor: Colors.white,
                overlayColor: corDestaque.withOpacity(0.2),
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              ),
              child: Slider(
                value: _minutosSelecionados.toDouble(),
                min: 1,
                max: 120,
                divisions: 119,
                onChanged: (val) => _alterarMinutos(val.round()),
              ),
            ),
            const SizedBox(height: 12),

            // Presets Rápidos com Chips Animados
            const Text(
              "Durações recomendadas:",
              style: TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((p) {
                final isSelected = _minutosSelecionados == p;
                return GestureDetector(
                  onTap: () => _alterarMinutos(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? corDestaque.withOpacity(0.25) : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? corDestaque : Colors.white.withOpacity(0.08),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: corDestaque.withOpacity(0.2),
                                blurRadius: 8,
                              )
                            ]
                          : [],
                    ),
                    child: Text(
                      "${p}m",
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 26),

            // Botões de Confirmação e Fechamento
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Cancelar", style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      widget.timerProvider.definirMinutosFoco(_minutosSelecionados);
                      Navigator.of(context).pop(_minutosSelecionados);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: corDestaque,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      shadowColor: corDestaque.withOpacity(0.4),
                    ),
                    child: Text(
                      "Aplicar (${_minutosSelecionados} min)",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildQuickIncButton(String label, VoidCallback onTap, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
