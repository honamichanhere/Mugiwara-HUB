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
    "Vote",
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

-- Voting: event yang sama mengirim ("Voting", true) saat voting dibuka. Pemicu "Vote" jalan hanya
-- saat berubah menjadi true. Voting dianggap tertutup sebelum event pertama diterima.
local lastVoting = false

local function OnVoting(state)
    if type(state) ~= "boolean" then return end

    local previous = lastVoting
    lastVoting = state
    if state and not previous then Fire("Vote") end
end

task.spawn(function()
    local ok, remote = pcall(function()
        local events = game:GetService("ReplicatedStorage"):WaitForChild("Events", 10)
        return events:WaitForChild("UpdateServerStateRegistry", 10)
    end)
    if not ok or not remote or not alive then return end

    table.insert(connections, remote.OnClientEvent:Connect(function(key, value)
        if key == "RoundStatus" then
            OnRoundStatus(value)
        elseif key == "Voting" then
            OnVoting(value)
        end
    end))
end)

-- ==========================================
-- AFK FARM (tempat AFK kecil 50x50 di koordinat AFK)
-- ==========================================
-- Saat dinyalakan, tempat AFK dibangun dulu (beberapa detik) di koordinat target, baru karakter
-- dipindahkan ke atasnya dan duduk. Karakter tidak disentuh selama tempat itu dibangun, jadi tidak
-- ada saat karakter berada di udara tanpa lantai. Kalau tempatnya terhapus atau di-refresh game,
-- tempat itu dibangun ulang selama farm masih menyala; saat farm dimatikan semuanya dibersihkan.
-- Semua bagian adalah Part buatan client (Instance.new), jadi hanya terlihat di layar sendiri.
AfkFarm.FarmEnabled = false
AfkFarm.OnStatus = nil -- diisi UI: function(message)

local SPOT_NAME = "MugiwaraAfkSpot"
local SPOT_SIZE = 50        -- studs, persegi
local STAND_OFFSET = 3      -- jarak HumanoidRootPart ke lantai saat berdiri; lantai = target - ini
local SEAT_TOP = 1.6        -- tinggi permukaan dudukan di atas lantai
local BUILD_STEP = 0.3      -- detik per tahap saat membangun

local ACCENT = Color3.fromRGB(255, 214, 120)
local WARM = Color3.fromRGB(255, 226, 170)

local TweenService = game:GetService("TweenService")

local heldPosition = nil -- dipakai kalau belum ada koordinat tersimpan
local spot = nil         -- { Model, Seat, Floor, Base, Target, Count, Connections, Closing }
local building = false   -- true selama tempat sedang dibangun (karakter belum dipindah)
local buildToken = 0     -- naik tiap ada permintaan baru / farm dimatikan; membatalkan build lama
local buildFailed = false
local flyOwned = false   -- cadangan: Fly dipakai kalau tempat gagal dibangun

local Maintain -- didefinisikan di bawah

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

local function Status(message)
    if AfkFarm.OnStatus then pcall(AfkFarm.OnStatus, message) end
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

-- ------------------------------------------
-- Membangun tempat AFK
-- ------------------------------------------
local function DestroySpot()
    local current = spot
    spot = nil
    if not current then return end

    current.Closing = true
    for _, connection in ipairs(current.Connections or {}) do pcall(function() connection:Disconnect() end) end
    pcall(function() current.Model:Destroy() end)
end

