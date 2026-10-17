local VERSION = "1.1.0"

-- ==========================================================
-- RE-EXECUTION SAFETY
-- Every module registers a cleanup function through
-- getgenv().MugiwaraRegisterCleanup(fn). When Main.lua runs again (re-execute or
-- the premium reload) all previous cleanups run first, so connections, loops and
-- instances from the old session never stack on top of the new one.
-- ==========================================================
local env = getgenv()

local function RunCleanups()
    local cleanups = env.MugiwaraCleanup
    env.MugiwaraCleanup = {}
    env.MugiwaraModules = {} -- module cache dikosongkan supaya sesi berikutnya mulai dari bersih
    if not cleanups then return end
    for i = #cleanups, 1, -1 do
        local ok, err = pcall(cleanups[i])
        if not ok then warn("[Mugiwara HUB] Cleanup error: " .. tostring(err)) end
    end
end

RunCleanups()

-- Used by the "Unload Hub" button: same teardown as a re-execute, without loading again.
-- A teleport already queued by queue_on_teleport cannot be cancelled by the executor.
env.MugiwaraUnload = RunCleanups

env.MugiwaraRegisterCleanup = function(fn)
    if type(fn) == "function" then table.insert(env.MugiwaraCleanup, fn) end
end

if env.MugiwaraExecuted then
    pcall(function()
        for _, gui in pairs(game:GetService("CoreGui"):GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name == "WindUI" then gui:Destroy() end
        end
    end)
end
env.MugiwaraExecuted = true

-- ==========================================================
-- SOURCE LOCATION
-- All hub files are loaded from one base URL. The branch defaults to "main".
-- To test another branch (for example "dev") without editing any file, set
-- getgenv().MugiwaraBranch = "dev" before loading Main.lua from that branch.
-- For a pinned release, put a commit hash in MugiwaraBranch instead.
-- ==========================================================
local BRANCH = env.MugiwaraBranch or "main"
local BASE_URL = "https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/" .. BRANCH .. "/"
local MAX_KEY_LENGTH = 128

-- Results are cached per session: importing the same path twice returns the SAME module
-- instance. Without this, a module imported by two tabs (e.g. Movement by the Main tab
-- and by the Misc shortcuts) would run twice and register duplicate connections.
env.MugiwaraModules = env.MugiwaraModules or {}

env.MugiwaraImport = function(path)
    local cached = env.MugiwaraModules[path]
    if cached ~= nil then return cached end

    local ok, result = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. path))()
    end)
    if not ok then
        warn("[Mugiwara HUB] Failed to load " .. path .. ": " .. tostring(result))
        return nil
    end

    env.MugiwaraModules[path] = result
    return result
end

-- Queue the hub for the next teleport once per server. Keying the flag on JobId means a
-- re-execute in the same server does not queue a duplicate, while every new server can
-- queue again (a plain boolean flag would block all teleports after the first).
local queue_on_tp = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
if queue_on_tp and env.MugiwaraTeleportQueuedFor ~= game.JobId then
    env.MugiwaraTeleportQueuedFor = game.JobId
    local branchPrefix = (BRANCH ~= "main") and ('getgenv().MugiwaraBranch = "' .. BRANCH .. '"; ') or ""
    queue_on_tp(branchPrefix .. 'loadstring(game:HttpGet("' .. BASE_URL .. 'Main.lua"))()')
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- LOCAL DATA FOLDER (executor workspace)
-- Renamed from "HonamiHub" to "MugiwaraHub". Existing users keep their saved premium
-- key, presets and copied skybox: the old folder is copied over once.
local FOLDER = "MugiwaraHub"
local LEGACY_FOLDER = "HonamiHub"
env.MugiwaraFolder = FOLDER

local function MigrateLegacyData()
    if not (isfolder and isfile and makefolder and readfile and writefile and listfiles) then return end
    if not isfolder(LEGACY_FOLDER) or isfolder(FOLDER) then return end

    makefolder(FOLDER)
    local function copyFile(relativePath)
        local from, to = LEGACY_FOLDER .. "/" .. relativePath, FOLDER .. "/" .. relativePath
        if isfile(from) then pcall(function() writefile(to, readfile(from)) end) end
    end

    copyFile("PremiumKey.txt")
    copyFile("CopiedSky.json")
    if isfolder(LEGACY_FOLDER .. "/Presets") then
        makefolder(FOLDER .. "/Presets")
        for _, file in ipairs(listfiles(LEGACY_FOLDER .. "/Presets")) do
            local name = file:match("([^/\\]+)$")
            if name then copyFile("Presets/" .. name) end
        end
    end
