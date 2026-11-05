# Stance UI

A **standalone Matcha UI library** from the [Matcha Animation Changer project](https://github.com/ThisIsFair/Animation-Market).

> **Release status: v0.1.0 — initial implementation.** Source syntax and a mocked Lua runtime smoke test have passed. Rendering and interaction have **not yet been tested inside Matcha/Roblox**; the project should be treated as a beta until that is done.

## Features

- Mono, Purple, Dark, and Midnight themes; custom palettes and accents
- Multiple draggable, resizable windows; minimize, close, and configurable show/hide hotkey (F4 by default)
- Sidebar tabs and collapsible sections
- Buttons, toggles, sliders, single/multi dropdowns, textboxes, keybinds, color pickers, labels, paragraphs, and dividers
- Mouse wheel/keyboard/visible-buttons scrolling; color presets; RGB channels and HSV conversion methods
- Notifications, confirmation dialogs, action callbacks, and change callbacks
- Flag persistence with optional `readfile`/`writefile` and `HttpService` JSON
- Pooled `Drawing` objects and clean `:Unload()` teardown
- Optional `setrobloxinput` handling while the pointer is over the UI or editing input

## Getting started

**Local loading:** Copy `Source.lua` into Matcha's accessible workspace and load it with:

```lua
local Stance = loadstring(readfile("Source.lua"))() or _G.StanceUI
```

**Remote loading from this repository's `main` branch:**

```lua
local Stance = loadstring(httpget(
    "https://raw.githubusercontent.com/ThisIsFair/Stance-UI/main/Source.lua"
))() or _G.StanceUI
```

Matcha discards top-level return values from `loadstring` chunks; Stance UI exposes the instance as `_G.StanceUI` for compatibility.

Create a window and controls:

```lua
local Window = Stance:CreateWindow({
    Title = "My Script",
    Theme = "Mono",
    Size = {880, 620},
    ToggleKey = 0x73, -- F4
})

local Main = Window:CreateTab({Name = "Main", Icon = "M"})
local Section = Main:CreateSection("Settings")

local Enabled = Section:CreateToggle({
    Name = "Enabled", Flag = "enabled", Default = false,
    Callback = function(value)
        print("Enabled:", value)
    end,
})

local Speed = Section:CreateSlider({
    Name = "Speed", Flag = "speed", Min = 0, Max = 100,
    Increment = 5, Default = 25,
    Callback = function(value)
        print("Speed:", value)
    end,
})

Window:Notify({Title = "Ready", Content = "Stance UI loaded", Type = "Success"})
-- Later: Stance:Unload()
```

See [`examples/Example.lua`](examples/Example.lua) for a demo featuring all component categories, and [`docs/API.md`](docs/API.md) for the full API.

## Runtime requirements

Required:

- Roblox globals: `game`, `workspace`, `Color3`, `Vector2`, `Drawing.new` / `Drawing.Fonts`
- Matcha input primitives: `ismouse1pressed`, `iskeypressed`; optional `isrbxactive`
- `RunService.RenderStepped` (or a `task.spawn`/`task.wait` fallback)

Optional:

- `setrobloxinput()` for preventing clicks and typing from affecting gameplay
- `isfile`, `readfile`, and `writefile` for configuration persistence
- `UserInputService.InputChanged` for mouse wheel scrolling; on-screen scroll buttons and Page Up/Down provide alternatives

The library does **not** require memory read/write APIs or any animation-specific functionality. It is intended for desktop mouse/keyboard use. Touch and controller input are not implemented in v0.1.0.

## Testing

`tests/smoke.lua` uses mocked Roblox/Matcha globals to exercise UI construction, input events, state, hotkeys, saving, and cleanup. It can be run in a Lua runtime with an appropriate test launcher. This is **not a substitute** for an in-game rendering test.

## Development workflow

`Source.lua` is the distributable single-file library. `examples` and `docs` are kept separate. New features should be added here, tested with mocks, then manually verified in Matcha before declaring them stable.

**Publishing:** This repository contains the initial beta source. Run the included smoke test and verify inside Matcha before using it as a stable dependency.

## Licensing

No license has been selected for the new repository yet. The repository owner should choose the terms before public redistribution or third-party contributions.