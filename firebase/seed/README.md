# Firestore seed documents

Documenti di configurazione letti dall'app, tenuti qui in JSON perché il
loro contenuto è codice quanto le regole: si rivede in diff, non a memoria
dentro la console.

## `config_appVersion.json` → `config/appVersion`

Il version gate (`lib/features/update/`) legge questo documento a ogni
avvio: decide chi resta fuori (`minSupportedVersion`) e a chi proporre
l'aggiornamento (`latestVersion`). Campi e semantica: `DEPLOYMENT.md` §3.3.

I valori committati qui sono il **seed neutro**: uguali alla versione in
`pubspec.yaml`, quindi nessuno viene bloccato e nessun dialog compare.
Servono ad avere il documento *presente* e con la forma giusta; i valori
veri si alzano a ogni rilascio, dopo il rollout.

Stringa vuota = campo non impostato (l'app la tratta come assente), così
`iosStoreUrl` resta innocuo finché l'app non è sull'App Store e non c'è un
id numerico da metterci.

### Come caricarlo

Console: Firestore → collezione `config` → documento `appVersion` → aggiungi
i campi come stringhe (salta quelli vuoti).

Oppure, per non farlo a mano a ogni ambiente:

```bash
node tools/seed_app_version.mjs firebase/seed/config_appVersion.json
```

Lo script scrive con l'Admin SDK e quindi ha bisogno di credenziali di
servizio (`GOOGLE_APPLICATION_CREDENTIALS`, oppure
`gcloud auth application-default login`): il login della Firebase CLI da
solo non basta, e la CLI non ha nessun comando per scrivere documenti.
