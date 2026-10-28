local HttpService = game:GetService("HttpService")

-- Pengaturan tampilan hub (tema, wallpaper, skala, blur) dan tema buatan user. Semuanya disimpan di
-- satu file JSON, jadi pilihan user kembali otomatis di eksekusi berikutnya. Tidak ada kaitannya
-- dengan fitur game.
local UISettings = {}

local FOLDER = "MugiwaraHubConfig"
local PATH = FOLDER .. "/UISettings.json"

local BUILTIN_THEMES = { ["Gear 5"] = true, ["Gear 4"] = true, ["Gear 3"] = true, ["Normal"] = true }
local MODES = { theme = true, custom = true, none = true }

UISettings.Defaults = {
    Theme = "Gear 5",
    Scale = 1,
    Blur = false,
    WallpaperMode = "theme", -- "theme" (wallpaper bawaan tema) | "custom" | "none"
    WallpaperId = "",
    WallpaperStrength = 70, -- persen; 70 = bawaan tema (transparansi 0.3)
}

UISettings.ScaleMin, UISettings.ScaleMax = 0.6, 1.4

local data = nil
local saveToken = 0

-- ---------------------------------------------------------------- warna
local function ToHex(color)
    return string.format("#%02x%02x%02x", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function FromHex(text)
    local r, g, b = tostring(text or ""):match("^#(%x%x)(%x%x)(%x%x)$")
    if not r then return nil end
    return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

UISettings.ToHex = ToHex

-- ---------------------------------------------------------------- file
local function CanFile()
    return writefile ~= nil and readfile ~= nil and isfile ~= nil
end

local function CleanThemeDef(def)
    if type(def) ~= "table" then return nil end
    local clean = {}
    for _, key in ipairs({ "Accent", "GradientA", "GradientB", "Background", "Text" }) do
        if not FromHex(def[key]) then return nil end
        clean[key] = def[key]
    end
    if type(def.Wallpaper) == "string" and #def.Wallpaper <= 80 then clean.Wallpaper = def.Wallpaper end
    return clean
end

local function ValidName(name)
    return type(name) == "string" and #name >= 2 and #name <= 24 and name:match("^[%w][%w _%-]*$") ~= nil
end

local function Fresh()
    local copy = {}
    for key, value in pairs(UISettings.Defaults) do copy[key] = value end
    copy.Themes = {}
    return copy
end

function UISettings.Load()
    data = Fresh()
    if not (CanFile() and isfile(PATH)) then return data end

    local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(PATH)) end)
    if not ok or type(decoded) ~= "table" then return data end

    if type(decoded.Theme) == "string" then data.Theme = decoded.Theme end
    if type(decoded.Scale) == "number" then data.Scale = math.clamp(decoded.Scale, UISettings.ScaleMin, UISettings.ScaleMax) end
    if type(decoded.Blur) == "boolean" then data.Blur = decoded.Blur end
    if MODES[decoded.WallpaperMode] then data.WallpaperMode = decoded.WallpaperMode end
    if type(decoded.WallpaperId) == "string" and #decoded.WallpaperId <= 80 then data.WallpaperId = decoded.WallpaperId end
    if type(decoded.WallpaperStrength) == "number" then data.WallpaperStrength = math.clamp(decoded.WallpaperStrength, 0, 100) end

    if type(decoded.Themes) == "table" then
        for name, def in pairs(decoded.Themes) do
            local clean = ValidName(name) and not BUILTIN_THEMES[name] and CleanThemeDef(def)
            if clean then data.Themes[name] = clean end
        end
    end
    return data
end

function UISettings.Flush()
    saveToken = saveToken + 1
    if not (data and CanFile()) then return end
    pcall(function()
        if makefolder and isfolder and not isfolder(FOLDER) then makefolder(FOLDER) end
        writefile(PATH, HttpService:JSONEncode(data))
    end)
end

-- Slider memanggil callback terus selama digeser; simpan sekali setelah berhenti.
local function SaveSoon()
    saveToken = saveToken + 1
    local mine = saveToken
    task.delay(0.6, function()
        if mine == saveToken then UISettings.Flush() end
    end)
end

function UISettings.Get(key)
    if not data then UISettings.Load() end
    return data[key]
end

function UISettings.Set(key, value)
    if not data then UISettings.Load() end
    if UISettings.Defaults[key] == nil then return end
    data[key] = value
    SaveSoon()
end

-- Mengembalikan semua pengaturan ke bawaan; tema buatan user tidak dihapus.
function UISettings.Reset()
    if not data then UISettings.Load() end
    for key, value in pairs(UISettings.Defaults) do data[key] = value end
    UISettings.Flush()
end

