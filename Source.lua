-- Stance UI 0.1.0 | Standalone Matcha Drawing API library
-- No external project dependencies. Designed for the Matcha executor runtime.

assert(type(Drawing) == "table" and type(Drawing.new) == "function", "Stance UI requires Matcha Drawing.new")
assert(type(Color3) == "table" and type(Color3.fromRGB) == "function", "Stance UI requires Roblox Color3")
assert(type(Vector2) == "table" and type(Vector2.new) == "function", "Stance UI requires Roblox Vector2")

if type(_G) == "table" and type(_G.StanceUIUnload) == "function" then
    pcall(_G.StanceUIUnload)
end

local VERSION = "0.1.0"
local Stance = { Version = VERSION, Windows = {}, Flags = {}, Destroyed = false }
local Engine = {
    pools = { Square = {}, Text = {}, Line = {} },
    used = { Square = 0, Text = 0, Line = 0 },
    regions = {}, connections = {}, alive = true,
    lastDown = false, lastMouseX = 0, lastMouseY = 0,
    mouseX = 0, mouseY = 0, drag = nil, focus = nil, capture = nil,
    popup = nil, wheel = 0, blocked = nil,
    lastPaint = 0, lastStep = 0, dirty = true, typingKey = nil, repeatAt = 0,
    heldKeys = {}, toasts = {}, lastSave = 0,
}

local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
local function round(n) return math.floor(n + 0.5) end
local function now() return type(tick) == "function" and tick() or os.clock() end
local function clock() return os.clock() end
local function pad(s, maxN) return tostring(s or ""):sub(1, maxN or 400) end
local function safe(fn, ...)
    if type(fn) ~= "function" then return true end
    local ok, err = pcall(fn, ...)
    if not ok then
        if type(warn) == "function" then warn("[Stance UI] Callback error: " .. tostring(err))
        else print("[Stance UI] Callback error: " .. tostring(err)) end
    end
    return ok
end
local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = deepCopy(v) end
    return result
end
local function blend(a, b, t)
    return { round(a[1] + (b[1] - a[1]) * t), round(a[2] + (b[2] - a[2]) * t), round(a[3] + (b[3] - a[3]) * t) }
end
local PALETTES = {
    Mono = {
        bg = {12, 12, 14}, side = {17, 17, 19}, panel = {22, 22, 25}, card = {27, 27, 30},
        hover = {39, 39, 43}, control = {34, 34, 38}, line = {45, 45, 49},
        text = {234, 234, 237}, sub = {159, 159, 169}, mute = {99, 99, 108}, accent = {234, 234, 237},
    },
    Purple = {
        bg = {14, 10, 22}, side = {20, 14, 31}, panel = {25, 18, 38}, card = {32, 24, 46},
        hover = {46, 36, 64}, control = {39, 30, 54}, line = {54, 45, 79},
        text = {236, 232, 248}, sub = {166, 156, 196}, mute = {104, 96, 134}, accent = {139, 92, 246},
    },
    Dark = {
        bg = {13, 13, 14}, side = {19, 19, 21}, panel = {24, 24, 27}, card = {29, 29, 33},
        hover = {46, 46, 52}, control = {37, 37, 41}, line = {46, 46, 52},
        text = {232, 232, 236}, sub = {152, 152, 162}, mute = {92, 92, 102}, accent = {96, 156, 248},
    },
    Midnight = {
        bg = {8, 11, 20}, side = {12, 16, 29}, panel = {15, 20, 34}, card = {19, 25, 41},
        hover = {33, 43, 70}, control = {27, 35, 58}, line = {36, 46, 70},
        text = {218, 230, 242}, sub = {132, 150, 172}, mute = {70, 86, 110}, accent = {45, 190, 220},
    },
}
local GOOD, WARN, BAD = {82, 210, 140}, {250, 190, 70}, {244, 104, 116}
local SWATCHES = { {139, 92, 246}, {96, 156, 248}, {45, 190, 220}, {82, 210, 140}, {250, 150, 70}, {240, 96, 146}, {234, 234, 237} }
local colorCache = {}
local function color3(rgb)
    local r, g, b = clamp(round(tonumber(rgb[1]) or 0), 0, 255), clamp(round(tonumber(rgb[2]) or 0), 0, 255), clamp(round(tonumber(rgb[3]) or 0), 0, 255)
    local key = r * 65536 + g * 256 + b
    if not colorCache[key] then colorCache[key] = Color3.fromRGB(r, g, b) end
    return colorCache[key]
end
local fonts = Drawing.Fonts or {}
local FONT = fonts.System or fonts.UI or fonts.Monospace or 0
local BOLD = fonts.SystemBold or FONT
local cornerSupported, fontSizeSupported = nil, nil

local function property(entry, name, value)
    if entry[name] ~= value then
        entry.obj[name] = value
        entry[name] = value
    end
end
local function take(kind)
    local i = Engine.used[kind] + 1
    Engine.used[kind] = i
    local pool = Engine.pools[kind]
    local entry = pool[i]
    if not entry then
        local obj = Drawing.new(kind)
        obj.Visible = false
        if kind == "Square" then
            obj.Filled = true
            if cornerSupported == nil then cornerSupported = pcall(function() obj.Corner = 0 end) end
        elseif kind == "Text" then
            obj.Outline = false
            if fontSizeSupported == nil then fontSizeSupported = pcall(function() obj.FontSize = 14 end) end
        end
        entry = { obj = obj }
        pool[i] = entry
    end
    return entry
end
local function rect(x, y, w, h, rgb, radius, z, opacity)
    if w <= 0 or h <= 0 then return end
    local e = take("Square")
    local px, py, pw, ph = round(x), round(y), math.max(1, round(w)), math.max(1, round(h))
    if e.px ~= px or e.py ~= py then property(e, "Position", Vector2.new(px, py)); e.px, e.py = px, py end
    if e.pw ~= pw or e.ph ~= ph then property(e, "Size", Vector2.new(pw, ph)); e.pw, e.ph = pw, ph end
    property(e, "Color", color3(rgb))
    property(e, "Transparency", clamp(opacity or 1, 0, 1))
    property(e, "ZIndex", z or 1)
    if cornerSupported then property(e, "Corner", clamp(round(radius or 0), 0, round(math.min(pw, ph) / 2))) end
    property(e, "Visible", true)
end
local function line(x1, y1, x2, y2, rgb, z, thickness, opacity)
    local e = take("Line")
    property(e, "From", Vector2.new(round(x1), round(y1)))
    property(e, "To", Vector2.new(round(x2), round(y2)))
    property(e, "Color", color3(rgb))
    property(e, "Thickness", thickness or 1)
    property(e, "Transparency", clamp(opacity or 1, 0, 1))
    property(e, "ZIndex", z or 1)
    property(e, "Visible", true)
end
local function textWidth(str, size) return #tostring(str or "") * size * 0.54 end
local function fitted(str, width, size)
    str = tostring(str or "")
    if width <= 0 then return "" end
    if textWidth(str, size) <= width then return str end
    local maxChars = math.max(1, math.floor(width / (size * 0.54)) - 2)
    return str:sub(1, maxChars) .. ".."
end
local function drawText(str, x, cy, size, rgb, z, isBold, centered, opacity)
    local e = take("Text")
    local fontSize = round(size)
    property(e, "Text", tostring(str or ""))
    property(e, "Position", Vector2.new(round(x), round(cy - fontSize / 2)))
    property(e, "Size", fontSize)
    if fontSizeSupported then property(e, "FontSize", fontSize) end
    property(e, "Center", centered == true)
    property(e, "Font", isBold and BOLD or FONT)
    property(e, "Color", color3(rgb))
    property(e, "ZIndex", z or 15)
    property(e, "Transparency", clamp(opacity or 1, 0, 1))
    property(e, "Visible", true)
end
local function beginFrame()
    for kind in pairs(Engine.used) do Engine.used[kind] = 0 end
    Engine.regions = {}
end
local function endFrame()
    for kind, pool in pairs(Engine.pools) do
        for i = Engine.used[kind] + 1, #pool do
            local e = pool[i]
            if e.Visible ~= false then property(e, "Visible", false) end
        end
    end
