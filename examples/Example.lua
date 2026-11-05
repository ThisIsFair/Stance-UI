-- Stance UI example. Matcha does not return values from loadstring chunks.
local Stance = loadstring(httpget("https://raw.githubusercontent.com/ThisIsFair/Stance-UI/main/Source.lua"))() or _G.StanceUI
assert(type(Stance) == "table" and type(Stance.CreateWindow) == "function", "Stance UI failed to initialize; check Matcha console")

local Window = Stance:CreateWindow({
    Id = "example",
    Title = "Stance UI Playground",
    Subtitle = "A standalone Matcha Drawing API library",
    Theme = "Mono",
    Size = {900, 650},
    ToggleKey = 0x73, -- F4
    ConfigFile = "stance_ui_example.json",
    AutoSave = true,
})

local Home = Window:CreateTab({Name = "Home", Icon = "H", Description = "Overview and quick actions"})
local Components = Window:CreateTab({Name = "Components", Icon = "C", Description = "Try the input components"})
local Appearance = Window:CreateTab({Name = "Appearance", Icon = "A", Description = "Change the window's look"})

local Welcome = Home:CreateSection("Welcome")
Welcome:CreateParagraph({
    Name = "Stance UI",
    Description = "Independent of the animation changer. F4 shows or hides this window.",
})
Welcome:CreateButton({
    Name = "Notification",
    Description = "Display a toast in the bottom-right corner",
    Callback = function()
        Window:Notify({Title = "It works!", Content = "Stance UI is running.", Type = "Success"})
    end,
})
Welcome:CreateButton({
    Name = "Confirmation dialog",
    Callback = function()
        Window:Confirm({
            Title = "Test the dialog?",
            Content = "This is a reusable confirmation component.",
            OnConfirm = function()
                Window:Notify({Title = "Confirmed", Content = "You clicked Confirm", Type = "Success"})
            end,
        })
    end,
})

local Basic = Components:CreateSection("Basic controls")
Basic:CreateToggle({
    Name = "Enable feature", Description = "A boolean value", Flag = "enabled", Default = false,
    Callback = function(value) print("Enabled:", value) end,
})
Basic:CreateSlider({
    Name = "Volume", Description = "0 to 100 in steps of 5", Flag = "volume",
    Min = 0, Max = 100, Increment = 5, Default = 50,
    Callback = function(value) print("Volume:", value) end,
})
Basic:CreateDropdown({
    Name = "Quality", Flag = "quality", Options = {"Low", "Medium", "High", "Ultra"},
    Default = "High", Callback = function(value) print("Quality:", value) end,
})
Basic:CreateDropdown({
    Name = "Active filters", Flag = "filters", Multiple = true,
    Options = {"Bloom", "Motion Blur", "Sharpen", "Vignette", "Grain", "Depth of Field", "Ambient Occlusion", "Film"},
    Default = {"Bloom", "Sharpen"},
    Callback = function(values) print("Active filters:", table.concat(values, ", ")) end,
})

local Advanced = Components:CreateSection("Advanced controls")
Advanced:CreateTextbox({
    Name = "Display name", Flag = "display_name", Default = "Stance",
    MaxLength = 30, Placeholder = "Type a name...",
    Callback = function(value) print("Name changed:", value) end,
    OnSubmit = function(value) print("Submitted:", value) end,
})
Advanced:CreateKeybind({
    Name = "Custom shortcut", Flag = "shortcut", Default = 0x75, -- F6
    Callback = function(key) print("New key:", key) end,
    OnPressed = function() Window:Notify("F6 shortcut activated") end,
})
Advanced:CreateColorPicker({
    Name = "Highlight color", Flag = "tint", Default = "#8B5CF6",
    Callback = function(rgb) print("Color:", rgb[1], rgb[2], rgb[3]) end,
})
Advanced:CreateDivider()
Advanced:CreateLabel({Name = "Components are created in their own sections."})

local Styling = Appearance:CreateSection("Appearance")
Styling:CreateDropdown({
    Name = "Theme", Options = {"Mono", "Purple", "Dark", "Midnight"}, Default = "Mono",
    Callback = function(value) Window:SetTheme(value) end,
})
Styling:CreateSlider({
    Name = "Window opacity", Min = 0.4, Max = 1, Increment = 0.1, Precision = 1, Default = 1,
    Callback = function(value) Window:SetOpacity(value) end,
})
Styling:CreateColorPicker({
    Name = "Accent override", Default = "#8B5CF6",
    Callback = function(rgb) Window:SetAccent(rgb) end,
})
Styling:CreateButton({
    Name = "Reset accent to theme default",
    Callback = function() Window:SetAccent(nil) end,
})
Styling:CreateButton({
    Name = "Save config now",
    Callback = function()
        local ok, err = Window:SaveConfig()
        Window:Notify({Title = ok and "Saved" or "Failed", Content = ok and "Configuration stored" or tostring(err), Type = ok and "Success" or "Error"})
    end,
})

Window:SelectTab("Home")
Window:Notify({Title = "Stance UI", Content = "Press F4 to hide or show the window", Type = "Info"})
