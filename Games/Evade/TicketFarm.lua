local TicketFarm = {}

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

TicketFarm.FarmEnabled = false
TicketFarm.AvoidEnabled = false
TicketFarm.SafeDistance = 30 -- studs; NextBot di dalam radius ini memicu teleport kabur
TicketFarm.TeleportDelay = 0 -- detik; jeda minimal antara dua teleport ke ticket (0 = langsung)

local TICK = 0.1                -- detik antar pengecekan
local TARGET_TIMEOUT = 5        -- detik; ticket yang tidak hilang dalam waktu ini dilewati
local REAPPLY_DISTANCE = 6      -- studs; kalau lebih jauh dari target, teleport ulang
local REAPPLY_COOLDOWN = 0.4    -- detik minimal antar teleport ke target yang sama
local STAND_HEIGHT = 4          -- studs di atas part ItemSpawns saat kabur

local alive = true
local currentTarget = nil
local targetSince = 0
local lastTeleport = 0
local lastFarmTeleport = -math.huge -- teleport ke ticket terakhir (teleport kabur dari NextBot tidak dihitung)
local ignored = setmetatable({}, { __mode = "k" }) -- ticket yang dilewati (timeout)
local warnedError = false

-- ==========================================
-- HELPERS
-- ==========================================

-- Yang dikendalikan pemain adalah LocalPlayer.Character (Workspace.Players.<nama>, punya
-- HumanoidRootPart; kamera juga mengikuti Humanoid-nya). Model di Workspace.Rigs hanya
-- salinan visual, jadi TIDAK digerakkan: memindahkannya bikin tampilan loncat keluar map.
local function GetBody()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and (character:FindFirstChild("HumanoidRootPart") or (humanoid and humanoid.RootPart))
    if not humanoid or not root then return nil end

    return { CharRoot = root, Humanoid = humanoid }
end

local function GetOrigin(body)
    return body.CharRoot.Position
end

