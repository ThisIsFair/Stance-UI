-- Runs in a mocked Lua runtime; does not connect to Roblox.
local made = 0
local removed = 0
local frames = 0
local files = {}
local mouse = {X = 0, Y = 0}
local pressed = false
local keys = {}
local inputEnabled = true
local stepCallback
local wheelCallback
Drawing = {
    Fonts = {System = 0, SystemBold = 1},
    new = function(kind)
        made = made + 1
        return {kind = kind, Remove = function(self) removed = removed + 1 end}
    end
}
Color3 = {fromRGB = function(r, g, b) return string.format("%d/%d/%d", r, g, b) end}
Vector2 = {new = function(x, y) return {X = x, Y = y} end}
workspace = {CurrentCamera = {ViewportSize = {X=1920, Y=1080}}}
Enum = {UserInputType = {MouseWheel = "MouseWheel"}}
tick = os.clock
ismouse1pressed = function() return pressed end
iskeypressed = function(key) return keys[key] == true end
isrbxactive = function() return true end
setrobloxinput = function(on) inputEnabled = on end
isfile = function(name) return files[name] ~= nil end
readfile = function(name) return files[name] end
writefile = function(name, body) files[name] = body end
local httpService = {
    JSONEncode = function(_, obj)
        -- Config serialization is mocked to avoid coupling this test to any JSON library.
        assert(type(obj.flags) == "table")
        return "VALID_JSON_PLACEHOLDER"
    end,
    JSONDecode = function(_, content)
        assert(content)
        return {flags={enabled=true}, width=900, height=650, tab="Main"}
    end,
}
local services = {
    Players = {LocalPlayer = {GetMouse = function() return mouse end}},
    HttpService = httpService,
    RunService = {RenderStepped = {Connect = function(_, callback)
        stepCallback = callback
        return {Disconnect = function() stepCallback = nil end}
    end}},
    UserInputService = {InputChanged = {Connect = function(_, callback)
        wheelCallback = callback
        return {Disconnect = function() wheelCallback = nil end}
    end}},
}
game = {GetService = function(_, name) return assert(services[name], name) end}

