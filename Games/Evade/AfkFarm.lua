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
-- AFK FARM (taman AFK kecil 50x50 di koordinat AFK)
-- ==========================================
-- Saat dinyalakan, taman AFK dibangun dulu (beberapa detik) di koordinat target, baru karakter
-- dipindahkan ke plazanya. Karakter tidak disentuh selama taman itu dibangun, jadi tidak ada saat
-- karakter berada di udara tanpa lantai. Duduk di bangku hanya lewat tombol (ToggleSit). Kalau tempatnya terhapus atau di-refresh game,
-- tempat itu dibangun ulang selama farm masih menyala; saat farm dimatikan semuanya dibersihkan.
-- Semua bagian adalah Part buatan client (Instance.new), jadi hanya terlihat di layar sendiri.
AfkFarm.FarmEnabled = false
AfkFarm.OnStatus = nil -- diisi UI: function(message)

local SPOT_NAME = "MugiwaraAfkSpot"
local SPOT_SIZE = 50        -- studs, persegi
local STAND_OFFSET = 3      -- jarak HumanoidRootPart ke lantai saat berdiri; lantai = target - ini
local BUILD_STEP = 0.3      -- detik per tahap saat membangun

local GRASS = Color3.fromRGB(92, 138, 74)
local HEDGE = Color3.fromRGB(46, 92, 52)
local LEAF = Color3.fromRGB(62, 128, 66)
local LEAF_LIGHT = Color3.fromRGB(88, 152, 80)
local BARK = Color3.fromRGB(110, 76, 50)
local STONE = Color3.fromRGB(150, 142, 130)
local STONE_DARK = Color3.fromRGB(96, 92, 88)
local STONE_LIGHT = Color3.fromRGB(176, 168, 154)
local WATER = Color3.fromRGB(120, 180, 230)
local IRON = Color3.fromRGB(40, 42, 48)
local PLANK = Color3.fromRGB(140, 100, 66)
local WARM = Color3.fromRGB(255, 214, 150)

local TweenService = game:GetService("TweenService")

