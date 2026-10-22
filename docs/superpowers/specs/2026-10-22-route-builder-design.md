# Route Builder — iOS client design

Date: 2026-10-22
Status: design approved in chat (architecture, Stops, Instructions+send, delivery). Waiting for written-spec review before the implementation plan.

## Partner decisions (brainstorming)

| Topic | Choice |
|---|---|
| Optional features | **C** — nearly the full optional list (photos, focus, swipe, A–Z index, notify, manual address, camera, API unit tests) |
| Demo video | **C** — no recording in this pass; README/`DECISIONS.md` explain how to record later |
| Extra beyond the brief | **A** — Undo (5s) after swipe-remove |
| Git delivery | Private GitHub repo named `route-builder` |
| Architecture | SwiftUI app + local package `RouteBuilderKit` |

## Goal

A portrait iPhone app for a depot dispatcher who builds one driver's morning route while standing at a counter, one hand, in a hurry. Two screens only: Stops, then Instructions. English, left to right. The app talks to the provided mock (`node server.js`, default `http://localhost:4000`). No backend changes, no login, no onboarding, no settings, no post-send product surface beyond driver notify and a success state on the same screen.

## Approach

Native SwiftUI on the existing Xcode project (iOS 27, iPhone only, portrait only). The network and route rules live in a local Swift package, `RouteBuilderKit`, so the API layer has unit tests that do not need a simulator. The app is a thin client of that package.

Rejected:

- React Native or Flutter. The brief is iOS-only, and an Xcode project is already here.
- All API code inside the app target only. Harder to unit-test against the mock's chaos without a simulator.
- Decoding with a strict `Codable` model that matches `API.md`. The mock deliberately disagrees with the document. A lenient JSON parser is the client.

## Service is the source of truth

Where the reference and the mock disagree, the client follows the mock.

| Topic | Document / mockup | Service | Client |
|---|---|---|---|
| Instruction length | 250 characters | `slice(0, 200)` | Field and counter stop at 200 |
| `packages` of 0 | not specified | `Number(x) \|\| 1` | Send at least 1 |
| `packages_max` | integer | number, numeric string, or null | Parse all three. Null uses a local cap of 9 |
| `last_delivery_at` | ISO-8601 | ISO with Z, ISO without Z, or unix seconds | Accept all three |
| Empty search | not specified | `items: null` | Treat as an empty list, not a crash |
| Page 2 | normal paging | repeats the last row of page 1 | Dedupe by `id`, keep first occurrence |
| `total` | true count | `rows.length + 1` | Ignore `total` |
| `has_more` | true until the last page | stays true on a short last page | Stop on an empty page or a page that adds no new ids. Cap at 20 pages |
| List errors | not specified | every 9th call is 500, every 14th is 503 + `Retry-After: 2` | Retry 500, 503, and 429 up to 3 extra times, honoring `Retry-After` |
| Photos | shown on the card | 3.5s+, `url` sometimes null, 0–3 items | Load off the critical path. Skip null URLs. Hide the row if there is nothing to show |
| Notify | 200 means sent | 200 with `status: "failed"` on the first try for every third stop. The same `Idempotency-Key` replays that failure | One request per stop. On `failed` or a transport error, retry once with a new key |
| Search | name, address, phone | `String.includes`, case-sensitive. Phone matches only when the query has 3+ digits | Send `q` exactly as typed |

A failed reload never clears stops, quantities, or instructions the dispatcher already entered. The draft is written to Application Support so a crash or a 500 does not throw the morning away.

## Screens

Visual source: the seven frames in the screens file. Phone width 390. Colors: canvas `#EEF1F3` (Stops) and `#CBD7DD` (Instructions), ink `#16232E`, teal `#0D6E76`, muted `#6B7C8A`, line `#DFE5E9`, disabled button `#D6DEE2` / `#93A3AC`, missing-instruction amber `#B4762A` / `#8A5A1E`, remove-swipe `#33454F`. Quantities use a monospaced face. SF Pro stands in for the mock's Heebo; the Latin metrics are the system font on iPhone.

### Stops

