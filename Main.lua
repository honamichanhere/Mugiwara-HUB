local VERSION = "1.2.0"

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
    -- Sisa dari versi hub yang masih memakai WindUI (satu kali, setelah update ke Mugiwara UI).
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

-- Loading screen (MugiwaraUI:Loading) menutupi proses load hub. Kapan dimulai tergantung ada
-- tidaknya key tersimpan (lihat StartLoader di bawah). Kalau gagal dibuat, hub tetap jalan tanpa
-- loading screen. Semua fungsi Loader* aman dipanggil sebelum loading screen dibuat (tidak
-- melakukan apa-apa).
env.MugiwaraVersion = VERSION
local MugiwaraUI = nil -- diisi setelah library dimuat (lihat "MUGIWARA UI" di bawah)
local Loader = nil

local function LoaderStatus(text)
    if Loader then pcall(function() Loader:SetStatus(text) Loader:Log(text, "info") end) end
end

-- Persen loading mengikuti tahap asli: `target` = persen setelah tahap ini selesai,
-- `cap` = batas rayapan selama tahap berikutnya masih berjalan.
local function LoaderProgress(target, cap)
    if Loader then pcall(function() Loader:SetProgress(target, cap) end) end
end

local function LoaderDestroy()
    if Loader then pcall(function() Loader:Destroy() end) Loader = nil end
end

local function StartLoader()
    if Loader then return end

    local ok, result = pcall(function()
        return MugiwaraUI:Loading({
            Title = "Mugiwara HUB",
            Owner = "Honami",
            Version = "v" .. VERSION,
            InstantCover = env.MugiwaraLoaderInstantCover == true,
        })
    end)
    if ok and type(result) == "table" then
        Loader = result
        env.MugiwaraRegisterCleanup(function() pcall(function() result:Destroy() end) end)
        LoaderProgress(4, 13)
    elseif not ok then
        warn("[Mugiwara HUB] Loading screen failed: " .. tostring(result))
    end
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

-- MUGIWARA UI
-- Dimuat lebih dulu karena loading screen dan layar key adalah bagian dari library. Versinya
-- dipatok ke satu tag (tag tidak pernah berubah, jadi push baru ke library tidak merusak hub).
-- Untuk memakai versi library yang lebih baru, ganti tag-nya di sini.
local UI_VERSION = "v0.10.0"
local UI_URL = "https://raw.githubusercontent.com/honamichanhere/Mugiwara-UI/" .. UI_VERSION .. "/dist/main.lua"

local uiOk, uiResult = pcall(function() return loadstring(game:HttpGet(UI_URL))() end)
if not uiOk or type(uiResult) ~= "table" or type(uiResult.CreateWindow) ~= "function" then
    LocalPlayer:Kick("[Mugiwara HUB] UI library failed to load. Please try again.")
    return
end
MugiwaraUI = uiResult
env.MugiwaraRegisterCleanup(function() pcall(function() MugiwaraUI:Destroy() end) end)

-- Pengaturan tampilan tersimpan (tema pilihan user dan tema buatannya) dipasang sebelum layar key
-- dan loading screen dibuat, supaya keduanya sudah memakai tema yang dipilih.
local UISettings = env.MugiwaraImport("Manager/UISettings.lua")
if UISettings then
    local okSettings, errSettings = pcall(function()
        UISettings.Load()
        UISettings.RegisterThemes(MugiwaraUI)
        MugiwaraUI:SetTheme(UISettings.Get("Theme"))
    end)
    if not okSettings then warn("[Mugiwara HUB] UI settings error: " .. tostring(errSettings)) end
    env.MugiwaraRegisterCleanup(UISettings.Flush)
end

-- Alamat server chat (Cloudflare Worker milik Mugiwara UI), contoh "https://mugiwara-chat.<akun>.workers.dev".
-- Kosong = tab Chat hanya menampilkan penjelasan.
local CHAT_URL = "https://mugiwara-chat.mugiwara-chat-worker.workers.dev"

-- PANDA AUTH PUSL-V4 SYSTEM
local savedKeyPath = FOLDER .. "/PremiumKey.txt"
local isPremiumUser = false

-- Key tersimpan = langsung proses load, jadi loading screen tampil dari awal. Tanpa key tersimpan
-- (perangkat baru) layar key harus muncul lebih dulu; loading screen baru dibuat setelah key
-- valid dan window dibuat. Kalau key tersimpan ternyata ditolak, loading screen disembunyikan
-- otomatis saat layar key muncul (lihat sebelum CreateWindow).
if readfile and isfile and isfile(savedKeyPath) then StartLoader() end