local function GetPosition(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local ok, pivot = pcall(function() return obj:GetPivot() end)
        if ok then return pivot.Position end
    end
    return nil
end

local function MoveTo(body, position)
    local root = body.CharRoot
    root.CFrame = CFrame.new(position) * (root.CFrame - root.CFrame.Position) -- rotasi dipertahankan
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    lastTeleport = os.clock()
end

local function GetTicketFolder()
    local effects = workspace:FindFirstChild("Effects")
    return effects and effects:FindFirstChild("Tickets")
end

-- NextBot = model di Workspace.Rigs yang punya "Hitbox" dan bukan rig pemain.
-- Mengembalikan daftar posisi Hitbox.
local function GetNextBotPositions()
    local positions = {}
    local rigs = workspace:FindFirstChild("Rigs")
    if not rigs then return positions end

    for _, rig in ipairs(rigs:GetChildren()) do
        if rig:IsA("Model") and not Players:FindFirstChild(rig.Name) then
            local hitbox = rig:FindFirstChild("Hitbox")
            local position = hitbox and GetPosition(hitbox)
            if position then table.insert(positions, position) end
        end
    end
    return positions
end

local function NearestDistance(position, botPositions)
    local nearest = math.huge
    for _, botPosition in ipairs(botPositions) do
        local distance = (position - botPosition).Magnitude
        if distance < nearest then nearest = distance end
    end
    return nearest
end

-- Pilih part Workspace.Map.ItemSpawns secara acak yang jauh dari semua NextBot.
-- Kalau tidak ada yang cukup jauh, ambil yang paling jauh.
local function PickSafeSpawn(botPositions)
    local map = workspace:FindFirstChild("Map")
    local spawns = map and map:FindFirstChild("ItemSpawns")
    if not spawns then return nil end

    local requiredDistance = TicketFarm.SafeDistance * 2
    local pool, farthest, farthestDistance = {}, nil, -1

    for _, inst in ipairs(spawns:GetDescendants()) do
        if inst:IsA("BasePart") then
            local distance = NearestDistance(inst.Position, botPositions)
            if distance >= requiredDistance then table.insert(pool, inst) end
            if distance > farthestDistance then farthest, farthestDistance = inst, distance end
        end
    end

    if #pool > 0 then return pool[math.random(1, #pool)] end
    return farthest
end

-- ==========================================
-- MAIN STEP
-- ==========================================
local function Step()
    local body = GetBody()
    local origin = body and GetOrigin(body)
    if not body or not origin or body.Humanoid.Health <= 0 then
        currentTarget = nil
        return
    end

    local botPositions = TicketFarm.AvoidEnabled and GetNextBotPositions() or {}

    -- 1. Kabur dari NextBot (prioritas tertinggi)
    if TicketFarm.AvoidEnabled and #botPositions > 0
        and NearestDistance(origin, botPositions) < TicketFarm.SafeDistance then
        local spot = PickSafeSpawn(botPositions)
        if spot then
            MoveTo(body, spot.Position + Vector3.new(0, STAND_HEIGHT, 0))
            currentTarget = nil
        end
        return
    end

    -- 2. Auto farm ticket
    if not TicketFarm.FarmEnabled then
        currentTarget = nil
        return
    end

    local folder = GetTicketFolder()
    if not folder then
        currentTarget = nil
        return
    end

    if currentTarget then
        if not currentTarget:IsDescendantOf(folder) then
            currentTarget = nil -- sudah hilang (terambil)
        elseif os.clock() - targetSince > TARGET_TIMEOUT then
            ignored[currentTarget] = true -- nyangkut, lewati
            currentTarget = nil
        elseif TicketFarm.AvoidEnabled then
            local position = GetPosition(currentTarget)
            if not position or NearestDistance(position, botPositions) < TicketFarm.SafeDistance then
                currentTarget = nil -- NextBot mendekati ticket ini
            end
        end
    end

    if not currentTarget then
        -- Jeda antar teleport ke ticket (slider Teleport Delay). Teleport kabur dari NextBot tidak ikut ditunda.
        if TicketFarm.TeleportDelay > 0 and os.clock() - lastFarmTeleport < TicketFarm.TeleportDelay then
            return
        end

        local best, bestDistance = nil, math.huge
        for _, ticket in ipairs(folder:GetChildren()) do
            if not ignored[ticket] then
                local position = GetPosition(ticket)
                if position then
                    local safe = not TicketFarm.AvoidEnabled
                        or NearestDistance(position, botPositions) >= TicketFarm.SafeDistance
                    local distance = (origin - position).Magnitude
                    if safe and distance < bestDistance then best, bestDistance = ticket, distance end
                end
            end
        end

        if best then
            currentTarget, targetSince = best, os.clock()
            MoveTo(body, GetPosition(best))
            lastFarmTeleport = os.clock()
        end
        -- Tidak ada ticket: diam di posisi terakhir, pemain bebas bergerak.
        return
    end

    -- Target masih ada: teleport ulang hanya kalau pemain terdorong jauh dari ticket.
    local position = GetPosition(currentTarget)
    if position and (origin - position).Magnitude > REAPPLY_DISTANCE
        and os.clock() - lastTeleport > REAPPLY_COOLDOWN then
        MoveTo(body, position)
    end
end

task.spawn(function()
    while alive do
        task.wait(TICK)
        if TicketFarm.FarmEnabled or TicketFarm.AvoidEnabled then
            local ok, err = pcall(Step)
            if not ok and not warnedError then
                warnedError = true
                warn("[Mugiwara HUB] Ticket Farm error: " .. tostring(err))
            end
        end
    end
end)

-- ==========================================
-- PUBLIC API
-- ==========================================
function TicketFarm.SetFarm(state)
    TicketFarm.FarmEnabled = state
    if not state then currentTarget = nil end
end

function TicketFarm.SetAvoid(state)
    TicketFarm.AvoidEnabled = state
end

function TicketFarm.SetSafeDistance(value)
    TicketFarm.SafeDistance = value
end

function TicketFarm.SetTeleportDelay(value)
    TicketFarm.TeleportDelay = math.max(0, tonumber(value) or 0)
end

-- Full teardown on re-execute / unload.
getgenv().MugiwaraRegisterCleanup(function()
    alive = false
    TicketFarm.FarmEnabled = false
    TicketFarm.AvoidEnabled = false
    currentTarget = nil
end)

return TicketFarm
