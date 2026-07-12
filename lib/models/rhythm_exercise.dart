import 'rhythm_element.dart';

/// An immutable, generated rhythm reading exercise — the unit that Sheet
/// Mode generates, plays, saves and exports to PDF.
///
/// The full music data ([measures]) is persisted alongside the generation
/// [seed]: the data is what gets rendered/played/exported, while the seed
/// keeps every exercise reproducible even if the generator evolves.
class RhythmExercise {
  final String id;
  final String title;
  final DateTime createdAt;
  final String difficultyId;
  final int bpm;
  final String timeSignature;
  final int measureCount;
  final int seed;
  final List<RhythmMeasure> measures;

  const RhythmExercise({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.difficultyId,
    required this.bpm,
    required this.timeSignature,
    required this.measureCount,
    required this.seed,
    required this.measures,
  });

  RhythmExercise copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    String? difficultyId,
    int? bpm,
    String? timeSignature,
    int? measureCount,
    int? seed,
    List<RhythmMeasure>? measures,
  }) {
    return RhythmExercise(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      difficultyId: difficultyId ?? this.difficultyId,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      measureCount: measureCount ?? this.measureCount,
      seed: seed ?? this.seed,
      measures: measures ?? this.measures,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'difficultyId': difficultyId,
        'bpm': bpm,
        'timeSignature': timeSignature,
        'measureCount': measureCount,
        'seed': seed,
        'measures': measures.map(_measureToJson).toList(),
      };

  factory RhythmExercise.fromJson(Map<String, dynamic> json) => RhythmExercise(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        difficultyId: json['difficultyId'] as String,
        bpm: json['bpm'] as int,
        timeSignature: json['timeSignature'] as String,
        measureCount: json['measureCount'] as int,
        seed: json['seed'] as int,
        measures: (json['measures'] as List)
            .map((m) => _measureFromJson(m as Map<String, dynamic>))
            .toList(),
      );

  static Map<String, dynamic> _measureToJson(RhythmMeasure measure) => {
        'timeSignature': measure.timeSignature,
        'elements': measure.elements.map(_elementToJson).toList(),
      };

  static RhythmMeasure _measureFromJson(Map<String, dynamic> json) =>
      RhythmMeasure(
        timeSignature: json['timeSignature'] as String,
        elements: (json['elements'] as List)
            .map((e) => _elementFromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static Map<String, dynamic> _elementToJson(RhythmElement element) => {
        'type': element.type.name,
        'duration': element.duration,
        'noteName': element.noteName,
        if (element.type == RhythmElementType.triplet)
          'tripletNotes': element.tripletNotes,
        if (element.type == RhythmElementType.beatGroup) ...{
          'groupDurations': element.groupDurations,
          'groupRests': element.groupRests,
          if (element.tupletLabel != null) 'tupletLabel': element.tupletLabel,
          if (element.figurationId != null)
            'figurationId': element.figurationId,
        },
      };

  static RhythmElement _elementFromJson(Map<String, dynamic> json) =>
      RhythmElement(
        type: RhythmElementType.values.byName(json['type'] as String),
        duration: (json['duration'] as num).toDouble(),
        noteName: json['noteName'] as String? ?? 'C4',
        tripletNotes: (json['tripletNotes'] as List?)?.cast<String>() ??
            const ['B4', 'B4', 'B4'],
        groupDurations: (json['groupDurations'] as List?)
                ?.map((d) => (d as num).toDouble())
                .toList() ??
            const [],
        groupRests: (json['groupRests'] as List?)?.cast<bool>() ?? const [],
        tupletLabel: json['tupletLabel'] as int?,
        figurationId: json['figurationId'] as String?,
      );
}
