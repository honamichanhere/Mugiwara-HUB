local VIPCommands = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- Command VIP dikirim persis seperti tombol ACTIVATE di menu VIP:
--     ReplicatedStorage.Events.Admin.VIPCommand:FireServer("!timer 1")
-- yaitu "!" + CommandNames[1] + argumen dipisah spasi. Server tetap yang memvalidasi
-- (atribut VIPCommandsAccess, daftar command VIPMenuAccessible), jadi modul ini hanya
-- bisa menjalankan apa yang memang boleh dilakukan pemilik server lewat menu VIP.

VIPCommands.MinInterval = 0.5               -- detik minimal antar command (anti-spam)
VIPCommands.AllowRewardDisabling = false    -- command yang mematikan reward diblokir secara default

-- Dipakai kalau data command game tidak bisa dibaca; hanya command ini yang diizinkan.
local FALLBACK_ALLOWED = { timer = true }

local lastSent = 0
local commandList = nil -- cache daftar command bawaan game

-- ==========================================
-- GAME DATA
-- ==========================================
local function LoadCommandList()
    if commandList ~= nil then return commandList end

    local ok, result = pcall(function()
        return require(ReplicatedStorage.Shared.Admin.Commands.Commands)
    end)
    commandList = (ok and type(result) == "table") and result or false
    return commandList
end

-- Cari definisi command dari nama atau alias-nya. nil kalau tidak ketemu / data tidak terbaca.
local function FindCommand(name)
    local list = LoadCommandList()
    if not list then return nil end

    local lowered = string.lower(name)
    for _, entry in ipairs(list) do
        for _, alias in ipairs(entry.CommandNames or {}) do
            if string.lower(alias) == lowered then return entry end
        end
    end
    return nil
end

-- ==========================================
-- ARGUMENT RESOLUTION
-- ==========================================
-- Menu VIP mengirim NAMA INSTANCE asli untuk argumen berupa aset (map, special round, tool,
-- NPC, dst.), mis. "PlushieHell". Teks yang diketik pemain ("Plushie Hell") belum tentu
-- sama, jadi dicocokkan dulu dengan isi folder yang sama dengan yang dipakai menu VIP
-- (entry.commandStringParents). Pencocokan tidak peka huruf besar/kecil dan spasi.
local assetCache = {} -- "ReplicatedStorage/Info/SpecialRounds" -> { {Name, Instance, Display}, ... }

local function Normalize(text)
    return string.lower((string.gsub(text, "[^%w]", "")))
end

local function GetPathRoot(first)
    if first == "ReplicatedStorage" then return ReplicatedStorage end
    if first == "workspace" or first == "Workspace" then return workspace end
    if first == "Lighting" then return game:GetService("Lighting") end
    return nil
end

local function CollectAssets(parents)
    local list = {}

    for _, path in ipairs(parents) do
        local key = table.concat(path, "/")
        local entries = assetCache[key]

        if not entries then
            entries = {}
            local node = GetPathRoot(path[1])
            for i = 2, #path do node = node and node:FindFirstChild(path[i]) end

            if node then
                for _, child in ipairs(node:GetChildren()) do
                    table.insert(entries, { Name = child.Name, Instance = child })
                end
            end
            assetCache[key] = entries
        end

        for _, item in ipairs(entries) do table.insert(list, item) end
    end

    return list
end

-- Nama tampilan (mis. "Plushie Hell") hanya dibaca dari ModuleScript saat pencocokan nama
-- biasa gagal, supaya modul tidak di-require tanpa perlu.
local function LoadDisplayNames(items)
    for _, item in ipairs(items) do
        if item.DisplayLoaded == nil then
            item.DisplayLoaded = true
            if item.Instance:IsA("ModuleScript") then
                local ok, data = pcall(require, item.Instance)
                if ok and type(data) == "table" then
                    if type(data.Name) == "string" then
                        item.Display = data.Name
                    elseif type(data.Info) == "table" and type(data.Info.Name) == "string" then
                        item.Display = data.Info.Name
                    end
                end
            end
        end
    end
end

