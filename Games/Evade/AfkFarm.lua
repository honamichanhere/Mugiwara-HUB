local AfkFarm = {}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local VIPCommands = getgenv().MugiwaraImport("Games/Evade/VIPCommands.lua")
local Movement = getgenv().MugiwaraImport("Manager/Movement.lua")

local ROOT = getgenv().MugiwaraFolder or "MugiwaraHub"
local PATH = ROOT .. "/AfkFarm.json"

-- Pemicu yang bisa dipilih untuk tiap event.
-- Pemicu fase ronde berasal dari event RoundStatus milik game (lihat EVENT SOURCES).
AfkFarm.Triggers = {
    "None",
    "Character Died",
    "Character Spawned",
    "Intermission",
    "Round Start",
    "Round End",
}
AfkFarm.MaxRules = 10  -- batas jumlah event supaya UI tidak membengkak
AfkFarm.MaxDelay = 120 -- detik

local MAX_COMMAND_LENGTH = 200
local MAINTAIN_INTERVAL = 0.5   -- detik antar pengecekan posisi AFK
local RETURN_DISTANCE = 15      -- studs; lebih jauh dari ini = dikembalikan ke posisi AFK

local alive = true
local connections = {}

-- ==========================================
-- SETTINGS (disimpan: posisi AFK dan daftar event; toggle selalu mulai OFF)
-- ==========================================
-- Rule = { Id, Command, Trigger, Delay }. Id naik terus dan tidak dipakai ulang, jadi label
-- "Event #n" di UI tetap stabil walau ada event yang dihapus.
local settings = { Position = nil, Rules = {}, NextId = 1 }

local function IsValidTrigger(name)
    return table.find(AfkFarm.Triggers, name) ~= nil
end

local function SanitizeRule(raw)
    raw = type(raw) == "table" and raw or {}
    local command = type(raw.Command) == "string" and string.sub(raw.Command, 1, MAX_COMMAND_LENGTH) or ""
    local trigger = IsValidTrigger(raw.Trigger) and raw.Trigger or "None"
    local delay = math.clamp(tonumber(raw.Delay) or 0, 0, AfkFarm.MaxDelay)
    return { Id = tonumber(raw.Id), Command = command, Trigger = trigger, Delay = delay }
end

local function Save()
    if not writefile then return end
    local data = { Position = settings.Position, Rules = settings.Rules, NextId = settings.NextId }
    pcall(function() writefile(PATH, HttpService:JSONEncode(data)) end)
end

do
    local loaded
    if readfile and isfile and isfile(PATH) then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(PATH)) end)
        if ok and type(decoded) == "table" then loaded = decoded end
    end

    local maxId = 0
    if loaded and type(loaded.Rules) == "table" then
        for _, raw in ipairs(loaded.Rules) do
            if #settings.Rules >= AfkFarm.MaxRules then break end
            local rule = SanitizeRule(raw)
            if rule.Id then
                maxId = math.max(maxId, rule.Id)
            else
                maxId = maxId + 1
                rule.Id = maxId
            end
            -- Event yang sama sekali kosong (misalnya slot sisa versi lama) tidak dimuat.
            local isEmpty = rule.Command == "" and rule.Trigger == "None" and rule.Delay == 0
            if not isEmpty then table.insert(settings.Rules, rule) end
        end
    end
    settings.NextId = math.max(maxId + 1, (loaded and tonumber(loaded.NextId)) or 1)

    -- Selalu ada minimal satu event supaya section tidak kosong saat pertama dibuka.
    if #settings.Rules == 0 then
        local rule = SanitizeRule({})
        rule.Id = settings.NextId
        settings.NextId = settings.NextId + 1
        table.insert(settings.Rules, rule)
    end

    local pos = loaded and loaded.Position
    if type(pos) == "table" and tonumber(pos.x) and tonumber(pos.y) and tonumber(pos.z) then
        settings.Position = { x = tonumber(pos.x), y = tonumber(pos.y), z = tonumber(pos.z) }
    end
end

-- ==========================================
-- EVENTS (rules)
-- ==========================================
-- Daftar hidup: UI memegang tabel rule yang sama dan mengubahnya lewat UpdateRule.
function AfkFarm.GetRules()
    return settings.Rules
