# Decisions

Hard limit: one page.

## Ambiguous / contradictory — what we chose

- **Instruction length:** API.md and mockups say 250; `server.js` truncates to 200. Client field and counter use **200**.
- **`packages_max` / dates / empty search:** document assumes clean types; service sends strings, nulls, unix seconds, and `items: null`. We parse leniently and treat null search items as `[]`.
- **Paging:** page 2 overlaps page 1; `has_more` can lie; `total` is wrong. We **dedupe by `id`**, ignore `total`, and stop when a page adds nothing new.
- **Notify:** HTTP 200 with `status: "failed"` is a real failure; reusing the same `Idempotency-Key` replays it. We retry once with a **new** key.
- **Service over docs** whenever they disagree.

## What we cut

- **Screen recording** — deferred; README explains how to capture later. No device recording in this pass.
- Post-send product surfaces beyond notify + success on the same screen.
- Auth, onboarding, settings, iPad, landscape.

## Optional scope kept

Photos strip, depth focus (scale + opacity + blur), swipe-remove, A–Z index, notify, manual address, on-device camera JPEG, kit unit tests. Extra: **5s Undo** after swipe-remove (one-handed rush).

## Pushback for a PM

- Shipping a mock that fails every 9th list call and lies about pagination without documenting it burns evaluation time; put chaos behind a `CHAOS=1` flag.
- Cap instructions at one number in both docs and service.
- “Notify returns 200 on failure” without a clear envelope invites double-sends; prefer 4xx/5xx or a documented `status` contract with idempotency examples.