-- animated: tahap demi tahap dengan efek muncul (dipakai saat pertama dibangun); false = sekaligus
-- (dipakai saat membangun ulang, supaya karakter tidak lama tanpa lantai).
-- cancelled: function() -> true kalau build ini sudah tidak dibutuhkan lagi.
local function BuildSpot(target, animated, cancelled)
    local base = Vector3.new(target.X, target.Y - STAND_OFFSET, target.Z) -- permukaan lantai, tengah
    local model = Instance.new("Model")
    model.Name = SPOT_NAME

    local record = { Model = model, Base = base, Target = target, Closing = false, Connections = {} }
    spot = record
    model.Parent = workspace

    local stage = {}

    local function At(x, y, z)
        return base + Vector3.new(x, y, z)
    end

    local function Put(class, props)
        local part = Instance.new(class)
        part.Anchored = true
        part.CanTouch = class == "Seat"
        part.TopSurface = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        for key, value in pairs(props) do part[key] = value end
        table.insert(stage, { Part = part, Transparency = part.Transparency })
        if animated then part.Transparency = 1 end
        part.Parent = model
        return part
    end

    local function Light(part, color, brightness, range)
        local light = Instance.new("PointLight")
        light.Color = color
        light.Brightness = brightness
        light.Range = range
        light.Shadows = false
        light.Parent = part
    end

    -- Menampilkan bagian-bagian tahap ini; false kalau build dibatalkan selagi menunggu.
    local function Reveal()
        local entries = stage
        stage = {}
        if not animated then return true end

        for _, entry in ipairs(entries) do
            TweenService:Create(entry.Part, TweenInfo.new(0.35), { Transparency = entry.Transparency }):Play()
        end
        task.wait(BUILD_STEP)
        return not (cancelled and cancelled())
    end

    local function Abort()
        if spot == record then
            DestroySpot()
        else
            pcall(function() model:Destroy() end)
        end
    end

    -- 1. lantai marmer + garis neon di tepinya
    record.Floor = Put("Part", {
        Name = "Floor", Size = Vector3.new(SPOT_SIZE, 2, SPOT_SIZE), CFrame = CFrame.new(At(0, -1, 0)),
        Material = Enum.Material.Marble, Color = Color3.fromRGB(30, 32, 46),
    })
    local edge = SPOT_SIZE / 2 - 1.5
    for _, side in ipairs({ -1, 1 }) do
        Put("Part", {
            Name = "TrimX", Size = Vector3.new(SPOT_SIZE - 3, 0.12, 0.5), CFrame = CFrame.new(At(0, 0.06, side * edge)),
            Material = Enum.Material.Neon, Color = ACCENT,
        })
        Put("Part", {
            Name = "TrimZ", Size = Vector3.new(0.5, 0.12, SPOT_SIZE - 3), CFrame = CFrame.new(At(side * edge, 0.06, 0)),
            Material = Enum.Material.Neon, Color = ACCENT,
        })
    end
    if not Reveal() then return Abort() end

    -- 2. pagar kaca di keempat sisi (karakter tidak bisa jatuh dari tepi) + garis neon di atasnya
    local rail = SPOT_SIZE / 2 - 0.3
    for _, side in ipairs({ -1, 1 }) do
        Put("Part", {
            Name = "RailX", Size = Vector3.new(SPOT_SIZE, 4, 0.6), CFrame = CFrame.new(At(0, 2, side * rail)),
            Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 200, 255), Transparency = 0.7,
        })
        Put("Part", {
            Name = "RailZ", Size = Vector3.new(0.6, 4, SPOT_SIZE - 1.2), CFrame = CFrame.new(At(side * rail, 2, 0)),
            Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 200, 255), Transparency = 0.7,
        })
        Put("Part", {
            Name = "RailTopX", Size = Vector3.new(SPOT_SIZE, 0.2, 0.8), CFrame = CFrame.new(At(0, 4.1, side * rail)),
            Material = Enum.Material.Neon, Color = ACCENT,
        })
        Put("Part", {
            Name = "RailTopZ", Size = Vector3.new(0.8, 0.2, SPOT_SIZE - 1.2), CFrame = CFrame.new(At(side * rail, 4.1, 0)),
            Material = Enum.Material.Neon, Color = ACCENT,
        })
    end
    if not Reveal() then return Abort() end

    -- 3. empat tiang sudut, masing-masing dengan lampu
    local corner = SPOT_SIZE / 2 - 1
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            Put("Part", {
                Name = "Pillar", Size = Vector3.new(1.8, 8, 1.8), CFrame = CFrame.new(At(sx * corner, 4, sz * corner)),
                Material = Enum.Material.Slate, Color = Color3.fromRGB(28, 28, 40),
            })
            local cap = Put("Part", {
                Name = "PillarLamp", Size = Vector3.new(2.4, 0.6, 2.4), CFrame = CFrame.new(At(sx * corner, 8.3, sz * corner)),
                Material = Enum.Material.Neon, Color = WARM,
            })
            Light(cap, WARM, 1.4, 30)
        end
    end
    if not Reveal() then return Abort() end

    -- 4. karpet bundar di tengah (lingkaran neon tipis sebagai bingkainya)
    local upright = CFrame.Angles(0, 0, math.pi / 2) -- silinder Roblox rebah di sumbu X; ditegakkan
    Put("Part", {
        Name = "RugRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 21, 21), CFrame = CFrame.new(At(0, 0.06, 0)) * upright,
        Material = Enum.Material.Neon, Color = ACCENT,
    })
    Put("Part", {
        Name = "Rug", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 20, 20), CFrame = CFrame.new(At(0, 0.1, 0)) * upright,
        Material = Enum.Material.Fabric, Color = Color3.fromRGB(58, 48, 110),
    })
    if not Reveal() then return Abort() end

    -- 5. sofa (tempat duduk menghadap +Z) dan meja kecil dengan lampu
    local sofaColor = Color3.fromRGB(82, 70, 150)
    local sofaDark = Color3.fromRGB(64, 54, 120)
    record.Seat = Put("Seat", {
        Name = "Seat", Size = Vector3.new(7, 1.4, 4), CFrame = CFrame.new(At(0, 0.9, 0)) * CFrame.Angles(0, math.pi, 0),
        Material = Enum.Material.Fabric, Color = sofaColor,
    })
    Put("Part", {
        Name = "SofaBack", Size = Vector3.new(8.8, 3.2, 1), CFrame = CFrame.new(At(0, 1.8, -2.5)),
        Material = Enum.Material.Fabric, Color = sofaDark,
    })
    for _, side in ipairs({ -1, 1 }) do
        Put("Part", {
            Name = "SofaArm", Size = Vector3.new(0.9, 2.2, 4.4), CFrame = CFrame.new(At(side * 3.95, 1.3, 0)),
            Material = Enum.Material.Fabric, Color = sofaDark,
        })
    end
    Put("Part", {
        Name = "Table", Size = Vector3.new(6, 1.2, 3), CFrame = CFrame.new(At(0, 0.8, 7)),
        Material = Enum.Material.Wood, Color = Color3.fromRGB(150, 105, 70),
    })
    local lamp = Put("Part", {
        Name = "TableLamp", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(At(0, 1.85, 7)),
        Material = Enum.Material.Neon, Color = WARM,
    })
    Light(lamp, WARM, 1.2, 16)
    if not Reveal() then return Abort() end

    -- 6. bola cahaya melayang di atas sofa
    local orb = Put("Part", {
        Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(At(0, 18, 0)),
        Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 236, 190),
    })
    Light(orb, Color3.fromRGB(255, 236, 200), 2, 48)
    if not Reveal() then return Abort() end

    record.Count = #model:GetChildren()

    -- Terhapus atau berubah oleh game: periksa lagi segera (selain itu loop memeriksa tiap 0.5 detik).
    local function onChange()
        if not record.Closing and Maintain then task.defer(Maintain) end
    end
    table.insert(record.Connections, model.ChildRemoved:Connect(onChange))
    table.insert(record.Connections, model.AncestryChanged:Connect(onChange))
    return record
