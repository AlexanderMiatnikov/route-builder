# AI process

Hard limit: one page.

## Kit / agent / model

- **Kit:** Superpowers (Cursor plugin), v6.1.1 cache / marketplace install.
- **Agent:** Cursor Agent (Composer), with Subagent-Driven Development after brainstorming + writing-plans.
- **Flow:** brainstorming (clarifying Qs) → design spec → implementation plan → SDD (tasks 1–2 via subagents; tasks 3–6 continued in-session after a multitask interrupt) → handoff docs.

## Cycle and gates

1. Clarifying questions (optional scope **C**, no video, undo, private GitHub `route-builder`, SwiftUI+kit).
2. Design sections approved in chat; written spec committed; partner said ok.
3. Plan expanded with TDD steps; partner chose Subagent-Driven.
4. Task 1–2: implementer + reviewer gates (approved with minors).
5. Task 3–5: app shell + both screens implemented and `xcodebuild` green.
6. Task 6: this handoff + private repo push.

Approved immediately: architecture, Stops, Instructions, delivery sections. Returned earlier work when brainstorming was skipped — restarted with questions.

## Where the agent was wrong (≥3)

1. **Skipped clarifying questions** on first pass despite Superpowers brainstorming — noticed by the partner; restarted Q&A.
2. **Wrote kit code before tests**, then the plan forced delete+TDD — correct process restored in Task 1.
3. **Early multitask fork** continued implementation while the partner wanted questions — interrupted and paused.

## What the kit helped / hurt

- Helped: forced a written spec, layered plan, TDD for the chaos API, review gates, artifact paths for handoff.
- Hurt: ceremony vs. a very complete brief; easy to “approve yourself” and skip questions; worktree consent vs. continuous SDD conflicted in practice.

## Time / tokens

Roughly one focused session from install → green simulator build. Exact token totals not exported by the host UI in this pass.
