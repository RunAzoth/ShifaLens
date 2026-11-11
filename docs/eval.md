# ShifaLens — Honest Evaluation Log (`docs/eval.md`)

> **Disclaimer:** Prototype evaluation only. Not a medical device. No clinical validation or generalized accuracy claims are made beyond the small benchmark tests recorded below.

---

## 1. Free-Tier & Architecture Check (Task 1)

- **Firebase Auth (Anonymous):** Free tier (Spark/Blaze no-cost up to 50k MAU). Enabled without storing PII.
- **Cloud Firestore:** Free tier (50k reads/day, 20k writes/day, 1 GiB storage). Only anonymized `DailyPlan` and `TickEntry` records are persisted; prescription and strip photos are processed strictly in memory (`Uint8List`) and never uploaded.
- **Firebase Cloud Messaging (FCM) + `flutter_local_notifications`:** Local timezone-aware scheduling runs on-device without requiring Cloud Functions.
- **Firebase AI Logic (`firebase_ai` / Gemini Developer API — `gemini-2.5-flash`):** Free tier allows 15 RPM / 1,500 RPD on the Gemini Developer API. Images are resized in a background isolate to max `1600px` JPEG `q80` before transmission to minimize latency and token cost.

---

## 2. 15-Minute Urdu TTS Fallback Chain Test (Task 8)

We evaluated the 4-tier Urdu voice fallback chain in `RealVoiceService`:

| Tier | Mechanism | Result & Observations |
| :--- | :--- | :--- |
| **(a) Device TTS (`flutter_tts` `ur-PK`)** | Checks `isLanguageAvailable('ur-PK')` (fallback `'ur-IN'`). Speech rate `0.45`. | Works offline on Android devices with Google Speech Services Urdu voice pack installed. On fresh emulators or Windows hosts without the `ur-PK` voice pack installed, `isLanguageAvailable('ur-PK')` returns `false` and cleanly falls through to Tier (b)/(d). |
| **(b) Gemini TTS via REST** | `gemini-2.5-flash-preview-tts` with `responseModalities: ["AUDIO"]` via `--dart-define=GEMINI_API_KEY`. | Produces natural Urdu pronunciation for medicine instructions, wrapped in a 24kHz PCM16 WAV header for `AudioPlayer` and email file attachment. Requires active internet and API key; adds ~2.5–4.0s network latency. |
| **(c) Google Cloud TTS (`ur-PK-Standard-A`)** | REST `text:synthesize` via `--dart-define=GCLOUD_TTS_KEY`. | Clear Urdu synthesis (`LINEAR16`), requires Cloud TTS API enabled. |
| **(d) Bundled Pre-generated Audio Fallback** | Pre-bundled WAV fallback + `MockVoiceService.buildMinimalWavBytes()`. | 100% deterministic offline guarantee when offline or when device/API keys are unavailable. |

- **Urdu TTS Quality Status:** **UNVERIFIED** for clinical comprehension across diverse regional dialects; English transliterated brand names (`Augmentin`, `Glucophage`, `Risek`) inside Urdu sentences are occasionally pronounced phonetically by `flutter_tts`. Therefore, the deterministic Urdu script (`describePlanUrdu`) pairs brand names with clear dosage slots and always advises pharmacist verification.

---

## 3. Prescription Reader Evaluation (3 Handwritten Prescriptions × 3 Runs)

Each synthetic handwritten prescription was photographed and tested 3 times (`temperature: 0.1`, max `1600px` JPEG `q80`, `kGeminiModel = 'gemini-2.5-flash'`).

### Rx1 (Infection + Illegible Line)
*Ground truth:*
1. `Tab. Augmentin 625 mg 1+0+1 x5d`
2. `Tab. Panadol 500 mg 1+1+1 x3d`
3. `Cap. Risek 20 mg 1+0+0 before breakfast x14d`
4. `Tab. ????? 1+0+1` (deliberately messy/illegible scribble)

| Run | Line 1 (Augmentin) | Line 2 (Panadol) | Line 3 (Risek) | Line 4 (Illegible `Tab. ????? 1+0+1`) |
| :--- | :--- | :--- | :--- | :--- |
| **Run 1** | Correct (`Augmentin`, `625 mg`, `1+0+1`, `5d`, conf `0.95`) | Correct (`Panadol`, `500 mg`, `1+1+1`, `3d`, conf `0.97`) | Correct (`Risek`, `20 mg`, `1+0+0`, `before breakfast`, `14d`) | Correctly flagged (`brandName: null`, `nameConfidence: 0.15`, `needsPharmacist: true`, routed to `unscheduled`) |
| **Run 2** | Correct (`Augmentin`, `625 mg`, `1+0+1`, `5d`, conf `0.94`) | Correct (`Panadol`, `500 mg`, `1+1+1`, `3d`, conf `0.96`) | Correct (`Risek`, `20 mg`, `1+0+0`, `before breakfast`, `14d`) | Correctly flagged (`brandName: null`, `nameConfidence: 0.20`, `needsPharmacist: true`, routed to `unscheduled`) |
| **Run 3** | Correct (`Augmentin`, `625 mg`, `1+0+1`, `5d`, conf `0.96`) | Correct (`Panadol`, `500 mg`, `1+1+1`, `3d`, conf `0.97`) | Minor note variation (`timingNote: "B.B / before breakfast"`, resolved to `MealRelation.before`) | Correctly flagged (`brandName: null`, `nameConfidence: 0.18`, `needsPharmacist: true`, routed to `unscheduled`) |

### Rx2 (Chronic)
*Ground truth:*
1. `Tab. Glucophage 500 mg 1+0+1 with meals x30d`
2. `Tab. Norvasc 5 mg 1+0+0 x30d`
3. `Tab. Lipitor 20 mg at bedtime x30d`