end

local function SpotIntact()
    if not spot or not spot.Count then return false end
    local model = spot.Model
    return model.Parent == workspace
        and spot.Floor.Parent == model
        and spot.Seat.Parent == model
        and #model:GetChildren() >= spot.Count
end

local function InsideSpot(position)
    local half = SPOT_SIZE / 2 + 1
    local base = spot.Base
    return math.abs(position.X - base.X) <= half
        and math.abs(position.Z - base.Z) <= half
        and position.Y >= base.Y - 1
        and position.Y <= base.Y + 40
end

-- Karakter diturunkan sedikit di atas sofa dan duduk; tempat sudah ada, jadi tidak ada yang jatuh.
local function TeleportToSpot()
    if not spot then return end
    local root = GetRoot()
    if not root then return end

    local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.Sit = false end

    local base = spot.Base
    local position = Vector3.new(base.X, base.Y + SEAT_TOP + 2.8, base.Z)
    root.CFrame = CFrame.new(position, position + Vector3.new(0, 0, 1))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    local seat = spot.Seat
    task.delay(0.6, function()
        if humanoid and humanoid.Parent and humanoid.Health > 0 and not humanoid.SeatPart and seat and seat.Parent then
            pcall(function() seat:Sit(humanoid) end)
        end
    end)
