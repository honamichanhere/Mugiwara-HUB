local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- 1. SYSTEM AUTO-LOGIN PREMIUM KEY (EXECUTOR ONLY)
-- ==========================================
local savedKeyPath = "HonamiHub/PremiumKey.txt"
local isPremiumUser = false

if not isfolder("HonamiHub") then makefolder("HonamiHub") end

if isfile(savedKeyPath) then
    local savedKey = readfile(savedKeyPath)
    if savedKey == "LUFFY" then
        isPremiumUser = true
    end
end

if not isPremiumUser then
    -- [GATEWAY GRATISAN] Taruh script Pandauth/Linkvertise lu di sini
    print("User Gratisan: Gateway Pandauth berjalan...")
end

-- ==========================================
-- 2. SETUP MODULES & INFO
-- ==========================================
local WindUI = require(ReplicatedStorage:WaitForChild("WindUI"):WaitForChild("Init"))
local MovementModule = require(ReplicatedStorage:WaitForChild("WindUI"):WaitForChild("Movement"))
local LightingModule = require(ReplicatedStorage:WaitForChild("WindUI"):WaitForChild("LightingManager"))

local success, gameInfo = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
local gameName = success and gameInfo.Name or "Unknown Game"
local premiumStatus = (LocalPlayer.MembershipType == Enum.MembershipType.Premium) and "Premium" or "Free"
local defaultWalkSpeed = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.WalkSpeed or 16
local defaultJumpPower = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.JumpPower or 50

-- ==========================================
-- 3. THEME & WINDOW
-- ==========================================
local ThemesList = WindUI:GetThemes()
ThemesList["Luffy"] = {
    Accent = Color3.fromHex("#ffffff"),
    Background = WindUI:Gradient({ ["0"] = { Color = Color3.fromHex("#643c23"), Transparency = 0 }, ["100"] = { Color = Color3.fromHex("#321900"), Transparency = 0 }},{ Rotation = -90 }),
    BackgroundTransparency = 0.5,
    Outline = Color3.fromHex("#ff9132"), Text = Color3.fromHex("#ffffff"), Placeholder = Color3.fromHex("#3c2819"),
    Button = Color3.fromHex("#7d4b32"), Icon = Color3.fromHex("#ffffff"), WindowShadow = Color3.fromHex("#000000"),
    WindowTopbarIcon = Color3.fromHex("#ffffff"), WindowTopbarTitle = Color3.fromHex("#ffdcc8"), WindowTopbarAuthor = Color3.fromHex("#ffb98c"),
    WindowTopbarButtonIcon = Color3.fromHex("#ffffff"), TabBackground = Color3.fromHex("#ff4b00"), TabTitle = Color3.fromHex("#ffffff"),
    TabIcon = Color3.fromHex("#ffffff"), ElementBackground = Color3.fromHex("#b9784b"), ElementTitle = Color3.fromHex("#ffffff"),
    ElementDesc = Color3.fromHex("#c8c8c8"), ElementIcon = Color3.fromHex("#ffffff"), Toggle = Color3.fromHex("#ffaf64"),
    ToggleBar = Color3.fromHex("#ffffff"), PopupBackground = Color3.fromHex("#643c23"), PopupBackgroundTransparency = 0.5,
    PopupTitle = Color3.fromHex("#ff6400"), PopupContent = Color3.fromHex("#ffffff"), PopupIcon = Color3.fromHex("#ffffff"),
    DialogBackground = Color3.fromHex("#1F1108"), DialogBackgroundTransparency = 0.5, DialogTitle = Color3.fromHex("#FFD700"),
    DialogContent = Color3.fromHex("#ffffff"), DialogIcon = Color3.fromHex("#FF8C00"),
}

local Window = WindUI:CreateWindow({
    Title = "Mugiwara HUB", Icon = "lucide:sparkles", Author = "by Honami", Folder = "HonamiHubConfig",
    Size = UDim2.fromOffset(480, 360), Transparent = true, Theme = "Luffy",
})
Window:Tag({ Title = "v1.0.0", Icon = "lucide:refresh-ccw-dot", Color = Color3.fromHex("#ffbe6e"), Radius = 13 })

local TabPremium = Window:Tab({ Title = '<font color="#ffff82">Premium Access</font>', Icon = "lucide:crown", IconColor = Color3.fromHex("#ffff82") })
local TabHome = Window:Tab({ Title = "Home", Icon = "lucide:ship" })
local TabMain = Window:Tab({ Title = "Main", Icon = "lucide:house" })
local TabLighting = Window:Tab({ Title = "Lighting", Icon = "lucide:sun" })