local heldPosition = nil -- dipakai kalau belum ada koordinat tersimpan
local spot = nil         -- { Model, Seats, Floor, Base, Target, Count, Connections, Closing }
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
-- Membangun taman AFK
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
    local base = Vector3.new(target.X, target.Y - STAND_OFFSET, target.Z) -- permukaan rumput, tengah
    local model = Instance.new("Model")
    model.Name = SPOT_NAME

    local record = { Model = model, Base = base, Target = target, Closing = false, Connections = {}, Seats = {} }
    spot = record
    model.Parent = workspace

    local stage = {}
    local half = SPOT_SIZE / 2
    local upright = CFrame.Angles(0, 0, math.pi / 2) -- silinder Roblox rebah di sumbu X; ditegakkan

    local function At(x, y, z)
        return base + Vector3.new(x, y, z)
    end

    local function Put(class, props)
        local part = Instance.new(class)
        part.Anchored = true
        part.CanTouch = false
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

    -- 1. rumput, jalan setapak berbentuk salib, dan plaza bundar di tengah
    record.Floor = Put("Part", {
        Name = "Floor", Size = Vector3.new(SPOT_SIZE, 2, SPOT_SIZE), CFrame = CFrame.new(At(0, -1, 0)),
        Material = Enum.Material.Grass, Color = GRASS,
    })
    Put("Part", {
        Name = "PathX", Size = Vector3.new(SPOT_SIZE - 4, 0.12, 6), CFrame = CFrame.new(At(0, 0.06, 0)),
        Material = Enum.Material.Cobblestone, Color = STONE,
    })
    Put("Part", {
        Name = "PathZ", Size = Vector3.new(6, 0.12, SPOT_SIZE - 4), CFrame = CFrame.new(At(0, 0.06, 0)),
        Material = Enum.Material.Cobblestone, Color = STONE,
    })
    Put("Part", {
        Name = "PlazaRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 17.4, 17.4), CFrame = CFrame.new(At(0, 0.07, 0)) * upright,
        Material = Enum.Material.Slate, Color = STONE_DARK,
    })
    Put("Part", {
        Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 16, 16), CFrame = CFrame.new(At(0, 0.09, 0)) * upright,
        Material = Enum.Material.Cobblestone, Color = STONE_LIGHT,
    })
    if not Reveal() then return Abort() end

    -- 2. pagar tanaman rendah di keempat sisi + dinding tak terlihat (karakter tidak bisa keluar atau jatuh)
    for _, side in ipairs({ -1, 1 }) do
        Put("Part", {
            Name = "HedgeX", Size = Vector3.new(SPOT_SIZE, 3, 2), CFrame = CFrame.new(At(0, 1.5, side * (half - 1))),
            Material = Enum.Material.Grass, Color = HEDGE,
        })
        Put("Part", {
            Name = "HedgeZ", Size = Vector3.new(2, 3, SPOT_SIZE - 4), CFrame = CFrame.new(At(side * (half - 1), 1.5, 0)),
            Material = Enum.Material.Grass, Color = HEDGE,
        })
        Put("Part", {
            Name = "WallX", Size = Vector3.new(SPOT_SIZE + 2, 16, 1), CFrame = CFrame.new(At(0, 8, side * (half + 0.5))),
            Transparency = 1,
        })
        Put("Part", {
            Name = "WallZ", Size = Vector3.new(1, 16, SPOT_SIZE + 2), CFrame = CFrame.new(At(side * (half + 0.5), 8, 0)),
            Transparency = 1,
        })
    end
    if not Reveal() then return Abort() end

    -- 3. empat pohon (batang padat, daun tidak menghalangi) dengan bunga di kakinya
    local flowerColors = { Color3.fromRGB(255, 160, 190), Color3.fromRGB(255, 226, 120), Color3.fromRGB(245, 245, 250) }
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            local x, z = sx * 16, sz * 15
            Put("Part", {
                Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 1.6, 1.6), CFrame = CFrame.new(At(x, 3.5, z)) * upright,
                Material = Enum.Material.Wood, Color = BARK,
            })
            Put("Part", {
                Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(11, 9, 11), CFrame = CFrame.new(At(x, 9.2, z)),
                Material = Enum.Material.Grass, Color = LEAF, CanCollide = false,
            })
            Put("Part", {
                Name = "CanopyTop", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 6, 7), CFrame = CFrame.new(At(x + sx * 1.6, 12, z - sz * 1.2)),
                Material = Enum.Material.Grass, Color = LEAF_LIGHT, CanCollide = false,
            })
            for index, offset in ipairs({ { 2.6, 1.2 }, { -1.4, 2.8 }, { 3, -2 } }) do
                Put("Part", {
                    Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(At(x + offset[1] * sx, 0.45, z + offset[2] * sz)),
                    Material = Enum.Material.SmoothPlastic, Color = flowerColors[index], CanCollide = false,
                })
            end
        end
    end
    if not Reveal() then return Abort() end

    -- 4. air mancur di tengah plaza
    Put("Part", {
        Name = "FountainBasin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 7, 7), CFrame = CFrame.new(At(0, 0.6, 0)) * upright,
        Material = Enum.Material.Cobblestone, Color = STONE_DARK,
    })
    Put("Part", {
        Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 5.6, 5.6), CFrame = CFrame.new(At(0, 1.22, 0)) * upright,
        Material = Enum.Material.Glass, Color = WATER, Transparency = 0.35, CanCollide = false,
    })
    Put("Part", {
        Name = "FountainColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 0.9, 0.9), CFrame = CFrame.new(At(0, 3.2, 0)) * upright,
        Material = Enum.Material.Slate, Color = STONE_LIGHT,
    })
    Put("Part", {
        Name = "FountainTop", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = CFrame.new(At(0, 5.3, 0)),
        Material = Enum.Material.Slate, Color = STONE_LIGHT,
    })
    if not Reveal() then return Abort() end

    -- 5. lampu jalan: dasar, tiang, kap, dan bola lampu hangat
    local function StreetLamp(x, z)
        Put("Part", {
            Name = "LampBase", Size = Vector3.new(1.6, 0.6, 1.6), CFrame = CFrame.new(At(x, 0.3, z)),
            Material = Enum.Material.Metal, Color = IRON,
        })
        Put("Part", {
            Name = "LampPole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 0.5, 0.5), CFrame = CFrame.new(At(x, 5.1, z)) * upright,
            Material = Enum.Material.Metal, Color = IRON,
        })
        local bulb = Put("Part", {
            Name = "LampBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), CFrame = CFrame.new(At(x, 10.3, z)),
            Material = Enum.Material.Neon, Color = WARM,
        })
        Light(bulb, WARM, 1.6, 32)
        Put("Part", {
            Name = "LampHood", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.6, 2.6), CFrame = CFrame.new(At(x, 11.3, z)) * upright,
            Material = Enum.Material.Metal, Color = IRON,
        })
    end
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            StreetLamp(sx * 9.5, sz * 9.5)
        end
    end
    StreetLamp(4.5, 20)
    StreetLamp(-4.5, -20)
    if not Reveal() then return Abort() end

    -- 6. dua bangku di tepi jalan setapak. Dudukan dimatikan; baru dinyalakan saat tombol Sit ditekan.
    -- facing = arah hadap pada sumbu Z (-1 menghadap -Z): sandaran selalu di belakang.
    local function Bench(x, z, facing)
        local seat = Put("Seat", {
            Name = "Bench", Size = Vector3.new(6, 0.5, 2), CFrame = CFrame.new(At(x, 1.5, z)) * CFrame.Angles(0, facing > 0 and math.pi or 0, 0),
            Material = Enum.Material.WoodPlanks, Color = PLANK, Disabled = true,
        })
        seat.CanTouch = true
        table.insert(record.Seats, seat)
        Put("Part", {
            Name = "BenchBack", Size = Vector3.new(6, 1.8, 0.4), CFrame = CFrame.new(At(x, 2.6, z - facing * 0.95)),
            Material = Enum.Material.WoodPlanks, Color = PLANK,
        })
        for _, side in ipairs({ -1, 1 }) do
            Put("Part", {
                Name = "BenchLeg", Size = Vector3.new(0.4, 1.25, 1.6), CFrame = CFrame.new(At(x + side * 2.5, 0.62, z)),
                Material = Enum.Material.Metal, Color = IRON,
            })
        end
    end
    Bench(-12, 4.6, -1)
    Bench(12, -4.6, 1)
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
    if model.Parent ~= workspace or spot.Floor.Parent ~= model or #model:GetChildren() < spot.Count then
        return false
    end
    for _, seat in ipairs(spot.Seats) do
        if seat.Parent ~= model then return false end
    end
    return true
