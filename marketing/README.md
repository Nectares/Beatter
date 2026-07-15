# Beatter — Pacchetto Marketing Store

Pacchetto completo per la pubblicazione su Apple App Store e Google Play (mercato italiano).
Tutte le immagini contengono **screenshot reali dell'app** (nessuna GUI inventata) oppure sono
composizioni 100% pubblicitarie brand-only (`01_brand`, `08_precisione`).

## Struttura

```
marketing/
├── screenshots/           # Catture RAW reali dell'app (sorgenti delle composizioni)
│   ├── phones/            #   430×932 @3x → 1290×2796
│   └── tablets/           #   1024×1366 @2x → 2048×2732
├── app_store/             # Screenshot finali App Store Connect (8 per misura)
│   ├── iphone_6_9/        #   1320×2868      ├── iphone_6_7/  1290×2796
│   ├── iphone_6_5/        #   1242×2688      ├── iphone_6_3/  1179×2556
│   ├── iphone_5_5/        #   1242×2208
│   ├── ipad_13_portrait/  #   2064×2752      ├── ipad_13_landscape/ 2752×2064
│   ├── ipad_11_portrait/  #   1668×2388      └── ipad_11_landscape/ 2388×1668
├── play_store/
│   ├── phones/            #   1080×1920 (9:16)
│   ├── tablets/           #   7" 1200×1920 · 10" 1600×2560 + landscape 2560×1600
│   └── feature_graphics/  #   feature 1024×500 · promo 180×120 · hero 1920×1080
├── feature_graphics/      # Hero large 2560×1440 + icone store (1024 App Store, 512 Play)
├── backgrounds/           # Sfondi brand (orizzontali e verticali) senza testo
├── descriptions/          # Copy completo IT: descrizioni, keyword, promo, 60 headline, ASO report
├── automation/            # capture_real_screens.js (Playwright → screenshot reali dal web build)
└── tools/                 # generate_assets.py (composizione + render di tutti i PNG)
```

## Ordine screenshot consigliato negli store
`01_brand → 04_poliritmi → 02_home → 03_flow_mode → 05_livelli → 06_lettura → 07_ascolta_ripeti → 08_precisione`
(razionale in [descriptions/aso_report.md](descriptions/aso_report.md))

## Rigenerare tutto

```bash
# 1. Avvia l'app web in modalità locale deterministica (nessun Firebase)
flutter run -d web-server --web-port 8348 --dart-define=FORCE_LOCAL_BACKEND=true

# 2. Cattura gli screenshot reali (telefono + tablet)
cd marketing/automation && npm install
node capture_real_screens.js phone
node capture_real_screens.js tablet

# 3. Componi e renderizza tutti gli asset (richiede Google Chrome)
python3 marketing/tools/generate_assets.py --sizes all
```

In alternativa, catture native da device/simulatore:
```bash
flutter drive --driver=integration_test/driver.dart \
  --target=integration_test/marketing_screenshots_test.dart \
  --dart-define=FORCE_LOCAL_BACKEND=true
```

## Note
- Composer Mode è "Presto" (coming soon) nell'app: **escluso deliberatamente** da screenshot e copy (le feature non attive non si pubblicizzano).
- Export: PNG non compressi, dimensioni esatte richieste dagli store, grafica vettoriale/CSS → qualità retina a ogni misura.
