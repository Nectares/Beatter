# ASO Report — Beatter (mercato italiano)

## 1. Titolo consigliato

| Store | Titolo | Perché |
|---|---|---|
| App Store | **Beatter — Rhythm Trainer** | Brand + categoria in inglese (gli utenti IT cercano anche "rhythm trainer"); le keyword IT vanno nel sottotitolo e nel campo keyword. |
| Google Play | **Beatter: Metronomo e Ritmo** | "Metronomo" è la query a più alto volume del settore in italiano; il titolo pesa più di ogni altro campo nell'algoritmo Play. |

## 2. Sottotitolo (App Store, max 30 char)
1. **Metronomo, ritmo, lettura** — copre 3 keyword primarie ✅ consigliato
2. Allena timing e ritmo
3. Il tuo coach ritmico (più emozionale, meno ASO)

## 3. Strategia keyword
- **Fase lancio (0-4 settimane):** puntare su nicchie a bassa concorrenza dove è realistico entrare in top 10: *poliritmi, solfeggio ritmico, lettura ritmica, rhythm trainer*.
- **Fase crescita:** attaccare *metronomo* (altissimo volume, alta concorrenza) tramite recensioni + velocity dei download ottenuta dalle nicchie.
- Il campo keyword App Store non deve ripetere parole già in titolo/sottotitolo.
- Dettaglio completo in [keywords_it.md](keywords_it.md).

## 4. Posizionamento vs concorrenti

| Concorrente | Punto di forza | Debolezza che Beatter attacca |
|---|---|---|
| Complete Rhythm Trainer | Completezza didattica | UI datata, inglese; Beatter è nativo italiano e premium |
| Yousician | Brand, gamification | Generalista e costoso; Beatter è specialista del ritmo |
| Simply Piano/Drums | Onboarding eccellente | Poca profondità ritmica (no poliritmi, no lettura pura) |
| Metronomi classici (Soundbrenner, Pro Metronome) | Utility affidabile | Solo click: nessun allenamento, nessun progresso |

**Messaggio differenziante:** *"Il metronomo ti dice dove sbagli. Beatter ti allena a non sbagliare."* Unica app con poliritmi visualizzati geometricamente + generatore di esercizi di lettura in italiano.

## 5. Ordine screenshot consigliato
I primi 2-3 screenshot decidono la conversione (su Play spesso se ne vede solo 1,5 above-the-fold):

1. `01_brand` — identità immediata: logo, nome, claim
2. `04_poliritmi` — il visual più distintivo (scuro, drammatico: pattern-interrupt nella galleria)
3. `02_home` — ampiezza dell'offerta in un colpo d'occhio
4. `03_flow_mode` — l'allenamento quotidiano
5. `05_livelli` — progressione principiante→pro (riduce la paura "non fa per me")
6. `06_lettura` — profondità didattica (pentagramma reale + PDF)
7. `07_ascolta_ripeti` — gamification
8. `08_precisione` — chiusura sul claim di precisione

## 6. Icona — raccomandazioni
- L'attuale badge arancione con "B" e bacchette è distintivo e riconoscibile ✔
- Per lo store: fondo pieno (gradiente radiale arancio, già generato in `feature_graphics/app_icon_*.png`), niente trasparenza.
- Test A/B futuro: variante con smerlatura semplificata — a 48px i dettagli del bordo si impastano.
- Evitare testo nell'icona; la "B" è già il brand.

## 7. Colore — raccomandazioni
- Palette store = palette app (arancio #FF7A00, terracotta #C1502E, crema #FFF8F1): coerenza icona → screenshot → primo avvio ✔
- L'arancio si distingue nella categoria Musica dominata da blu/nero/viola.
- Mantenere lo screenshot scuro (Polyrhythm) in seconda posizione: il contrasto crema/scuro comunica "profondità pro".

## 8. Ottimizzazione conversione
- **Recensioni:** chiedere la recensione dopo un "Nuovo record!" in Reading Mode (momento di picco emotivo), mai al primo avvio.
- **Play Store:** compilare la sezione "Novità" a ogni release — pesa sul ranking.
- **Video anteprima (fase 2):** 15-20s di Polyrhythm Lab in movimento convertono più di qualsiasi screenshot statico.
- **Localizzazione EN subito dopo il lancio IT:** il campo keyword EN cattura anche ricerche italiane in inglese ("rhythm trainer", "drum practice").

## 9. Scheda store — checklist
- [ ] Categoria: Musica (primaria) + Istruzione (secondaria, solo App Store)
- [ ] Tag Play: metronomo, rhythm trainer, batteria, esercizi musicali
- [ ] Rating contenuti: 4+/PEGI 3
- [ ] Privacy policy URL + data safety form (l'app usa Firebase Auth/Firestore/Analytics)
- [ ] Feature graphic caricata (obbligatoria su Play): `play_store/feature_graphics/feature_graphic_1024x500.png`
- [ ] Screenshot iPad obbligatori se l'app dichiara supporto iPad ✔ già generati

## 10. Analisi prima impressione (5 secondi)
Un utente che atterra sulla scheda vede: icona arancione distintiva → titolo con "metronomo/rhythm" → screenshot brand con claim in italiano → screenshot scuro dei poliritmi. In 5 secondi capisce: *è un'app italiana, premium, specializzata nel ritmo, non l'ennesimo metronomo*. Questo è esattamente il posizionamento voluto.

**Rischio principale:** "Composer Mode" appare nell'app come "Presto" (coming soon) — è corretto NON mostrarlo negli screenshot (Apple respinge feature non funzionanti pubblicizzate). Al rilascio di Composer, aggiungere lo screenshot dedicato e aggiornare le descrizioni.
