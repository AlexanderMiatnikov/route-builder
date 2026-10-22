# Route Builder iOS Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a portrait iPhone client that loads the mock address book, builds a one- or multi-stop route with instructions, posts it once, notifies the driver, and survives the mock's deliberate chaos.

**Architecture:** `RouteBuilderKit` (Swift package, Foundation only) owns lenient JSON, paging+dedupe, retries, single-flight submit, and notify retry. The SwiftUI app in `Route Builder/` owns the two screens, draft persistence, and camera. `mock/server.js` is an unmodified copy of the provided service.

**Tech Stack:** Swift 5, SwiftUI, iOS 27, XCTest via `swift test`, Xcode 27, Node 18+ for the mock.

## Global Constraints

- iPhone only, portrait only, English, LTR.
- Client only. Do not change mock behavior. Copy `/Users/user/Downloads/server.js` into `mock/server.js` unmodified.
- Base URL: Info.plist `APIBaseURL` default `http://localhost:4000`; override env `ROUTE_API_BASE_URL`.
- Instruction cap is **200** (service), not 250.
- Packages sent: at least 1, at most `packages_max`, or **9** when `packages_max` is null.
- Dedupe stops by `id`. Never wipe directory or draft on a later request failure.
- Double-tap Finish must not POST twice (`RouteGateway` single-flight).
- Notify: on `status: "failed"` or transport error, retry once with a **new** `Idempotency-Key`.
- Empty/whitespace instructions block Finish; show amber error on that card.
- Photos + camera JPEG never go in the POST body.
- Optional scope **C** + undo-after-swipe; no demo video in this pass (document how to record).
- UI colors/copy from the design spec / screens HTML.
- Private GitHub repo `route-builder` at the end (Task 5).
- If untracked `RouteBuilderKit/` sources exist without a green test suite, **delete them** and rebuild via TDD. Do not "adapt" pre-written code.

## File map

| Path | Responsibility |
|---|---|
| `RouteBuilderKit/` | Models, parsers, HTTP, directory merge, gateway |
| `Route Builder/*.swift` | Theme, config, draft store, view model, two screens |
| `mock/server.js` | Unmodified mock API |
| `docs/superpowers/*` | Spec + this plan |
| `docs/ai/progress.md` | Copy of SDD ledger before finish |
| `README.md`, `DECISIONS.md`, `AI_PROCESS.md` | Handoff |

---

### Task 1: Kit models + lenient parsing + initials (TDD)

**Files:**
- Create: `RouteBuilderKit/Package.swift`
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/Models.swift`
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/Parsing.swift`
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/Initials.swift`
- Test: `RouteBuilderKit/Tests/RouteBuilderKitTests/ParsingTests.swift`

**Interfaces:**
- Produces: `Stop`, `StopPage`, `DeliveryPhoto`, `RouteStopPayload`, `CreatedRoute`, `NotifyResult`, `RouteDraft`, `DraftStop`, `APIError`, `InstructionRules.maxCharacters` (=200), `InstructionRules.isEmpty(_:)`, `PackageCount.clamp(_:max:)`, `StopPageParser.page(from:)`, `PhotoParser.photos(from:)`, `Initials.make(from:)`, `Initials.sectionLetter(name:)`, `StopGrouping.sections(_:)`

- [ ] **Step 1: Remove any untracked kit sketch**

```bash
rm -rf RouteBuilderKit
```

- [ ] **Step 2: Scaffold the package**

`Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RouteBuilderKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RouteBuilderKit", targets: ["RouteBuilderKit"])],
    targets: [
        .target(name: "RouteBuilderKit"),
        .testTarget(name: "RouteBuilderKitTests", dependencies: ["RouteBuilderKit"])
    ],
    swiftLanguageModes: [.v5]
)
```

- [ ] **Step 3: Write failing tests** in `ParsingTests.swift` covering at least:

```swift
import XCTest
@testable import RouteBuilderKit

