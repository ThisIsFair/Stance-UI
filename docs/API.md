# Stance UI API — v0.3.0

The API is intentionally declarative. Create windows, then tabs, then sections, then controls. Tab-level `Create*` methods automatically create an implicit `General` section.

## Initialization and lifecycle

```lua
local Stance = loadstring(httpget("https://raw.githubusercontent.com/ThisIsFair/Stance-UI/main/Source.lua"))() or _G.StanceUI

local Window = Stance:CreateWindow({
    Id = "my-script",                  -- Optional; stable identifier
    Title = "My Script",
    Subtitle = "Optional supporting text",
    Theme = "Mono",                   -- Mono, Purple, Dark, Midnight
    Accent = {139, 92, 246},           -- Optional RGB override or "#8B5CF6"
    Opacity = 1,                       -- 0.35 - 1
    Size = {880, 620},                 -- min 700x520
    Position = {100, 80},              -- Optional
    Visible = true,
    ToggleKey = 0x73,                  -- F4; false disables toggle
    AutoSave = true,
    ConfigFile = "stance_config.json", -- Optional, current workspace
})

local Home = Window:CreateTab({Name = "Home", Icon = "H", Description = "Overview"})
local Section = Home:CreateSection({Name = "General", Expanded = true})

Window:SelectTab("Home")
Window:SetTitle("Renamed")
Window:SetTheme("Dark")
Window:SetAccent({45, 190, 220}) -- nil to clear override
Window:SetOpacity(0.85)
Window:SetVisible(true)
Window:Toggle()
Window:Minimize(false)
Window:Notify({Title = "Hello", Content = "World", Type = "Success", Duration = 4})
Window:Confirm({Title = "Continue?", Content = "Optional text", OnConfirm = function() end})
Window:SaveConfig()  -- returns ok, error
Window:LoadConfig()  -- reapply stored flags and geometry
Window:GetFlag("enabled")
Window:SetFlag("enabled", true)
Window:Destroy() -- deletes this window
Stance:Unload() -- clears every window, drawing, event connection and input capture
```

`Stance:CreateWindow()` can be called more than once. `Stance:GetWindow(id)` locates an instance. `Stance:Notify(...)` uses the last window if present. `Stance:GetStats()` returns Drawing pool counts and input state. `Stance:Render()` and `Stance:Step(dt)` are provided for deterministic testing; in Matcha, the frame loop is normally automatic.

Matcha may discard `loadstring()` return values; the current instance is also available as `_G.StanceUI`. Rerunning `Source.lua` unloads the previous instance via `_G.StanceUIUnload`.

## Tabs and sections

```lua
local Tab = Window:CreateTab("Main")
local Advanced = Tab:CreateSection({Name="Advanced", Expanded=false})
Advanced:SetExpanded(true)
Advanced:Destroy()
```

Controls may be added directly to a `Tab` or an explicit `Section`:

```lua
Tab:CreateToggle({Name="Visible", Default=true})
Advanced:CreateToggle({Name="Visible", Default=true, Flag="visible_advanced"})
```

## Controls

Every control accepts `Name`, `Description`, `Visible`, `Disabled`, and `Callback` (where appropriate). Data controls also accept `Flag` and `Default`. Every control returns an object supporting:

- `:Get()` — returns value (tables are copied)
- `:Set(value, silent?)` — updates value; invokes `Callback(value)` unless `silent` is true
- `:Reset(silent?)` — returns to the configured default
- `:SetVisible(boolean)`, `:SetDisabled(boolean)`, `:SetName(string)`, `:Destroy()`

### Button

```lua
Section:CreateButton({Name="Run", Description="Execute a task", Callback=function() print("Clicked") end})
```

Use `button:Press()` to invoke its callback programmatically.

### Toggle

```lua
Section:CreateToggle({Name="Enabled", Flag="enabled", Default=false, Callback=function(enabled) end})
```

### Slider

```lua
Section:CreateSlider({Name="Threshold", Flag="threshold", Min=0, Max=1,
    Increment=0.05, Precision=2, Default=0.5, Callback=function(value) end})
```

Slider values are clamped and quantized to `Increment`; default precision is `0`. Use `Precision=1` or greater for fractional increments.

### Dropdown — single and multiple selection

```lua
local Choice = Section:CreateDropdown({Name="Mode", Options={"Low","Medium","High"}, Default="High"})
local Filters = Section:CreateDropdown({Name="Filters", Multiple=true,
    Options={"Bloom","Sharpen","Grain"}, Default={"Bloom"}})
Choice:SetOptions({"Low", "Ultra"})
```

Options may be strings/numbers or `{Value=..., Label=...}` records. With `Multiple=true`, values and callbacks are arrays and selecting an option toggles membership without closing the menu. Dropdowns with more than 7 items have scroll buttons and mouse wheel support.

### Textbox

```lua
Section:CreateTextbox({Name="Display name", Flag="name", Default="", MaxLength=40,
    Placeholder="Enter a name...", Callback=function(value) end,
    OnSubmit=function(value) end})
-- Alias: CreateInput
```