end
local function within(x, y, r)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end
local function region(x, y, w, h, fn, owner, kind, tip)
    if w <= 0 or h <= 0 then return end
    Engine.regions[#Engine.regions + 1] = { x = x, y = y, w = w, h = h, fn = fn, owner = owner, kind = kind, tip = tip }
end
local function hovering(x, y, w, h)
    return Engine.mouseX >= x and Engine.mouseX <= x + w and Engine.mouseY >= y and Engine.mouseY <= y + h
end
local function isDown(vk)
    if type(iskeypressed) ~= "function" then return false end
    local ok, down = pcall(iskeypressed, vk)
    return ok and down == true
end
local function mouseDown()
    if type(ismouse1pressed) ~= "function" then return false end
    local ok, down = pcall(ismouse1pressed)
    return ok and down == true
end
local function activeRoblox()
    if type(isrbxactive) ~= "function" then return true end
    local ok, isActive = pcall(isrbxactive)
    return not ok or isActive == true
end
local function viewport()
    local ok, vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    if ok and vp then return vp.X, vp.Y end
    return 1920, 1080
end
local function getMouse()
    local ok, mx, my = pcall(function()
        local m = game:GetService("Players").LocalPlayer:GetMouse()
        return m.X, m.Y
    end)
    if ok and type(mx) == "number" and type(my) == "number" then return mx, my end
    return Engine.mouseX, Engine.mouseY
end
local function markedDirty() Engine.dirty = true end
local function formatKey(vk)
    if type(vk) ~= "number" or vk <= 0 then return "None" end
    if vk >= 0x30 and vk <= 0x39 or vk >= 0x41 and vk <= 0x5A then return string.char(vk) end
    if vk >= 0x70 and vk <= 0x7B then return "F" .. (vk - 0x6F) end
    local names = { [0x08] = "Backspace", [0x09] = "Tab", [0x0D] = "Enter", [0x10] = "Shift", [0x11] = "Ctrl", [0x12] = "Alt", [0x1B] = "Esc", [0x20] = "Space", [0x21] = "PgUp", [0x22] = "PgDn", [0x24] = "Home", [0x25] = "Left", [0x26] = "Up", [0x27] = "Right", [0x28] = "Down", [0x2E] = "Delete" }
    return names[vk] or string.format("0x%02X", vk)
end
local CHARACTERS, SHIFT = {}, {}
for i = 0x30, 0x39 do CHARACTERS[i] = string.char(i) end
for i = 0x41, 0x5A do CHARACTERS[i] = string.char(i + 32) end
for vk, ch in pairs({ [0x20]=" ", [0xBA]=";", [0xBB]="=", [0xBC]=",", [0xBD]="-", [0xBE]=".", [0xBF]="/", [0xC0]="`", [0xDB]="[", [0xDC]="\\", [0xDD]="]", [0xDE]="'" }) do CHARACTERS[vk] = ch end
for vk, ch in pairs({ [0x30]=")", [0x31]="!", [0x32]="@", [0x33]="#", [0x34]="$", [0x35]="%", [0x36]="^", [0x37]="&", [0x38]="*", [0x39]="(", [0xBA]=":", [0xBB]="+", [0xBC]="<", [0xBD]="_", [0xBE]=">", [0xBF]="?", [0xC0]="~", [0xDB]="{", [0xDC]="|", [0xDD]="}", [0xDE]='"' }) do SHIFT[vk] = ch end
for vk = 0x41, 0x5A do SHIFT[vk] = string.char(vk) end

local function normalizeRGB(value)
    if type(value) == "string" then
        local h = value:gsub("#", "")
        if #h == 6 and h:match("^%x+$") then return { tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16) } end
    elseif type(value) == "table" then
        return { clamp(round(tonumber(value[1] or value.r or value.R) or 0), 0, 255), clamp(round(tonumber(value[2] or value.g or value.G) or 0), 0, 255), clamp(round(tonumber(value[3] or value.b or value.B) or 0), 0, 255) }
    end
    return {139, 92, 246}
end
local function rgbHex(c) return string.format("#%02X%02X%02X", c[1], c[2], c[3]) end
local function hsvToRGB(h, s, v)
    h = ((tonumber(h) or 0) % 360) / 60
    s, v = clamp(tonumber(s) or 0, 0, 1), clamp(tonumber(v) or 0, 0, 1)
    local c = v * s
    local x = c * (1 - math.abs(h % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0
    if h < 1 then r, g, b = c, x, 0
    elseif h < 2 then r, g, b = x, c, 0
    elseif h < 3 then r, g, b = 0, c, x
    elseif h < 4 then r, g, b = 0, x, c
    elseif h < 5 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    return {round((r + m) * 255), round((g + m) * 255), round((b + m) * 255)}
end
local function rgbToHSV(rgb)
    local r, g, b = rgb[1] / 255, rgb[2] / 255, rgb[3] / 255
    local lo, hi = math.min(r, g, b), math.max(r, g, b)
    local d = hi - lo
    local h = 0
    if d > 0 then
        if hi == r then h = ((g - b) / d) % 6
        elseif hi == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h * 60
    end
    return h, hi == 0 and 0 or d / hi, hi
end
local function themeOf(window)
    local raw = PALETTES[window.Theme] or PALETTES.Mono
    local t = {}
    for key, value in pairs(raw) do t[key] = value end
    if window.Accent then t.accent = window.Accent end
    local light = 0.299 * t.accent[1] + 0.587 * t.accent[2] + 0.114 * t.accent[3]
    t.onAccent = light > 148 and {11, 11, 14} or {255, 255, 255}
    t.accentDark = blend(t.card, t.accent, 0.18)
    t.good, t.warn, t.bad = GOOD, WARN, BAD
    return t
end

-- Public data model -----------------------------------------------------------
local WindowMethods, TabMethods, SectionMethods, ControlMethods = {}, {}, {}, {}
WindowMethods.__index, TabMethods.__index = WindowMethods, TabMethods
SectionMethods.__index, ControlMethods.__index = SectionMethods, ControlMethods

local function sanitizeFileName(title)
    return tostring(title or "window"):lower():gsub("[^%w_%-]", "_"):sub(1, 48)
end
local function decodeJSON(raw)
    if type(raw) ~= "string" then return nil end
    local ok, result = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
    return ok and type(result) == "table" and result or nil
end
local function encodeJSON(value)
    local ok, result = pcall(function() return game:GetService("HttpService"):JSONEncode(value) end)
    if ok then return result end
    return nil
end
local function loadConfig(window)
    if window.AutoSave == false or type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    local ok, data = pcall(function()
        if isfile(window.ConfigFile) then return decodeJSON(readfile(window.ConfigFile)) end
    end)
    if not ok or type(data) ~= "table" then return end
    window._saved = type(data.flags) == "table" and data.flags or {}
    if type(data.x) == "number" then window.X = data.x end
    if type(data.y) == "number" then window.Y = data.y end
    if type(data.width) == "number" then window.Width = clamp(data.width, window.MinWidth, 2000) end
    if type(data.height) == "number" then window.Height = clamp(data.height, window.MinHeight, 1400) end
    if type(data.tab) == "string" then window._savedTab = data.tab end
    if type(data.theme) == "string" and PALETTES[data.theme] then window.Theme = data.theme end
    if type(data.accent) == "table" then window.Accent = normalizeRGB(data.accent) end
    if type(data.opacity) == "number" then window.Opacity = clamp(data.opacity, 0.35, 1) end
end
function WindowMethods:SaveConfig()
    if self.Destroyed or type(writefile) ~= "function" then return false, "writefile unavailable" end
    local data = {
        version = 1, flags = self.Flags, x = self.X, y = self.Y,
        width = self.Width, height = self.Height,
        tab = self.SelectedTab and self.SelectedTab.Name or "",
        theme = self.Theme, accent = self.Accent, opacity = self.Opacity,
    }
    local encoded = encodeJSON(data)
    if not encoded then return false, "JSON encode unavailable" end
    local ok, err = pcall(writefile, self.ConfigFile, encoded)
    if ok then self._dirty = false; return true end
    return false, tostring(err)
end
function WindowMethods:LoadConfig()
    if self.Destroyed then return false, "window destroyed" end
    local oldFile = self.ConfigFile
    self._saved = {}
    loadConfig(self)
    if not next(self._saved) and type(isfile) == "function" then
        local ok, exists = pcall(isfile, oldFile)
        if ok and not exists then return false, "config not found" end
    end
    for _, tab in ipairs(self.Tabs) do
        for _, section in ipairs(tab.Sections) do
            for _, control in ipairs(section.Controls) do
                if control.Flag and self._saved[control.Flag] ~= nil then
                    control:Set(self._saved[control.Flag], true)
                end
            end
        end
        if tab.Name == self._savedTab then self.SelectedTab = tab end
    end
    markedDirty()
    return true
end
function WindowMethods:_changed()
    self._dirty = true
    self._saveAt = now() + 0.7
    markedDirty()
end
function WindowMethods:GetFlag(name)
    return self.Flags[name]
end
function WindowMethods:SetFlag(name, value)
    for _, tab in ipairs(self.Tabs) do
        for _, section in ipairs(tab.Sections) do
            for _, control in ipairs(section.Controls) do
                if control.Flag == name then control:Set(value); return true end
            end
        end
    end
    return false
end
function WindowMethods:SetTheme(theme)
    if PALETTES[theme] then self.Theme = theme; self:_changed(); return true end
    return false
end
function WindowMethods:SetAccent(rgb)
    self.Accent = rgb and normalizeRGB(rgb) or nil
    self:_changed()
end
function WindowMethods:SetOpacity(value)
    self.Opacity = clamp(tonumber(value) or 1, 0.35, 1)
    self:_changed()
end
function WindowMethods:SetTitle(title)
    self.Title = pad(title, 70)
    self:_changed()
end
function WindowMethods:SetVisible(visible)
    self.Visible = not not visible
    if not self.Visible then
        if Engine.focus and Engine.focus.window == self then Engine.focus = nil end
        if Engine.capture and Engine.capture.window == self then Engine.capture = nil end
        if Engine.popup and Engine.popup.window == self then Engine.popup = nil end
    end
    markedDirty()
end
function WindowMethods:Toggle() self:SetVisible(not self.Visible) end
function WindowMethods:Minimize(value)
    if value == nil then value = not self.Minimized end
    self.Minimized = not not value
    markedDirty()
end
function WindowMethods:SelectTab(tab)
    if type(tab) == "string" then
        for _, candidate in ipairs(self.Tabs) do
            if candidate.Name == tab then tab = candidate; break end
        end
    end
    if type(tab) ~= "table" or tab.Window ~= self then return false end
    self.SelectedTab = tab
    Engine.popup = nil
    if Engine.focus and Engine.focus.window == self then Engine.focus = nil end
    self:_changed()
    return true
end
function WindowMethods:Destroy()
    if self.Destroyed then return end
    if self.AutoSave and self._dirty then self:SaveConfig() end
    self.Destroyed = true
    for i, candidate in ipairs(Stance.Windows) do
        if candidate == self then table.remove(Stance.Windows, i); break end
    end
    if Engine.focus and Engine.focus.window == self then Engine.focus = nil end
    if Engine.capture and Engine.capture.window == self then Engine.capture = nil end
    if Engine.popup and Engine.popup.window == self then Engine.popup = nil end
    if Engine.drag and Engine.drag.window == self then Engine.drag = nil end
    markedDirty()
end
function WindowMethods:Notify(options)
    if type(options) == "string" then options = { Content = options } end
    options = options or {}
    local item = {
        window = self, title = pad(options.Title or "Stance UI", 52),
        content = pad(options.Content or options.Text or "", 160),
        kind = tostring(options.Type or "Info"),
        expires = now() + clamp(tonumber(options.Duration) or 3.5, 1, 20),
    }
    Engine.toasts[#Engine.toasts + 1] = item
    if #Engine.toasts > 5 then table.remove(Engine.toasts, 1) end
    markedDirty()
    return item
end
function WindowMethods:Confirm(options)
    options = options or {}
    self._modal = {
        Title = pad(options.Title or "Are you sure?", 55),
        Content = pad(options.Content or "", 190),
        ConfirmText = pad(options.ConfirmText or "Confirm", 24),
        CancelText = pad(options.CancelText or "Cancel", 24),
        OnConfirm = options.OnConfirm, OnCancel = options.OnCancel,
    }
    Engine.popup = nil
    markedDirty()
end
function WindowMethods:CreateTab(options)
    if type(options) == "string" then options = { Name = options } end
    options = options or {}
    local tab = setmetatable({
        Window = self, Name = pad(options.Name or "Tab " .. (#self.Tabs + 1), 40),
        Icon = pad(options.Icon or "", 3), Sections = {}, Scroll = 0, MaxScroll = 0,
        Description = pad(options.Description or "", 140),
        _implicitSection = nil,
    }, TabMethods)
    self.Tabs[#self.Tabs + 1] = tab
    if not self.SelectedTab or tab.Name == self._savedTab then self.SelectedTab = tab end
    markedDirty()
    return tab
end
function TabMethods:CreateSection(options)
    if type(options) == "string" then options = { Name = options } end
    options = options or {}
    local section = setmetatable({
        Tab = self, Name = pad(options.Name or "General", 64),
        Description = pad(options.Description or "", 120),
        Expanded = options.Expanded ~= false, Controls = {},
    }, SectionMethods)
    self.Sections[#self.Sections + 1] = section
    markedDirty()
    return section
end
function TabMethods:_defaultSection()
    if not self._implicitSection then self._implicitSection = self:CreateSection("General") end
    return self._implicitSection
end
function SectionMethods:SetExpanded(expanded)
    self.Expanded = not not expanded
    self.Tab.Window:_changed()
end
function SectionMethods:Destroy()
    local sections = self.Tab.Sections
    for i, candidate in ipairs(sections) do
        if candidate == self then table.remove(sections, i); break end
    end
    if self.Tab._implicitSection == self then self.Tab._implicitSection = nil end
    self.Tab.Window:_changed()
end

local function normalizeOptions(options)
    if type(options) == "string" then return { Name = options } end
    return options or {}
end
local function optionList(items)
    local values = {}
    for _, item in ipairs(type(items) == "table" and items or {}) do
        if type(item) == "table" then
            local v = item.Value
            if v == nil then v = item[1] end
            if v ~= nil then values[#values + 1] = { Value = v, Label = tostring(item.Label or item.Name or item[2] or v) } end
        else
            values[#values + 1] = { Value = item, Label = tostring(item) }
        end
    end
    return values
end
local function sameRGB(a, b)
    return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end
local function sameArray(a, b)
    if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end
local function containsValue(values, value)
    if type(values) ~= "table" then return false end
    for _, item in ipairs(values) do if item == value then return true end end
    return false
end
function ControlMethods:Get()
    return deepCopy(self.Value)
end
function ControlMethods:Set(value, silent)
    if self.Destroyed then return false end
    local prev = self.Value
    local kind = self.Kind
    if kind == "Toggle" then
        value = not not value
    elseif kind == "Slider" then
        local n = tonumber(value) or self.Min
        n = clamp(n, self.Min, self.Max)
        n = self.Min + round((n - self.Min) / self.Increment) * self.Increment
        local precision = self.Precision
        value = tonumber(string.format("%." .. precision .. "f", clamp(n, self.Min, self.Max)))
    elseif kind == "Dropdown" then
        if self.Multiple then
            if type(value) ~= "table" then return false end
            local selected = {}
            for _, opt in ipairs(self.Options) do
                if containsValue(value, opt.Value) then selected[#selected + 1] = opt.Value end
            end
            value = selected
        else
            local found = false
            for _, opt in ipairs(self.Options) do if opt.Value == value then found = true; break end end
            if not found then return false end
        end
    elseif kind == "Textbox" then
        value = pad(value, self.MaxLength)
    elseif kind == "Keybind" then
        local n = tonumber(value)
        value = n and clamp(round(n), 0, 255) or 0
    elseif kind == "ColorPicker" then
        value = normalizeRGB(value)
    else
        value = value
    end
    local same = (kind == "ColorPicker" and sameRGB(prev, value))
        or (kind == "Dropdown" and self.Multiple and sameArray(prev, value))
        or (kind ~= "ColorPicker" and not (kind == "Dropdown" and self.Multiple) and prev == value)
    if same then return true end
    self.Value = deepCopy(value)
    if self.Flag then
        self.Window.Flags[self.Flag] = deepCopy(value)
        Stance.Flags[self.Window.Id .. "." .. self.Flag] = deepCopy(value)
    end
    self.Window:_changed()
    if not silent then safe(self.Callback, deepCopy(value)) end
    return true
end
function ControlMethods:Reset(silent) return self:Set(deepCopy(self.Default), silent) end
function ControlMethods:SetHSV(h, s, v, silent)
    if self.Kind ~= "ColorPicker" then return false end
    return self:Set(hsvToRGB(h, s, v), silent)
end
function ControlMethods:GetHSV()
    if self.Kind ~= "ColorPicker" then return nil end
    return rgbToHSV(self.Value)
end
function ControlMethods:SetVisible(visible)
    self.Visible = not not visible
    self.Window:_changed()
end
function ControlMethods:SetDisabled(disabled)
    self.Disabled = not not disabled
    markedDirty()
end
function ControlMethods:SetName(name)
    self.Name = pad(name, 100)
    markedDirty()
end
function ControlMethods:SetOptions(values)
    if self.Kind ~= "Dropdown" then return false end
    self.Options = optionList(values)
    if self.Multiple then
        self:Set(type(self.Value) == "table" and self.Value or {})
    else
        local found = false
        for _, opt in ipairs(self.Options) do if opt.Value == self.Value then found = true; break end end
        if not found and self.Options[1] then self:Set(self.Options[1].Value) end
    end
    if Engine.popup and Engine.popup.control == self then Engine.popup = nil end
    markedDirty()
    return true
end
function ControlMethods:Press()
    if self.Kind ~= "Button" or self.Disabled or self.Destroyed then return false end
    safe(self.Callback)
    return true
end
function ControlMethods:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for i, control in ipairs(self.Section.Controls) do
        if control == self then table.remove(self.Section.Controls, i); break end
    end
    if Engine.focus and Engine.focus.control == self then Engine.focus = nil end
    if Engine.capture and Engine.capture.control == self then Engine.capture = nil end
    if Engine.popup and Engine.popup.control == self then Engine.popup = nil end
    if self.Flag then
        self.Window.Flags[self.Flag] = nil
        Stance.Flags[self.Window.Id .. "." .. self.Flag] = nil
    end
    self.Window:_changed()
end
local function createControl(section, kind, opts)
    opts = normalizeOptions(opts)
    local window = section.Tab.Window
    local flag = opts.Flag or (kind ~= "Button" and kind ~= "Label" and kind ~= "Paragraph" and kind ~= "Divider" and (sanitizeFileName(section.Tab.Name) .. "_" .. sanitizeFileName(opts.Name or kind) .. "_" .. tostring(#section.Controls + 1)) or nil)
    if flag then flag = tostring(flag) end
    local value = opts.Default
    local c = setmetatable({
        Kind = kind, Window = window, Section = section,
        Name = pad(opts.Name or opts.Text or kind, 100),
        Description = pad(opts.Description or "", 170),
        Callback = opts.Callback, OnPressed = opts.OnPressed, OnSubmit = opts.OnSubmit,
        Flag = flag, Visible = opts.Visible ~= false, Disabled = opts.Disabled == true,
        Min = tonumber(opts.Min) or 0, Max = tonumber(opts.Max) or 100,
        Increment = math.max(0.000001, tonumber(opts.Increment) or 1),
        Precision = clamp(tonumber(opts.Precision) or 0, 0, 5),
        MaxLength = clamp(tonumber(opts.MaxLength) or 100, 1, 1000),
        Options = optionList(opts.Options or opts.Values), Multiple = kind == "Dropdown" and opts.Multiple == true,
        Placeholder = tostring(opts.Placeholder or "Type here..."),
        _pressed = false, _lastPressed = false,
    }, ControlMethods)
    if c.Max < c.Min then c.Min, c.Max = c.Max, c.Min end
    if kind == "Toggle" and value == nil then value = false end
    if kind == "Slider" and value == nil then value = c.Min end
    if kind == "Dropdown" and value == nil then value = c.Multiple and {} or (c.Options[1] and c.Options[1].Value) end
    if kind == "Textbox" and value == nil then value = "" end
    if kind == "Keybind" and value == nil then value = 0 end
    if kind == "ColorPicker" and value == nil then value = {139, 92, 246} end
    c.Default = deepCopy(value)
    if flag and window._saved[flag] ~= nil then value = window._saved[flag] end
    section.Controls[#section.Controls + 1] = c
    c:Set(value, true)
    markedDirty()
    return c
end
for _, pair in ipairs({
    { "CreateButton", "Button" }, { "CreateToggle", "Toggle" },
    { "CreateSlider", "Slider" }, { "CreateDropdown", "Dropdown" },
    { "CreateTextbox", "Textbox" }, { "CreateInput", "Textbox" },
    { "CreateKeybind", "Keybind" }, { "CreateColorPicker", "ColorPicker" },
    { "CreateLabel", "Label" }, { "CreateParagraph", "Paragraph" },
    { "CreateDivider", "Divider" },
}) do
    local method, kind = pair[1], pair[2]
    SectionMethods[method] = function(self, opts) return createControl(self, kind, opts) end
    TabMethods[method] = function(self, opts) return createControl(self:_defaultSection(), kind, opts) end
end

local windowSequence = 0
function Stance:CreateWindow(options)
    assert(not self.Destroyed, "Stance UI has been unloaded")
    options = options or {}
    windowSequence = windowSequence + 1
    local width = options.Size and options.Size[1] or options.Width or 880
    local height = options.Size and options.Size[2] or options.Height or 620
    local vw, vh = viewport()
    local w = setmetatable({
        Id = tostring(options.Id or windowSequence),
        Title = pad(options.Title or "Stance UI", 70),
        Subtitle = pad(options.Subtitle or "A minimal, customizable workspace", 140),
        Width = clamp(tonumber(width) or 880, 700, 2000),
        Height = clamp(tonumber(height) or 620, 520, 1400),
        MinWidth = 700, MinHeight = 520,
        X = tonumber(options.Position and options.Position[1]) or round((vw - (tonumber(width) or 880)) / 2),
        Y = tonumber(options.Position and options.Position[2]) or round((vh - (tonumber(height) or 620)) / 2),
        Theme = PALETTES[options.Theme] and options.Theme or "Mono",
        Accent = options.Accent and normalizeRGB(options.Accent) or nil,
        Opacity = clamp(tonumber(options.Opacity) or 1, 0.35, 1),
        Tabs = {}, Flags = {}, SelectedTab = nil,
        Visible = options.Visible ~= false, Minimized = false,
        ToggleKey = options.ToggleKey == false and 0 or tonumber(options.ToggleKey) or 0x73,
        AutoSave = options.AutoSave ~= false,
        ConfigFile = tostring(options.ConfigFile or ("stance_ui_" .. sanitizeFileName(options.Title) .. ".json")),
        _saved = {}, _savedTab = nil, _dirty = false, _saveAt = 0,
        _modal = nil, Destroyed = false,
    }, WindowMethods)
    loadConfig(w)
    self.Windows[#self.Windows + 1] = w
    markedDirty()
    return w
end
function Stance:RegisterTheme(name, colors)
    if type(name) ~= "string" or name == "" or type(colors) ~= "table" then return false end
    local required = {"bg", "side", "panel", "card", "hover", "control", "line", "text", "sub", "mute", "accent"}
    local palette = {}
    for _, key in ipairs(required) do
        if type(colors[key]) ~= "table" then return false end
        palette[key] = normalizeRGB(colors[key])
    end
    PALETTES[name] = palette
    markedDirty()
    return true
end
function Stance:Notify(options)
    local window = self.Windows[#self.Windows]
    if window then return window:Notify(options) end
    return nil
end
function Stance:GetWindow(id)
    for _, w in ipairs(self.Windows) do if w.Id == tostring(id) or w.Title == id then return w end end
    return nil
end

-- Renderer --------------------------------------------------------------------
local function controlHeight(c)
    if c.Kind == "Slider" then return 78 end
    if c.Kind == "ColorPicker" then return 144 end
    if c.Kind == "Paragraph" then return 72 end
    if c.Kind == "Divider" then return 24 end
    if c.Kind == "Button" then return 55 end
    if c.Kind == "Label" then return 50 end
    return 62
end
local function drawButton(x, y, w, h, label, style, theme, z, action, owner, disabled)
    local hover = not disabled and hovering(x, y, w, h)
    local bg = (style == "primary" and theme.accent)
        or (style == "danger" and blend(theme.card, theme.bad, hover and 0.32 or 0.19))
        or (hover and theme.hover or theme.control)
    rect(x, y, w, h, bg, 12, z, owner.Opacity)
    local foreground = style == "primary" and theme.onAccent or (disabled and theme.mute or theme.text)
    drawText(fitted(label, w - 14, 13), x + w / 2, y + h / 2, 13, foreground, z + 2, true, true)
    if not disabled and action then region(x, y, w, h, action, owner, "button") end
end
local function paintControl(c, x, y, w, h, theme, z)
    local window = c.Window
    local opacity = window.Opacity
    local disabled = c.Disabled
    local hover = hovering(x, y, w, h)
    rect(x, y, w, h, hover and not disabled and theme.hover or theme.card, 14, z, opacity)
    local labelWidth = math.max(120, w * 0.48)
    local labelX = x + 16
    local fg = disabled and theme.mute or theme.text
    local hasDescription = c.Description ~= ""
    local center = y + h / 2
    if c.Kind == "Divider" then
        line(x + 16, center, x + w - 16, center, theme.line, z + 1, 1, opacity)
        return
    end
    if c.Kind == "Label" or c.Kind == "Paragraph" then
        drawText(fitted(c.Name, w - 35, 15), labelX, y + (hasDescription and 18 or h / 2), 15, fg, z + 2, true)
        if hasDescription then
            drawText(fitted(c.Description, w - 38, 12), labelX, y + 42, 12, theme.sub, z + 2)
        end
        return
    end
    if c.Kind == "Button" then
        local bx, bw = x + w - 136, 118
        drawText(fitted(c.Name, bx - labelX - 8, 14), labelX, center + (hasDescription and -9 or 0), 14, fg, z + 2, true)
        if hasDescription then drawText(fitted(c.Description, bx - labelX - 8, 11), labelX, center + 12, 11, theme.mute, z + 2) end
        drawButton(bx, y + 10, bw, h - 20, "Run", "primary", theme, z + 2, function() c:Press() end, window, disabled)
        if not disabled then region(x + 1, y + 1, bw > 0 and bx - x - 2 or w - 2, h - 2, function() c:Press() end, window) end
        return
    end
    if c.Kind == "Slider" then
        drawText(fitted(c.Name, w - 145, 14), labelX, y + 20, 14, fg, z + 2, true)
        local formatted = string.format("%." .. c.Precision .. "f", c.Value)
        drawText(formatted, x + w - 22, y + 20, 13, theme.sub, z + 2, false, true)
        if hasDescription then drawText(fitted(c.Description, w - 36, 11), labelX, y + 38, 11, theme.mute, z + 2) end
        local sx, sw, sy = x + 20, w - 40, y + h - 19
        rect(sx, sy - 3, sw, 6, theme.line, 3, z + 2, opacity)
        local p = c.Max == c.Min and 0 or clamp((c.Value - c.Min) / (c.Max - c.Min), 0, 1)
        rect(sx, sy - 3, math.max(1, sw * p), 6, theme.accent, 3, z + 3, opacity)
        rect(sx + p * sw - 7, sy - 7, 14, 14, theme.text, 7, z + 4, opacity)
        if not disabled then
            region(sx - 6, sy - 15, sw + 12, 30, function()
                Engine.drag = { kind = "slider", control = c, window = window, x = sx, width = sw }
            end, window, "slider")
        end
        return
    end
    if c.Kind == "ColorPicker" then
        drawText(fitted(c.Name, w - 125, 14), labelX, y + 19, 14, fg, z + 2, true)
        rect(x + w - 95, y + 10, 29, 19, c.Value, 6, z + 3, opacity)
        drawText(rgbHex(c.Value), x + w - 60, y + 19, 12, theme.sub, z + 2, false, true)
        if hasDescription then drawText(fitted(c.Description, w - 35, 11), labelX, y + 39, 11, theme.mute, z + 2) end
        local colorY = y + (hasDescription and 55 or 44)
        local labels, fill = {"R", "G", "B"}, { {240, 98, 110}, {92, 210, 143}, {98, 151, 245} }
        for ch = 1, 3 do
            local cy = colorY + (ch - 1) * 27
            local sx, sw = x + 49, math.max(60, w - 140)
            drawText(labels[ch], labelX, cy + 1, 12, theme.sub, z + 2, true)
            rect(sx, cy - 3, sw, 6, theme.line, 3, z + 2, opacity)
            rect(sx, cy - 3, math.max(1, sw * c.Value[ch] / 255), 6, fill[ch], 3, z + 3, opacity)
            rect(sx + sw * c.Value[ch] / 255 - 5, cy - 6, 11, 12, theme.text, 6, z + 4, opacity)
            drawText(tostring(c.Value[ch]), x + w - 54, cy, 12, theme.sub, z + 2, false, true)
            if not disabled then
                local channel = ch
                region(sx - 4, cy - 11, sw + 8, 23, function()
                    Engine.drag = { kind = "color", control = c, window = window, x = sx, width = sw, channel = channel }
                end, window, "color")
            end
        end
        drawText("PRESETS", labelX, y + 132, 10, theme.mute, z + 2, true)
        for i, rgb in ipairs(SWATCHES) do
            local px = x + 86 + (i - 1) * 28
            rect(px, y + 124, 19, 17, rgb, 6, z + 4, opacity)
            if not disabled then
                local swatch = rgb
                region(px, y + 123, 22, 19, function() c:Set(swatch) end, window, "swatch")
            end
        end
        return
    end
    drawText(fitted(c.Name, labelWidth - 24, 14), labelX, center + (hasDescription and -9 or 0), 14, fg, z + 2, true)
    if hasDescription then drawText(fitted(c.Description, labelWidth - 22, 11), labelX, center + 12, 11, theme.mute, z + 2) end
    if c.Kind == "Toggle" then
        local tx, ty = x + w - 67, center - 13
        rect(tx, ty, 46, 26, c.Value and theme.accent or theme.line, 13, z + 2, opacity)
        local thumb = c.Value and tx + 25 or tx + 4
        rect(thumb, ty + 4, 18, 18, c.Value and theme.onAccent or theme.sub, 9, z + 3, opacity)
        if not disabled then region(x, y, w, h, function() c:Set(not c.Value) end, window, "toggle") end
    elseif c.Kind == "Dropdown" then
        local bx, bw, bh = x + w - math.min(250, math.max(145, w * 0.47)), math.min(250, math.max(145, w * 0.47)), 34
        local by = center - bh / 2
        rect(bx, by, bw, bh, theme.control, 10, z + 2, opacity)
        local valueText = tostring(c.Value or "Select...")
        if c.Multiple then
            local labels = {}
            for _, opt in ipairs(c.Options) do
                if containsValue(c.Value, opt.Value) then labels[#labels + 1] = opt.Label end
            end
            valueText = #labels > 0 and table.concat(labels, ", ") or "Select..."
        else
            for _, opt in ipairs(c.Options) do if opt.Value == c.Value then valueText = opt.Label; break end end
        end
        drawText(fitted(valueText, bw - 45, 13), bx + 12, center, 13, theme.text, z + 3)
        drawText("v", bx + bw - 19, center, 15, theme.sub, z + 3, false, true)
        if not disabled then
            region(bx, by, bw, bh, function()
                if Engine.popup and Engine.popup.control == c then Engine.popup = nil
                else Engine.popup = { kind = "dropdown", control = c, window = window, x = bx, y = by + bh + 5, w = bw } end
            end, window, "dropdown")
        end
    elseif c.Kind == "Textbox" then
        local bw = math.min(300, math.max(175, w * 0.51))
        local bx, by = x + w - bw - 14, center - 18
        local focused = Engine.focus and Engine.focus.control == c
        rect(bx - 1, by - 1, bw + 2, 38, focused and theme.accent or theme.line, 10, z + 2, opacity)
        rect(bx, by, bw, 36, theme.control, 9, z + 3, opacity)
        local str = c.Value ~= "" and c.Value or c.Placeholder
        local col = c.Value ~= "" and theme.text or theme.mute
        if focused then str = str .. "|" end
        drawText(fitted(str, bw - 24, 13), bx + 10, center, 13, col, z + 4)
        if not disabled then region(bx, by, bw, 36, function()
            Engine.capture = nil; Engine.focus = { control = c, window = window }
        end, window, "textbox") end
    elseif c.Kind == "Keybind" then
        local bx, bw = x + w - 132, 114
        local capturing = Engine.capture and Engine.capture.control == c
        drawButton(bx, center - 17, bw, 34, capturing and "Press a key..." or formatKey(c.Value),
            capturing and "primary" or "soft", theme, z + 2, function()
                Engine.focus = nil
                Engine.capture = { control = c, window = window, started = now() + 0.18 }
            end, window, disabled)
    end
end

local function paintWindow(window, index)
    if not window.Visible then return end
    local theme = themeOf(window)
    local z = index * 100
    local x, y, w, h = window.X, window.Y, window.Width, window.Height
    local opacity = window.Opacity
    local bodyH = window.Minimized and 74 or h
    rect(x, y, w, bodyH, theme.bg, 24, z + 1, opacity)
    rect(x + 10, y + 10, w - 20, bodyH - 20, theme.panel, 20, z + 2, opacity)
    rect(x + 10, y + 10, w - 20, 62, theme.panel, 19, z + 3, opacity)
    drawText("S T A N C E   /   U I", x + 27, y + 31, 12, theme.sub, z + 8, true)
    drawText(fitted(window.Title, w - 390, 14), x + 27, y + 53, 14, theme.text, z + 8, true)
    region(x + 12, y + 12, w - 134, 60, function()
        Engine.drag = { kind = "window", window = window, dx = Engine.mouseX - x, dy = Engine.mouseY - y }
    end, window, "header")
    local closeX = x + w - 51
    drawButton(closeX, y + 25, 27, 27, "x", "soft", theme, z + 6,
        function() window:SetVisible(false) end, window)
    drawButton(closeX - 34, y + 25, 27, 27, window.Minimized and "+" or "-", "soft", theme, z + 6,
        function() window:Minimize() end, window)
    if window.Minimized then return end
    local sideX, sideY, sideW, sideH = x + 10, y + 82, 154, h - 92
    rect(sideX, sideY, sideW, sideH, theme.side, 18, z + 3, opacity)
    drawText("WORKSPACE", sideX + 18, sideY + 26, 11, theme.mute, z + 6, true)
    for i, tab in ipairs(window.Tabs) do
        local ty = sideY + 48 + (i - 1) * 54
        if ty + 44 <= sideY + sideH - 16 then
            local selected = window.SelectedTab == tab
            local hov = hovering(sideX + 9, ty, sideW - 18, 44)
            rect(sideX + 9, ty, sideW - 18, 44,
                selected and theme.accentDark or (hov and theme.hover or theme.side), 12, z + 5, opacity)
            if selected then rect(sideX + 9, ty + 8, 3, 28, theme.accent, 2, z + 6, opacity) end
            if tab.Icon ~= "" then
                rect(sideX + 20, ty + 11, 23, 23, selected and theme.accent or theme.line, 8, z + 6, opacity)
                drawText(tab.Icon, sideX + 32, ty + 22, 12, selected and theme.onAccent or theme.sub, z + 7, true, true)
            end
            drawText(fitted(tab.Name, tab.Icon == "" and sideW - 39 or sideW - 70, 13),
                sideX + (tab.Icon ~= "" and 53 or 20), ty + 22, 13,
                selected and theme.text or theme.sub, z + 7, selected)
            region(sideX + 9, ty, sideW - 18, 44, function() window:SelectTab(tab) end, window, "tab")
        end
    end
    drawText("v" .. VERSION, sideX + 17, sideY + sideH - 24, 11, theme.mute, z + 6)
    local cx, cw = x + 181, w - 203
    local tab = window.SelectedTab
    drawText(tab and fitted(tab.Name, cw - 145, 23) or "Your workspace", cx + 3, y + 113, 23, theme.text, z + 7, true)
    local subtitle = tab and (tab.Description ~= "" and tab.Description or window.Subtitle) or window.Subtitle
    drawText(fitted(subtitle, cw - 25, 12), cx + 4, y + 138, 12, theme.mute, z + 7)
    local listTop, listBottom = y + 164, y + h - 61
    rect(cx, listTop, cw, listBottom - listTop, theme.panel, 18, z + 4, opacity)
    rect(cx, y + h - 49, cw, 31, theme.panel, 10, z + 4, opacity)
    if tab then
        local contentX, contentW = cx + 13, cw - 26
        local contentTop, contentBottom = listTop + 10, listBottom - 10
        local currentY = contentTop - tab.Scroll
        local contentHeight = 0
        for _, section in ipairs(tab.Sections) do
            local sectionHeight = 43
            if section.Expanded then
                for _, c in ipairs(section.Controls) do
                    if c.Visible and not c.Destroyed then sectionHeight = sectionHeight + controlHeight(c) + 7 end
                end
            end
            sectionHeight = sectionHeight + 10
            if currentY >= contentTop and currentY + 40 <= contentBottom then
                rect(contentX, currentY, contentW, 40, theme.control, 11, z + 5, opacity)
                drawText(fitted(section.Name, contentW - 70, 14), contentX + 15, currentY + 20, 14, theme.text, z + 6, true)
                drawText(section.Expanded and "-" or "+", contentX + contentW - 22, currentY + 20, 17, theme.sub, z + 6, true, true)
                region(contentX, currentY, contentW, 40, function() section:SetExpanded(not section.Expanded) end, window, "section")
            end
            local ry = currentY + 45
            if section.Expanded then
                for _, c in ipairs(section.Controls) do
                    if c.Visible and not c.Destroyed then
                        local rh = controlHeight(c)
                        if ry >= contentTop and ry + rh <= contentBottom then
                            paintControl(c, contentX, ry, contentW, rh, theme, z + 6)
                        end
                        ry = ry + rh + 7
                    end
                end
            end
            currentY = currentY + sectionHeight + 10
            contentHeight = contentHeight + sectionHeight + 10
        end
        tab.MaxScroll = math.max(0, contentHeight - (contentBottom - contentTop))
        if tab.Scroll > tab.MaxScroll then tab.Scroll = tab.MaxScroll end
        -- Always-available scroll buttons, in addition to mouse wheel and PgUp/PgDn.
        local footerY = y + h - 46
        drawText("" .. #tab.Sections .. " sections", cx + 14, footerY + 12, 11, theme.mute, z + 6)
        drawText(tostring(math.floor(tab.Scroll)) .. "/" .. tostring(math.floor(tab.MaxScroll)), cx + cw - 113, footerY + 12, 11, theme.sub, z + 6, false, true)
        drawButton(cx + cw - 63, footerY, 25, 25, "^", "soft", theme, z + 6,
            function() tab.Scroll = clamp(tab.Scroll - 115, 0, tab.MaxScroll); markedDirty() end, window, tab.Scroll <= 0)
        drawButton(cx + cw - 33, footerY, 25, 25, "v", "soft", theme, z + 6,
            function() tab.Scroll = clamp(tab.Scroll + 115, 0, tab.MaxScroll); markedDirty() end, window, tab.Scroll >= tab.MaxScroll)
        region(cx, contentTop, cw, contentBottom - contentTop, nil, window, "scrollarea")
    else
        drawText("Create a tab to get started.", cx + 25, listTop + 60, 14, theme.sub, z + 7)
    end
    -- Resize handle; cursor dragging is constrained by min dimensions.
    rect(x + w - 27, y + h - 28, 3, 3, theme.sub, 1, z + 15, opacity)
    rect(x + w - 34, y + h - 28, 3, 3, theme.sub, 1, z + 15, opacity)
    rect(x + w - 27, y + h - 35, 3, 3, theme.sub, 1, z + 15, opacity)
    region(x + w - 24, y + h - 24, 24, 24, function()
        Engine.drag = { kind = "resize", window = window, ox = Engine.mouseX, oy = Engine.mouseY, w = w, h = h }
    end, window, "resize")
end

local function drawDropdownPopup(popup)
    local c, window = popup.control, popup.window
    if not c or c.Destroyed or window.Destroyed or not window.Visible or window.Minimized then Engine.popup = nil; return end
    local theme = themeOf(window)
    local z = #Stance.Windows * 100 + 80
    local vw, vh = viewport()
    local count = #c.Options
    local rowHeight = 33
    local visibleRows = math.min(7, count)
    local ph = visibleRows * rowHeight + 12 + (count > 7 and 30 or 0)
    local py = popup.y
    if py + ph > vh - 10 then py = math.max(10, popup.y - 40 - ph) end
    local px = clamp(popup.x, 4, math.max(4, vw - popup.w - 5))
    region(0, 0, vw, vh, function() Engine.popup = nil end, window, "overlay")
    rect(px - 2, py - 2, popup.w + 4, ph + 4, theme.line, 14, z + 1, window.Opacity)
    rect(px, py, popup.w, ph, theme.panel, 12, z + 2, window.Opacity)
    if count == 0 then drawText("No options", px + 12, py + 20, 12, theme.mute, z + 5) end
    c._optionScroll = clamp(c._optionScroll or 0, 0, math.max(0, count - visibleRows))
    for i = 1, visibleRows do
        local opt = c.Options[i + c._optionScroll]
        if opt then
            local yy = py + 6 + (i - 1) * rowHeight
            local selected = c.Multiple and containsValue(c.Value, opt.Value) or opt.Value == c.Value
            rect(px + 6, yy, popup.w - 12, rowHeight - 2,
                selected and theme.accentDark or (hovering(px + 6, yy, popup.w - 12, rowHeight - 2) and theme.hover or theme.panel), 8, z + 3, window.Opacity)
            drawText(fitted(opt.Label, popup.w - 30, 13), px + 15, yy + 15, 13, selected and theme.accent or theme.text, z + 4, selected)
            region(px + 6, yy, popup.w - 12, rowHeight - 2, function()
                if c.Multiple then
                    local updated = deepCopy(c.Value)
                    if containsValue(updated, opt.Value) then
                        for i = #updated, 1, -1 do if updated[i] == opt.Value then table.remove(updated, i) end end
                    else
                        updated[#updated + 1] = opt.Value
                    end
                    c:Set(updated)
                else
                    c:Set(opt.Value)
                    Engine.popup = nil
                end
            end, window, "option")
        end
    end
    -- Scroll wheel and arrow buttons allow selection lists of arbitrary length.
    if count > visibleRows then
        local footerY = py + ph - 27
        drawText(tostring(c._optionScroll + 1) .. "-" .. tostring(c._optionScroll + visibleRows) .. "/" .. tostring(count),
            px + 25, footerY + 12, 10, theme.mute, z + 4)
        drawButton(px + popup.w - 64, footerY, 25, 23, "^", "soft", theme, z + 4,
            function() c._optionScroll = clamp(c._optionScroll - 1, 0, count - visibleRows); markedDirty() end,
            window, c._optionScroll == 0)
        drawButton(px + popup.w - 33, footerY, 25, 23, "v", "soft", theme, z + 4,
            function() c._optionScroll = clamp(c._optionScroll + 1, 0, count - visibleRows); markedDirty() end,
            window, c._optionScroll >= count - visibleRows)
    end
    popup.drawn = { x = px, y = py, w = popup.w, h = ph }
end
local function drawModal(window)
    if not window._modal or not window.Visible then return end
    local theme = themeOf(window)
    local m = window._modal
    local vw, vh = viewport()
    local z = #Stance.Windows * 100 + 85
    rect(window.X, window.Y, window.Width, window.Height, theme.bg, 23, z + 1, 0.82)
    region(0, 0, vw, vh, nil, window, "modalblock")
    local mw = math.min(window.Width - 80, 420)
    local mh = 195
    local mx = window.X + (window.Width - mw) / 2
    local my = window.Y + (window.Height - mh) / 2
    rect(mx, my, mw, mh, theme.line, 19, z + 2, window.Opacity)
    rect(mx + 2, my + 2, mw - 4, mh - 4, theme.panel, 17, z + 3, window.Opacity)
    drawText(fitted(m.Title, mw - 42, 19), mx + 22, my + 31, 19, theme.text, z + 4, true)
    drawText(fitted(m.Content, mw - 48, 12), mx + 22, my + 76, 12, theme.sub, z + 4)
    drawButton(mx + mw - 236, my + mh - 55, 101, 34, m.CancelText, "soft", theme, z + 5,
        function() window._modal = nil; safe(m.OnCancel) end, window)
    drawButton(mx + mw - 121, my + mh - 55, 101, 34, m.ConfirmText, "primary", theme, z + 5,
        function() window._modal = nil; safe(m.OnConfirm) end, window)
end
local function drawNotifications()
    local vw, vh = viewport()
    local y = vh - 25
    for i = #Engine.toasts, 1, -1 do
        local toast = Engine.toasts[i]
        local window = toast.window
        local theme = window and themeOf(window) or PALETTES.Mono
        local tw, th = math.min(340, vw - 26), 65
        y = y - th
        local x = vw - tw - 16
        local z = #Stance.Windows * 100 + 96
        rect(x, y, tw, th, theme.panel, 13, z, 0.96)
        local mark = toast.kind == "Success" and GOOD or toast.kind == "Warning" and WARN or toast.kind == "Error" and BAD or theme.accent
        rect(x + 12, y + 11, 4, th - 22, mark, 2, z + 1)
        drawText(fitted(toast.title, tw - 44, 13), x + 28, y + 21, 13, theme.text, z + 2, true)
        drawText(fitted(toast.content, tw - 44, 11), x + 28, y + 44, 11, theme.sub, z + 2)
        y = y - 8
    end
end
local function render()
    beginFrame()
    for i, window in ipairs(Stance.Windows) do paintWindow(window, i) end
    if Engine.popup and not Engine.popup.window._modal then drawDropdownPopup(Engine.popup) end
    for _, window in ipairs(Stance.Windows) do if window._modal then drawModal(window) end end
    drawNotifications()
    endFrame()
    Engine.dirty = false
    Engine.lastPaint = clock()
end

-- Input, hotkeys, lifecycle ----------------------------------------------------
local function bringForward(window)
    for i, w in ipairs(Stance.Windows) do
        if w == window then
            if i ~= #Stance.Windows then
                table.remove(Stance.Windows, i)
                Stance.Windows[#Stance.Windows + 1] = window
            end
            break
        end
    end
end
local function applyDrag()
    local d = Engine.drag
    if not d or d.window.Destroyed then Engine.drag = nil; return end
    local w = d.window
    if d.kind == "window" then
        local vw, vh = viewport()
        w.X = clamp(round(Engine.mouseX - d.dx), -w.Width + 120, vw - 120)
        w.Y = clamp(round(Engine.mouseY - d.dy), 0, vh - 66)
        w:_changed()
    elseif d.kind == "resize" then
        w.Width = clamp(round(d.w + Engine.mouseX - d.ox), w.MinWidth, 2000)
        w.Height = clamp(round(d.h + Engine.mouseY - d.oy), w.MinHeight, 1400)
        w:_changed()
    elseif d.kind == "slider" then
        local p = clamp((Engine.mouseX - d.x) / math.max(1, d.width), 0, 1)
        local c = d.control
        if not c.Destroyed then c:Set(c.Min + (c.Max - c.Min) * p) end
    elseif d.kind == "color" then
        local c = d.control
        if not c.Destroyed then
            local rgb = deepCopy(c.Value)
            rgb[d.channel] = round(clamp((Engine.mouseX - d.x) / math.max(1, d.width), 0, 1) * 255)
            c:Set(rgb)
        end
    end
end
local function handleText(dt)
    local f = Engine.focus
    if not f then Engine.typingKey = nil; return end
    local c = f.control
    if c.Destroyed or c.Window.Destroyed or not c.Window.Visible then Engine.focus = nil; return end
    if not activeRoblox() then Engine.typingKey = nil; return end
    local pressed = nil
    if isDown(0x1B) then
        if Engine.typingKey ~= 0x1B then Engine.focus = nil end
        Engine.typingKey = 0x1B
        return
    end
    if isDown(0x0D) then
        if Engine.typingKey ~= 0x0D then
            Engine.focus = nil
            safe(c.OnSubmit, c.Value)
        end
        Engine.typingKey = 0x0D
        return
    end
    if isDown(0x08) then pressed = 0x08
    else
        for vk = 0x20, 0xDE do
            if CHARACTERS[vk] and isDown(vk) then pressed = vk; break end
        end
    end
    if not pressed then Engine.typingKey = nil; return end
    local t = now()
    if Engine.typingKey ~= pressed then
        Engine.typingKey = pressed
        Engine.repeatAt = t + 0.38
    elseif t < Engine.repeatAt then
        return
    else
        Engine.repeatAt = t + 0.045
    end
    if pressed == 0x08 then c:Set(c.Value:sub(1, -2))
    else
        local shift = isDown(0x10) or isDown(0xA0) or isDown(0xA1)
        local nextChar = shift and (SHIFT[pressed] or CHARACTERS[pressed]) or CHARACTERS[pressed]
        c:Set(c.Value .. nextChar)
    end
end
local function handleCapture()
    local capture = Engine.capture
    if not capture or not activeRoblox() or now() < capture.started then return end
    local c = capture.control
    if c.Destroyed or c.Window.Destroyed or not c.Window.Visible then Engine.capture = nil; return end
    if isDown(0x1B) then Engine.capture = nil; return end
    if isDown(0x08) or isDown(0x2E) then c:Set(0); Engine.capture = nil; return end
    -- Avoid binding mouse primary/secondary, OS keys, or the window's toggle key.
    for vk = 0x04, 0xFE do
        if vk ~= c.Window.ToggleKey and vk ~= 0x5B and vk ~= 0x5C and vk ~= 0x5D and isDown(vk) then
            c:Set(vk)
            Engine.heldKeys[vk] = true
            Engine.capture = nil
            return
        end
    end
end
local function handleHotkeys()
    if not activeRoblox() then return end
    if Engine.focus or Engine.capture then return end
    local seen = {}
    for _, window in ipairs(Stance.Windows) do
        local key = window.ToggleKey
        if key ~= 0 and not seen[key] then
            seen[key] = true
            local down = isDown(key)
            if down and not Engine.heldKeys[key] then window:Toggle() end
            Engine.heldKeys[key] = down
        end
        for _, tab in ipairs(window.Tabs) do
            for _, section in ipairs(tab.Sections) do
                for _, c in ipairs(section.Controls) do
                    if c.Kind == "Keybind" and not c.Disabled and not c.Destroyed and c.Value > 0 then
                        local vk = c.Value
                        if not seen[vk] then
                            seen[vk] = true
                            local down = isDown(vk)
                            if down and not Engine.heldKeys[vk] then safe(c.OnPressed, vk) end
                            Engine.heldKeys[vk] = down
                        end
                    end
                end
            end
        end
    end
    for vk, previous in pairs(Engine.heldKeys) do if previous and not seen[vk] and not isDown(vk) then Engine.heldKeys[vk] = false end end
end
local function scrollAtMouse(delta)
    if delta == 0 then return end
    if Engine.popup and Engine.popup.kind == "dropdown" then
        local p = Engine.popup
        if p.drawn and within(Engine.mouseX, Engine.mouseY, p.drawn) then
            local c = p.control
            c._optionScroll = clamp((c._optionScroll or 0) - delta * 2, 0, math.max(0, #c.Options - 7))
            markedDirty()
            return
        end
    end
    for i = #Stance.Windows, 1, -1 do
        local w = Stance.Windows[i]
        if w.Visible and not w.Minimized and w.SelectedTab then
            local cx, cy = w.X + 181, w.Y + 164
            if hovering(cx, cy, w.Width - 203, w.Height - 225) then
                local tab = w.SelectedTab
                tab.Scroll = clamp(tab.Scroll - delta * 55, 0, tab.MaxScroll)
                markedDirty()
                return
            end
        end
    end
end
local function handleClick()
    local hit = nil
    for i = #Engine.regions, 1, -1 do
        local r = Engine.regions[i]
        if within(Engine.mouseX, Engine.mouseY, r) and r.owner and not r.owner.Destroyed then
            if r.kind ~= "scrollarea" then hit = r; break end
        end
    end
    if hit then
        if Engine.focus and hit.kind ~= "textbox" then Engine.focus = nil end
        if Engine.capture and hit.kind ~= "keybind" then Engine.capture = nil end
        local window = hit.owner
        if hit.kind ~= "overlay" and hit.kind ~= "modalblock" then bringForward(window) end
        if hit.fn then safe(hit.fn) end
        if hit.kind == "slider" or hit.kind == "color" then applyDrag() end
    else
        Engine.focus = nil
        Engine.capture = nil
        Engine.popup = nil
    end
    markedDirty()
end
local function captureGameInput()
    local hovered = false
    for _, w in ipairs(Stance.Windows) do
        if w.Visible and hovering(w.X, w.Y, w.Width, w.Minimized and 74 or w.Height) then hovered = true; break end
    end
    local shouldBlock = hovered or Engine.focus ~= nil or Engine.capture ~= nil or Engine.popup ~= nil
    if shouldBlock == Engine.blocked then return end
    if type(setrobloxinput) == "function" then
        local ok = pcall(setrobloxinput, not shouldBlock)
        if ok then Engine.blocked = shouldBlock end
    else
        Engine.blocked = shouldBlock
    end
end
local function update(dt)
    if Stance.Destroyed then return end
    local mx, my = getMouse()
    local moved = mx ~= Engine.mouseX or my ~= Engine.mouseY
    Engine.mouseX, Engine.mouseY = mx, my
    local down = mouseDown() and activeRoblox()
    local clicked = down and not Engine.lastDown
    if clicked then handleClick() end
    if Engine.drag then
        if down then applyDrag() else Engine.drag = nil end
    end
    Engine.lastDown = down
    if Engine.capture then handleCapture() else handleText(dt) end
    handleHotkeys()
    if Engine.wheel ~= 0 then scrollAtMouse(Engine.wheel); Engine.wheel = 0 end
    -- Keyboard fallback when Matcha does not forward MouseWheel.
    local pageUp, pageDown = isDown(0x21), isDown(0x22)
    if pageUp and not Engine.heldKeys[0x21] then scrollAtMouse(3) end
    if pageDown and not Engine.heldKeys[0x22] then scrollAtMouse(-3) end
    Engine.heldKeys[0x21], Engine.heldKeys[0x22] = pageUp, pageDown
    captureGameInput()
    local t = now()
    for i = #Engine.toasts, 1, -1 do
        if Engine.toasts[i].expires <= t then table.remove(Engine.toasts, i); markedDirty() end
    end
    for _, w in ipairs(Stance.Windows) do
        if w.AutoSave and w._dirty and w._saveAt <= t then w:SaveConfig() end
    end
    local interval = (moved or down or Engine.focus or Engine.capture or Engine.popup or #Engine.toasts > 0) and 1 / 60 or 1 / 24
    if Engine.dirty or clock() - Engine.lastPaint >= interval then render() end
end

function Stance:GetStats()
    return {
        windows = #self.Windows,
        squares = #Engine.pools.Square,
        texts = #Engine.pools.Text,
        lines = #Engine.pools.Line,
        visible = (function() local n = 0; for _, w in ipairs(self.Windows) do if w.Visible then n = n + 1 end end; return n end)(),
        inputBlocked = Engine.blocked == true,
        version = VERSION,
    }
end
function Stance:Render() render() end
function Stance:Step(dt) update(tonumber(dt) or 1/60) end
function Stance:Unload()
    if self.Destroyed then return end
    self.Destroyed = true
    Engine.alive = false
    for _, w in ipairs(self.Windows) do
        if w.AutoSave and w._dirty then w:SaveConfig() end
        w.Destroyed = true
    end
    self.Windows = {}
    for _, connection in ipairs(Engine.connections) do pcall(function() connection:Disconnect() end) end
    Engine.connections = {}
    for _, pool in pairs(Engine.pools) do
        for _, entry in ipairs(pool) do pcall(function() entry.obj:Remove() end) end
    end
    Engine.pools = { Square = {}, Text = {}, Line = {} }
    Engine.used = { Square = 0, Text = 0, Line = 0 }
    Engine.regions = {}
    Engine.focus, Engine.capture, Engine.popup, Engine.drag = nil, nil, nil, nil
    if type(setrobloxinput) == "function" then pcall(setrobloxinput, true) end
    Engine.blocked = false
    if type(_G) == "table" and _G.StanceUIUnload == self._unloadFn then _G.StanceUIUnload = nil end
end
Stance.Destroy = Stance.Unload

local function connectRunService()
    local ok, runService = pcall(function() return game:GetService("RunService") end)
    local loopConnected = false
    if ok and runService then
        local okConnection, connection = pcall(function()
            return runService.RenderStepped:Connect(function(dt)
                if not Engine.alive then return end
                local t = clock()
                if t - Engine.lastStep < 1 / 120 then return end
                Engine.lastStep = t
                local worked, err = pcall(update, math.min(dt or 1/60, 0.25))
                if not worked and type(warn) == "function" then warn("[Stance UI] Update: " .. tostring(err)) end
            end)
        end)
        if okConnection and connection then Engine.connections[#Engine.connections + 1] = connection; loopConnected = true end
    end
    local okInput, inputService = pcall(function() return game:GetService("UserInputService") end)
    if okInput and inputService then
        local okConnection, connection = pcall(function()
            return inputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseWheel then
                    Engine.wheel = Engine.wheel + input.Position.Z
                end
            end)
        end)
        if okConnection and connection then Engine.connections[#Engine.connections + 1] = connection end
    end
    if not loopConnected and type(task) == "table" and type(task.spawn) == "function" then
        task.spawn(function()
            while Engine.alive do
                pcall(update, 1/60)
                task.wait(1/60)
            end
        end)
    end
end
Stance._unloadFn = function() Stance:Unload() end
if type(_G) == "table" then _G.StanceUIUnload = Stance._unloadFn end
connectRunService()
return Stance
