# UX STEP 2 — Wonderlog | Piano di viaggio leggero

**STATO:** UX DRAFT / ATTESA APPROVAZIONE. **Fonte:** TPLUX-REF-0011 Trip Planner; E2 riguarda solo struttura dell'export (15 MD, 6 CSV, 4 immagini), non automazioni, mappe, costi automatici o formule. Tutti i testi e i dati del prototipo sono originali e fittizi.

**Baseline:** Wonderlog `c63009158867eaeaae3cf0a02995335f8ffd89d1`, App-Factory-Core `d4ed1185d36d419228fba6b57a979cde308bd321`.

[**Prototipo HTML originale navigabile**](PROTOTIPO_PIANO_VIAGGIO.html) (nessun accesso ai dati dell'app né chiamate geocoding/routing).

## Product fit: un viaggio Wonderlog, non una copia di Notion

L'esperienza proposta `Piano di viaggio leggero` permette di creare un nuovo `Journey` attraverso gli input **già supportati** dal repository. In un secondo momento il viaggio potrà ricevere memorie/foto già gestite da Wonderlog. Non progettare un nuovo DB `Trip/Itinerary/Expenses/Packing` senza product approval.

**Primo pilota gratuito**: creazione guidata di un singolo Journey con titolo, destinazione, periodo e `description` editoriale contenente sezioni `Idee per le tappe`, `Cose da ricordare` e `Bagaglio essenziale`. Le sezioni sono **testo**, non veri task/booking/budget con calcoli. I campi del form esistente sono riusati.

## Ancoraggio al codice reale

- `flutter/lib/features/journeys/domain/journey.dart`: id, title, destination, country, startDate/endDate, description, lat/long, favorite, archived; **nessun campo budget o packing strutturato** in quel domain object.
- `flutter/lib/features/journeys/domain/journey_repository.dart`: `createJourney(title, destination, startDate, endDate, country, description)`; `WonderlogRepository` estende la porta.
- `flutter/lib/features/journeys/presentation/journey_widgets.dart`: `showCreateJourneyDialog` per title, destination, dates; validazione e controllo Premium limit **prima della creazione**.
- `flutter/lib/features/premium/domain/premium_gate.dart`: i limiti di Journey già esistono; il template non deve aggirarli.
- `flutter/lib/app/theme/wonderlog_tokens.dart`: seed `#E85D75`, accent `#7C5CE5`, card radius 20, touch target 48.
- `ROADMAP.md`: preservare cutover, gestione Memories, optional cloud, offline maps provider gating e release evidence.

## Schermate e percorso utente

1. **Nuovo viaggio → Da un modello** (nuovo entrypoint solo **proposto**): card `Viaggio da organizzare` e anteprima.
2. **Anteprima**: header destinazione, timeline editoriale con `idee di tappe` e lista personale in `description`; non usare una mappa simulata né badge `Prenotato`.
3. **Personalizzazione**: nome, destinazione, data di partenza/ritorno, opzione se includere sezioni testuali per tappe/bagagli. Nessuna prenotazione, prezzo o POI inventato.
4. **Riepilogo**: un `Journey`, campi e descrizione che verranno scritti; il futuro adapter chiama il writer canonico **solo** dopo conferma e gate Premium riesaminato.
5. **Maxi-step 3**: commit una volta con ricevuta d'installazione idempotente, nessun Journey duplicato in retry. Aprire pagina Journey esistente dopo salvataggio.
6. **Rimozione modello**: non cancellare viaggio, ricordi, foto o collegamenti del cliente.

## Stati e limitazioni

- Data fine non precedente alla data di inizio; titolo e destinazione obbligatori.
- La demo permette di cambiare i valori e simula il riepilogo, ma NON inserisce nel DB o usa servizi remoti. Destinazioni e tappe testuali sono inventate.
- Errori per limite Free, Premium sconosciuto, date invalide, contenuto troppo lungo, memoria insufficiente, offline, switch account, permesso/media, rollback. Nessun bypass ai limiti.
- **Visual QA futuro:** 360dp/large screen, font scale, dark mode, 48dp, IT/EN/ES/FR/PT + locale aggiuntivo se configurato dal repo; non affermare L10n testata finché non verificata.
- **Fuori MVP**: vero itinerario navigabile, budget numerico, packing checklist con persistenza relazionale, prenotazioni, integrazione geocoding, sync, acquisti premium. Necessitano roadmap separata e Product Bible.

**Gate:** approvazione UX prima dell'implementazione in Flutter e dei nuovi product fields. Nessuna modifica a Journey, Drift, RevenueCat, maps, provider, database o build in questo step.
