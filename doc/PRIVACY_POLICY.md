# Beatter — Informativa sulla Privacy

**Ultimo aggiornamento:** 16 luglio 2026 · **Versione:** 1.0 · **Lingua:** Italiano

> Documento sorgente dell'informativa privacy di Beatter. La versione pubblicata
> online (https://beatter.it/privacy/) deve restare allineata a questo file.
> I contenuti riflettono il comportamento reale dell'app in modalità di
> produzione (backend Firebase attivo). Quando Firebase non è disponibile,
> l'app funziona in **modalità locale** e la maggior parte dei dati resta solo
> sul dispositivo.

---

## In breve

- Beatter è utilizzabile anche **senza account**: molti dati (esercizi,
  impostazioni, record) restano **sul tuo dispositivo**.
- Se crei un account, usiamo i servizi **Firebase di Google** per autenticarti,
  salvare i tuoi contenuti e sincronizzare i tuoi progressi.
- Alcuni dati (nome visualizzato, foto e punti) sono **visibili agli altri
  utenti** nelle **classifiche**, se partecipi.
- Usiamo strumenti di **analisi d'uso** e di **segnalazione dei crash** per
  migliorare l'app e la sua stabilità.
- **Non vendiamo** i tuoi dati e **non mostriamo pubblicità** di terze parti.

---

## 1. Titolare del trattamento

Il titolare del trattamento dei dati personali raccolti tramite l'applicazione
Beatter (di seguito "Beatter", "l'app", "noi") è **Nectares Devlabs**, sviluppatore
dell'applicazione (identificativi app `com.nectares.beatter`).

Per qualsiasi richiesta relativa alla privacy puoi scriverci a
**nectares.devlabs@gmail.com**.

## 2. Dati che trattiamo

A seconda di come usi l'app, trattiamo le seguenti categorie di dati:

- **Dati dell'account** — indirizzo email e identificativo utente (UID) quando
  ti registri o accedi. In base al metodo di accesso possiamo ricevere anche
  **nome visualizzato** e **foto profilo** (ad es. da Google o Apple).
- **Profilo** — nome visualizzato, eventuale foto, username (per future funzioni
  social) e preferenze impostate nell'app.
- **Contenuti generati dagli utenti** — composizioni ritmiche, pattern, esercizi
  e brani salvati che crei con le modalità di Beatter.
- **Statistiche di esercizio** — cronologia degli allenamenti (durata, livello
  di difficoltà), risultati di precisione, punti, obiettivi/achievement, record
  personali e serie giornaliere.
- **Impostazioni dell'app** — BPM preferiti, suddivisioni, tema e altre
  configurazioni.
- **Dati di utilizzo e diagnostici** — eventi di utilizzo dell'app (vedi §9),
  informazioni sul dispositivo e sulla versione dell'app, e report di crash
  (vedi §9).

Quando usi Beatter **senza account** (o in modalità locale), la maggior parte di
questi dati resta memorizzata **localmente sul tuo dispositivo** e non viene
trasmessa ai nostri server.

## 3. Finalità e basi giuridiche

Trattiamo i tuoi dati per le seguenti finalità:

- **Fornire il servizio** (esecuzione del contratto) — autenticarti, salvare e
  sincronizzare i tuoi contenuti e progressi, calcolare punti e classifiche.
- **Migliorare l'app** (legittimo interesse o consenso, dove richiesto) — capire
  quali funzioni sono usate e diagnosticare problemi tecnici.
- **Sicurezza** (legittimo interesse) — prevenire abusi, frodi, manipolazione dei
  punteggi e accessi non autorizzati.
- **Adempimenti di legge** (obbligo legale) — quando previsto dalla normativa
  applicabile.

## 4. Servizi e fornitori terzi

Per erogare le funzioni cloud, Beatter si affida a **Google Firebase** (Google
Ireland Limited / Google LLC). In modalità di produzione sono utilizzati i
seguenti servizi:

- **Firebase Authentication** — registrazione e accesso (email/password, Google,
  Apple, accesso anonimo).
- **Cloud Firestore** — database in cui vengono salvati profilo, impostazioni,
  contenuti, cronologia allenamenti, statistiche, punti, achievement e voci di
  classifica.
- **Firebase Storage** — archiviazione di eventuali file/media associati ai tuoi
  contenuti o al profilo.
- **Cloud Functions** — elaborazioni lato server (vedi §10).
- **Firebase Analytics** — statistiche di utilizzo aggregate (vedi §9).
- **Firebase Crashlytics** — segnalazione dei crash su dispositivi mobili (vedi §9).
- **Firebase App Check** — protezione delle risorse cloud da usi non autorizzati.

Questi servizi trattano i dati come responsabili del trattamento per nostro
conto. Per maggiori informazioni consulta la
[privacy di Firebase](https://firebase.google.com/support/privacy) e la
[privacy policy di Google](https://policies.google.com/privacy).

## 5. Account e autenticazione

La creazione di un account è **facoltativa** e serve a sincronizzare i tuoi
contenuti e progressi tra dispositivi e a partecipare alle classifiche. Beatter
supporta l'accesso tramite:

- **Email e password**;
- **Google** (Google Sign-In);
- **Apple** (Accedi con Apple);
- **accesso anonimo** (utilizzo senza fornire dati identificativi).

Tramite Firebase Authentication trattiamo il tuo indirizzo email (se applicabile)
e un identificativo univoco (UID). Con Google o Apple riceviamo le informazioni
di base necessarie all'accesso (identificativo e, se disponibili, email, nome e
foto), secondo le autorizzazioni che concedi.

Puoi **richiedere l'eliminazione** del tuo account e dei dati associati
scrivendoci (vedi §13). Per motivi di integrità dei dati, l'eliminazione
dell'account è gestita **lato server** e non direttamente dal client.

## 6. Contenuti generati dagli utenti

Le composizioni, i pattern, gli esercizi e i brani che crei e salvi ("contenuti
generati dagli utenti") sono di tua proprietà. Se usi l'app con un account,
vengono salvati su Cloud Firestore / Firebase Storage per permetterti di
ritrovarli e sincronizzarli. Questi contenuti sono **privati** e accessibili solo
dal tuo account (e, per finalità tecniche e di supporto, da personale autorizzato
— vedi §15). Non li rendiamo pubblici né li condividiamo con altri utenti.

## 7. Statistiche di esercizio

Per mostrarti i tuoi progressi, Beatter registra i risultati delle sessioni di
pratica: durata e livello degli allenamenti, precisione, punti, achievement,
record personali e serie giornaliere. Con un account, questi dati vengono
sincronizzati per essere consultabili su più dispositivi e alimentano le
meccaniche di gamification (punti e classifiche, vedi §8).

## 8. Classifiche e funzioni social

Se partecipi alle **classifiche** (globale e settimanale), alcune informazioni del
tuo profilo — **nome visualizzato, foto profilo e punteggio** — vengono mostrate
agli **altri utenti autenticati** dell'app. Queste voci di classifica sono
mantenute aggiornate lato server (vedi §10).

Gli **username** (handle) eventualmente riservati per future funzioni social sono
tecnicamente a lettura pubblica (servono a garantire l'unicità del nome). Il resto
del tuo profilo resta invece **privato**.

Se non desideri comparire nelle classifiche o vuoi rimuovere i tuoi dati social,
contattaci (vedi §13).

## 9. Analytics e diagnostica

Per capire come viene usata l'app e migliorarla, in modalità di produzione
utilizziamo:

- **Firebase Analytics** — raccoglie eventi di utilizzo, ad esempio: accesso e
  registrazione (con il metodo usato), visualizzazioni di schermata, completamento
  di un allenamento (tipo, durata, punti provvisori), salvataggio di una
  composizione e sblocco di achievement. Ad Analytics viene associato il tuo
  identificativo utente (UID) per collegare gli eventi al tuo account.
- **Firebase Crashlytics** — attivo su **dispositivi mobili (iOS e Android)**,
  raccoglie report tecnici in caso di errore o crash (tipo di dispositivo,
  versione, stato dell'app, stack trace) e vi associa il tuo UID per aiutarci a
  correggere i problemi. Crashlytics **non è attivo sul web**.

Questi dati sono usati per finalità statistiche e di stabilità e non per profilare
la tua persona a fini pubblicitari. Dove richiesto dalla normativa applicabile,
raccoglieremo il consenso e aggiorneremo questa informativa.

## 10. Elaborazioni lato server (Cloud Functions)

Alcune operazioni vengono eseguite automaticamente sui nostri server tramite
Firebase Cloud Functions, in particolare per:

- calcolare punti, statistiche aggregate e achievement a partire dagli
  allenamenti che salvi;
- mantenere aggiornate le voci di **classifica** quando modifichi il profilo o
  ottieni nuovi punti;
- eseguire il **reset settimanale** dei punti della classifica settimanale.

Queste elaborazioni sono necessarie a fornire le funzioni di progressione e
gamification dell'app.

## 11. Conservazione dei dati

Conserviamo i dati dell'account e i contenuti sincronizzati finché il tuo account
è attivo o finché sono necessari a fornirti il servizio. I dati memorizzati
localmente rimangono sul tuo dispositivo finché non li elimini o disinstalli
l'app. Quando richiedi l'eliminazione dell'account, i dati associati vengono
rimossi entro tempi tecnici ragionevoli, salvo obblighi di conservazione previsti
dalla legge.

## 12. Trasferimenti internazionali

I servizi Firebase possono comportare il trattamento dei dati anche al di fuori
dello Spazio Economico Europeo. In tali casi Google adotta garanzie adeguate (ad
esempio le Clausole Contrattuali Standard approvate dalla Commissione Europea) per
assicurare un livello di protezione conforme al GDPR.

## 13. I tuoi diritti

In conformità al Regolamento (UE) 2016/679 (GDPR), hai diritto di accedere ai tuoi
dati, rettificarli, cancellarli, limitarne o opporti al trattamento, e alla
portabilità. Puoi inoltre revocare in ogni momento un eventuale consenso prestato.

Molte azioni sono disponibili direttamente nell'app (ad esempio la modifica del
profilo e delle impostazioni). Per esercitare i tuoi diritti, richiedere
l'eliminazione dell'account o presentare un reclamo, scrivici a
**nectares.devlabs@gmail.com**. Hai anche il diritto di rivolgerti all'autorità di
controllo competente (in Italia, il Garante per la protezione dei dati personali).

## 14. Minori

Beatter non è destinato a bambini di età inferiore a quella prevista dalla
normativa applicabile per prestare autonomamente il consenso al trattamento (in
Italia, 14 anni). Non raccogliamo consapevolmente dati di minori senza il consenso
di chi ne esercita la responsabilità genitoriale. Se ritieni che ciò sia avvenuto,
contattaci e provvederemo alla rimozione.

## 15. Sicurezza

Adottiamo misure tecniche e organizzative adeguate a proteggere i dati da accessi
non autorizzati, perdita o divulgazione, tra cui regole di sicurezza Firestore per
utente, protezione delle risorse tramite **Firebase App Check** e calcolo dei
punti lato server per prevenirne la manipolazione. Personale **amministratore
autorizzato** può accedere ai dati di profilo per finalità di supporto e
moderazione. Nessun sistema è però sicuro al 100%: ti invitiamo a proteggere le
tue credenziali e a segnalarci tempestivamente eventuali anomalie.

## 16. Modifiche a questa informativa

Potremmo aggiornare questa informativa per riflettere cambiamenti nell'app o nella
normativa. In caso di modifiche sostanziali te ne daremo avviso tramite l'app o
altri canali appropriati. La data in cima a questo documento indica sempre
l'ultimo aggiornamento.

## 17. Contatti

Per qualsiasi domanda su questa informativa o sul trattamento dei tuoi dati,
scrivici a **nectares.devlabs@gmail.com**.
