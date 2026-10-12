-- ANTI-DUPLICATE & AUTO-EXECUTE
if getgenv().HonamiHub_Executed then
    pcall(function()
        for _, gui in pairs(game:GetService("CoreGui"):GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name == "WindUI" then gui:Destroy() end
        end
    end)
end
getgenv().HonamiHub_Executed = true

local queue_on_tp = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
if queue_on_tp then
    queue_on_tp('loadstring(game:HttpGet("LINK_RAW_SCRIPT_UTAMA_LU"))()')
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- PANDA AUTH PUSL-V4 SYSTEM
local savedKeyPath = "HonamiHub/PremiumKey.txt"
local isPremiumUser = false

if makefolder and isfolder and not isfolder("HonamiHub") then makefolder("HonamiHub") end

local PUSL = loadstring(game:HttpGet("https://secure.pandauth.com/pv4/lib"))()
if not PUSL or type(PUSL.configure) ~= "function" then
    LocalPlayer:Kick("[Panda Auth] Library failed to initialize.")
    return
end

PUSL.configure({ serviceId = "honami" })

local function ValidateKey(inputKey)
    local result = PUSL.validate(inputKey)
    local customPremiumCheck = not string.match(inputKey, "^PANDA")
    return result.success, (result.isPremium or customPremiumCheck), result
end

if readfile and isfile and isfile(savedKeyPath) then
    local savedKey = readfile(savedKeyPath)
    local isValid, isPrem, _ = ValidateKey(savedKey)
    if isValid and isPrem then isPremiumUser = true else if delfile then delfile(savedKeyPath) end end
end

-- SETUP WIND UI & THEME
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local ThemesList = WindUI:GetThemes()

ThemesList["Luffy"] = {}
for key, value in pairs(ThemesList["Dark"]) do ThemesList["Luffy"][key] = value end
ThemesList["Luffy"].Accent = Color3.fromHex("#ffffff")
ThemesList["Luffy"].Background = WindUI:Gradient({ ["0"] = { Color = Color3.fromHex("#643c23"), Transparency = 0 }, ["100"] = { Color = Color3.fromHex("#321900"), Transparency = 0 }},{ Rotation = -90 })
ThemesList["Luffy"].BackgroundTransparency = 0.5
ThemesList["Luffy"].Outline = Color3.fromHex("#ff9132")
ThemesList["Luffy"].Text = Color3.fromHex("#ffffff")
ThemesList["Luffy"].Placeholder = Color3.fromHex("#3c2819")
ThemesList["Luffy"].Button = Color3.fromHex("#7d4b32")
ThemesList["Luffy"].Icon = Color3.fromHex("#ffffff")
ThemesList["Luffy"].WindowShadow = Color3.fromHex("#000000")
ThemesList["Luffy"].WindowTopbarIcon = Color3.fromHex("#ffffff")
ThemesList["Luffy"].WindowTopbarTitle = Color3.fromHex("#ffdcc8")
ThemesList["Luffy"].WindowTopbarAuthor = Color3.fromHex("#ffb98c")
ThemesList["Luffy"].WindowTopbarButtonIcon = Color3.fromHex("#ffffff")
ThemesList["Luffy"].TabBackground = Color3.fromHex("#ff4b00")
ThemesList["Luffy"].TabTitle = Color3.fromHex("#ffffff")
ThemesList["Luffy"].TabIcon = Color3.fromHex("#ffffff")
ThemesList["Luffy"].ElementBackground = Color3.fromHex("#b9784b")
ThemesList["Luffy"].ElementTitle = Color3.fromHex("#ffffff")
ThemesList["Luffy"].ElementDesc = Color3.fromHex("#c8c8c8")
ThemesList["Luffy"].ElementIcon = Color3.fromHex("#ffffff")
ThemesList["Luffy"].Toggle = Color3.fromHex("#ffaf64")
ThemesList["Luffy"].ToggleBar = Color3.fromHex("#ffffff")
ThemesList["Luffy"].PopupBackground = Color3.fromHex("#643c23")
ThemesList["Luffy"].PopupBackgroundTransparency = 0.5
ThemesList["Luffy"].PopupTitle = Color3.fromHex("#ff6400")
ThemesList["Luffy"].PopupContent = Color3.fromHex("#ffffff")
ThemesList["Luffy"].PopupIcon = Color3.fromHex("#ffffff")
ThemesList["Luffy"].DialogBackground = Color3.fromHex("#1F1108")
ThemesList["Luffy"].DialogBackgroundTransparency = 0.5
ThemesList["Luffy"].DialogTitle = Color3.fromHex("#FFD700")
ThemesList["Luffy"].DialogContent = Color3.fromHex("#ffffff")
ThemesList["Luffy"].DialogIcon = Color3.fromHex("#FF8C00")

local UnlockPremiumFeatures

local windowConfig = {
    Title = "Mugiwara HUB", Icon = "lucide:sparkles", Author = "by Honami", Folder = "HonamiHubConfig",
    Size = UDim2.fromOffset(580, 390), Transparent = true, Theme = "Luffy",
}

if not isPremiumUser then
    windowConfig.KeySystem = {
        Key = "LUFFY", Note = "Enter the Free Key or Premium Key.", URL = PUSL.getKeyUrl(), SaveKey = true,
        KeyValidator = function(inputKey)
            local isValid, isPrem, result = ValidateKey(inputKey)
            if isValid then
                if isPrem then
                    isPremiumUser = true
                    if writefile then writefile(savedKeyPath, inputKey) end 
                    WindUI:Notify({ Title = "Premium Access!", Content = "Premium Key Valid!", Duration = 3 })
                    task.spawn(function() task.wait(1); if UnlockPremiumFeatures then UnlockPremiumFeatures() end end)
                else
                    WindUI:Notify({ Title = "Free Access!", Content = "Free Key Valid!", Duration = 3 })
                end
                return true 
            else
                WindUI:Notify({ Title = "Validation Failed!", Content = result.message or result.error or "Invalid Key!", Duration = 3 })
                return false
            end
        end
    }
end

local Window = WindUI:CreateWindow(windowConfig)
Window:Tag({ Title = "v1.0.0", Icon = "lucide:refresh-ccw-dot", Color = Color3.fromHex("#ffbe6e"), Radius = 13 })

-- TAB PREMIUM ACCESS (GLOBAL)
local TabPremium = Window:Tab({ Title = '<font color="#ffff82">Premium Access</font>', Icon = "lucide:crown", IconColor = Color3.fromHex("#ffff82") })
local InputKeyPremium = ""

local PremiumParagraph = TabPremium:Paragraph({
    Title = '<font color="#ffd2a5">Mugiwara HUB Premium</font>',
    Desc = isPremiumUser and '<font color="#ffffff">You are already a Premium user! Thank you for your continued support.</font>' or '<font color="#ffffff">Upgrade to Premium to unlock exclusive features across all categories.</font>',
    Image = "rbxassetid://139792463546727", 
    ImageSize = 75 
})

if not isPremiumUser then
    local BtnBuyPremium = TabPremium:Button({
        Title = "Purchase Premium Key", 
        Desc = "Click to copy the official TikTok link, then send a direct message to purchase.", 
        Icon = "lucide:shopping-cart",
        Callback = function() 
            if setclipboard then setclipboard("https://tiktok.com/@honamichanhere") end
            WindUI:Notify({ Title = "Action Successful", Content = "The purchase link has been copied to your clipboard.", Duration = 5 }) 
        end
    })

    local VIPSection = TabPremium:Section({ Title = "Premium Activation", Icon = "lucide:key", Opened = true, Box = true })
    
    VIPSection:Input({ 
        Title = "Premium Key", 
        Placeholder = "Enter your premium key here...", 
        Callback = function(Text) InputKeyPremium = Text end 
    })
    
    VIPSection:Button({
        Title = "Verify & Activate",
        Callback = function()
            if InputKeyPremium == "" then return end
            WindUI:Notify({ Title = "Validation in Progress", Content = "Connecting to Panda Auth server...", Duration = 2 })
            
            local isValid, isPrem, result = ValidateKey(InputKeyPremium)
            if isValid and isPrem then
                if writefile then writefile(savedKeyPath, InputKeyPremium) end
                isPremiumUser = true
                WindUI:Notify({ Title = "Authentication Successful", Content = "Premium access granted and key safely stored.", Duration = 3 })
                
                if UnlockPremiumFeatures then UnlockPremiumFeatures() end
                PremiumParagraph:SetDesc('<font color="#ffffff">You are already a Premium user! Thank you for your continued support.</font>')
                
                if BtnBuyPremium then BtnBuyPremium:Destroy() end
                if VIPSection then VIPSection:Destroy() end
            else
                WindUI:Notify({ Title = "Authentication Failed", Content = result.message or result.error or "Invalid, expired, or non-premium key provided.", Duration = 3 })
            end
        end
    })
end

-- GLOBAL TABS & GAME DETECTOR
local function LoadGlobalTabs()
    local loadHome = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/Tabs/HomeTab.lua"))
    if loadHome then loadHome()(Window, isPremiumUser, WindUI) end
    
    local loadLighting = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/Tabs/LightingTab.lua"))
    if loadLighting then loadLighting()(Window, isPremiumUser, WindUI) end
    
    local loadCamera = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/Tabs/CameraTab.lua"))
    if loadCamera then loadCamera()(Window, isPremiumUser, WindUI) end
end

LoadGlobalTabs()

local currentPlaceId = game.PlaceId
local UniversalModuleURL = "https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/Universal.lua" 
local TargetModuleURL = nil

local SupportedGames = {
    Evade = { PlaceIds = { 9872472334, 99214917572799, 10668472534 }, URL = "https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/Games/Evade/Init.lua" },
    VD = { PlaceIds = { 1234567890 }, URL = "URL_GITHUBLU_NANTI_VD_INIT.LUA" }
}

for _, data in pairs(SupportedGames) do
    for _, id in ipairs(data.PlaceIds) do
        if id == currentPlaceId then
            TargetModuleURL = data.URL
            break
        end
    end
end

local moduleLoaded = false

if TargetModuleURL then
    local success, func = pcall(function() return loadstring(game:HttpGet(TargetModuleURL))() end)
    if success and type(func) == "function" then
        task.spawn(func, Window, isPremiumUser, WindUI)
        moduleLoaded = true
    end
end

if not moduleLoaded then
    local success, func = pcall(function() return loadstring(game:HttpGet(UniversalModuleURL))() end)
    if success and type(func) == "function" then
        task.spawn(func, Window, isPremiumUser, WindUI)
    end
end

Window:EditOpenButton({ Title = "Open Mugiwara HUB", CornerRadius = UDim.new(1, 0), OnlyMobile = false, Enabled = true, Draggable = true })