-- Mengembalikan nama instance yang cocok, atau nil + teks saran.
local function ResolveAsset(parents, text)
    local items = CollectAssets(parents)
    local needle = Normalize(text)
    if #items == 0 or needle == "" then return text end -- tidak ada data pembanding: biarkan apa adanya

    for _, item in ipairs(items) do
        if item.Name == text then return item.Name end
    end
    for _, item in ipairs(items) do
        if Normalize(item.Name) == needle then return item.Name end
    end

    LoadDisplayNames(items)
    for _, item in ipairs(items) do
        if item.Display and Normalize(item.Display) == needle then return item.Name end
    end

    local prefixMatches, suggestions = {}, {}
    for _, item in ipairs(items) do
        local name = Normalize(item.Name)
        local display = item.Display and Normalize(item.Display) or ""
        if string.sub(name, 1, #needle) == needle or string.sub(display, 1, #needle) == needle then
            table.insert(prefixMatches, item)
        end
        if (string.find(name, needle, 1, true) or string.find(display, needle, 1, true)) and #suggestions < 5 then
            table.insert(suggestions, item.Name)
        end
    end
    if #prefixMatches == 1 then return prefixMatches[1].Name end

    if #suggestions > 0 then
        return nil, " Did you mean: " .. table.concat(suggestions, ", ") .. "?"
    end
    return nil, " Check the spelling."
end

-- Samakan argumen dengan cara menu VIP merakitnya: slot terakhir menampung semua sisa kata,
-- dan argumen berjenis commandString yang berasal dari folder aset dicocokkan ke nama aslinya.
local function NormalizeArgs(entry, args)
    local layout = entry.CommandLayout or {}

    if #layout > 0 and #args > #layout then
        local extra = table.concat(args, " ", #layout, #args)
        for i = #args, #layout + 1, -1 do args[i] = nil end
        args[#layout] = extra
    end

    for index, kind in ipairs(layout) do
        local value = args[index]
        if kind == "commandString" and value then
            local parents = (entry.specificCommandStringParents and entry.specificCommandStringParents[index])
                or entry.commandStringParents
            if parents then
                local resolved, hint = ResolveAsset(parents, value)
                if not resolved then
                    return nil, "No match for '" .. value .. "'." .. (hint or "")
                end
                args[index] = resolved
            end
        end
    end

    return args
end

function VIPCommands.GetRemote()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local admin = events and events:FindFirstChild("Admin")
    return admin and admin:FindFirstChild("VIPCommand")
end

function VIPCommands.HasAccess()
    return LocalPlayer:GetAttribute("VIPCommandsAccess") == true
end

-- true / false kalau command diketahui, nil kalau tidak diketahui.
function VIPCommands.DisablesRewards(name)
    local entry = FindCommand(name)
    if not entry then return nil end
    return entry.VIPCommandDisablesRewards == true
end

-- ==========================================
-- RUN
-- ==========================================

-- Jalankan command. Contoh: VIPCommands.Run("timer", 1)  ->  "!timer 1"
-- Mengembalikan true, teks_yang_dikirim  atau  false, alasan.
function VIPCommands.Run(name, ...)
    if type(name) ~= "string" or not string.match(name, "^[%w_]+$") then
        return false, "Invalid command name."
    end

    if not VIPCommands.HasAccess() then
        return false, "You do not have VIP command access in this server."
    end

    local remote = VIPCommands.GetRemote()
    if not remote then
        return false, "The VIP command remote was not found."
    end

    local entry = FindCommand(name)
    local canonical = name

    if entry then
        if entry.VIPMenuAccessible ~= true then
            return false, "'" .. name .. "' is not available through the VIP menu."
        end
        if entry.VIPCommandDisablesRewards == true and not VIPCommands.AllowRewardDisabling then
            return false, "'" .. name .. "' disables rewards for this server. Enable reward-disabling commands to use it."
        end
        canonical = (entry.CommandNames and entry.CommandNames[1]) or name
    elseif not FALLBACK_ALLOWED[string.lower(name)] then
        return false, "Could not verify '" .. name .. "' against the game's command list."
    end

    local args = {}
    for _, arg in ipairs({ ... }) do
        local text = tostring(arg)
        if string.find(text, "[%c]") then
            return false, "Command arguments cannot contain control characters."
        end
        table.insert(args, text)
    end

    if entry then
        local normalized, problem = NormalizeArgs(entry, args)
        if not normalized then return false, problem end
        args = normalized
    end

    local message = "!" .. canonical
    if #args > 0 then message = message .. " " .. table.concat(args, " ") end

    if os.clock() - lastSent < VIPCommands.MinInterval then
        return false, "Sending commands too fast."
    end
    lastSent = os.clock()

    local ok, err = pcall(function() remote:FireServer(message) end)
    if not ok then return false, tostring(err) end

    return true, message
end

-- Jalankan teks mentah seperti yang diketik di chat, misalnya "!timer 1".
function VIPCommands.RunText(text)
    text = tostring(text or ""):match("^%s*(.-)%s*$")
    text = text:gsub("^!", "")
    if text == "" then return false, "Enter a command first." end

    local tokens = {}
    for token in string.gmatch(text, "%S+") do table.insert(tokens, token) end

    local name = table.remove(tokens, 1)
    return VIPCommands.Run(name, table.unpack(tokens))
end

-- Skip intermission (atau persingkat timer ronde) dengan menyetel timer ke N detik.
function VIPCommands.SetTimer(seconds)
    return VIPCommands.Run("timer", seconds or 1)
end

return VIPCommands
