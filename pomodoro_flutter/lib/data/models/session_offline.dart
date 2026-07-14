class SessionOffline {
  final String intervalo;
  final DateTime inicio;
  final DateTime fim;
  final String tecnologia;
  final DateTime timestamp;
  final String? campoRelacao;
  final String? idRelacao;

  SessionOffline({
    required this.intervalo,
    required this.inicio,
    required this.fim,
    required this.tecnologia,
    required this.timestamp,
    this.campoRelacao,
    this.idRelacao,
  });

  factory SessionOffline.fromJson(Map<String, dynamic> json) {
    return SessionOffline(
      intervalo: json['intervalo'] as String,
      inicio: DateTime.parse(json['inicio'] as String),
      fim: DateTime.parse(json['fim'] as String),
      tecnologia: json['tecnologia'] as String? ?? 'Outros',
      timestamp: DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toUtc().toIso8601String()),
      campoRelacao: json['campo_relacao'] as String?,
      idRelacao: json['id_relacao'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intervalo': intervalo,
      'inicio': inicio.toIso8601String(),
      'fim': fim.toIso8601String(),
      'tecnologia': tecnologia,
      'timestamp': timestamp.toIso8601String(),
      'campo_relacao': campoRelacao,
      'id_relacao': idRelacao,
    };
  }
}