LoaderStatus("Loading Panda Auth")
local libOk, PUSL = pcall(function() return loadstring(game:HttpGet("https://secure.pandauth.com/pv4/lib"))() end)
if not libOk or type(PUSL) ~= "table" or type(PUSL.configure) ~= "function" then
    LoaderDestroy()
    LocalPlayer:Kick("[Panda Auth] Library failed to initialize.")
    return
end

PUSL.configure({ serviceId = "honami" })
LoaderProgress(14, 23)

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
    LoaderStatus("Checking saved key")
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

-- KEY
LoaderProgress(24, 42)

-- Tanpa key premium yang valid, layar key (komponen Mugiwara UI) tampil. Kalau loading screen sudah
-- berjalan karena ada key tersimpan yang ditolak, loading screen ditutup dulu dan dibuat lagi setelah
-- key diterima. Key yang diterima disimpan oleh library dan divalidasi ulang di run berikutnya
-- (Validate dipanggil lagi dengan key itu), jadi layar key hanya muncul sekali.
if not isPremiumUser then
    LoaderDestroy()

    local keyOptions = {
        Title = "Mugiwara HUB",
        Subtitle = "by Honami",
        Icon = "lucide:sparkles",
        Note = "Enter the Free Key or Premium Key.",
        Folder = "MugiwaraHubConfig",
        SaveKey = true,
        Validate = function(inputKey)
            local isValid, isPrem, result = ValidateKey(inputKey)
            if not isValid then
                return false, result.message or result.error or result.reason or "Invalid key!"
            end

            if isPrem then
                -- Window baru dibuat setelah key diterima, jadi tab premium langsung terbuka.
                isPremiumUser = true
                if writefile then pcall(writefile, savedKeyPath, (tostring(inputKey):match("^%s*(.-)%s*$"))) end
                return true, "Premium key accepted"
            end
            return true, "Free key accepted"
        end,
    }

    local keyUrl = PUSL.getKeyUrl()
    if keyUrl then
        keyOptions.Links = { { Title = "Get Key", Icon = "lucide:external-link", Link = keyUrl } }
    end

    local KeyUI = MugiwaraUI:KeySystem(keyOptions)
    if not KeyUI:Wait() then return end -- kartu key ditutup tanpa key: hub tidak dimuat
end

-- WINDOW
LoaderProgress(44, 51)
LoaderStatus("Creating window")

local Window = MugiwaraUI:CreateWindow({
    Title = "Mugiwara HUB",
    Subtitle = "by Honami",
    Icon = "lucide:sparkles",
    Folder = "MugiwaraHubConfig",
    Version = "v" .. VERSION,
    Size = UDim2.fromOffset(640, 420),
})
env.MugiwaraRegisterCleanup(function() Window:Destroy() end)

-- Window dibangun dalam keadaan tertutup selama loading screen tampil, lalu dibuka lagi dengan
-- animasi pop-up di akhir (ShowWindowWithPopup). Library membuka window sendiri saat dibuat, jadi
-- langsung ditutup di frame yang sama (belum ada yang sempat terlihat). ScreenGui-nya SENGAJA tetap
-- menyala: layout elemen tidak dihitung pada ScreenGui yang dimatikan, jadi tab yang dibangun
-- selagi mati bisa tampil kosong.
pcall(function()
    Window:Close()
    -- Close() memunculkan tombol buka kecil; tombol itu baru boleh muncul kalau user menutup window.
    if Window.OpenButton then Window.OpenButton.Visible = false end
end)

-- Tambahan dari sisi hub untuk hal yang tidak ada di library (teks "Premium Only", gambar di
-- samping Paragraph, judul Tab/Section berwarna, SetValue/SetColor, event buka/tutup).
local UIExtras = env.MugiwaraImport("Manager/UIExtras.lua")
if UIExtras then
    local okExtras, errExtras = pcall(UIExtras.Install, MugiwaraUI, Window)
    if not okExtras then warn("[Mugiwara HUB] UIExtras error: " .. tostring(errExtras)) end
end

-- Skala, blur, dan wallpaper tersimpan (tema sudah terpasang di atas).
if UISettings then
    local okApply, errApply = pcall(UISettings.ApplyAll, MugiwaraUI, Window)
    if not okApply then warn("[Mugiwara HUB] UI settings apply error: " .. tostring(errApply)) end
