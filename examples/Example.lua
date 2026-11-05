-- Stance UI / Mono playground. Uses the original Stance visual language.
local Stance = loadstring(httpget("https://raw.githubusercontent.com/ThisIsFair/Stance-UI/main/Source.lua"))() or _G.StanceUI
assert(type(Stance) == "table" and type(Stance.CreateWindow) == "function", "Stance UI failed to initialize")

local Window = Stance:CreateWindow({
    Id = "stance-mono-demo",
    Title = "Stance UI",
    HomeTitle = "Your workspace",
    Subtitle = "A standalone Drawing API library with the original Stance design.",
    Theme = "Mono", Size = {900, 680}, ToggleKey = 0x73, -- F4
    ConfigFile = "stance_ui_mono_demo.json", AutoSave = true,
    Footer = "Stance UI  /  Mono", Status = "Ready",
})
local Home = Window:CreateTab({Name="Home", Icon="home", Description="Build a clean interface with Stance components."})
local Browse = Window:CreateTab({Name="Browse", Icon="list", Description="Explore and interact with reusable controls."})
local Favorites = Window:CreateTab({Name="Favorites", Icon="star", Description="Save your commonly used settings."})
local Mix = Window:CreateTab({Name="Mix", Icon="layers", Description="Combine components in any order."})
local Presets = Window:CreateTab({Name="Presets", Icon="bookmark", Description="Save and restore your configuration."})
local Controls = Window:CreateTab({Name="Controls", Icon="keys", Description="Keyboard shortcuts and input testing."})
local Settings = Window:CreateTab({Name="Settings", Icon="sliders", Description="Themes, accents and sizing."})

Home:CreateCard({Name="Windows",Kicker="Create and manage layouts",Value="Mono UI",
    Description="Resizable, draggable shell",Button="Browse components",Callback=function() Window:SelectTab(Browse) end})
Home:CreateCard({Name="Controls",Kicker="Interactive elements",Value="All in one",
    Description="Toggles, sliders, fields...",Button="Configure controls",Callback=function() Window:SelectTab(Controls) end})
Home:CreateCard({Name="Appearance",Kicker="Your style",Value="4 themes",
    Description="Mono with custom accents",Button="Appearance settings",Callback=function() Window:SelectTab(Settings) end})

local Start=Home:CreateSection("Your library")
Start:CreateParagraph({Name="Stance Mono",Description="The original black-and-white Stance look, now available for any Matcha script."})
Start:CreateButton({Name="Show notification",Callback=function()
    Window:Notify({Title="Stance UI",Content="Welcome to the Mono library!",Type="Success"})
end})
Start:CreateButton({Name="Confirm action",Callback=function()
    Window:Confirm({Title="Stance confirmation",Content="This dialog is reusable.",
        OnConfirm=function() Window:Notify({Title="Confirmed",Content="Action accepted",Type="Success"}) end})
end})

local Basic=Browse:CreateSection("Basic controls")
Basic:CreateToggle({Name="Enable feature",Description="A boolean value",Flag="enabled",Default=false,
    Callback=function(v) print("Enabled:",v) end})
Basic:CreateSlider({Name="Volume",Description="0 to 100 in steps of 5",Flag="volume",Min=0,Max=100,
    Increment=5,Default=50,Callback=function(v) print("Volume:",v) end})
Basic:CreateDropdown({Name="Quality",Flag="quality",Options={"Low","Medium","High","Ultra"},Default="High"})
Basic:CreateDropdown({Name="Active filters",Flag="filters",Multiple=true,
    Options={"Bloom","Motion Blur","Sharpen","Vignette","Grain","Depth of Field","Ambient Occlusion","Film"},
    Default={"Bloom","Sharpen"}})
local Advanced=Browse:CreateSection("Advanced controls")
Advanced:CreateTextbox({Name="Display name",Flag="name",Default="Stance",MaxLength=30,Placeholder="Type a name..."})
Advanced:CreateColorPicker({Name="Accent",Flag="color",Default="#FFFFFF"})
Advanced:CreateDivider()
Advanced:CreateLabel({Name="Tabs, sections and controls are all reusable."})

local Fav=Favorites:CreateSection("Quick actions")
Fav:CreateLabel({Name="Build your own favorites using Stance flags and callbacks."})
Fav:CreateButton({Name="Enable demo feature",Callback=function() Window:SetFlag("enabled",true);Window:Notify("Feature enabled") end})

local MixSection=Mix:CreateSection("Mix and match")
MixSection:CreateParagraph({Name="Fully reusable",Description="Compose entirely different pages using the same Mono components."})
MixSection:CreateToggle({Name="Experimental option",Flag="experimental",Default=false})
MixSection:CreateSlider({Name="Effect strength",Flag="strength",Min=0,Max=1,Increment=0.05,Precision=2,Default=0.5})

local PresetSection=Presets:CreateSection("Configuration")
PresetSection:CreateButton({Name="Save configuration",Callback=function()
    local ok,err=Window:SaveConfig()
    Window:Notify({Title=ok and "Saved" or "Failed",Content=ok and "Settings saved" or tostring(err),Type=ok and "Success" or "Error"})
end})
PresetSection:CreateButton({Name="Reload configuration",Callback=function()
    local ok,err=Window:LoadConfig()
    Window:Notify({Title=ok and "Loaded" or "Failed",Content=ok and "Settings loaded" or tostring(err),Type=ok and "Success" or "Error"})
end})
local KeySection=Controls:CreateSection("Keyboard")
KeySection:CreateKeybind({Name="Demo shortcut",Flag="shortcut",Default=0x75,
    OnPressed=function() Window:Notify({Title="Shortcut",Content="Key pressed",Type="Success"}) end})
KeySection:CreateParagraph({Name="F4",Description="Show or hide Stance. Search tabs and controls with the top-right Search button."})
local Appearance=Settings:CreateSection("Appearance")
Appearance:CreateDropdown({Name="Theme",Options={"Mono","Purple","Dark","Midnight"},Default="Mono",
    Callback=function(v) Window:SetTheme(v) end})
Appearance:CreateSlider({Name="Opacity",Min=0.4,Max=1,Increment=0.1,Precision=1,Default=1,
    Callback=function(v) Window:SetOpacity(v) end})
Appearance:CreateColorPicker({Name="Accent override",Default="#FFFFFF",Callback=function(rgb) Window:SetAccent(rgb) end})
Appearance:CreateButton({Name="Reset accent",Callback=function() Window:SetAccent(nil) end})

Window:CreateFooterButton({Name="Reset",Style="ghost",Width=80,Callback=function()
    Window:SetTheme("Mono");Window:SetAccent(nil);Window:SetStatus("Reset")
end})
Window:CreateFooterButton({Name="Undo",Width=84,Callback=function() Window:Notify("Wire your own undo logic here") end})
Window:CreateFooterButton({Name="Apply",Style="primary",Width=112,Callback=function()
    Window:SetStatus("Applied")
    Window:Notify({Title="Applied",Content="Your settings are ready",Type="Success"})
end})
Window:SelectTab(Home)
Window:Notify({Title="Stance UI",Content="Mono loaded. Press F4 to toggle.",Type="Info"})