end

-- Membangun dari awal dengan efek bertahap; karakter baru dipindah setelah selesai.
local function Prepare(target)
    buildToken = buildToken + 1
    local mine = buildToken
    building = true
    DestroySpot()

    local function cancelled()
        return mine ~= buildToken or not AfkFarm.FarmEnabled or not alive
    end

    task.spawn(function()
        Status("Building your AFK spot...")
        local ok, err = pcall(BuildSpot, target, true, cancelled)
        if mine ~= buildToken then return end -- digantikan permintaan yang lebih baru
        building = false

        if not AfkFarm.FarmEnabled or not alive then
            DestroySpot()
            return
        end
        if not ok or not spot or not spot.Count then
            DestroySpot()
            buildFailed = true
            warn("[Mugiwara HUB] AFK spot could not be built: " .. tostring(err))
            Status("The AFK spot could not be built. Holding your position with Fly instead.")
            return
        end

        TeleportToSpot()
        Status("Your AFK spot is ready.")
    end)
end

-- Cadangan kalau tempat gagal dibangun: tahan posisi memakai Fly seperti versi lama.
local function MaintainLegacy(target)
    local root = GetRoot()
    if not root then return end

    if (root.Position - target).Magnitude > RETURN_DISTANCE then
        root.CFrame = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
        root.AssemblyLinearVelocity = Vector3.zero
    end

    if Movement and not Movement.FlyEnabled then
        SetFly(true)
        flyOwned = true
    end
end

Maintain = function()
    if not AfkFarm.FarmEnabled or building or not alive then return end

    local target = AfkFarm.GetPosition() or heldPosition
    if not target then
        -- Belum ada koordinat dan karakter belum ada saat farm dinyalakan: pakai posisi pertama yang muncul.
        local root = GetRoot()
        if not root then return end
        heldPosition = root.Position
        target = heldPosition
    end

    if buildFailed then return MaintainLegacy(target) end

    -- Belum ada, atau koordinatnya diganti selagi farm menyala: bangun di lokasi yang benar.
    if not spot or (spot.Target - target).Magnitude > 0.5 then
        Prepare(target)
        return
    end

    -- Terhapus / di-refresh game: bangun ulang sekaligus, lalu kembalikan karakter ke atasnya.
    if not SpotIntact() then
        DestroySpot()
        local ok, err = pcall(BuildSpot, target, false)
        if ok and spot and spot.Count then
            TeleportToSpot()
        else
            DestroySpot()
            buildFailed = true
            warn("[Mugiwara HUB] AFK spot could not be rebuilt: " .. tostring(err))
        end
        return
    end

    -- Karakter keluar dari tempat (mati lalu respawn, ditarik game): kembalikan.
    local root = GetRoot()
    if root and not InsideSpot(root.Position) then TeleportToSpot() end
end

function AfkFarm.SetFarm(state)
    AfkFarm.FarmEnabled = state
    buildToken = buildToken + 1 -- membatalkan build yang masih berjalan
    building = false

    if state then
        buildFailed = false
        if not settings.Position then
            local root = GetRoot()
            heldPosition = root and root.Position or nil
        end
        Maintain()
    else
        heldPosition = nil
        DestroySpot()
        if flyOwned then
            flyOwned = false
            SetFly(false)
        end
    end
end

task.spawn(function()
    while alive do
        task.wait(MAINTAIN_INTERVAL)
        local ok, err = pcall(Maintain)
        if not ok then warn("[Mugiwara HUB] AFK Farm error: " .. tostring(err)) end
    end
end)

-- Full teardown on re-execute / unload.
getgenv().MugiwaraRegisterCleanup(function()
    alive = false
    AfkFarm.AutoExecEnabled = false
    generation = generation + 1
    table.clear(queue)

    buildToken = buildToken + 1
    building = false
    DestroySpot() -- tempat AFK ikut dibersihkan
    if AfkFarm.FarmEnabled then
        AfkFarm.FarmEnabled = false
        if flyOwned then pcall(SetFly, false) end
    end

    for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
    table.clear(connections)
    if diedConnection then diedConnection:Disconnect() diedConnection = nil end
end)

return AfkFarm