end

-- Key valid (atau lolos tanpa layar key): kalau loading screen belum dibuat, mulai sekarang
-- sehingga animasi masuknya terlihat. Loading screen langsung menutup layar (tanpa fade) supaya
-- tab yang dibangun tidak kelihatan.
if not Loader then
    env.MugiwaraLoaderInstantCover = true
    StartLoader()
    env.MugiwaraLoaderInstantCover = nil
end
if Loader then
    LoaderProgress(52, 52 + math.floor(18 / 3) - 1)
    LoaderStatus("Building tabs")
end

-- Locked state is decided when each element is created, so after activating through the
-- "Verify & Activate" button the hub reloads to unlock every premium feature.
UnlockPremiumFeatures = function()
    MugiwaraUI:Notify({ Title = "Premium Unlocked", Content = "Reloading hub to unlock premium features...", Duration = 3 })
    task.delay(1.5, function()
        pcall(function() Window:Destroy() end)
        local ok, err = pcall(function() loadstring(game:HttpGet(BASE_URL .. "Main.lua"))() end)
        if not ok then warn("[Mugiwara HUB] Reload failed: " .. tostring(err)) end
    end)
end

-- TAB PREMIUM ACCESS (GLOBAL)
local PREMIUM_GOLD = Color3.fromRGB(255, 255, 130) -- sama dengan #ffff82 pada judul premium
local TabPremium = Window:Tab({ Title = '<font color="#ffff82">Premium Access</font>', Icon = "lucide:crown", IconColor = PREMIUM_GOLD })
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
        IconColor = PREMIUM_GOLD,
        Callback = function() 
            if setclipboard then setclipboard("https://tiktok.com/@honamichanhere") end
            MugiwaraUI:Notify({ Title = "Action Successful", Content = "The purchase link has been copied to your clipboard.", Duration = 5 }) 
        end
    })

    local VIPSection = TabPremium:Section({ Title = "Premium Activation", Icon = "lucide:key", IconColor = PREMIUM_GOLD, Opened = true, Box = true })

    VIPSection:Input({
        Title = "Premium Key",
        Icon = "lucide:key-round",
        IconColor = PREMIUM_GOLD,
        Placeholder = "Enter your premium key here...", 
        Callback = function(Text) InputKeyPremium = Text end 
    })
    
    VIPSection:Button({
        Title = "Verify & Activate",
        Icon = "lucide:badge-check",
        IconColor = PREMIUM_GOLD,
        Callback = function()
            if InputKeyPremium == "" then return end
            MugiwaraUI:Notify({ Title = "Validation in Progress", Content = "Connecting to Panda Auth server...", Duration = 2 })
            
            local isValid, isPrem, result = ValidateKey(InputKeyPremium)
            if isValid and isPrem then
                if writefile then pcall(writefile, savedKeyPath, (tostring(InputKeyPremium):match("^%s*(.-)%s*$"))) end
                isPremiumUser = true
                MugiwaraUI:Notify({ Title = "Authentication Successful", Content = "Premium access granted and key safely stored.", Duration = 3 })

                PremiumParagraph:SetDesc('<font color="#ffffff">You are already a Premium user! Thank you for your continued support.</font>')

                if BtnBuyPremium then BtnBuyPremium:Destroy() end
                if VIPSection then VIPSection:Destroy() end
                UnlockPremiumFeatures()
            else
                MugiwaraUI:Notify({ Title = "Authentication Failed", Content = result.message or result.error or result.reason or "Invalid, expired, or non-premium key provided.", Duration = 3 })
            end
        end
    })
end

-- GLOBAL TABS & GAME DETECTOR
local GlobalTabs = { "Tabs/HomeTab.lua", "Tabs/LightingTab.lua", "Tabs/CameraTab.lua" }

local function LoadGlobalTabs()
    local total = #GlobalTabs
    for index, path in ipairs(GlobalTabs) do
        local build = getgenv().MugiwaraImport(path)
        if type(build) == "function" then
            local ok, err = pcall(build, Window, isPremiumUser, MugiwaraUI)
            if not ok then warn("[Mugiwara HUB] Tab " .. path .. " error: " .. tostring(err)) end
        end

        -- 52% -> 70% dibagi rata antar tab; setelah tab terakhir lanjut merayap ke tahap modul game.
        local done = 52 + math.floor(18 * index / total)
        local nextDone = index == total and 90 or (52 + math.floor(18 * (index + 1) / total) - 1)
        LoaderProgress(done, nextDone)
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