local UnlockPremiumFeatures -- Forward Declaration

-- ==========================================
-- TAB PREMIUM
-- ==========================================
local InputKeyPremium = ""

TabPremium:Paragraph({ Title = '<font color="#ffd2a5">Mugiwara HUB Premium!</font>', Desc = '<font color="#ffffff">Upgrade to premium to unlock all premium features.</font>', Image = "rbxassetid://139792463546727", ImageSize = 75 })
TabPremium:Button({ Title = "Buy Premium Key", Desc = "Click to copy the link, then DM that account.", Icon = "lucide:copy", Callback = function() setclipboard("https://www.tiktok.com/@honamichanhere"); WindUI:Notify({ Title = "Copied!", Content = "TikTok link copied to clipboard.", Duration = 3 }) end })

local VIPSection = TabPremium:Section({ Title = "Premium Activation", Icon = "lucide:key", Opened = false, Box = true })
VIPSection:Input({ Title = "Premium Key", Placeholder = "Input key...", Callback = function(Text) InputKeyPremium = Text end })
VIPSection:Button({
    Title = "Click to activate",
    Callback = function()
        if InputKeyPremium == "LUFFY" then
            writefile(savedKeyPath, InputKeyPremium)
            isPremiumUser = true
            WindUI:Notify({ Title = "Valid Key!", Content = "Premium aktif & Key otomatis tersimpan!", Duration = 4 })
            UnlockPremiumFeatures()
        else
            WindUI:Notify({ Title = "Invalid Key!", Content = "Wrong key or not a premium key!", Duration = 3 })
        end
    end
})

