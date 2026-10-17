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

    local parts = { "!" .. canonical }
    for _, arg in ipairs({ ... }) do
        local text = tostring(arg)
        if string.find(text, "[%c]") then
            return false, "Command arguments cannot contain control characters."
        end
        table.insert(parts, text)
    end
    local message = table.concat(parts, " ")

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