end
pcall(MigrateLegacyData)

if makefolder and isfolder and not isfolder(FOLDER) then makefolder(FOLDER) end

-- PANDA AUTH PUSL-V4 SYSTEM
local savedKeyPath = FOLDER .. "/PremiumKey.txt"
local isPremiumUser = false

local libOk, PUSL = pcall(function() return loadstring(game:HttpGet("https://secure.pandauth.com/pv4/lib"))() end)
if not libOk or type(PUSL) ~= "table" or type(PUSL.configure) ~= "function" then
    LocalPlayer:Kick("[Panda Auth] Library failed to initialize.")
    return
end

PUSL.configure({ serviceId = "honami" })

-- Premium status comes ONLY from the isPremium flag returned by the Panda Auth server,
-- never from the shape of the key string.
local function ValidateKey(inputKey)
    inputKey = tostring(inputKey or ""):match("^%s*(.-)%s*$")
    if inputKey == "" or #inputKey > MAX_KEY_LENGTH then
        return false, false, { message = "Invalid key format." }
    end

    local ok, result = pcall(PUSL.validate, inputKey)
    if not ok or type(result) ~= "table" then
        return false, false, { message = "Could not reach the auth server.", offline = true }
    end
    return result.success == true, result.isPremium == true, result
end

if readfile and isfile and isfile(savedKeyPath) then
    local okRead, savedKey = pcall(readfile, savedKeyPath)
    if okRead then
        local isValid, isPrem, result = ValidateKey(savedKey)
        if isValid and isPrem then
            isPremiumUser = true
        elseif delfile and not (result and result.offline) then
            -- Delete the saved key only when the server actually rejects it,
            -- not when the user is simply offline.
            pcall(delfile, savedKeyPath)
        end
    end
end

-- SETUP WIND UI & THEME
local uiOk, WindUI = pcall(function() return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))() end)
if not uiOk or type(WindUI) ~= "table" then
    LocalPlayer:Kick("[Mugiwara HUB] UI library failed to load. Please try again.")
    return
end
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
    Title = "Mugiwara HUB", Icon = "lucide:sparkles", Author = "by Honami", Folder = "MugiwaraHubConfig",
    Size = UDim2.fromOffset(580, 390), Transparent = true, Theme = "Luffy",
}

if not isPremiumUser then
    windowConfig.KeySystem = {
        Key = "LUFFY", Note = "Enter the Free Key or Premium Key.", URL = PUSL.getKeyUrl(), SaveKey = true,
        KeyValidator = function(inputKey)
            local isValid, isPrem, result = ValidateKey(inputKey)
            if isValid then
                if isPrem then
                    -- The window is only created after the key is accepted, so the tabs
                    -- below load in premium mode without needing a reload.
                    isPremiumUser = true
                    if writefile then pcall(writefile, savedKeyPath, (tostring(inputKey):match("^%s*(.-)%s*$"))) end
                    WindUI:Notify({ Title = "Premium Access!", Content = "Premium Key Valid!", Duration = 3 })
                else
                    WindUI:Notify({ Title = "Free Access!", Content = "Free Key Valid!", Duration = 3 })
                end
                return true 
            else
                WindUI:Notify({ Title = "Validation Failed!", Content = result.message or result.error or result.reason or "Invalid Key!", Duration = 3 })
                return false
            end
        end
    }
end

-- WindUI's built-in "Get key" button copies the link silently. While the key window is
-- open, setclipboard is wrapped so a notification appears when the key link is copied,
-- then the original function is restored once the window has been created.
local originalSetClipboard = setclipboard
if not isPremiumUser and originalSetClipboard and windowConfig.KeySystem then
    local keyUrl = windowConfig.KeySystem.URL
    getgenv().setclipboard = function(text, ...)
        local ok, err = pcall(originalSetClipboard, text, ...)
        if ok and text == keyUrl then
            pcall(function()
                WindUI:Notify({ Title = "Key Link Copied", Content = "Paste it in your browser to get your key.", Duration = 4 })
            end)
        end
        if not ok then error(err, 0) end
    end
