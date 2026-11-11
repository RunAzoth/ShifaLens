# ShifaLens (شفا لینز)

> **"A pharmacist's explanation for every patient, in Urdu, with pictures."**  
> **ہر مریض کے لیے فارماسسٹ کی وضاحت، اردو میں، تصویروں کے ساتھ۔**  
> *Built for the "Build with Google" Hackathon (GDGoC CUI) — Healthcare Track (SDG 3 Primary, SDG 10 Supporting).*

---

## 1. Problem & Target Users

In Pakistan, millions of low-literacy patients, older adults, and family caregivers leave clinics with handwritten or English-only prescriptions and multiple look-alike blister strips. Unfamiliar brand names (e.g., *Panadol* + *Calpol* both containing paracetamol), critical food-timing rules (e.g., *Risek* 30 minutes before breakfast, *Cipro* separated from dairy and iron by 2 hours), and complex dosing shorthand (`1+0+1`, `TDS`, `HS`, `SOS`) lead to preventable medication errors.

**ShifaLens** turns a prescription photo into a pharmacist-guided, Urdu-first visual daily schedule with English subtitles:
1. **Capture & AI Transcription** -> Gemini reads visible lines without guessing.
2. **Confirm & Safety Gate** -> Uncertain/illegible lines (`confidence < 0.75`) are flagged and routed to a separate **"Not scheduled — ask your pharmacist"** list.
3. **Meal-Based Daily Timeline** -> Sun, moon, and meal icons (plus optional Ramadan Suhoor/Iftar layout marked *"Suggested — confirm with your doctor"*).
4. **Curated Food-Medicine & Side-Effect Cards** -> Plain Urdu + English guidance + *"Call your doctor if..."* red flags + qualitative Pakistani Plate Guide (roti, daal, sabzi, salad).
5. **Physical Strip Matcher & Printable Stickers** -> Matches up to 6 blister/box photos against the confirmed prescription, catching strength mismatches and unprescribed strips.
6. **Urdu Voice & Grounded Q&A** -> Deterministic spoken Urdu plan + strictly context-grounded Q&A (text or recorded voice) with code-level source verification.
7. **Local Dose Reminders, Tick Log & Caregiver Email** -> Schedules local bilingual notifications, logs adherence ticks, and emails a PDF + Urdu audio summary to a family caregiver.

---

## 2. UN Sustainable Development Goals (SDG Alignment)

- **SDG 3 — Good Health and Well-Being (Primary):** Directly targets medication safety and patient comprehension by preventing duplicate generic overdoses, enforcing food-drug separation rules, highlighting red-flag symptoms, and never fabricating dosing advice.
- **SDG 10 — Reduced Inequalities (Supporting):** Removes literacy and English-language barriers for underserved Urdu-speaking patients and elderly citizens through RTL Urdu typography, spoken audio, and shape/colour/letter pill identity badges (`0..9`).

---

## 3. Architecture: *"AI Perceives and Converses; Verified Rules Decide"*

```mermaid
flowchart TD
    subgraph Client["ShifaLens Flutter App (Android / Material 3)"]
        Photo["Prescription / Strip Photo (In-Memory Uint8List)"]
        VoiceIn["Patient Urdu/English Question (Text or Audio)"]
        ConfirmUI["User Confirmation & Pharmacist Flag Gate"]
        Engine["RealScheduleEngine (Pure Deterministic Dart)"]
        Know["RealKnowledgeService (Firestore + Offline JSON)"]
        PostVal["Code Post-Validator (Confidence >= 0.75 & Context Key Check)"]
        Notif["RealReminderService (flutter_local_notifications + FCM Token)"]
        Share["RealShareService (Email PDF + Urdu WAV / share_plus)"]
    end

    subgraph Gemini["Firebase AI Logic (gemini-2.5-flash)"]
        OCR["RealPrescriptionReader (JSON Schema, Temp 0.1)"]
        StripAI["RealStripMatcher (Label OCR & Strength Read)"]
        QAAI["RealQAService (Strictly Context-Grounded JSON)"]
    end

    subgraph Firebase["Firebase Backend (Anonymous Auth + Firestore)"]
        FSKnow["Read-Only Knowledge Collections\n(brands_generics, food_med, side_effects, plate_guide/main)"]
        FSUser["User Private Docs (users/{uid}/plans, ticks, devices/fcm)\nNo Photos, No PII"]
    end

    Photo -->|Resized max 1600px JPEG q80 in Isolate| OCR
    Photo -->|Up to 6 Strips| StripAI
    OCR --> PostVal
    StripAI --> PostVal
    Know <--> FSKnow
    PostVal -->|Brand -> Generic via KnowledgeService| Know
    PostVal --> ConfirmUI
    ConfirmUI -->|Confirmed Lines Only| Engine
    Know -->|Food Cards, Side Effects, Duplicate Alerts| Engine
    Engine -->|Anonymized DailyPlan & Ticks| FSUser
    Engine -->|Context Block Only| QAAI
    VoiceIn --> QAAI
    QAAI -->|Every source[] verified in validKeys| PostVal
    Engine --> Notif
    Engine --> Share
```

