# Route Builder iOS Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a portrait iPhone client that loads the mock address book, builds a one- or multi-stop route, requires an instruction per stop, and posts it once.

**Architecture:** `RouteBuilderKit` (Swift package, Foundation only) owns decoding, paging, retries, submit single-flight, and notify retry. The SwiftUI app in `Route Builder/` renders the two screens and persists the draft. The mock in `mock/server.js` is the unmodified service.

**Tech Stack:** Swift 5, SwiftUI, iOS 27, XCTest via `swift test`, Xcode 27.

## Global Constraints

- iPhone only, portrait only, English, LTR.
- Client only. Do not change mock behavior. Copy `server.js` into `mock/` unmodified.
- Base URL: Info.plist `APIBaseURL`, default `http://localhost:4000`, override `ROUTE_API_BASE_URL`.
- Instruction cap is 200 (service), not 250 (doc and mockup).
- Package count sent to the server is at least 1 and at most `packages_max`, or 9 when `packages_max` is null.
- Dedupe stops by `id`. Never wipe a loaded directory or a draft because a later request failed.
- Double-tap on Finish must not POST twice.
- Notify retries a `failed` status with a new `Idempotency-Key`.
- Empty or whitespace instructions block Finish and mark that card.
- Photos and the camera shot stay off the POST body. Camera JPEGs stay on device.
- UI copy and colors come from the screens file (see the design spec).

---

### Task 1: Kit models, lenient parsing, initials

**Files:**
- Create: `RouteBuilderKit/Package.swift`
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/Models.swift`
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/Parsing.swift`
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/Initials.swift`
- Test: `RouteBuilderKit/Tests/RouteBuilderKitTests/ParsingTests.swift`

**Interfaces:**
- Produces: `Stop`, `StopPage`, `DeliveryPhoto`, `RouteStopPayload.normalized()`, `CreatedRoute`, `NotifyResult`, `APIError`, `StopPageParser.page(from:)`, `PhotoParser.photos(from:)`, `Initials.make(from:)`, `Initials.sectionLetter(name:)`, `InstructionRules.maxCharacters` (200), `InstructionRules.isEmpty(_:)`, `PackageCount.clamp(_:max:)`

- [ ] Write failing tests for string/number/null `packages_max`, three date shapes, null `items`, a bad row skipped beside a good row, null photo URLs dropped, initials (SG, P9, LZ, RP, 2P), clamp, and the 200-character cap.
- [ ] Run `swift test` and confirm the tests fail to compile.
- [ ] Implement the parsers and rules.
- [ ] Run `swift test` and confirm they pass.
- [ ] Commit.

### Task 2: HTTP client, directory merge, single-flight submit

**Files:**
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/APIClient.swift`
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/DirectoryLoader.swift`
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/RouteGateway.swift`
- Test: `RouteBuilderKit/Tests/RouteBuilderKitTests/ClientTests.swift`

**Interfaces:**
- Consumes: Task 1 types.
- Produces: `protocol Dispatching`, `APIClient`, `DirectoryLoader.load(pageSize:query:)`, `PageMerge.merge(existing:page:)`, `actor RouteGateway` with `submit(_:)` and `notifyDriver(routeID:stopIDs:)`.

- [ ] Write failing tests: 500 then 200 retries once; 400 does not retry; overlapping page 2 dedupes; `has_more: true` plus an empty next page stops; concurrent `submit` performs one POST; notify failure retries with a different idempotency key; request body clamps instructions to 200 and packages to at least 1.
- [ ] Run the new tests and confirm failure.
- [ ] Implement.
- [ ] Run `swift test` and confirm the suite passes.
- [ ] Commit.

### Task 3: App shell, Stops, Instructions, send

**Files:**
- Modify: `Route Builder.xcodeproj/project.pbxproj` (link the package, iPhone, portrait, ATS)
- Create: `Route Builder/Info.plist`
- Create: `Route Builder/Theme.swift`
- Create: `Route Builder/APIConfig.swift`
- Create: `Route Builder/DraftStore.swift`
- Create: `Route Builder/DispatcherModel.swift`
- Create: `Route Builder/StopsScreen.swift`
- Create: `Route Builder/InstructionsScreen.swift`
- Create: `Route Builder/QuantityPopover.swift`
- Create: `Route Builder/ManualStopSheet.swift`
- Create: `Route Builder/CameraCapture.swift`
- Modify: `Route Builder/ContentView.swift`
- Modify: `Route Builder/Route_BuilderApp.swift`
- Create: `mock/server.js` (unmodified copy)
- Create: `Route Builder.xcodeproj/xcshareddata/xcschemes/Route Builder.xcscheme`

**Interfaces:**
- Consumes: `APIClient`, `DirectoryLoader`, `RouteGateway`, `RouteDraft` persistence via `DraftStore`.

- [ ] Link `RouteBuilderKit`. Restrict the target to iPhone portrait. Allow cleartext HTTP for the mock. Set `APIBaseURL`.
- [ ] Build the two screens to the design spec, including search, sections, index, chips, quantity popover, manual address, depth-scroll focus, swipe remove with undo, photo strip, camera capture, and send/error/success.
- [ ] `xcodebuild` the scheme for a simulator and fix compile errors.
- [ ] Commit.

### Task 4: Submission docs

**Files:**
- Create: `README.md`
- Create: `DECISIONS.md` (one page)
- Create: `AI_PROCESS.md` (one page)
- Create: `docs/ai/progress.md` (ledger copy)

- [ ] Document launch steps and the base URL location.
- [ ] Commit.

## Self-review

- Spec and plan agree on the 200-character cap, the null `packages_max` cap of 9, dedupe, and single-flight submit.
- No TBD placeholders.
- UI tasks are one deliverable: a buildable two-screen client. Splitting each SwiftUI file into its own task would not be independently reviewable without the model.