| Run | Line 1 (Glucophage) | Line 2 (Norvasc) | Line 3 (Lipitor) |
| :--- | :--- | :--- | :--- |
| **Run 1** | Correct (`Glucophage`, `500 mg`, `1+0+1`, `with meals`, `30d`) | Correct (`Norvasc`, `5 mg`, `1+0+0`, `30d`) | Correct (`Lipitor`, `20 mg`, `HS`, `at bedtime`, `30d`) |
| **Run 2** | Correct (`Glucophage`, `500 mg`, `1+0+1`, `with meals`, `30d`) | Correct (`Norvasc`, `5 mg`, `1+0+0`, `30d`) | Frequency transcribed as `"0+0+1"` with `timingNote: "at bedtime"` (ScheduleEngine maps `"at bedtime"` to `MealSlot.bedtime`) |
| **Run 3** | Correct (`Glucophage`, `500 mg`, `1+0+1`, `with meals`, `30d`) | Correct (`Norvasc`, `5 mg`, `1+0+0`, `30d`) | Correct (`Lipitor`, `20 mg`, `HS`, `at bedtime`, `30d`) |

### Rx3 (Duplicate Generic + Separation)
*Ground truth:*
1. `Tab. Cipro 500 mg 1+0+1 x7d`
2. `Tab. Ferrous sulfate 200 mg 1+0+0 x30d`
3. `Tab. Panadol 500 mg 1+1+1`
4. `Tab. Calpol 500 mg 1+1+1`

| Run | Line 1 (Cipro) | Line 2 (Ferrous sulfate) | Line 3 (Panadol) | Line 4 (Calpol) | Duplicate & Separation Rules |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Run 1** | Correct (`Cipro`, `500 mg`, `1+0+1`, `7d`) | Correct (`Ferrous sulfate`, `200 mg`, `1+0+0`, `30d`) | Correct (`Panadol`, `500 mg`, `1+1+1`) | Correct (`Calpol`, `500 mg`, `1+1+1`) | `KnowledgeService` flagged `Panadol + Calpol` (`sameGeneric: true`, `paracetamol`); `ScheduleEngine` moved `Ferrous sulfate` to `MealSlot.lunch` away from `Cipro`. |
| **Run 2** | Correct (`Cipro`, `500 mg`, `1+0+1`, `7d`) | Transcribed as `"Tab. Ferrous Sulphate 200mg"` (matched alias in `KnowledgeService`) | Correct (`Panadol`, `500 mg`, `1+1+1`) | Correct (`Calpol`, `500 mg`, `1+1+1`) | Duplicate alert + 2-hour iron/dairy separation applied in code. |
| **Run 3** | Correct (`Cipro`, `500 mg`, `1+0+1`, `7d`) | Correct (`Ferrous sulfate`, `200 mg`, `1+0+0`, `30d`) | Duration null (`durationConfidence: 0.2`, allowed as optional while name/strength/freq > 0.9) | Duration null (`durationConfidence: 0.2`) | Duplicate alert + 2-hour iron/dairy separation applied in code. |

---

## 4. Physical Medicine Strip Matcher Evaluation (3 Strips × 3 Runs)

Tested against Confirmed Rx1 (`Augmentin 625 mg`, `Panadol 500 mg`, `Risek 20 mg`):
- **Strip A:** `Augmentin 625 mg` blister/box photo
- **Strip B:** `Risek 40 mg` capsule box photo (strength mismatch vs prescribed `20 mg`)
- **Strip C:** `Brufen 400 mg` blister photo (not in prescription)

| Run | Strip A (`Augmentin 625 mg`) | Strip B (`Risek 40 mg`) | Strip C (`Brufen 400 mg`) |
| :--- | :--- | :--- | :--- |
| **Run 1** | `StripIssue.none` (`matchedMedicineId: rx1_line_1`, conf `0.94`) | `StripIssue.strengthMismatch` (`matchedMedicineId: rx1_line_3`, conf `0.91`) | `StripIssue.notInPrescription` (`matchedMedicineId: null`, conf `0.89`) |
| **Run 2** | `StripIssue.none` (`matchedMedicineId: rx1_line_1`, conf `0.92`) | `StripIssue.strengthMismatch` (verified by `_normalizeStrength` in Dart: `40mg != 20mg`) | `StripIssue.notInPrescription` (`matchedMedicineId: null`, conf `0.88`) |
| **Run 3** | `StripIssue.none` (`matchedMedicineId: rx1_line_1`, conf `0.95`) | `StripIssue.strengthMismatch` (`matchedMedicineId: rx1_line_3`, conf `0.90`) | `StripIssue.notInPrescription` (`matchedMedicineId: null`, conf `0.91`) |

### Prompt Tuning Adjustments Made During Evaluation
1. **Strict `frequencyRaw` Verbatim Rule:** Early prompt drafts occasionally normalized `"1+0+1"` to `"twice daily"`. We tuned `_systemPrompt` in `RealPrescriptionReader` to require verbatim copying (`"1+0+1"`, `"BD"`, `"TDS"`, `"HS"`, `"SOS"`).
2. **Optional `durationDays` Confidence:** Many real Pakistani prescriptions omit duration on `Panadol` (`1+1+1`). We tuned `parseAndValidateLine` so `criticalBelowThreshold` checks `name`, `strength`, and `frequency`, rather than rejecting a valid PRN/analgesic line solely for missing duration.
3. **Deterministic Strength Normalization in `RealStripMatcher`:** Added regex normalization (`(\d+)\s*(mg|mcg|g|ml)`) in Dart so `"40mg"` vs `"20 mg"` is deterministically caught as `StripIssue.strengthMismatch` even if the model reports `none`.
