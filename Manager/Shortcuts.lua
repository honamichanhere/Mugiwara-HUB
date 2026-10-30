local Shortcuts = {}

local HttpService = game:GetService("HttpService")

local Keybinds = getgenv().MugiwaraImport("Manager/Keybinds.lua")

-- Shortcut keyboard buatan pengguna: tiap shortcut menjalankan SATU kontrol hub (Toggle, Slider atau Button) lewat
-- sebuah tombol. Daftar kontrol yang bisa dipilih datang dari Window._MugiwaraControls (lihat Manager/UIExtras.lua);
-- di sini hanya data, penyimpanan, dan cara menjalankannya. UI-nya ada di Tabs/ShortcutsUI.lua.
--
-- Disimpan di <MugiwaraHub>/Shortcuts.json. Sebuah shortcut menunjuk kontrolnya lewat nama tampilnya (jenis + judul +
-- jalur Tab > Section), jadi shortcut untuk game lain tetap tersimpan dan hanya tidak aktif kalau kontrolnya tidak ada.

Shortcuts.Max = 20
Shortcuts.MaxNameLength = 30
Shortcuts.Types = { "Toggle", "Slider", "Button" }
Shortcuts.ToggleModes = { "Toggle", "Turn On", "Turn Off" }

local ROOT = getgenv().MugiwaraFolder or "MugiwaraHub"
local PATH = ROOT .. "/Shortcuts.json"

Shortcuts.List = {}

local function Contains(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

function Shortcuts.CleanName(text)
    local name = string.gsub(tostring(text or ""), "[%c<>]", "")
    name = string.match(name, "^%s*(.-)%s*$")
    return string.sub(name, 1, Shortcuts.MaxNameLength)
end

-- Memaksa satu entri ke bentuk yang valid (data dari file bisa saja rusak atau diubah tangan).
local function Normalize(raw)
    if type(raw) ~= "table" then return nil end
    local kind = Contains(Shortcuts.Types, raw.Type) and raw.Type or "Toggle"
    local entry = {
        Name = Shortcuts.CleanName(raw.Name),
        Type = kind,
        Target = type(raw.Target) == "string" and raw.Target ~= "" and string.sub(raw.Target, 1, 200) or nil,
        Key = (Keybinds and type(raw.Key) == "string" and Keybinds.IsValidKey(raw.Key)) and raw.Key or nil,
        Mode = Contains(Shortcuts.ToggleModes, raw.Mode) and raw.Mode or "Toggle",
        Value = (type(raw.Value) == "number" and raw.Value == raw.Value and math.abs(raw.Value) < 1e12) and raw.Value or nil,
    }
    return entry
end

function Shortcuts.Load()
    Shortcuts.List = {}
    if readfile and isfile and isfile(PATH) then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(PATH)) end)
        if ok and type(decoded) == "table" and type(decoded.Items) == "table" then
            for _, raw in ipairs(decoded.Items) do
                if #Shortcuts.List >= Shortcuts.Max then break end
                local entry = Normalize(raw)
                if entry then table.insert(Shortcuts.List, entry) end
            end
        end
    end
    return Shortcuts.List
end

function Shortcuts.Save()
    if not writefile then return false end
    local items = {}
    for _, entry in ipairs(Shortcuts.List) do
        table.insert(items, {
            Name = entry.Name, Type = entry.Type, Target = entry.Target, Key = entry.Key, Mode = entry.Mode, Value = entry.Value,
        })
    end
    return (pcall(function() writefile(PATH, HttpService:JSONEncode({ Version = 1, Items = items })) end))
end

-- Entri baru (kosong). Mengembalikan entri, atau nil dan alasannya kalau sudah penuh.
function Shortcuts.Add()
    if #Shortcuts.List >= Shortcuts.Max then
        return nil, "You can have up to " .. Shortcuts.Max .. " shortcuts."
    end
    local entry = Normalize({ Type = "Toggle" })
    table.insert(Shortcuts.List, entry)
    Shortcuts.Save()
    return entry
end

function Shortcuts.Remove(entry)
    for index, other in ipairs(Shortcuts.List) do
        if other == entry then
            table.remove(Shortcuts.List, index)
            Shortcuts.Save()
            return true
        end
    end
    return false
end

function Shortcuts.IndexOf(entry)
    for index, other in ipairs(Shortcuts.List) do
        if other == entry then return index end
    end
    return nil
end

-- Judul yang ditampilkan: nama buatan pengguna, atau "Shortcut #n" kalau namanya kosong.
function Shortcuts.TitleOf(entry)
    if entry.Name ~= "" then return entry.Name end
    return "Shortcut #" .. tostring(Shortcuts.IndexOf(entry) or "?")
end

-- ---------- Kontrol hub ----------
-- registry = Window._MugiwaraControls = { List = { { Type, Title, Path, Display, Element, ... } }, Version }

-- Kontrol yang masih ada dan sejenis. Elemen yang sudah dihapus tidak dikembalikan.
function Shortcuts.ControlsOfType(registry, kind)
    local out = {}
    for _, control in ipairs(registry and registry.List or {}) do
        local frame = control.Element and control.Element.Frame
        local alive = not (frame and frame.Parent == nil)
        if control.Type == kind and alive then table.insert(out, control) end
    end
    return out
end

function Shortcuts.FindControl(registry, entry)
    if not entry.Target then return nil end
    for _, control in ipairs(Shortcuts.ControlsOfType(registry, entry.Type)) do
        if control.Display == entry.Target then return control end
    end
    return nil
end

-- Rentang slider sebuah kontrol: min, max, default (nil kalau bukan slider).
function Shortcuts.SliderRange(control)
    if not control or control.Type ~= "Slider" then return nil end
    local opts = control.Element and control.Element.Options or {}
    local range = type(opts.Value) == "table" and opts.Value or {}
    return range.Min or opts.Min or 0, range.Max or opts.Max or 100, range.Default or opts.Default
end

local function Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Menjalankan shortcut. Mengembalikan: berhasil, pesan singkat untuk notifikasi.
function Shortcuts.Run(registry, entry)
    local control = Shortcuts.FindControl(registry, entry)
    if not control then
        return false, entry.Target and "That control is not available here." or "Pick a feature for this shortcut first."
    end

    local element = control.Element
    if element.Locked then
        return false, control.Title .. " is locked (premium only)."
    end

    if control.Type == "Button" then
        local ok = pcall(function() element:Fire() end)
        return ok, ok and control.Title or "Could not press " .. control.Title .. "."
    end

    if control.Type == "Toggle" then
        local want
        if entry.Mode == "Turn On" then
            want = true
        elseif entry.Mode == "Turn Off" then
            want = false
        else
            want = not element.Value
        end
        local ok = pcall(function() element:Set(want) end)
        return ok, control.Title .. ": " .. (want and "ON" or "OFF")
    end

    -- Slider
    if entry.Value == nil then return false, "Set a value for this shortcut first." end
    local min, max = Shortcuts.SliderRange(control)
    local value = Clamp(entry.Value, min, max)
    local ok = pcall(function() element:Set(value) end)
    return ok, control.Title .. " = " .. tostring(value)
end

Shortcuts.Load()

return Shortcuts