end

function AfkFarm.AddRule()
    if #settings.Rules >= AfkFarm.MaxRules then
        return nil, "You can have at most " .. AfkFarm.MaxRules .. " events."
    end

    local rule = SanitizeRule({})
    rule.Id = settings.NextId
    settings.NextId = settings.NextId + 1
    table.insert(settings.Rules, rule)
    Save()
    return rule
end

function AfkFarm.RemoveRule(rule)
    local index = table.find(settings.Rules, rule)
    if index then
        table.remove(settings.Rules, index)
        Save()
    end
end

function AfkFarm.UpdateRule(rule, field, value)
    local candidate = { Id = rule.Id, Command = rule.Command, Trigger = rule.Trigger, Delay = rule.Delay }
    candidate[field] = value

    local clean = SanitizeRule(candidate)
    rule.Command, rule.Trigger, rule.Delay = clean.Command, clean.Trigger, clean.Delay
    Save()
end

-- ==========================================
-- AUTO EXECUTE
-- ==========================================
AfkFarm.AutoExecEnabled = false
AfkFarm.OnResult = nil -- diisi UI: function(rule, ok, message)

-- Command dikirim satu per satu lewat antrean supaya dua event yang terpicu bersamaan
-- tidak ditolak oleh batas kecepatan kirim.
local queue = {}
local pumping = false
local generation = 0 -- naik tiap toggle dimatikan; menghentikan command yang masih menunggu delay

local function Pump()
    if pumping then return end
    pumping = true

    task.spawn(function()
        while alive and #queue > 0 do
            local item = table.remove(queue, 1)
            if AfkFarm.AutoExecEnabled and VIPCommands then
                local ok, result = VIPCommands.RunText(item.Command)
                if AfkFarm.OnResult then pcall(AfkFarm.OnResult, item.Rule, ok, result) end
            end
            task.wait((VIPCommands and VIPCommands.MinInterval or 0.5) + 0.1)
        end
        pumping = false
    end)
end

local function Fire(trigger)
    if not AfkFarm.AutoExecEnabled then return end
    local myGeneration = generation

    for _, rule in ipairs(table.clone(settings.Rules)) do
        if rule.Trigger == trigger and rule.Command ~= "" then
            task.delay(rule.Delay, function()
                if not alive or not AfkFarm.AutoExecEnabled or generation ~= myGeneration then return end
                -- Event bisa dihapus atau diubah selama delay; baca keadaan terbaru.
                if not table.find(settings.Rules, rule) or rule.Command == "" then return end
                table.insert(queue, { Rule = rule, Command = rule.Command })
                Pump()
            end)
        end
    end
end

function AfkFarm.SetAutoExec(state)
    AfkFarm.AutoExecEnabled = state
    if not state then
        generation = generation + 1
        table.clear(queue)
    end
end

-- ==========================================
-- EVENT SOURCES
-- ==========================================
local diedConnection = nil

local function WatchCharacter(character)
    if diedConnection then diedConnection:Disconnect() diedConnection = nil end

    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid and alive then
        diedConnection = humanoid.Died:Connect(function() Fire("Character Died") end)
    end
end

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(character)
    Fire("Character Spawned")
    task.spawn(WatchCharacter, character)
end))
if LocalPlayer.Character then task.spawn(WatchCharacter, LocalPlayer.Character) end

-- Fase ronde Evade: ReplicatedStorage.Events.UpdateServerStateRegistry mengirim ("RoundStatus", n)
--   0 = tidak ada ronde (menunggu pemain / ronde selesai), 1 = intermission, 2 = ronde berjalan.
-- Pemicu hanya jalan saat status BERUBAH. Nilai pertama yang diterima cuma jadi acuan (mis.
-- sinkronisasi saat baru join), supaya masuk server di tengah fase tidak langsung memicu event.
local ROUND_TRIGGERS = { [1] = "Intermission", [2] = "Round Start" }
local lastRoundStatus = nil

local function OnRoundStatus(status)
    if type(status) ~= "number" then return end

    local previous = lastRoundStatus
    lastRoundStatus = status
    if previous == nil or previous == status then return end

    if status == 0 then
        Fire("Round End")
    elseif ROUND_TRIGGERS[status] then
        Fire(ROUND_TRIGGERS[status])
    end