end

local Window = WindUI:CreateWindow(windowConfig)

if originalSetClipboard then getgenv().setclipboard = originalSetClipboard end
Window:Tag({ Title = "v" .. VERSION, Icon = "lucide:refresh-ccw-dot", Color = Color3.fromHex("#ffbe6e"), Radius = 13 })
env.MugiwaraRegisterCleanup(function() Window:Destroy() end)

-- Locked state is decided when each element is created, so after activating through the
-- "Verify & Activate" button the hub reloads to unlock every premium feature.
UnlockPremiumFeatures = function()
    WindUI:Notify({ Title = "Premium Unlocked", Content = "Reloading hub to unlock premium features...", Duration = 3 })
    task.delay(1.5, function()
        pcall(function() Window:Destroy() end)
        local ok, err = pcall(function() loadstring(game:HttpGet(BASE_URL .. "Main.lua"))() end)
        if not ok then warn("[Mugiwara HUB] Reload failed: " .. tostring(err)) end
    end)
end

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
                if writefile then pcall(writefile, savedKeyPath, (tostring(InputKeyPremium):match("^%s*(.-)%s*$"))) end
                isPremiumUser = true
                WindUI:Notify({ Title = "Authentication Successful", Content = "Premium access granted and key safely stored.", Duration = 3 })

                PremiumParagraph:SetDesc('<font color="#ffffff">You are already a Premium user! Thank you for your continued support.</font>')

                if BtnBuyPremium then BtnBuyPremium:Destroy() end
                if VIPSection then VIPSection:Destroy() end
                UnlockPremiumFeatures()
            else
                WindUI:Notify({ Title = "Authentication Failed", Content = result.message or result.error or result.reason or "Invalid, expired, or non-premium key provided.", Duration = 3 })
            end
        end
    })
end

-- GLOBAL TABS & GAME DETECTOR
local GlobalTabs = { "Tabs/HomeTab.lua", "Tabs/LightingTab.lua", "Tabs/CameraTab.lua" }

local function LoadGlobalTabs()
    for _, path in ipairs(GlobalTabs) do
        local build = getgenv().MugiwaraImport(path)
        if type(build) == "function" then
            local ok, err = pcall(build, Window, isPremiumUser, WindUI)
            if not ok then warn("[Mugiwara HUB] Tab " .. path .. " error: " .. tostring(err)) end
        end
    end
end

LoadGlobalTabs()

local currentPlaceId = game.PlaceId
local UniversalModulePath = "Universal.lua"
local TargetModulePath = nil

-- Register new games here (PlaceIds + path to the game's Init.lua).
local SupportedGames = {
    Evade = { PlaceIds = { 9872472334, 99214917572799, 10668472534 }, Path = "Games/Evade/Init.lua" },
}

for _, data in pairs(SupportedGames) do
    for _, id in ipairs(data.PlaceIds) do
        if id == currentPlaceId then
            TargetModulePath = data.Path
            break
        end
    end
end

local moduleLoaded = false

if TargetModulePath then
    local func = getgenv().MugiwaraImport(TargetModulePath)
    if type(func) == "function" then
        task.spawn(func, Window, isPremiumUser, WindUI)
        moduleLoaded = true
    end
end

if not moduleLoaded then
    local func = getgenv().MugiwaraImport(UniversalModulePath)
    if type(func) == "function" then
        task.spawn(func, Window, isPremiumUser, WindUI)
    end
end

-- Misc is global and is created after the game's Main tab so it always sits below it.
local buildMisc = getgenv().MugiwaraImport("Tabs/MiscTab.lua")
if type(buildMisc) == "function" then
    local ok, err = pcall(buildMisc, Window, isPremiumUser, WindUI)
    if not ok then warn("[Mugiwara HUB] Misc tab error: " .. tostring(err)) end
end

Window:EditOpenButton({ Title = "Open Mugiwara HUB", CornerRadius = UDim.new(1, 0), OnlyMobile = false, Enabled = true, Draggable = true })