Typing is handled with polled keyboard virtual key codes. Escape blurs the field; Enter blurs and fires `OnSubmit`. The v0.3.0 keyboard layout is **US QWERTY**; non-US layouts and IME composition are not supported.

### Keybind

```lua
Section:CreateKeybind({Name="Trigger", Flag="shortcut", Default=0x75,
    Callback=function(newKey) end,  -- fires on binding changes
    OnPressed=function(vk) end,    -- fires on key-down while active
})
```

Click the keybind control and press a key. Esc cancels, Backspace/Delete clears it. The window toggle key and Windows keys are excluded from binding capture.

### Color picker

```lua
local Picker = Section:CreateColorPicker({Name="Tint", Flag="tint", Default="#8B5CF6",
    Callback=function(rgb) print(rgb[1], rgb[2], rgb[3]) end})
Picker:Set({255, 0, 128})
Picker:SetHSV(290, 0.8, 1) -- hue 0..360, saturation/value 0..1
local h, s, v = Picker:GetHSV()
```

Colors are represented as **integer RGB triplets** `{r,g,b}`. The UI exposes RGB channel sliders and seven color presets. HSV conversion is available through methods.

### Static elements

```lua
Section:CreateLabel({Name="Section heading", Description="Optional description"})
Section:CreateParagraph({Name="Notice", Description="A short line of body text"})
Section:CreateDivider()
```

## Settings and configuration

Each `Flag` is unique **within a window**; `Window.Flags` stores its current value. The shared lookup `Stance.Flags` prefixes flags as `windowId.flag`.

With `AutoSave=true`, changed settings are stored ~0.7 seconds after the latest change when file APIs are available. The configuration contains flag values, geometry, selected tab, theme, accent, and opacity. No external files, cloud accounts, or network calls are used by the library itself.

```lua
local ok, reason = Window:SaveConfig()
if not ok then print(reason) end
```

For scripts that don't want file persistence, use `AutoSave=false`. You can still call `:SaveConfig()` explicitly if `writefile` is available.

## Custom palettes

```lua
Stance:RegisterTheme("MyTheme", {
    bg={12,12,14}, side={17,17,19}, panel={22,22,25}, card={27,27,30},
    hover={39,39,43}, control={34,34,38}, line={45,45,49},
    text={234,234,237}, sub={159,159,169}, mute={99,99,108}, accent={139,92,246},
})
Window:SetTheme("MyTheme")
```

The renderer is intentionally based on Matcha's known `Drawing` primitives (`Square`, `Text`, `Line`) and uses an object pool to avoid allocating new objects on each frame.

## Current limitations

The project has passed a local mocked-runtime smoke test, but it has **not** yet been visually verified inside Matcha. The Drawing implementation has no built-in clipping; partially visible rows are culled during scrolling instead of being pixel-clipped. Native touch/controller navigation, IME composition, font measurement, and screen-reader semantics are not supported. On platforms that don't forward `UserInputService.InputChanged`, use the scroll buttons or Page Up/Page Down.

## Original Stance Mono layout (v0.3.0)

The default `Mono` theme has the same black/white palette and circular icon rail as the Matcha Animation Changer's Mono UI. Standard icon names: `home`, `list`, `star`, `layers`, `bookmark`, `keys`, and `sliders`. When `Icon` is omitted or a one-letter abbreviation, the library chooses an icon from the tab name; other names fall back to an initial. The final `Settings` / `Appearance` tab is pinned to the bottom of the rail.

```lua
local Home = Window:CreateTab({Name="Home",Icon="home",Description="Overview"})
Home:CreateCard({
    Number="01", Name="Scripts", Kicker="A reusable dashboard card",
    Value="3 running", Description="Your status", Button="Browse",
    Callback=function(card) print(card.Name) end,
})
Window:SetStatus("Applied", true) -- text and green-dot boolean
Window:SetFooter("Custom status details")
Window:CreateFooterButton({Name="Apply",Style="primary",Width=112,Callback=function() print("Apply") end})
```

Maximum three dashboard cards per tab. `CreateFooterButton` styles are `soft`, `primary`, `ghost`, and `danger`, and actions are aligned right. The top-right Search control matches tab names and control names, selecting the matching destination.

## Matcha rendering calibration

The original Stance v4 Mono UI-only source uses `CENTER_BOTH_AXES = true`, `TEXT_DY = 0`, `ALPHA_INVERTED = false`, and `CHAR_W = 0.54`. These values are reproduced by default. To adjust for an executor with different text anchoring or alpha semantics:

```lua
Stance:Calibrate({
    CENTER_BOTH_AXES = true,
    TEXT_DY = 0,
    ALPHA_INVERTED = false,
    CHAR_W = 0.54,
})
```

The library uses the actual Stance v4 pill/card/icon geometry and maintains pooled drawing objects. The host app supplies content through normal reusable sections and controls; **no animation catalog or animation engine is loaded**.
