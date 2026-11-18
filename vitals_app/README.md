# VitalWatch

Patient-facing Flutter UI for long-term wearable wellness insights. This build uses **mock data only** — no Health Connect, networking, or backend yet.

## Run

```bash
flutter pub get
flutter run
```

Pick your Android phone in the device picker. In Cursor/VS Code, use the **vitals** launch config (Dart/Flutter), not Chrome localhost.

Demo shortcut on Sign in: **Enter demo mode** skips onboarding and opens Home.

## Demo script (Rahul persona)

1. Complete or skip onboarding → Home
2. Open an amber/red flag → read the plain-language statement and chart
3. Toggle a symptom → see priority raised
4. Open Alerts → Advise checkup card
5. Request doctor review (simulated) from flag detail
6. Habits → tick micro-goals / try breathing
7. Settings → Demo tools → switch to Meera for the green story

## Layout

- `lib/core/` — theme, shared widgets, adaptive shell, router
- `lib/domain/` — models + abstract repositories
- `lib/data/mock/` — generator, flag engine, mock repos
- `lib/features/` — screens by feature
- `lib/providers/` — Riverpod wiring
- `assets/rules/rules.json` — flag rules as data

## Next: Health Connect + backend

Replace the `Mock*` classes behind the repository interfaces in `lib/domain/repositories/` (each marked `// Later: backed by Health Connect + FastAPI.`). Screens only talk to Riverpod providers, so UI should not need rewrites.

## Tests

```bash
flutter analyze
flutter test
```