final class ParsingTests: XCTestCase {
    func testPackagesMax_number_string_null() throws {
        let data = """
        {"items":[
          {"id":"a","name":"A","address":"1","phone":"1","packages_max":5},
          {"id":"b","name":"B","address":"1","phone":"1","packages_max":"7"},
          {"id":"c","name":"C","address":"1","phone":"1","packages_max":null}
        ],"page":1,"page_size":10,"has_more":false}
        """.data(using: .utf8)!
        let page = try StopPageParser.page(from: data)
        XCTAssertEqual(page.items[0].packagesMax, 5)
        XCTAssertEqual(page.items[1].packagesMax, 7)
        XCTAssertNil(page.items[2].packagesMax)
    }

    func testNullItemsIsEmptyList() throws {
        let data = #"{"items":null,"page":1,"page_size":10,"has_more":false}"#.data(using: .utf8)!
        XCTAssertEqual(try StopPageParser.page(from: data).items, [])
    }

    func testSkipsMalformedRow() throws {
        let data = """
        {"items":[null,{"id":"ok","name":"Ok","address":"x","phone":"y"}],
         "page":1,"page_size":10,"has_more":false}
        """.data(using: .utf8)!
        XCTAssertEqual(try StopPageParser.page(from: data).items.map(\.id), ["ok"])
    }

    func testDates_isoZ_isoNoZ_unix() throws {
        // three last_delivery_at shapes → non-nil Date
    }

    func testPhotoNullUrlDropped() throws {
        let data = """
        {"items":[
          {"id":"p0","url":"https://example.com/a.jpg","tag":"entrance"},
          {"id":"p1","url":null,"tag":"parking"}
        ]}
        """.data(using: .utf8)!
        XCTAssertEqual(try PhotoParser.photos(from: data).map(\.id), ["p0"])
    }

    func testInitials() {
        XCTAssertEqual(Initials.make(from: "Sova Studio Gallery"), "SG")
        XCTAssertEqual(Initials.make(from: "Pilates 9 Studio"), "P9")
        XCTAssertEqual(Initials.make(from: "The Little Zoo"), "LZ")
        XCTAssertEqual(Initials.make(from: "Roma Pizza — Central Bus Station branch"), "RP")
        XCTAssertEqual(Initials.make(from: "24/7 Pharmacy"), "2P")
        XCTAssertEqual(Initials.sectionLetter(name: "24/7 Pharmacy"), "#")
    }

