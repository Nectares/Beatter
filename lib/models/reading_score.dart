/// Il record personale di un esercizio in Reading Mode: massimo numero di
/// good (tap corretti) e massima strike (good consecutivi) mai raggiunti.
/// [id] è l'id dell'esercizio salvato a cui il record appartiene.
class ReadingScore {
  final String id;
  final int good;
  final int strike;
  final DateTime updatedAt;

  const ReadingScore({
    required this.id,
    required this.good,
    required this.strike,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'good': good,
        'strike': strike,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ReadingScore.fromJson(Map<String, dynamic> json) => ReadingScore(
        id: json['id'] as String? ?? '',
        good: json['good'] as int? ?? 0,
        strike: json['strike'] as int? ?? 0,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
