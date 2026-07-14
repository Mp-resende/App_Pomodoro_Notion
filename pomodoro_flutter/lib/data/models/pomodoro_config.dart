import 'dart:convert';

class PomodoroConfig {
  int tempoTrabalho;         // minutos
  int tempoDescansoCurto;    // minutos
  int tempoDescansoLongo;    // minutos
  int pomodorosAteLongBreak;
  bool somAlarmeAtivado;
  bool notificacoesSistema;
  List<String> categorias;

  PomodoroConfig({
    this.tempoTrabalho = 25,
    this.tempoDescansoCurto = 5,
    this.tempoDescansoLongo = 15,
    this.pomodorosAteLongBreak = 4,
    this.somAlarmeAtivado = true,
    this.notificacoesSistema = true,
    List<String>? categorias,
  }) : this.categorias = categorias ?? ["Python", "C#", "SQL", "n8n", "Arquitetura", "Implanta", "Outros"];

  // Construtor fábrica para carregar a partir de um JSON
  factory PomodoroConfig.fromJson(Map<String, dynamic> json) {
    return PomodoroConfig(
      tempoTrabalho: json['tempo_trabalho'] as int? ?? 25,
      tempoDescansoCurto: json['tempo_descanso_curto'] as int? ?? 5,
      tempoDescansoLongo: json['tempo_descanso_longo'] as int? ?? 15,
      pomodorosAteLongBreak: json['pomodoros_ate_long_break'] as int? ?? 4,
      somAlarmeAtivado: json['som_alarme_ativado'] as bool? ?? true,
      notificacoesSistema: json['notificacoes_sistema'] as bool? ?? true,
      categorias: (json['categorias'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  // Converte para mapa JSON preservando a nomenclatura snake_case do Python
  Map<String, dynamic> toJson() {
    return {
      'tempo_trabalho': tempoTrabalho,
      'tempo_descanso_curto': tempoDescansoCurto,
      'tempo_descanso_longo': tempoDescansoLongo,
      'pomodoros_ate_long_break': pomodorosAteLongBreak,
      'som_alarme_ativado': somAlarmeAtivado,
      'notificacoes_sistema': notificacoesSistema,
      'categorias': categorias,
    };
  }

  // Adiciona uma nova categoria se não existir
  bool adicionarCategoria(String categoria) {
    categoria = categoria.trim();
    if (categoria.isEmpty) return false;
    if (categorias.contains(categoria)) return false;
    categorias.add(categoria);
    return true;
  }
}