    func testClampAndInstructionCap() {
        XCTAssertEqual(PackageCount.clamp(0, max: 5), 1)
        XCTAssertEqual(PackageCount.clamp(99, max: nil), 9)
        XCTAssertEqual(InstructionRules.maxCharacters, 200)
        XCTAssertTrue(InstructionRules.isEmpty("  \n"))
        let long = String(repeating: "a", count: 250)
        XCTAssertEqual(RouteStopPayload(stopID: "x", packages: 0, instructions: long).normalized().instructions.count, 200)
        XCTAssertEqual(RouteStopPayload(stopID: "x", packages: 0, instructions: "hi").normalized().packages, 1)
    }
}
```

- [ ] **Step 4: Run tests — expect compile/link failure**

```bash
cd RouteBuilderKit && swift test
```

Expected: FAIL (types missing).

- [ ] **Step 5: Implement** `Models.swift`, `Parsing.swift`, `Initials.swift` so the tests pass. Lenient parsing via `JSONSerialization`, not strict `Codable` for inbound list payloads.

- [ ] **Step 6: Run tests — expect PASS**

```bash
cd RouteBuilderKit && swift test
```

- [ ] **Step 7: Commit**

```bash
git add RouteBuilderKit
git commit -m "Add RouteBuilderKit parsers and initials with unit tests"
```

---

### Task 2: HTTP client, directory merge, RouteGateway (TDD)

**Files:**
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/APIClient.swift`
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/DirectoryLoader.swift`
- Create: `RouteBuilderKit/Sources/RouteBuilderKit/RouteGateway.swift`
- Create: `RouteBuilderKit/Tests/RouteBuilderKitTests/StubDispatch.swift`
- Test: `RouteBuilderKit/Tests/RouteBuilderKitTests/ClientTests.swift`

**Interfaces:**
- Consumes: Task 1 types.
- Produces:
  - `protocol Dispatching: Sendable` with `fetchStops(page:pageSize:query:)`, `fetchPhotos(stopID:)`, `createRoute(stops:)`, `notify(routeID:stopID:idempotencyKey:)`
  - `APIClient` conforming to `Dispatching` (retries 429/500/503 ≤3 extras, honors `Retry-After`)
  - `PageMerge.merge(existing:page:) -> (items: [Stop], added: Int)`
  - `DirectoryLoader.load(pageSize:query:) async throws -> [Stop]`
  - `actor RouteGateway` with `submit(_:) async throws -> CreatedRoute` and `notifyDriver(routeID:stopIDs:) async -> [NotifyResult]`

- [ ] **Step 1: Write failing tests** using an in-memory stub that records call counts and returns scripted failures/pages. Cover:
  - Retry once after 500 then succeed; **do not** retry 400.
  - Page 2 overlapping id deduped; `has_more: true` + empty next page stops.
  - Two concurrent `submit` calls → exactly one `createRoute`.
  - Notify returns `failed` → second call uses a **different** idempotency key.
  - Body after normalize: packages ≥ 1, instructions ≤ 200.

- [ ] **Step 2: `swift test` — FAIL**

- [ ] **Step 3: Implement** client, merge, loader, gateway.

`RouteGateway.submit` sketch:

```swift
public actor RouteGateway {
    private let api: any Dispatching
    private var inFlight: Task<CreatedRoute, Error>?

    public func submit(_ stops: [RouteStopPayload]) async throws -> CreatedRoute {
        if let inFlight { return try await inFlight.value }
        let task = Task { try await api.createRoute(stops: stops.map { $0.normalized() }) }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}
```

Notify: for each stop, call once; if `!sent`, call again with `UUID().uuidString` as a new key.

- [ ] **Step 4: `swift test` — PASS**

- [ ] **Step 5: Commit**

```bash
git add RouteBuilderKit
git commit -m "Add resilient API client, directory merge, and single-flight gateway"
```

---

### Task 3: App shell — package link, ATS, theme, draft, model

**Files:**
- Modify: `Route Builder.xcodeproj/project.pbxproj` (local package ref, `TARGETED_DEVICE_FAMILY=1`, portrait-only orientations, `INFOPLIST_FILE`)
- Create: `Route Builder/Info.plist` (`APIBaseURL`, `NSAppTransportSecurity` allowing local networking / arbitrary loads for debug HTTP, camera/photo usage strings)
- Create: `Route Builder/Theme.swift` (colors from spec)
- Create: `Route Builder/APIConfig.swift` (`baseURL` from env then plist then localhost)
- Create: `Route Builder/DraftStore.swift` (Codable to Application Support)
- Create: `Route Builder/DispatcherModel.swift` (`@Observable` / `@MainActor` state machine)
- Create: `mock/server.js` (copy from Downloads, unmodified)
- Create: `Route Builder.xcodeproj/xcshareddata/xcschemes/Route Builder.xcscheme`
- Modify: `Route Builder/Route_BuilderApp.swift`, `ContentView.swift` (wire model; screens can be stubs)

**Interfaces:**
- Consumes: `APIClient`, `DirectoryLoader`, `RouteGateway`, `RouteDraft`.
- Produces: `DispatcherModel` with selection mode, stops list, search, draft, load/search/submit/notify methods.

- [ ] **Step 1: Copy mock**

```bash
mkdir -p mock
cp "/Users/user/Downloads/server.js" mock/server.js
cp "/Users/user/Downloads/API.md" mock/API.md
```

- [ ] **Step 2: Link package + Info.plist + iPhone/portrait.** Verify:

```bash
xcodebuild -project "Route Builder.xcodeproj" -scheme "Route Builder" -destination 'platform=iOS Simulator,name=iPhone 17' build
```

(Use whatever iPhone simulator is installed; adjust name via `xcrun simctl list devices available`.)

- [ ] **Step 3: Implement `DraftStore` + `DispatcherModel`** that loads directory, merges search, persists draft on change, and never clears draft on load error.

- [ ] **Step 4: Build succeeds; commit**

```bash
git add "Route Builder" "Route Builder.xcodeproj" mock
git commit -m "Wire RouteBuilderKit into the app shell with draft persistence"
```

---

### Task 4: Stops screen UI

**Files:**
- Create: `Route Builder/StopsScreen.swift`
- Create: `Route Builder/QuantityPopover.swift`
- Create: `Route Builder/ManualStopSheet.swift`
- Create: `Route Builder/AlphabetIndex.swift`
- Modify: `ContentView.swift` / `DispatcherModel.swift` as needed

- [ ] **Step 1: Implement Stops** to match the design spec: header, tabs, One/Multi switch, search, sectioned list, A–Z index, quantity popover, chips, Continue, empty-search + manual address.

- [ ] **Step 2: Build for simulator. Smoke: launch with `node mock/server.js`, load list, select two stops, set quantity, Continue enabled.**

- [ ] **Step 3: Commit**

```bash
git commit -am "Build Stops picker with search, sections, chips, and quantity"
```

---

### Task 5: Instructions screen + send + extras

**Files:**
- Create: `Route Builder/InstructionsScreen.swift`
- Create: `Route Builder/CameraCapture.swift`
- Create: `Route Builder/PhotoStrip.swift`
- Modify: `DispatcherModel.swift`

- [ ] **Step 1: Implement Instructions** — depth focus (scale + opacity + optional blur), instruction field 200 chars, Clear all, amber empty-instruction error, swipe remove + **5s Undo**, last-delivery photos (skip null URLs), on-device camera/library capture, Finish → single-flight submit → notify → success/error UI.

- [ ] **Step 2: Build. Smoke full flow against mock: select → instruct → remove one → finish.**

- [ ] **Step 3: Commit**

```bash
git commit -am "Build Instructions feed with focus, swipe undo, photos, and send"
```

---

### Task 6: Handoff docs + GitHub private repo

**Files:**
- Create: `README.md`
- Create: `DECISIONS.md` (≤1 page)
- Create: `AI_PROCESS.md` (≤1 page)
- Create: `docs/ai/progress.md` (copy from `.superpowers/sdd/<plan>/progress.md` when SDD finishes; if no ledger yet, write a short hand-authored ledger of tasks)

- [ ] **Step 1: Write README** with exact steps:

```bash
node mock/server.js          # http://localhost:4000
# open Route Builder.xcodeproj, run on iPhone simulator
# base URL: Route Builder/Info.plist key APIBaseURL
# override: ROUTE_API_BASE_URL
# physical device: set APIBaseURL to your Mac's LAN IP
```

Also how to record the 60–90s demo later (deferred).

- [ ] **Step 2: Write DECISIONS.md and AI_PROCESS.md** (≤1 page each).

- [ ] **Step 3: Commit docs**

```bash
git add README.md DECISIONS.md AI_PROCESS.md docs/ai
git commit -m "Add handoff docs for mock launch and AI process"
```

- [ ] **Step 4: Create private GitHub repo and push**

```bash
gh repo create route-builder --private --source=. --remote=origin --push
```

If the name is taken: `route-builder-ios`. Report the URL.

- [ ] **Step 5: Finish branch** via `finishing-a-development-branch`; when prompted, choose **keep the branch** ("оставить ветку"). Copy progress ledger to `docs/ai/` **before** any ledger cleanup.

---

## Spec coverage self-review

| Spec requirement | Task |
|---|---|
| Lenient decode / null items / date shapes | 1 |
| Initials + `#` section | 1 |
| Retry / dedupe / has_more lie | 2 |
| Single-flight POST + notify new key | 2 |
| Base URL + ATS + draft persistence | 3 |
| Stops picker + search + manual + index + chips | 4 |
| Instructions focus / swipe undo / photos / camera / send | 5 |
| README / DECISIONS / AI_PROCESS / private GitHub / keep branch | 6 |
| Instruction 200 / packages clamp | 1+2+5 |
| No demo video this pass | 6 (documented) |

No TBD placeholders. Types align across tasks (`Dispatching`, `RouteGateway.submit`, `InstructionRules.maxCharacters`).
