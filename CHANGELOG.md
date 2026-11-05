# Changelog

## 0.3.0 — original Stance v4 UI-only source integration

- Rebased Mono palette and exact shell/sidebar/icon geometry on the author-supplied UI-only Lua source instead of approximating screenshots.
- Restored the source's Matcha text anchoring with calibration options and extra Triangle pooling.
- Added single-window fast-path drawing translation during dragging, plus buffered configuration saves.
- Integrated original hover/typing input-capture approach with optional ContextActionService movement sinking.
- Kept the generic window/tab/control API, with no animation catalog, data or playback dependency.
- Rechecked mock-runtime smoke tests and updated geometric snapshot.


## 0.2.0 — Stance Mono visual alignment

- Rebuilt Mono around the original Matcha Animation Changer aesthetics instead of generic dark rectangular sidebars.
- Restored the exact black-and-white Mono palette, icon rail, circular navigation, rounded outline cards and pill buttons.
- Added script-defined `Tab:CreateCard()` dashboard cards (up to three per tab).
- Added `Window:SetStatus()`, `Window:SetFooter()` and `Window:CreateFooterButton()`.
- Added a real top-bar Search overlay for tab and control names.
- Updated the full demo to show the Stance dashboard style, its seven navigation destinations, and generic controls.
- Kept existing control APIs, configuration persistence, hotkeys and safe teardown.
- Mocked Lua runtime tests passed. Live Matcha visual verification remains pending.

## 0.1.0 — Initial library beta

- Published the standalone library, demo, API documentation and smoke test.
- Added Matcha-compatible `_G.StanceUI` fallback for `loadstring()` chunks that discard return values.
