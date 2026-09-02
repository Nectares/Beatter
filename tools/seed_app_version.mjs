// Carica un documento di configurazione su Firestore.
//
//   node tools/seed_app_version.mjs [file.json] [--project beatterapp]
//
// Serve perché la Firebase CLI sa cancellare documenti ma non scriverli, e
// rifare i campi a mano nella console a ogni ambiente è un invito a
// sbagliarne uno. Usa l'Admin SDK: servono credenziali di servizio
// (GOOGLE_APPLICATION_CREDENTIALS o `gcloud auth application-default
// login`), che è anche il motivo per cui questo script sta qui e non gira
// da solo in CI.
//
// Il documento è `config/appVersion` (vedi DEPLOYMENT.md §3.3): sbagliare
// `minSupportedVersion` chiude fuori gli utenti, quindi lo script stampa
// cosa sta per scrivere e chiede conferma se non passi --yes.

import { readFile } from 'node:fs/promises';
import { createInterface } from 'node:readline/promises';
import { stdin, stdout, argv, exit } from 'node:process';

const DOC_PATH = 'config/appVersion';

const args = argv.slice(2);
const file = args.find((a) => !a.startsWith('--')) ?? 'firebase/seed/config_appVersion.json';
const project = valueOf('--project') ?? 'beatterapp';
const assumeYes = args.includes('--yes');

function valueOf(flag) {
  const index = args.indexOf(flag);
  return index === -1 ? undefined : args[index + 1];
}

const raw = JSON.parse(await readFile(file, 'utf8'));

// Le stringhe vuote nel seed valgono "non impostato": scriverle davvero
// significherebbe salvare campi finti sul documento.
const data = Object.fromEntries(
  Object.entries(raw).filter(([, v]) => typeof v !== 'string' || v.trim() !== ''),
);

console.log(`Progetto : ${project}`);
console.log(`Documento: ${DOC_PATH}`);
console.log(`Da       : ${file}`);
console.log(JSON.stringify(data, null, 2));

if (!assumeYes) {
  const rl = createInterface({ input: stdin, output: stdout });
  const answer = await rl.question('\nScrivo su Firestore? [y/N] ');
  rl.close();
  if (answer.trim().toLowerCase() !== 'y') {
    console.log('Annullato.');
    exit(0);
  }
}

const { initializeApp, applicationDefault } = await import('firebase-admin/app');
const { getFirestore } = await import('firebase-admin/firestore');

initializeApp({ credential: applicationDefault(), projectId: project });
await getFirestore().doc(DOC_PATH).set(data, { merge: true });

console.log(`Scritto ${DOC_PATH}.`);
