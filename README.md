# Stance UI

A **standalone Matcha UI library** from the [Matcha Animation Changer project](https://github.com/ThisIsFair/Animation-Market).

The rendering primitives, Mono geometry, keyboard handling, and input capture in this version are adapted from the original **Stance v4 Mono UI-only Lua source** provided by the project author. This is a reusable component library, **not** the animation pack UI or an animation playback script.

Stance UI extracts the **actual Stance Mono visual language** into a reusable Drawing API library. The default theme is the original black-and-white design: a narrow capsule icon rail, circular outline icons, thin-border rounded cards, outlined pill buttons, spacious content pane, and understated footer/status area. It does **not** include the animation changer or depend on its files.

> **v0.3.0 beta — UI-only source alignment.** Lua syntax, mocked runtime behavior, and a geometric drawing snapshot have been checked. **Live Matcha rendering and input remain to be verified** in Roblox.

## Load directly in Matcha

```lua
local Stance = loadstring(httpget("https://raw.githubusercontent.com/ThisIsFair/Stance-UI/main/Source.lua"))() or _G.StanceUI
assert(Stance and Stance.CreateWindow, "Stance UI failed to initialize")
```

**Try the full demo** (the examples use the exact same library):

```lua
loadstring(httpget("https://raw.githubusercontent.com/ThisIsFair/Stance-UI/main/examples/Example.lua"))()
```

Matcha may discard a chunk's return value. `Source.lua` also registers the current instance as `_G.StanceUI`; reruns unload the previous one using `_G.StanceUIUnload`.

## Stance v4 source alignment

The original source is the design authority for this release. Notable source-matched details:

- Mono palette: pure black backgrounds, white primary accents, dark gray 1px borders
- Capsule sidebar at **x + 14**, width **78**; main outlined pane at **x + 102**, rounded radius **28**
- Circular navigation with an active **28 / 27 / 22px** three-ring treatment and vector line icons
- Matcha text calibration: horizontally centered text uses Matcha's dual-axis `Center` anchor; the baseline is adjustable via `Stance:Calibrate()`
- Pooled Drawing Square/Text/Line/Triangle primitives with write-on-change caching
- While dragging a single window without overlays, cached drawings and their hitboxes can translate rather than fully repaint
- Hover-based `setrobloxinput()` and optional ContextActionService movement-key sinking while typing/capturing

The original file also included animation-specific catalog and favorites logic. None of that is shipped as a runtime dependency of this library.

## Features

- Original Mono palette by default, plus Purple, Dark, Midnight and custom accents.
- Draggable, resizable window; compact circular-icon navigation; rounded outlined main pane.
- Up to **three reusable dashboard cards per tab** with script-defined labels and callbacks.
- Tabs, collapsible sections, buttons, toggles, sliders, single/multi dropdowns, text fields, color pickers, keybinds, labels and dividers.
- Working search across tab names and control names, action/status footer, notifications and confirmation dialogs.
- Automatic flag saving/loading, configurable window/section settings, optional mouse input capture.
- Reusable pooled Drawing primitives, cleanup, and the configurable F4 show/hide hotkey.

## Minimal usage

```lua
local Stance = loadstring(httpget("https://raw.githubusercontent.com/ThisIsFair/Stance-UI/main/Source.lua"))() or _G.StanceUI

local Window = Stance:CreateWindow({Title="My Script", Theme="Mono", Size={900,680}, Status="Ready"})
local Home = Window:CreateTab({Name="Home", Icon="home", Description="My workspace"})
local Settings = Window:CreateTab({Name="Settings", Icon="sliders"})

Home:CreateCard({Name="Settings", Value="Ready", Button="Configure", Callback=function()
    Window:SelectTab(Settings)
end})
local Section = Settings:CreateSection("General")
Section:CreateToggle({Name="Enabled", Flag="enabled", Default=false, Callback=function(on)
    print("Enabled",on)
end})
Window:CreateFooterButton({Name="Apply", Style="primary", Callback=function()
    Window:SetStatus("Applied")
end})
```

See [the example](examples/Example.lua) and [full API](docs/API.md) for more components and callbacks.

## Requirements

- Matcha `Drawing.new()` with `Square`, `Line`, and `Text` shapes (rounded `Square.Corner` if available).
- Roblox globals (`game`, `workspace`, `Color3`, `Vector2`), and Matcha `ismouse1pressed()` / `iskeypressed()`.
- `RunService.RenderStepped` or Matcha `task.spawn` / `task.wait` fallback.
- Optional: `setrobloxinput`, `isfile`, `readfile`, `writefile` (the last three for persistence), `httpget`, and `loadstring` (remote loader).

## Project separation

This is a **standalone library**: it doesn't import or modify the animation catalog, playback engine, or other Animation-Market files. Only generic UI design and rendering concepts were extracted into Stance UI.

## Quality status

The mocked [smoke test](tests/smoke.lua) exercises controls, click/drag input, keybinds, confirmation, save/load, cleanup and Matcha's return-less `loadstring` behavior. A software snapshot is used for inspecting the Drawing object geometry; it is **not** a native Matcha screenshot. Live testing is needed before calling the new layout production-stable.