-- ==========================================
-- TAB HOME
-- ==========================================
local UserInfo = TabHome:Paragraph({ Title = LocalPlayer.DisplayName, Desc = "Loading...", Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150", ImageSize = 100 })
task.spawn(function()
    while task.wait(1) do
        local realPing, realFPS = 0, 0
        pcall(function() realPing = math.round(LocalPlayer:GetNetworkPing() * 1000) end)
        pcall(function() realFPS = math.round(1 / RunService.RenderStepped:Wait()) end)
        pcall(function() UserInfo:SetDesc(string.format("User ID: %d\nAccount Age: %d Days\nRoblox Premium: %s\nKey Status: %s\nLocation: Hidden\nPing: %s ms | FPS: %s", LocalPlayer.UserId, LocalPlayer.AccountAge, premiumStatus, (isPremiumUser and "Premium Key" or "Free Key"), tostring(realPing), tostring(realFPS))) end)
    end
end)

TabHome:Divider({ Title = "Server Information" })
TabHome:Paragraph({ Title = gameName, Desc = string.format("Place ID: %d\nJob ID: %s\nPlayers: %d / %d", game.PlaceId, game.JobId, #Players:GetPlayers(), Players.MaxPlayers) })

TabHome:Divider({ Title = "Developer & Credits" })
TabHome:Button({ Title = "Official TikTok", Icon = "lucide:copy", Callback = function() setclipboard("https://www.tiktok.com/@honamichanhere") end })
TabHome:Button({ Title = "Official Discord", Icon = "lucide:copy", Callback = function() setclipboard("https://discord.gg/djmrevtSV7") end })
TabHome:Button({ Title = "UI Framework: WindUI", Icon = "lucide:copy", Callback = function() setclipboard("https://footagesus.github.io/WindUI-Docs") end })
TabHome:Button({ Title = "Authentication: Pandauth", Icon = "lucide:copy", Callback = function() setclipboard("https://ads.pandauth.com") end })

-- ==========================================
-- TAB MAIN
-- ==========================================
local PremiumMain = TabMain:Section({ Title = '<font color="#ffff82">Premium Features</font>', Icon = "rbxassetid://74594159374416", Opened = false, Box = true })
local VipToggleTest = PremiumMain:Toggle({ Title = "Tes", Locked = not isPremiumUser, Desc = "Tes toggle", Callback = nil })
local VipSliderTest = PremiumMain:Slider({ Title = "Tes", Locked = not isPremiumUser, Step = 1, Value = { Min = 0, Max = 10, Default = 1 }, Callback = nil })

local MovementSection = TabMain:Section({ Title = "Character Movements", Icon = "lucide:footprints", Opened = false, Box = true })
local ToggleTweenSpeed
local ToggleSpeed = MovementSection:Toggle({ Title = "Enable Speed Hack", Callback = function(Value) MovementModule.SpeedEnabled = Value; if not Value then MovementModule.RestoreSpeed() end; if Value and ToggleTweenSpeed then ToggleTweenSpeed:Set(false) end end })
MovementSection:Slider({ Title = "Speed Hack Value", Step = 1, Value = { Min = 0, Max = 200, Default = defaultWalkSpeed }, Callback = function(Value) MovementModule.SpeedValue = Value end })
ToggleTweenSpeed = MovementSection:Toggle({ Title = "Enable Tween Speed", Callback = function(Value) MovementModule.TweenSpeedEnabled = Value; if Value and ToggleSpeed then ToggleSpeed:Set(false) end end })
MovementSection:Slider({ Title = "Tween Speed Value", Step = 1, Value = { Min = 0, Max = 200, Default = defaultWalkSpeed }, Callback = function(Value) MovementModule.TweenSpeedValue = Value end })

MovementSection:Divider({ Title = "Jump & Flight" })
MovementSection:Toggle({ Title = "Enable Jump Power", Callback = function(Value) MovementModule.JumpEnabled = Value; if not Value then MovementModule.RestoreJump() end end })
MovementSection:Slider({ Title = "Jump Power Value", Step = 1, Value = { Min = 0, Max = 200, Default = defaultJumpPower }, Callback = function(Value) MovementModule.JumpValue = Value end })
MovementSection:Toggle({ Title = "Enable Fly", Callback = function(Value) MovementModule.ToggleFly(Value) end })
MovementSection:Slider({ Title = "Fly Speed", Step = 1, Value = { Min = 0, Max = 500, Default = 16 }, Callback = function(Value) MovementModule.FlySpeed = Value end })
MovementSection:Toggle({ Title = "Enable Noclip", Callback = function(Value) MovementModule.NoclipEnabled = Value end })

-- ==========================================
-- TAB LIGHTING
-- ==========================================
TabLighting:Divider({ Title = "System Control" })
TabLighting:Toggle({ Title = "Lock Lighting", Desc = "Force Override! Tahan semua nilai di sc ini", Locked = false, Callback = function(Value) LightingModule.LockEnabled = Value end })

local PremiumLighting = TabLighting:Section({ Title = '<font color="#ffff82">Premium Features</font>', Icon = "rbxassetid://74594159374416", Opened = false, Box = true })
local lockMsg = "Buy Premium to unlock!"

local VipLoadPreset = PremiumLighting:Dropdown({ Title = "Load Presets", Locked = not isPremiumUser, LockedTitle = lockMsg, Values = LightingModule.GetPresetsList(), Value = "Default", Callback = function(Option) LightingModule.LoadPreset(Option) end })
local VipSavePreset = PremiumLighting:Input({ Title = "Save Preset", Locked = not isPremiumUser, LockedTitle = lockMsg, Placeholder = "Preset Name", Callback = function(Text) LightingModule.SavePreset(Text); WindUI:Notify({ Title = "Tersimpan", Content = "Preset " .. Text .. " disimpan!", Duration = 3 }); VipLoadPreset:Refresh(LightingModule.GetPresetsList()) end })

local skyboxNames = {}
for name, _ in pairs(LightingModule.SkyboxDatabase) do table.insert(skyboxNames, name) end
local VipSkyBox = PremiumLighting:Dropdown({ Title = "Sky Box", Icon = "lucide:cloudy", Locked = not isPremiumUser, LockedTitle = lockMsg, Values = skyboxNames, Value = "Default Sky", Callback = function(Option) LightingModule.LoadSkybox(LightingModule.SkyboxDatabase[Option]) end })
local VipLoadSkyBox = PremiumLighting:Input({ Title = "Load Sky Box", Locked = not isPremiumUser, LockedTitle = lockMsg, Placeholder = "Asset ID", Callback = function(Text) LightingModule.LoadSkybox(Text) end })

local VipSkyAnim = PremiumLighting:Toggle({ Title = "Sky Box Animation", Locked = not isPremiumUser, LockedTitle = lockMsg, Callback = function(Value) LightingModule.SkyAnimEnabled = Value end })
local VipSkyRot = PremiumLighting:Slider({ Title = "Rotation Speed", Locked = not isPremiumUser, LockedTitle = lockMsg, Step = 1, Value = { Min = 0, Max = 100, Default = 10 }, Callback = function(Value) LightingModule.SkyAnimSpeed = Value end })
local VipCopySky = PremiumLighting:Button({ Title = "Copy Sky Box", Locked = not isPremiumUser, LockedTitle = lockMsg, Callback = function() LightingModule.CopySkybox(); WindUI:Notify({Title="Disalin", Content="SkyBox disalin ke sistem!", Duration=2}) end })
local VipPasteSky = PremiumLighting:Button({ Title = "Paste Sky Box", Locked = not isPremiumUser, LockedTitle = lockMsg, Callback = function() LightingModule.PasteSkybox() end })

local Lighting = TabLighting:Section({ Title = "Lighting", Icon = "lucide:haze", Opened = false, Box = true })
Lighting:Colorpicker({ Title = "Ambient", Callback = function(Value) LightingModule.UpdateValue("Lighting", "Ambient", Value) end })
Lighting:Slider({ Title = "Brightness", Step = 0.1, Value = { Min = LightingModule.Limits.Lighting.Brightness.Min, Max = LightingModule.Limits.Lighting.Brightness.Max, Default = LightingModule.Defaults.Lighting.Brightness }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "Brightness", Value) end })
Lighting:Slider({ Title = "Clock Time", Step = 0.1, Value = { Min = LightingModule.Limits.Lighting.ClockTime.Min, Max = LightingModule.Limits.Lighting.ClockTime.Max, Default = LightingModule.Defaults.Lighting.ClockTime }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ClockTime", Value) end })
Lighting:Slider({ Title = "Exposure Compensation", Step = 0.1, Value = { Min = LightingModule.Limits.Lighting.ExposureCompensation.Min, Max = LightingModule.Limits.Lighting.ExposureCompensation.Max, Default = LightingModule.Defaults.Lighting.ExposureCompensation }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ExposureCompensation", Value) end })

local Atmosphere = TabLighting:Section({ Title = "Atmosphere", Icon = "lucide:sun-dim", Opened = false, Box = true })
Atmosphere:Slider({ Title = "Density", Step = 0.01, Value = { Min = LightingModule.Limits.Atmosphere.Density.Min, Max = LightingModule.Limits.Atmosphere.Density.Max, Default = LightingModule.Defaults.Atmosphere.Density }, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Density", Value) end })
Atmosphere:Colorpicker({ Title = "Color", Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Color", Value) end })

local Bloom = TabLighting:Section({ Title = "Bloom", Icon = "lucide:target", Opened = false, Box = true })
Bloom:Toggle({ Title = "Enabled", Callback = function(Value) LightingModule.ToggleEffect("Bloom", Value) end })
Bloom:Slider({ Title = "Intensity", Step = 0.1, Value = { Min = LightingModule.Limits.Bloom.Intensity.Min, Max = LightingModule.Limits.Bloom.Intensity.Max, Default = LightingModule.Defaults.Bloom.Intensity }, Callback = function(Value) LightingModule.UpdateValue("Bloom", "Intensity", Value) end })

local ColorCorrection = TabLighting:Section({ Title = "Color Correction", Icon = "lucide:palette", Opened = false, Box = true })
ColorCorrection:Toggle({ Title = "Enabled", Callback = function(Value) LightingModule.ToggleEffect("ColorCorrection", Value) end })
ColorCorrection:Slider({ Title = "Saturation", Step = 0.01, Value = { Min = LightingModule.Limits.ColorCorrection.Saturation.Min, Max = LightingModule.Limits.ColorCorrection.Saturation.Max, Default = LightingModule.Defaults.ColorCorrection.Saturation }, Callback = function(Value) LightingModule.UpdateValue("ColorCorrection", "Saturation", Value) end })

Window:EditOpenButton({ Title = "Open Mugiwara HUB", CornerRadius = UDim.new(1, 0), OnlyMobile = false, Enabled = true, Draggable = true })
TabHome:Select()

-- ==========================================
-- FUNGSI UNLOCK PREMIUM
-- ==========================================
function UnlockPremiumFeatures()
    VipToggleTest:Unlock()
    VipSliderTest:Unlock()
    VipLoadPreset:Unlock()
    VipSavePreset:Unlock()
    VipSkyBox:Unlock()
    VipLoadSkyBox:Unlock()
    VipSkyAnim:Unlock()
    VipSkyRot:Unlock()
    VipCopySky:Unlock()
    VipPasteSky:Unlock()
end

if isPremiumUser then
    task.defer(UnlockPremiumFeatures)
end
