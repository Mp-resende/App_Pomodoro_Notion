import 'dart:math';
import 'package:flutter/material.dart';

class CircularTimer extends StatelessWidget {
  final double progress;
  final String timeStr;
  final bool modoDescanso;
  final bool pausado;

  const CircularTimer({
    Key? key,
    required this.progress,
    required this.timeStr,
    required this.modoDescanso,
    required this.pausado,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Escolhe a cor do tema dinamicamente baseada no modo de descanso ou pausa
    final Color corDestaque = pausado 
        ? Colors.amberAccent 
        : (modoDescanso ? Colors.orangeAccent : Colors.cyanAccent);
    
    final Color corFundoAnel = Colors.white.withOpacity(0.04);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Efeito de brilho de fundo (Glow)
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: corDestaque.withOpacity(0.015),
              boxShadow: [
                BoxShadow(
                  color: corDestaque.withOpacity(0.06),
                  blurRadius: 40,
                  spreadRadius: 10,
                )
              ]
            ),
          ),
          // Anel de progresso circular animado
          SizedBox(
            width: 250,
            height: 250,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return CustomPaint(
                  painter: _TimerRingPainter(
                    progress: value,
                    color: corDestaque,
                    backgroundColor: corFundoAnel,
                  ),
                );
              },
            ),
          ),
          // Exibição do tempo e rótulo do estado atual
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                opacity: pausado ? 0.6 : 1.0,
                duration: const Duration(milliseconds: 250),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace', // Mantém fonte mono para evitar vibração nos números
                    color: corDestaque,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: corDestaque.withOpacity(0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Indicador visual de estado em formato de cápsula com Glassmorphism
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: corDestaque.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: corDestaque.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  pausado ? "PAUSADO" : (modoDescanso ? "DESCANSO" : "FOCO"),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                    color: corDestaque,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Pintor customizado para renderizar os arcos do timer
class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _TimerRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 8;

    // 1. Desenha o anel de background completo
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Desenha o arco ativo correspondente à porcentagem de progresso
    final activePaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.3),
          color,
          color.withOpacity(0.3),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: const GradientRotation(-pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    // Multiplica 2*pi pelo progresso (de 0.0 a 1.0) para obter o ângulo total
    final double sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Inicia no topo (12 horas)
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
