import '../../models/rhythm_element.dart';

/// Un membro di una figurazione: una nota o una pausa con la sua durata
/// espressa in battiti (frazione di semiminima).
class FigurationMember {
  final double beats;
  final bool isRest;

  const FigurationMember(this.beats, {this.isRest = false});
}

/// Una figurazione ritmica che il generatore di Sheet Mode può piazzare.
///
/// Il catalogo rispecchia 1:1 le immagini in
/// `assets/audio/figurazioni_quarti_png`: ogni figurazione con [beats] == 1
/// vale esattamente una semiminima ([id] = nome del PNG). Le uniche voci
/// senza immagine sono le note semplici consentite oltre il battito:
/// `half` (minima, 2/4) e `whole` (semibreve, 4/4).
///
/// [grouped] segna le figurazioni rese come singolo [RhythmElementType
/// .beatGroup] (terzine e varianti, quintina, sestina, biscrome): i loro
/// membri hanno durate non binarie e vanno disegnati/riprodotti come gruppo.
/// Le altre si espandono in normali [RhythmElement] binari.
class BeatFiguration {
  final String id;
  final List<FigurationMember> members;
  final bool grouped;

  /// Numero della staffa del gruppo irregolare (3, 5, 6); null per i gruppi
  /// esatti (le otto biscrome) e per le figurazioni binarie.
  final int? tupletLabel;

  const BeatFiguration(
    this.id,
    this.members, {
    this.grouped = false,
    this.tupletLabel,
  });

  /// Durata complessiva in battiti (1 per tutte le figurazioni del catalogo
  /// PNG, 2 per la minima, 4 per la semibreve).
  double get beats => grouped
      ? 1.0
      : members.fold(0.0, (sum, m) => sum + m.beats);

  /// True se la figurazione è un'unica pausa che copre tutto il suo valore
  /// (usato dai vincoli di generazione per evitare silenzi consecutivi).
  bool get isFullRest => members.every((m) => m.isRest);

  /// Materializza la figurazione in elementi renderizzabili/riproducibili.
  ///
  /// Ogni figurazione da 1 battito è un BLOCCO indivisibile: diventa un
  /// singolo [RhythmElementType.beatGroup] che porta con sé le durate/pause
  /// dei membri (per il playback) e l'id del PNG (per il rendering come
  /// glifo intero). Sul pentagramma non compaiono mai crome, semicrome o
  /// biscrome sciolte. Solo minima e semibreve restano note semplici.
  List<RhythmElement> toElements(String pitch) {
    if (beats > 1.0) {
      return members
          .map(
            (m) => RhythmElement(
              type: m.beats == 4.0
                  ? RhythmElementType.whole
                  : RhythmElementType.half,
              duration: m.beats,
              noteName: pitch,
            ),
          )
          .toList();
    }
    return [
      RhythmElement(
        type: RhythmElementType.beatGroup,
        duration: 1.0,
        noteName: pitch,
        groupDurations: members.map((m) => m.beats).toList(),
        groupRests: members.map((m) => m.isRest).toList(),
        tupletLabel: tupletLabel,
        figurationId: id,
      ),
    ];
  }
}

const FigurationMember _n4 = FigurationMember(1.0); // semiminima
const FigurationMember _r4 = FigurationMember(1.0, isRest: true);
const FigurationMember _n8 = FigurationMember(0.5); // croma
const FigurationMember _r8 = FigurationMember(0.5, isRest: true);
const FigurationMember _n16 = FigurationMember(0.25); // semicroma
const FigurationMember _r16 = FigurationMember(0.25, isRest: true);
const FigurationMember _n8d = FigurationMember(0.75); // croma puntata
const FigurationMember _r8d = FigurationMember(0.75, isRest: true);
const FigurationMember _nT = FigurationMember(1 / 3); // croma di terzina
const FigurationMember _rT = FigurationMember(1 / 3, isRest: true);
const FigurationMember _nT16 = FigurationMember(1 / 6); // semicroma di terzina
const FigurationMember _nQ = FigurationMember(0.2); // quintina
const FigurationMember _nS = FigurationMember(1 / 6); // sestina
const FigurationMember _n32 = FigurationMember(0.125); // biscroma