end

task.spawn(function()
    local ok, remote = pcall(function()
        local events = game:GetService("ReplicatedStorage"):WaitForChild("Events", 10)
        return events:WaitForChild("UpdateServerStateRegistry", 10)
    end)
    if not ok or not remote or not alive then return end

    table.insert(connections, remote.OnClientEvent:Connect(function(key, value)
        if key == "RoundStatus" then OnRoundStatus(value) end
    end))
end)

-- ==========================================
-- AFK FARM (tahan di koordinat AFK memakai Fly)
-- ==========================================
AfkFarm.FarmEnabled = false

local heldPosition = nil -- dipakai kalau belum ada koordinat tersimpan
local flyOwned = false   -- true kalau Fly dinyalakan oleh modul ini

local function GetRoot()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return nil end
    return root
end

local function SetFly(state)
    if not Movement then return end
    local ui = Movement.UI and Movement.UI.Fly
    if ui and ui.Set then
        ui:Set(state) -- toggle di UI ikut bergerak dan memanggil ToggleFly
    else
        Movement.ToggleFly(state)
    end
end

function AfkFarm.GetPosition()
    local pos = settings.Position
    return pos and Vector3.new(pos.x, pos.y, pos.z) or nil
end

function AfkFarm.FormatPosition()
    local pos = settings.Position
    if not pos then return "" end
    return string.format("%.1f, %.1f, %.1f", pos.x, pos.y, pos.z)
end

local function StorePosition(vector)
    settings.Position = { x = vector.X, y = vector.Y, z = vector.Z }
    Save()
end

-- Terima teks "x, y, z". Mengembalikan true, teks_terformat atau false, alasan.
function AfkFarm.SetPositionFromText(text)
    text = tostring(text or "")
    if text:match("^%s*$") then
        settings.Position = nil
        Save()
        return true, ""
    end

    local numbers = {}
    for token in string.gmatch(text, "[^,%s]+") do
        local number = tonumber(token)
        if not number then return false, "Coordinates must be numbers, for example 0, 500, 0." end
        table.insert(numbers, number)
    end
    if #numbers ~= 3 then return false, "Enter exactly three numbers: x, y, z." end

    StorePosition(Vector3.new(numbers[1], numbers[2], numbers[3]))
    return true, AfkFarm.FormatPosition()
end

function AfkFarm.UseCurrentPosition()
    local root = GetRoot()
    if not root then return false, "Your character was not found." end

    StorePosition(root.Position)
    return true, AfkFarm.FormatPosition()
end

function AfkFarm.SetFarm(state)
    AfkFarm.FarmEnabled = state

    if state then
        if not settings.Position then
            local root = GetRoot()
            heldPosition = root and root.Position or nil
        end
    else
        heldPosition = nil
        if flyOwned then
            flyOwned = false
            SetFly(false)
        end
    end
end

task.spawn(function()
    while alive do
        task.wait(MAINTAIN_INTERVAL)
        if AfkFarm.FarmEnabled then
            local ok, err = pcall(function()
                local root = GetRoot()
                if not root then return end

                local target = AfkFarm.GetPosition() or heldPosition
                if target and (root.Position - target).Magnitude > RETURN_DISTANCE then
                    root.CFrame = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
                    root.AssemblyLinearVelocity = Vector3.zero
                end

                if Movement and not Movement.FlyEnabled then
                    SetFly(true)
                    flyOwned = true
                end
            end)
            if not ok then warn("[Mugiwara HUB] AFK Farm error: " .. tostring(err)) end
        end
    end
end)

-- Full teardown on re-execute / unload.
getgenv().MugiwaraRegisterCleanup(function()
    alive = false
    AfkFarm.AutoExecEnabled = false
    generation = generation + 1
    table.clear(queue)

    if AfkFarm.FarmEnabled then
        AfkFarm.FarmEnabled = false
        if flyOwned then pcall(SetFly, false) end
    end

    for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
    table.clear(connections)
    if diedConnection then diedConnection:Disconnect() diedConnection = nil end
end)

return AfkFarm