-- ---------------------------------------------------------------- tema buatan user
function UISettings.IsBuiltinTheme(name)
    return BUILTIN_THEMES[name] == true
end

function UISettings.IsCustomTheme(name)
    if not data then UISettings.Load() end
    return data.Themes[name] ~= nil
end

function UISettings.CustomThemeNames()
    if not data then UISettings.Load() end
    local names = {}
    for name in pairs(data.Themes) do table.insert(names, name) end
    table.sort(names)
    return names
end

local function Luminance(color)
    return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
end

-- Token tema dari 5 warna + wallpaper opsional. Token lain (kartu, garis, status) memakai bawaan library.
function UISettings.BuildTokens(def)
    local accent = FromHex(def.Accent)
    local gradientA, gradientB = FromHex(def.GradientA), FromHex(def.GradientB)
    local background, text = FromHex(def.Background), FromHex(def.Text)

    local tokens = {
        Accent = accent,
        Background = background,
        Text = text,
        SubText = text:Lerp(background, 0.22),
        Muted = text:Lerp(background, 0.5),
        OnAccent = Luminance(accent) > 0.55 and Color3.fromRGB(16, 18, 30) or Color3.new(1, 1, 1),
        Popup = background:Lerp(Color3.new(0, 0, 0), 0.35),
        Gradient = { gradientA, gradientA:Lerp(gradientB, 1 / 3), gradientA:Lerp(gradientB, 2 / 3), gradientB },
        Desc = "Custom theme",
    }
    if def.Wallpaper and def.Wallpaper ~= "" then tokens.Wallpaper = def.Wallpaper end
    return tokens
end

-- Mendaftarkan semua tema tersimpan ke library (dipanggil sekali setelah library dimuat).
function UISettings.RegisterThemes(UI)
    if not data then UISettings.Load() end
    for name, def in pairs(data.Themes) do
        pcall(function() UI:AddTheme(name, UISettings.BuildTokens(def)) end)
    end
end

-- def: { Accent, GradientA, GradientB, Background, Text (semua "#rrggbb"), Wallpaper? }
function UISettings.SaveTheme(UI, name, def)
    if not data then UISettings.Load() end
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if not ValidName(name) then
        return false, "Use 2 to 24 letters, numbers, spaces, - or _ for the name."
    end
    if BUILTIN_THEMES[name] then
        return false, "That name belongs to a built-in theme."
    end
    local clean = CleanThemeDef(def)
    if not clean then return false, "One of the colors is invalid." end

    data.Themes[name] = clean
    UISettings.Flush()
    UI:AddTheme(name, UISettings.BuildTokens(clean))
    return true, name
end

function UISettings.DeleteTheme(UI, name)
    if not data then UISettings.Load() end
    if not data.Themes[name] then return false end
    if UI:GetTheme() == name then UI:SetTheme(UISettings.Defaults.Theme) end
    data.Themes[name] = nil
    pcall(function() UI.Theme.Presets[name] = nil end)
    UISettings.Flush()
    return true
end

-- ---------------------------------------------------------------- menerapkan ke window
-- Wallpaper bawaan tema muncul dengan transparansi tema; kekuatan yang dipilih user dipasang
-- setelah gambarnya selesai tampil (library mem-tween transparansi saat gambar baru dipasang).
function UISettings.ApplyStrength(Window)
    if not data or data.WallpaperMode == "none" then return end
    local label = Window.BackgroundImage
    if label and label.Visible then
        label.ImageTransparency = 1 - data.WallpaperStrength / 100
    end
end

function UISettings.ApplyStrengthSoon(Window)
    if not data or data.WallpaperStrength == UISettings.Defaults.WallpaperStrength then return end
    task.delay(1, function() pcall(UISettings.ApplyStrength, Window) end)
end

function UISettings.ApplyWallpaper(Window)
    if not data then UISettings.Load() end
    local mode = data.WallpaperMode
    if mode == "custom" and data.WallpaperId ~= "" then
        Window:SetBackground(data.WallpaperId, 1 - data.WallpaperStrength / 100, 0.45)
    elseif mode == "none" then
        Window:SetBackground(nil)
    else
        Window:UseThemeBackground()
        UISettings.ApplyStrengthSoon(Window)
    end
end

-- Dipanggil sekali tepat setelah window dibuat.
function UISettings.ApplyAll(UI, Window)
    if not data then UISettings.Load() end
    if UI:GetTheme() ~= data.Theme then UI:SetTheme(data.Theme) end
    pcall(Window.SetScale, Window, data.Scale)
    if data.Blur then pcall(Window.SetBlur, Window, true) end
    pcall(UISettings.ApplyWallpaper, Window)
end

return UISettings