/// ─────────────────────────────────────────────────────────────────────────
/// IL catalogo: ogni id con lettera+numero corrisponde al PNG omonimo in
/// assets/audio/figurazioni_quarti_png. Verificato figura per figura contro
/// le immagini (posizione di travature, punti, pause e numeri di gruppo).
/// ─────────────────────────────────────────────────────────────────────────
const Map<String, BeatFiguration> kBeatFigurations = {
  // Note semplici oltre il battito (senza PNG, consentite esplicitamente).
  'whole': BeatFiguration('whole', [FigurationMember(4.0)]),
  'half': BeatFiguration('half', [FigurationMember(2.0)]),

  // A — il battito semplice.
  'A1': BeatFiguration('A1', [_n4]),
  'A2': BeatFiguration('A2', [_r4]),

  // B — crome.
  'B1': BeatFiguration('B1', [_n8, _n8]),
  'B2': BeatFiguration('B2', [_r8, _n8]),

  // C — semicrome, figure puntate e pause interne.
  'C1': BeatFiguration('C1', [_n16, _n16, _n16, _n16]),
  'C2': BeatFiguration('C2', [_n16, _n16, _n8]),
  'C3': BeatFiguration('C3', [_n8, _n16, _n16]),
  'C4': BeatFiguration('C4', [_n16, _n8, _n16]),
  'C5': BeatFiguration('C5', [_n8d, _n16]),
  'C6': BeatFiguration('C6', [_n16, _n16, _r8]),
  'C7': BeatFiguration('C7', [_r16, _n8d]),
  'C8': BeatFiguration('C8', [_r8d, _n16]),
  'C9': BeatFiguration('C9', [_r8, _n16, _n16]),
  'C10': BeatFiguration('C10', [_r16, _n16, _n8]),
  'C11': BeatFiguration('C11', [_r16, _n8, _n16]),
  'C12': BeatFiguration('C12', [_r16, _n16, _n16, _n16]),

  // D — terzina di crome e varianti con pause.
  'D1': BeatFiguration('D1', [_nT, _nT, _nT], grouped: true, tupletLabel: 3),
  'D2': BeatFiguration('D2', [_nT, _rT, _nT], grouped: true, tupletLabel: 3),
  'D3': BeatFiguration('D3', [_nT, _nT, _rT], grouped: true, tupletLabel: 3),
  'D4': BeatFiguration('D4', [_rT, _nT, _nT], grouped: true, tupletLabel: 3),
  'D5': BeatFiguration('D5', [_nT, _rT, _rT], grouped: true, tupletLabel: 3),
  'D6': BeatFiguration('D6', [_rT, _nT, _rT], grouped: true, tupletLabel: 3),
  'D7': BeatFiguration('D7', [_rT, _rT, _nT], grouped: true, tupletLabel: 3),

  // E/F/G — quintina, sestina, otto biscrome.
  'E1': BeatFiguration('E1', [_nQ, _nQ, _nQ, _nQ, _nQ],
      grouped: true, tupletLabel: 5),
  'F1': BeatFiguration('F1', [_nS, _nS, _nS, _nS, _nS, _nS],
      grouped: true, tupletLabel: 6),
  'G1': BeatFiguration(
      'G1', [_n32, _n32, _n32, _n32, _n32, _n32, _n32, _n32],
      grouped: true),

  // H — mezza terzina di semicrome + croma (e speculare).
  'H1': BeatFiguration('H1', [_nT16, _nT16, _nT16, _n8],
      grouped: true, tupletLabel: 3),
  'H2': BeatFiguration('H2', [_n8, _nT16, _nT16, _nT16],
      grouped: true, tupletLabel: 3),

  // L — terzine di crome con membri suddivisi in semicrome.
  'L1': BeatFiguration('L1', [_nT16, _nT16, _nT, _nT],
      grouped: true, tupletLabel: 3),
  'L2': BeatFiguration('L2', [_nT, _nT16, _nT16, _nT],
      grouped: true, tupletLabel: 3),
  'L3': BeatFiguration('L3', [_nT, _nT, _nT16, _nT16],
      grouped: true, tupletLabel: 3),
  'L4': BeatFiguration('L4', [_nT16, _nT16, _nT16, _nT16, _nT],
      grouped: true, tupletLabel: 3),
  'L5': BeatFiguration('L5', [_nT, _nT16, _nT16, _nT16, _nT16],
      grouped: true, tupletLabel: 3),
  'L6': BeatFiguration('L6', [_nT16, _nT16, _nT, _nT16, _nT16],
      grouped: true, tupletLabel: 3),
};

/// Lookup che fallisce rumorosamente su un id sconosciuto: un preset che
/// referenzia una figurazione inesistente è un bug di configurazione da
/// scoprire subito, non da mascherare.
BeatFiguration figurationById(String id) {
  final figuration = kBeatFigurations[id];
  assert(figuration != null, 'Figurazione sconosciuta: $id');
  return figuration ?? kBeatFigurations['A1']!;
}