- Title "Morning route — Central area". Subtitle is computed: with nothing selected, "`N` stops in the book"; with a selection, "`P` packages | `N` stops". The mock's "38 packages | 14 stops" is sample copy, not a constant.
- Tabs: Stops and Instructions. Instructions is inactive until at least one stop is selected. Stops from the second screen returns without discarding the draft.
- Mode switch: "One stop / Single delivery" and "Multi-stop route / Several stops", with the yellow "New" badge on multi. One stop is the default. Switching to one stop keeps the earliest selection and drops the rest.
- Search field placeholder "Search by name, street, or phone". Empty query shows the directory. A non-empty query calls `GET /v1/stops?q=` after a short debounce. No matches: "No stop found" and "Try another street or enter an address manually", plus manual entry.
- Directory load uses `page_size=50`, walks pages, dedupes, sorts by name, and sections by the first letter. A leading non-letter ("24/7 Pharmacy") goes under "#". The A–Z index (plus "#" when needed) scrolls to that section. Letters with no section are dim.
- Row: checkbox, initials tile, name, address, phone. Selected rows fill the whole row (`#E3F0F1`) and the checkbox in teal. The trailing slot shows the phone when the row is not selected and the `N×` pill (white fill, teal border) when it is selected; the phone is never stacked under the address. The pill opens the quantity popover anchored to the pill.
- Initials: drop a leading The/A/An and bare "&" / dashes. Two or three words: first letter of the first word and of the last, unless the second word is only digits ("Pilates 9 Studio" → P9, "Sova Studio Gallery" → SG, "The Little Zoo" → LZ). Four or more words: first two words ("Roma Pizza — …" → RP). "24/7 Pharmacy" → 2P.
- Tapping a row selects it. One-stop replaces the previous selection. Multi toggles. Default quantity is 1. The pill opens a popover: minus, value, plus, Save. Limits are 1…`packages_max`, or 1…9 when the max is missing. Dismissing without Save keeps the old value.
- Chips for the selection sit above Continue. The chip removes that stop. Continue reads "Continue (N stops)" and is disabled at zero.

Manual address (from the empty search state): name, address, phone. Address is required. The stop id is `local_` plus a UUID. It is selected immediately, stored only on the device, and is not sent to the photo endpoint.

### Instructions

One card per selected stop, in selection order. The card shows name, `N×`, address, last-delivery photos, the instruction field, a counter `n/200`, Clear all, and "Photo of the drop-off point". Footer line: "Instructions save automatically and go to the driver when you finish".

The card nearest the vertical center is fully opaque and full size. Others scale toward `(0.80, 0.94)`, fade to 0.65, and blur up to 3pt, matching the depth frame.

Finish is refused while any instruction is empty or whitespace. The first such card gets the amber border, the "!" mark, and "Add instructions for this stop before finishing", and the feed scrolls to it. Typing clears that card's error.

Swipe reveals "Remove from route" on `#33454F`. A removed card can be undone for a few seconds (extra, see below). Removing the last stop returns to Stops.

The camera row stores a JPEG under Application Support. It is never uploaded. If the camera is unavailable (simulator), the photo library is the fallback so the control still does something.

### Send

`POST /v1/routes` with `{ stop_id, packages, instructions }`. The button switches to a sending state and ignores further taps. `RouteGateway` also coalesces concurrent submits onto one task, so a double tap cannot create two routes. Failure leaves the draft intact and shows the error with a retry. Success shows the route id on the same screen.

Then `POST /v1/routes/{id}/notify` once per stop. A `status: "failed"` body, or a thrown error, is retried once with a new idempotency key. Notify does not undo a created route. Per-stop results are listed under the success state. "Start another route" clears the draft; that is the only post-send control, so the dispatcher is not stuck.

## Data that must survive

`RouteDraft` (mode, ordered stops, quantities, instructions, local photo path) is saved on every edit. Relaunch restores it. Photo files outlive a failed POST.

## Something extra

Undo after a swipe-delete. The dispatcher is one-handed and rushed; a destructive swipe is the easiest mistake on this screen. The undo token keeps the stop, its instruction text, its quantity, and its on-device photo for five seconds.

## Out of scope

Anything after a successful send besides notify and the success state. Auth, onboarding, settings, iPad, landscape, and a third screen.

## Tests

`RouteBuilderKit` unit tests cover lenient decoding, null search items, page overlap, a lying `has_more`, retries, instruction clamping, package minimum, single-flight submit, and notify retry with a fresh idempotency key. They use stubs, not the live process-global failure counter, so they stay deterministic.

## Base URL

`APIBaseURL` in the app Info.plist, default `http://localhost:4000`. Override at launch with the environment variable `ROUTE_API_BASE_URL`. Debug ATS allows local and arbitrary HTTP so the simulator (`localhost`) and a phone on the same Wi-Fi (LAN IP) can both reach the mock.

## Delivery

- Layered git history on `feature/route-builder`, then private GitHub repo `route-builder`.
- `README.md` with exact mock launch steps and where the base URL is set.
- `DECISIONS.md` and `AI_PROCESS.md`, each ≤ one page. Note that the screen recording is deferred and how to produce it.
- Superpowers artifacts: this spec, `docs/superpowers/plans/*.md`, and a copy of the SDD ledger into `docs/ai/` before finishing the branch (choose "keep the branch" at the end).