### Non-Negotiable Safety Invariants
1. **Zero AI Hallucination in Clinical Rules:** Gemini never invents generic mappings, dosing schedules, drug-food rules, or side effects. All brand-to-generic resolution, duplicate alerts, and schedules come from `RealKnowledgeService` and `RealScheduleEngine`.
2. **Nothing Unconfirmed Becomes a Schedule:** Any line with `confidence < 0.75`, illegible handwriting (`Tab. ????? 1+0+1`), ambiguous fuzzy brand match (Levenshtein distance `<= 2`), or unconfirmed status is placed in `DailyPlan.unscheduled`.
3. **Code-Level Q&A Grounding Check:** `RealQAService.postValidateResponse` verifies in Dart that every returned `source` key exists in the plan's `VALID_CONTEXT_KEYS`; otherwise it forces `grounded = false`, `escalateToPharmacist = true`, and substitutes `"Please ask your pharmacist or doctor."`
4. **Prompt-Injection Defense & Privacy:** All text inside photos is treated strictly as untrusted data. Prescription and strip photos live only in RAM (`Uint8List`) and are never uploaded to Firestore or Cloud Storage.

---

## 4. Tech Stack

- **Framework:** Flutter (Dart 3, Material 3, Android-first, RTL Urdu + English subtitles)
- **State & Routing:** `flutter_riverpod`, `go_router`
- **Google & Firebase Tech:** `firebase_core`, `firebase_auth` (Anonymous Auth), `cloud_firestore`, `firebase_messaging` (FCM), `firebase_ai` (`gemini-2.5-flash` via Firebase AI Logic)
- **Device & Media:** `flutter_local_notifications` + `timezone`, `flutter_tts`, `audioplayers`, `record`, `image_picker`, `image` (isolate compression), `pdf`, `printing`, `flutter_email_sender`, `share_plus`, `shared_preferences`

---

## 5. Setup & Running

### Standard App (Mock Mode by Default for Instant Offline Demo)
```bash
flutter pub get
flutter run
```

### Standalone AI Lab (Test Real Gemini Services Directly)
```bash
flutter run -t lib/debug/main_ailab.dart \
  --dart-define=FIREBASE_API_KEY=<YOUR_FIREBASE_API_KEY> \
  --dart-define=GEMINI_API_KEY=<YOUR_GEMINI_API_KEY>
```

### Seeding Curated Knowledge & Plate Illustration to Firestore
```bash
dart run tool/seed_firestore.dart --project=madlab-9b032 --token=<OAUTH_ACCESS_TOKEN>
```

### How to Send a Test FCM Push Notification for the Demo
1. **Honest Architecture Note:** Daily dose-time alarms are scheduled **locally on-device** using `flutter_local_notifications` (`zonedSchedule` with `Asia/Karachi` timezone and boot reschedule) so they work reliably offline without requiring paid Cloud Functions cron jobs.
2. **FCM Push Demo:** When `ReminderService.registerFcmToken()` runs, it registers the device's FCM token and stores it in Firestore at `users/{uid}/devices/fcm`.
3. To trigger a live push during the presentation:
   - Open **Firebase Console -> Messaging (Cloud Messaging) -> New campaign -> Notifications**.
   - Enter Title: `شفا لینز یاد دہانی / ShifaLens Reminder` and Text: `رات کے کھانے کے بعد آگمینٹن (625 mg) لینے کا وقت ہو گیا ہے۔`
   - Click **Send test message**, paste the token from `users/{uid}/devices/fcm` (or the AI Lab status log), and click **Test**.

---

## 6. AI Use & Disclosure

- **Runtime AI Model:** Google Gemini Flash (`gemini-2.5-flash` via `firebase_ai` / Firebase AI Logic) is used strictly for:
  1. Prescription OCR transcription (`RealPrescriptionReader`)
  2. Physical blister/box text reading (`RealStripMatcher`)
  3. Context-grounded bilingual patient Q&A (`RealQAService`)
  4. Optional REST TTS fallback (`RealVoiceService`)
- **Plate Guide Illustration:** The flat illustration of a balanced Pakistani plate (roti, daal, sabzi, salad) stored in `assets/data/plate_guide.json` and Firestore `plate_guide/main` (<300 KB base64 PNG) is programmatically/AI-generated and disclosed as such in the app.
- **Development Disclosure:** AI coding assistants were used during the hackathon to scaffold boilerplate and draft initial conservative JSON entries in `assets/data/*.json`. Every curated record is marked `"reviewed": false` until reviewed by a licensed pharmacist.

---

## 7. Honest Limitations

1. **Prototype Only — Not a Medical Device:** ShifaLens does not diagnose conditions, alter doses, recommend stopping medicines, or prescribe diets/calorie targets.
2. **Synthetic Data Only:** All demo prescriptions (`Rx1`, `Rx2`, `Rx3`) are synthetic invented cases.
3. **Curated Tables Pending Pharmacist Review:** All records in `brands_generics.json`, `food_med.json`, `side_effects.json`, and `plate_guide.json` default to `"reviewed": false` so the UI displays *"Pending pharmacist review"*.
4. **Handwriting OCR Uncertainty:** Cursive doctor handwriting can be misread; our threshold (`<0.75`) errs on the side of caution by refusing to schedule uncertain lines.
5. **Urdu TTS Quality:** Android device Urdu TTS (`ur-PK`) pronunciation of English brand names varies by device OEM; documented in `docs/eval.md`.
6. **Local Alarms vs. Server Push:** Dose-time reminders are local device notifications; FCM is included for token registration and console-triggered caregiver demo pushes.
