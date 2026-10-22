# Route Builder

iOS client for a fictional courier depot. A dispatcher builds a morning route: pick stops, set package counts, write driver instructions, then POST the route to the mock API.

English UI, portrait iPhone only. Backend is the included mock — do not change its behavior.

## Requirements

- Xcode 27+ (iOS 27 SDK)
- Node 18+ (for the mock only)

## Run the mock API

```bash
cd mock
node server.js          # http://localhost:4000
node server.js 5001     # optional custom port
```

Health check: `GET http://localhost:4000/health` → `{"ok":true,"requests":N}`.

## Run the app

1. Start the mock (above).
2. Open `Route Builder.xcodeproj` in Xcode.
3. Select an **iPhone** simulator (portrait).
4. Run (⌘R).

### Where the base URL is set

| Priority | Source |
|---|---|
| 1 | Environment variable `ROUTE_API_BASE_URL` |
| 2 | Info.plist key `APIBaseURL` in `Route Builder/Info.plist` |
| 3 | Fallback `http://localhost:4000` |

Defaults:

- **iOS Simulator:** `http://localhost:4000` (works as-is).
- **Physical iPhone:** same Wi‑Fi as your Mac; set `APIBaseURL` to your Mac’s LAN IP, e.g. `http://192.168.1.12:4000`. Debug builds allow cleartext HTTP (`NSAllowsArbitraryLoads` / local networking).

Xcode scheme → Run → Arguments → Environment Variables is a convenient place to set `ROUTE_API_BASE_URL` without editing the plist.

## Tests

```bash
cd RouteBuilderKit
swift test
```

Covers lenient JSON decoding, paging/dedupe, retries, single-flight submit, and notify idempotency-key retry.

## Project layout

- `Route Builder/` — SwiftUI app (Stops + Instructions)
- `RouteBuilderKit/` — networking and route rules (unit-tested)
- `mock/` — unmodified mock server + `API.md`
- `docs/superpowers/` — design spec and implementation plan
- `docs/ai/progress.md` — Superpowers SDD ledger copy

## GitHub (private)

Intended remote: private repo named `route-builder`.

```bash
gh auth login
gh repo create route-builder --private --source=. --remote=origin --push
```

If the name is taken: `route-builder-ios`. Then grant the reviewer access.

## Demo video (deferred)

Record a 60–90s single-take screen recording on a device (or simulator — note that in `DECISIONS.md`): select stops → set quantities → write instructions → swipe-remove one stop → finish. Use QuickTime (device) or Simulator → File → Record Screen.