end

local function InsideSpot(position)
    local limit = SPOT_SIZE / 2 + 1
    local base = spot.Base
    return math.abs(position.X - base.X) <= limit
        and math.abs(position.Z - base.Z) <= limit
        and position.Y >= base.Y - 1
        and position.Y <= base.Y + 40
end

local function GetHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

-- Karakter diturunkan di plaza, di depan air mancur, menghadap ke sana. Tidak duduk otomatis.
local function TeleportToSpot()
    if not spot then return end
    local root = GetRoot()
    if not root then return end

    local humanoid = GetHumanoid()
    if humanoid then humanoid.Sit = false end

    local base = spot.Base
    local position = Vector3.new(base.X, base.Y + STAND_OFFSET + 0.4, base.Z + 6)
    root.CFrame = CFrame.new(position, Vector3.new(base.X, position.Y, base.Z))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

-- Duduk di bangku terdekat, atau berdiri lagi kalau sedang duduk. Dudukan hanya aktif selama ada
-- yang duduk, jadi berjalan melewati bangku tidak membuat karakter duduk sendiri.
function AfkFarm.ToggleSit()
    if not AfkFarm.FarmEnabled or building or not spot or not spot.Count then
        return false, "Turn AFK Farm on and wait until the park is built."
    end

    local root, humanoid = GetRoot(), GetHumanoid()
    if not root or not humanoid then return false, "Your character was not found." end

    if humanoid.SeatPart then
        humanoid.Sit = false
        return true, "Standing up."
    end

    local nearest, distance = nil, math.huge
    for _, seat in ipairs(spot.Seats) do
        local gap = (seat.Position - root.Position).Magnitude
        if seat.Parent and gap < distance then nearest, distance = seat, gap end
    end
    if not nearest then return false, "There is no bench to sit on." end

    nearest.Disabled = false
    root.CFrame = CFrame.new(nearest.Position + Vector3.new(0, 3, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    local sat = pcall(function() nearest:Sit(humanoid) end)

    -- Setelah berdiri (tombol, lompat, atau terlempar) dudukan dimatikan lagi.
    local released = false
    local connection
    local function release()
        if released then return end
        released = true
        if connection then connection:Disconnect() end
        nearest.Disabled = true
    end
    connection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
        if not humanoid.SeatPart then release() end
    end)
    task.delay(1, function()
        if not humanoid.SeatPart then release() end -- gagal duduk
    end)

    if not sat then
        release()
        return false, "Could not sit down."
    end
    return true, "Sitting on the bench. Press again to stand up."
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
        Status("Building your AFK park...")
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
            Status("The AFK park could not be built. Holding your position with Fly instead.")
            return
        end

        TeleportToSpot()
        Status("Your AFK park is ready. Use Sit / Stand to take a seat.")
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
