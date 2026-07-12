import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Un glifo di figurazione pronto da disegnare: la maschera alpha più la
/// sua dimensione display in pixel logici, normalizzata perché OGNI testa
/// di nota abbia la stessa larghezza ([FigurationImages.targetHeadWidth])
/// indipendentemente dalla risoluzione e densità del PNG di origine.
class FigurationGlyph {
  final ui.Image image;
  final double displayWidth;
  final double displayHeight;

  const FigurationGlyph(this.image, this.displayWidth, this.displayHeight);
}

/// Cache dei glifi delle figurazioni da 1/4 estratti dai PNG di
/// `assets/audio/figurazioni_quarti_png`.
///
/// Ogni PNG è nero-su-bianco con ampi margini: al caricamento viene
/// ridimensionato, ritagliato al bounding box del glifo e convertito in una
/// maschera alpha (bianco premoltiplicato), così `MusicStaffPainter` può
/// tingerlo di qualunque colore con un `ColorFilter` `srcIn` — lo stesso
/// glifo funziona sul tema dell'app e sulla pagina bianca del PDF.
///
/// La dimensione display di ogni glifo è ancorata alla larghezza delle
/// teste misurata nei pixel (massima corsa orizzontale d'inchiostro nel
/// terzo inferiore del glifo): i PNG hanno risoluzioni e proporzioni
/// diverse, ma a schermo tutte le note escono della stessa taglia.
///
/// Il caricamento è lazy e idempotente: le viste chiamano [ensureLoaded] e
/// ascoltano il notifier per ridipingere quando i glifi sono pronti; finché
/// un glifo manca il painter usa il fallback vettoriale.
class FigurationImages extends ChangeNotifier {
  FigurationImages._();

  static final FigurationImages instance = FigurationImages._();

  static const String _dir = 'assets/audio/figurazioni_quarti_png';

  /// Altezza di decodifica: sovracampionata rispetto allo schermo perché i
  /// glifi più larghi (fino a ~215px logici) restino nitidi anche nel
  /// raster 3× del PDF, senza tenere megapixel in memoria.
  static const int _decodeHeight = 320;

  /// Larghezza display delle teste di nota: la stessa `noteWidth` dei glifi
  /// vettoriali, così i blocchi combaciano con minime e semibrevi.
  static const double targetHeadWidth = 12.0;

  final Map<String, FigurationGlyph> _glyphs = {};
  Future<void>? _loading;

  FigurationGlyph? of(String id) => _glyphs[id];

  bool get isLoaded => _glyphs.isNotEmpty;

  /// Cambia quando nuovi glifi diventano disponibili — i painter la
  /// catturano alla costruzione così `shouldRepaint` sa di ridipingere.
  int get epoch => _glyphs.length;

  /// Avvia (una sola volta) il caricamento di tutti i glifi; notifica i
  /// listener al termine. Sicuro da chiamare da build().
  Future<void> ensureLoaded() => _loading ??= _loadAll();

  Future<void> _loadAll() async {
    // Gli id coincidono coi nomi dei file PNG nella cartella.
    const ids = [
      'A1', 'A2', 'B1', 'B2',
      'C1', 'C2', 'C3', 'C4', 'C5', 'C6',
      'C7', 'C8', 'C9', 'C10', 'C11', 'C12',
      'D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7',
      'E1', 'F1', 'G1', 'H1', 'H2',
      'L1', 'L2', 'L3', 'L4', 'L5', 'L6',
    ];

    for (final id in ids) {
      try {
        final data = await rootBundle.load('$_dir/$id.png');
        final glyph = await _toGlyph(data.buffer.asUint8List());
        if (glyph != null) _glyphs[id] = glyph;
      } catch (_) {
        // Un glifo mancante non deve bloccare gli altri: per quel battito
        // resta il fallback vettoriale del painter.
      }
      // Un glifo per giro di event loop: il lavoro sui pixel è sincrono e
      // senza questo yield congelerebbe la UI per l'intero caricamento.
      await Future<void>.delayed(Duration.zero);
    }

    notifyListeners();
  }

  /// Decodifica il PNG a bassa risoluzione, ritaglia il bounding box del
  /// glifo, misura la larghezza delle teste e produce un'immagine bianca
  /// con alpha = scurezza del pixel più la sua taglia display.
  static Future<FigurationGlyph?> _toGlyph(Uint8List pngBytes) async {
    final codec = await ui.instantiateImageCodec(
      pngBytes,
      targetHeight: _decodeHeight,
    );
    final frame = await codec.getNextFrame();
    final ui.Image decoded = frame.image;

    final byteData =
        await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
    final int width = decoded.width;
    final int height = decoded.height;
    decoded.dispose();
    if (byteData == null) return null;
    final Uint8List rgba = byteData.buffer.asUint8List();

    // Bounding box dei pixel "inchiostro" (luminanza sotto soglia).
    int minX = width, minY = height, maxX = -1, maxY = -1;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int i = (y * width + x) * 4;
        final int lum = (rgba[i] + rgba[i + 1] + rgba[i + 2]) ~/ 3;
        if (lum < 230) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < minX || maxY < minY) return null; // PNG vuoto

    final int cw = maxX - minX + 1;
    final int ch = maxY - minY + 1;
    final Uint8List mask = Uint8List(cw * ch * 4);
    for (int y = 0; y < ch; y++) {
      for (int x = 0; x < cw; x++) {
        final int src = ((y + minY) * width + (x + minX)) * 4;
        final int lum = (rgba[src] + rgba[src + 1] + rgba[src + 2]) ~/ 3;
        final int alpha = 255 - lum;
        final int dst = (y * cw + x) * 4;
        // Bianco premoltiplicato: (a, a, a, a).
        mask[dst] = alpha;
        mask[dst + 1] = alpha;
        mask[dst + 2] = alpha;
        mask[dst + 3] = alpha;
      }
    }

    // Larghezza delle teste: massima corsa orizzontale d'inchiostro nel 35%
    // inferiore del glifo (le teste sono sempre in basso; travature e
    // numeri di gruppo stanno in alto). Per la pausa di semiminima da sola
    // la misura cade sul corpo della pausa, che ha circa la stessa
    // larghezza di una testa — la taglia resta coerente senza casi
    // speciali.
    int headPx = 1;
    final int headTop = maxY - (ch * 0.35).floor();
    for (int y = math.max(headTop, minY); y <= maxY; y++) {
      int run = 0;
      for (int x = minX; x <= maxX; x++) {
        final int i = (y * width + x) * 4;
        final int lum = (rgba[i] + rgba[i + 1] + rgba[i + 2]) ~/ 3;
        if (lum < 230) {
          run++;
          if (run > headPx) headPx = run;
        } else {
          run = 0;
        }
      }
    }

    final double scale = targetHeadWidth / headPx;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      mask,
      cw,
      ch,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    return FigurationGlyph(image, cw * scale, ch * scale);
  }
}
