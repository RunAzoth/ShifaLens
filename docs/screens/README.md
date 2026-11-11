# ShifaLens — Presentation Screen Set (`docs/screens`)

 Tagline: *"A pharmacist's explanation for every patient, in Urdu, with pictures."*

1. **[01_home_bilingual.svg](01_home_bilingual.svg)** — Warm clinic Home screen with Bilingual (`Urdu + English`) toggle, `64dp` Hero Camera action, Synthetic Demo Prescriptions (`Rx1` / `Rx2` / `Rx3`), and `"Prototype. Not a medical device."` safety banner.
2. **[02_review_confirm_flagged.svg](02_review_confirm_flagged.svg)** — Review & Confirm screen with pinned zoomable prescription thumbnail, always-visible `AiTag`, per-field `ConfidenceChip`s, amber `"Ask your pharmacist"` card (`Tab. ????? 1+0+1`) with 3 one-tap actions (`Fix it`, `Keep as "ask pharmacist"`, `Remove`), and Confirm button locked until resolved.
3. **[03_today_timeline_day_arc.svg](03_today_timeline_day_arc.svg)** — Today Timeline ("day arc" shifting from sunrise saffron to night indigo), sticky `"🔊 Listen to my plan"` voice bar, Ramadan toggle, `"Not scheduled: ask your pharmacist"` section, and interactive `DoseCard`s with `PillBadge` + `SlotIcon`.
4. **[04_medicines_food_safety.svg](04_medicines_food_safety.svg)** — Medicine Detail sheet with big food-medicine pictogram cards, `"Pending pharmacist review"` (`ReviewBadge`), calm `"Common effects"`, and red-tinted `"Call your doctor if..."` emergency warnings.
5. **[05_strip_matching_stickers.svg](05_strip_matching_stickers.svg)** — Physical Medicine Strip Matching results (`Matched` with `PillBadge`, `Strength mismatch`, `Not in this prescription`, missing strip list) and `"Make stickers"` (`PNG-to-PDF` die-cut sticker sheet).
6. **[06_ask_grounded_urdu_qa.svg](06_ask_grounded_urdu_qa.svg)** — Grounded Urdu Q&A chat with picture suggestion chips, hold-to-talk microphone, `AiTag`, Urdu audio playback, and distinct `"Ask your pharmacist"` escalation card when `escalateToPharmacist == true`.