-- Modul game dibangun di thread sendiri (bisa menunggu jaringan); jumlah yang masih berjalan
-- dicatat supaya window baru ditampilkan setelah semuanya selesai.
local pendingBuilds = 0
local function BuildAsync(func)
    pendingBuilds = pendingBuilds + 1
    task.spawn(function()
        local ok, err = pcall(func, Window, isPremiumUser, MugiwaraUI)
        if not ok then warn("[Mugiwara HUB] Game module error: " .. tostring(err)) end
        pendingBuilds = pendingBuilds - 1
    end)
end

LoaderStatus("Loading game modules")

if TargetModulePath then
    local func = getgenv().MugiwaraImport(TargetModulePath)
    if type(func) == "function" then
        BuildAsync(func)
        moduleLoaded = true
    end
end

if not moduleLoaded then
    local func = getgenv().MugiwaraImport(UniversalModulePath)
    if type(func) == "function" then
        BuildAsync(func)
    end
end

-- Misc is global and is created after the game's Main tab so it always sits below it.
local buildMisc = getgenv().MugiwaraImport("Tabs/MiscTab.lua")
if type(buildMisc) == "function" then
    local ok, err = pcall(buildMisc, Window, isPremiumUser, MugiwaraUI)
    if not ok then warn("[Mugiwara HUB] Misc tab error: " .. tostring(err)) end
end

-- Chat tepat di bawah Misc; UI Config (tab section Appearance) paling bawah.
local buildChat = getgenv().MugiwaraImport("Tabs/ChatTab.lua")
if type(buildChat) == "function" then
    local ok, err = pcall(buildChat, Window, isPremiumUser, MugiwaraUI, CHAT_URL)
    if not ok then warn("[Mugiwara HUB] Chat tab error: " .. tostring(err)) end
end

local buildUIConfig = getgenv().MugiwaraImport("Tabs/UIConfigTab.lua")
if type(buildUIConfig) == "function" then
    local ok, err = pcall(buildUIConfig, Window, isPremiumUser, MugiwaraUI)
    if not ok then warn("[Mugiwara HUB] UI Config tab error: " .. tostring(err)) end
end
LoaderProgress(80, 93)

-- Tunggu modul game yang masih membangun tab (maksimal 15 detik), lalu tampilkan window.
local revealDeadline = os.clock() + 15
while pendingBuilds > 0 and os.clock() < revealDeadline do task.wait(0.1) end
LoaderProgress(96, 98)

-- Window ditutup selagi dibangun (lihat bagian WINDOW), jadi Open() memutar animasi pop-up library
-- dari awal.
local function ShowWindowWithPopup()
    pcall(function() Window:Open() end)
end

-- Loading screen diselesaikan dulu (animasi keluar). Semua tab sudah dibangun dan layout-nya sudah
-- dihitung; window tetap tertutup selama loading screen memudar, lalu muncul dengan animasi
-- pop-up begitu loading screen selesai.
if Loader then
    local loaderDone = false
    local doneConnection = Loader.Finished:Connect(function()
        if loaderDone then return end
        loaderDone = true
        ShowWindowWithPopup()
    end)
    pcall(function() Loader:Finish() end)

    local finishDeadline = os.clock() + 6
    while not loaderDone and os.clock() < finishDeadline do task.wait(0.05) end
    doneConnection:Disconnect()
    if not loaderDone then
        loaderDone = true
        ShowWindowWithPopup() -- loading screen macet: tampilkan paksa
    end
    LoaderDestroy()
else
    ShowWindowWithPopup() -- loading screen tidak bisa dibuat: window langsung ditampilkan
end

-- Selama jendela hub terbuka kursor dibebaskan (shift lock mengunci mouse di tengah layar);
-- saat ditutup, kondisi aslinya dikembalikan. Window:Open() sudah jalan sebelum callback
-- dipasang, jadi keadaan awal dibaca dari Window.Opened. Dipasang setelah window ditampilkan,
-- supaya kursor tidak dibebaskan selagi window masih tersembunyi.
local Cursor = env.MugiwaraImport("Manager/Cursor.lua")
if Cursor then
    if UIExtras then
        UIExtras.HookVisibility(Window, function() Cursor.SetWindowOpen(true) end, function() Cursor.SetWindowOpen(false) end)
    end
    Cursor.SetWindowOpen(Window.Opened == true)
end