local ui = assert(dofile("Source.lua"))
assert(ui.Version == "0.2.0")
assert(_G.StanceUI == ui, "library must export itself to _G.StanceUI")
local w = ui:CreateWindow({Id="Test", Title="Demo", Position={100,60}, Size={880,620}, ConfigFile="test.json"})
local tab = w:CreateTab("Main")
local settings = w:CreateTab({Name="Settings",Icon="sliders"})
local cards = settings:CreateCard({Name="Card",Value="Ready",Button="Main",Callback=function() w:SelectTab(tab) end})
assert(#settings.Cards == 1 and cards.Value == "Ready")
local sec = tab:CreateSection("Testing")
local presses, toggles, sliderChanges, binds = 0, 0, 0, 0
local toggle = sec:CreateToggle({Name="Enabled", Flag="enabled", Default=false,
    Callback=function(v) toggles=toggles+1 end})
local slider = sec:CreateSlider({Name="Volume", Flag="volume", Min=0, Max=100, Increment=5, Default=35,
    Callback=function() sliderChanges=sliderChanges+1 end})
local dropdown = sec:CreateDropdown({Name="Multiselect", Flag="multi", Multiple=true, Options={"A","B","C"}, Default={"B"}})
local input = sec:CreateInput({Name="Entry", Flag="text", MaxLength=6, Default="hi"})
local color = sec:CreateColorPicker({Name="Tint", Flag="color", Default="#AABBCC"})
local keybind = sec:CreateKeybind({Name="Key", Flag="key", Default=0x72, OnPressed=function() binds=binds+1 end})
local button = sec:CreateButton({Name="Run", Callback=function() presses=presses+1 end})
local label = sec:CreateLabel({Name="Information"})
assert(toggle:Get() == false)
assert(slider:Get() == 35)
assert(dropdown:Get()[1] == "B")
assert(input:Get() == "hi")
assert(color:Get()[2] == 187)
assert(toggles == 0, "creation must not fire callback")
assert(slider:Set(39) and slider:Get() == 40 and sliderChanges == 1)
assert(not dropdown:Set("A"), "multi requires table")
assert(dropdown:Set({"X", "C", "A"}) and #dropdown:Get() == 2 and dropdown:Get()[1] == "A")
assert(input:Set("123456789") and input:Get() == "123456")
assert(color:Set("#001122") and color:Get()[3] == 34)
assert(button:Press() and presses == 1)
assert(w:GetFlag("volume") == 40)
assert(w:SetFlag("volume", 70) and slider:Get() == 70)
assert(w:SetTheme("Purple") and not w:SetTheme("NotTheme"))
w:SetAccent({12,34,56})
w:SetOpacity(0.7)
assert(w:SetStatus("Ready", true) == nil)
local action = w:CreateFooterButton({Name="Apply",Style="primary",Width=100,Callback=function() presses=presses+1 end})
assert(action.Name == "Apply")
w:SetTheme("Mono");w:SetAccent(nil)
ui:Render()
assert(made > 20, "no drawing objects were created")
local stats = ui:GetStats()
assert(stats.windows == 1 and stats.squares > 0 and stats.texts > 0)

local function click(x,y)
    mouse.X, mouse.Y = x,y
    pressed = false; ui:Step(1/60)
    pressed = true; ui:Step(1/60)
    pressed = false; ui:Step(1/60)
end
-- Control placed under the section header, click anywhere in toggle row.
click(350, 335)
assert(toggle:Get() == true and toggles == 1, "toggle click failed")
-- Slider input uses held mouse drag and incremental steps.
click(610, 429)
assert(slider:Get() >= 40 and slider:Get() <= 55, "slider click failed")
-- Multi-select popup must handle options without closing after a selection.
click(760, 485)
click(730, 516)
assert(#dropdown:Get() == 1 and dropdown:Get()[1] == "C", "dropdown option click failed")
assert(not inputEnabled or not pressed, "input gating did not execute")
click(1900,1040) -- dismiss the multi-select popup
mouse.X,mouse.Y=1900,1040; ui:Step(1/60)
assert(inputEnabled, "input wasn't restored outside window")

-- Searching for a tab must actually navigate, not just draw a decorative button.
click(860, 105)
assert(w._searching, "Search button failed to open")
keys[0x53] = true -- S, matches Settings and main's section name only if present
ui:Step(1/60);keys[0x53]=false;ui:Step(1/60)
ui:Render()
click(650, 235)
assert(w.SelectedTab == settings and not w._searching, "Search result failed to navigate")
-- Main returns through the circular icon rail.
click(151, 127)
assert(w.SelectedTab == tab, "Circular navigation did not select Main")

-- Window close/minimize buttons must not be hidden behind the drag region.
click(932, 105)
assert(w.Visible == false, "close button did not register")
w:SetVisible(true); ui:Render()
w:Minimize(true)
ui:Render()
click(891, 97)
assert(w.Minimized == false, "minimized plus button did not restore")

-- Keybind OnPressed only fires on a pressed edge.
keys[0x72] = true; ui:Step(1/60); ui:Step(1/60)
assert(binds == 1, "bound key should trigger once")
keys[0x72] = false; ui:Step(1/60)
keys[0x72] = true; ui:Step(1/60)
assert(binds == 2)
keys[0x72] = false

-- Hotkey toggles visibility while hidden.
keys[0x73] = true; ui:Step(1/60)
assert(w.Visible == false)
keys[0x73] = false; ui:Step(1/60)
keys[0x73] = true; ui:Step(1/60)
assert(w.Visible == true)
keys[0x73] = false; ui:Step(1/60)

local ok, err = w:SaveConfig()
assert(ok, tostring(err))
assert(files["test.json"] ~= nil)
assert(type(stepCallback) == "function")
assert(type(wheelCallback) == "function")
w:Confirm({Title="Confirm", Content="A test", OnConfirm=function() presses=presses+1 end})
ui:Render()
assert(ui:GetStats().windows == 1)
click(680, 430)
assert(presses == 2, "confirm dialog button failed")
w:Notify({Title="Hello", Content="Works", Duration=1})
ui:Render()
assert(w:SetFlag("enabled", false))
assert(toggle:Get() == false)
w:Destroy()
assert(ui:GetStats().windows == 0)
ui:Unload()
assert(_G.StanceUI == nil, "unload should clear the exported global")
assert(removed == made, string.format("drawing leak: made %d removed %d", made, removed))
assert(inputEnabled == true)
print("PASS: mocked Stance UI smoke test; " .. made .. " drawing instances cleaned up")

-- Verify the shipped example script initializes and fully cleans up with the same mocked API.
-- Matcha-specific regression: a loaded chunk runs but returns NO values.
loadstring = function(source)
    local chunk = assert(load(source))
    return function(...) chunk(...) end
end
httpget = function(url)
    assert(url == "https://raw.githubusercontent.com/ThisIsFair/Stance-UI/main/Source.lua")
    local file = assert(io.open("Source.lua", "rb"))
    local body = file:read("*a")
    file:close()
    return body
end
assert(dofile("examples/Example.lua") == nil)
assert(type(_G.StanceUIUnload) == "function", "example did not initialize library")
assert(type(_G.StanceUI) == "table", "Matcha-style loadstring lost the exported library")
_G.StanceUIUnload()
assert(_G.StanceUI == nil, "example unload left stale global")
assert(removed == made, "example left drawing objects behind")
print("PASS: shipped example initializes and unloads with mock runtime")
