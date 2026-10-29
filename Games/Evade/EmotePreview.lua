-- Pratinjau emote untuk Visual Emotes. Evade tidak punya gambar emote: tiap kotak di menu game adalah
-- ViewportFrame berisi rig (ReplicatedStorage.Assets.Items.VisualRigR15Emote / VisualRigClassic) yang
-- memainkan animasi emote, dibekukan di detik 0.5, ditambah model properti emote. Modul ini membuat hal
-- yang sama sendiri (mengikuti Emote.lua / ClientItemService milik game, tanpa require modul game: require
-- modul layanan game dari executor bisa menggantung), lalu menyimpan hasilnya sebagai MODEL DIAM: pose
-- dibakukan dari sendi. Model itulah yang dipakai Mugiwara UI (GridDropdown, item Viewport), jadi tidak
-- ada animasi yang berjalan di UI hub: hemat sumber daya.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Preview = {}

local TRACK_TIMEOUT = 3  -- detik menunggu panjang animasi diketahui (sama seperti game: maksimal 5)
local SETTLE_FRAMES = 2  -- frame tambahan supaya pose benar-benar terpasang di part
local POSE_TIME = 0.5    -- detik animasi yang dibekukan, sama dengan game
local MAX_HOSTS = 4      -- render yang boleh berjalan bersamaan (animasi dimuat dari server, jadi lama)

local alive = true
local hostGui = nil
local hosts = {}         -- { Frame, InUse }: ViewportFrame tersembunyi
local cache = {}         -- [modul emote] = model diam hasil render
local inflight = {}      -- [modul emote] = true selama sedang dirender

local function HeartbeatWait(frames)
    for _ = 1, frames or 1 do RunService.Heartbeat:Wait() end
end

local function IsR15()
    local ok, rigType = pcall(function() return Players.LocalPlayer:GetAttribute("RigType") end)
    if ok and rigType ~= nil then return rigType == "R15" end
    return true
end

-- Rig kosong milik game untuk pratinjau (R15 atau klasik).
local function RigTemplate(r15)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local items = assets and assets:FindFirstChild("Items")
    return items and items:FindFirstChild(r15 and "VisualRigR15Emote" or "VisualRigClassic")
end

function Preview.Available()
    return RigTemplate(IsR15()) ~= nil
end

-- ViewportFrame kecil hampir tidak terlihat; namanya berawalan "Mugiwara" supaya Hide GUI tidak menyentuhnya.
local function EnsureGui()
    if hostGui and hostGui.Parent then return hostGui end

    local parent
    pcall(function() parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not parent then parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

    hostGui = Instance.new("ScreenGui")
    hostGui.Name = "MugiwaraEmotePreview"
    hostGui.ResetOnSpawn = false
    hostGui.DisplayOrder = -10
    hostGui.IgnoreGuiInset = true
    hostGui.Parent = parent
    table.clear(hosts)
    return hostGui
end

-- Mengambil host yang bebas (membuat baru sampai MAX_HOSTS, kalau tidak menunggu).
local function AcquireHost()
    while alive do
        local gui = EnsureGui()
        for _, entry in ipairs(hosts) do
            if not entry.InUse and entry.Frame.Parent then
                entry.InUse = true
                return entry
            end
        end
        if #hosts < MAX_HOSTS then
            local frame = Instance.new("ViewportFrame")
            frame.Name = "Host" .. (#hosts + 1)
            frame.Size = UDim2.fromOffset(8, 8)
            frame.Position = UDim2.fromOffset(0, 0)
            frame.BackgroundTransparency = 1
            frame.ImageTransparency = 0.98
            frame.Parent = gui
            local entry = { Frame = frame, InUse = true }
            table.insert(hosts, entry)
            return entry
        end
        task.wait(0.03)
    end
    return nil
end

-- ------------------------------------------
-- Isi emote (sama dengan cara game membacanya)
-- ------------------------------------------
-- Emote berpilihan (folder Selection) memakai pilihan pertama untuk pratinjau.
local function Variant(item)
    local selection = item:FindFirstChild("Selection")
    if selection then return selection:GetChildren()[1] or item end
    return item
end

-- Animasi utama untuk pratinjau (Intro / Outro tidak dipakai).
local function FindAnimation(item, r15)
    if item:FindFirstChild("Animations") or item:FindFirstChild("Selection") then
        local container = item:FindFirstChild("Selection") and Variant(item) or item
        local animations = container:FindFirstChild("Animations")
        local folder = animations and animations:FindFirstChild(r15 and "R15" or "R6")
        local animation = folder and folder:FindFirstChild("Animation")
        if animation and animation.AnimationId ~= "" then return animation end
        return nil
    end
    return item:FindFirstChild(r15 and "Animation" or "AnimationClassic")
end

-- Jarak akar ke kaki terendah (dari getRootOffset milik game): properti emote dipasang relatif ke sini.
local function RootOffset(model)
    local root = model:FindFirstChild("HumanoidRootPart")
    if not (root and root:IsA("BasePart")) then return 0 end

    local lowest = math.huge
    for _, name in ipairs({ "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }) do
        local part = model:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            local half = part.Size / 2
            for _, sx in ipairs({ -1, 1 }) do
                for _, sy in ipairs({ -1, 1 }) do
                    for _, sz in ipairs({ -1, 1 }) do
                        lowest = math.min(lowest, (part.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)).Y)
                    end
                end
            end
        end
    end
    if lowest == math.huge then return 0 end
    return root.Position.Y - lowest - 2.75
end

-- Model properti emote (EmoteModel, mis. gitar atau tunggangan) dipasang ke rig, seperti Emote:SetModel.
local function AttachProps(rig, item, r15)
    local template = Variant(item):FindFirstChild(r15 and "Character" or "CharacterClassic")
    if not template then return end

    local ok, copy = pcall(function() return template:Clone() end)
    if not ok or not copy then return end

    local emoteModel = copy:FindFirstChild("EmoteModel")
    if not emoteModel then
        copy:Destroy()
        return
    end

    local primary = rig:FindFirstChild("HumanoidRootPart", true) or rig.PrimaryPart
    local target = rig:FindFirstChild("R15Visual") or rig
    local offset = CFrame.new(0, RootOffset(copy), 0)

    emoteModel.Parent = target
    for _, child in ipairs(emoteModel:GetChildren()) do
        if (child:IsA("Motor6D") or child:IsA("Weld")) and child.Part0 and child.Part0.Parent == copy then
            if child.Part0.Name == "HumanoidRootPart" then
                child.Part0 = primary
                child.C0 = offset * child.C0
            else
                child.Part0 = target:FindFirstChild(child.Part0.Name)
            end
        end
    end
    copy:Destroy()
end

-- Animator rig pratinjau (rig memakai AnimationController, bukan Humanoid); dibuat kalau belum ada.
local function GetAnimator(rig)
    local controller = rig:FindFirstChildWhichIsA("AnimationController", true) or rig:FindFirstChildWhichIsA("Humanoid", true)
    if not controller then return nil end
    return controller:FindFirstChildOfClass("Animator") or (function()
        local animator = Instance.new("Animator")
        animator.Parent = controller
        return animator
    end)()
end

-- ------------------------------------------
-- Pose diam
-- ------------------------------------------
-- Menghitung ulang posisi tiap part dari sendi (Motor6D memakai Transform hasil animasi, Weld tidak),
-- dimulai dari part akar. Hasilnya tidak bergantung pada simulasi: model bisa ditaruh di ViewportFrame biasa.
local function SolveJoints(rig)
    local root = rig:FindFirstChild("HumanoidRootPart", true) or rig.PrimaryPart
    if not root then return false end

    local joints = {}
    for _, descendant in ipairs(rig:GetDescendants()) do
        if descendant:IsA("Motor6D") or descendant:IsA("Weld") then
            if descendant.Part0 and descendant.Part1 then table.insert(joints, descendant) end
        end
    end

    local solved = { [root] = true }
    local progress = true
    while progress do
        progress = false
        for _, joint in ipairs(joints) do
            local part0, part1 = joint.Part0, joint.Part1
            if solved[part0] and not solved[part1] then
                local transform = joint:IsA("Motor6D") and joint.Transform or CFrame.new()
                part1.CFrame = part0.CFrame * joint.C0 * transform * joint.C1:Inverse()
                solved[part1] = true
                progress = true
            end
        end
    end
    return true
end

-- Putar seluruh model supaya part utamanya sejajar sumbu dunia (rotasi identitas), posisi akarnya tetap.
-- Kamera game diletakkan relatif ke PrimaryPart rig (di depan karakter), tetapi rig di host bisa menghadap arah
-- lain; tanpa ini sisi yang terlihat di grid bisa dari samping.
local function Orient(model)
    local primary = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart", true)
    if not primary then return end

    local inverse = primary.CFrame:Inverse()
    local base = CFrame.new(primary.Position)
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then descendant.CFrame = base * (inverse * descendant.CFrame) end
    end
end

-- Salinan diam dari rig: tanpa Animator / controller / script, semua part Anchored, menghadap depan.
local function Freeze(rig, name)
    local copy = rig:Clone()
    copy.Name = name
    for _, descendant in ipairs(copy:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
        elseif descendant:IsA("AnimationController") or descendant:IsA("Humanoid") or descendant:IsA("Animator") or descendant:IsA("LuaSourceContainer") or descendant:IsA("Sound") then
            pcall(function() descendant:Destroy() end)
        end
    end
    Orient(copy)
    return copy
end

-- Model diam emote ini dari cache, atau nil kalau belum dirender.
function Preview.Get(entry)
    return entry and cache[entry.Instance] or nil
end

-- Membuang hasil render lama (dipakai setelah emote ditukar: gambarnya ikut berubah).
function Preview.Invalidate(entry)
    local model = entry and cache[entry.Instance]
    if model then
        cache[entry.Instance] = nil
        pcall(function() model:Destroy() end)
    end
end

-- Memuat animasi semua emote ini lebih dulu, serentak, di latar belakang (mempercepat render berikutnya).
function Preview.Preload(entries)
    local r15 = IsR15()
    local list = {}
    for _, entry in ipairs(entries) do
        if not cache[entry.Instance] then
            local animation = FindAnimation(entry.Instance, r15)
            if animation then table.insert(list, animation) end
        end
    end
    if #list == 0 then return end
    task.spawn(function()
        pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
    end)
end

-- Merender satu emote (menunggu sampai selesai; boleh yield). Mengembalikan model atau nil, alasan.
-- Beberapa emote boleh dirender bersamaan (sampai MAX_HOSTS).
function Preview.Bake(entry)
    if not alive then return nil, "unloaded" end
    local cached = cache[entry.Instance]
    if cached then return cached end

    local r15 = IsR15()
    local template = RigTemplate(r15)
    if not template then return nil, "the game's preview rig was not found" end

    -- emote yang sama sedang dirender (mis. oleh sisi grid lain): tunggu hasilnya
    while inflight[entry.Instance] do
        task.wait(0.03)
        if not alive then return nil, "unloaded" end
    end
    cached = cache[entry.Instance]
    if cached then return cached end
    inflight[entry.Instance] = true

    local hostEntry = AcquireHost()
    if not hostEntry then
        inflight[entry.Instance] = nil
        return nil, "unloaded"
    end

    local model
    local world
    local ok, err = pcall(function()
        world = Instance.new("WorldModel")
        world.Parent = hostEntry.Frame

        local rig = template:Clone()
        rig.Parent = world
        AttachProps(rig, entry.Instance, r15)

        local animation = FindAnimation(entry.Instance, r15)
        local animator = animation and GetAnimator(rig)
        if animation and animator then
            local track = animator:LoadAnimation(animation)
            track.Priority = Enum.AnimationPriority.Action3
            track:Play(0)
            track:AdjustSpeed(0)

            local limit = os.clock() + TRACK_TIMEOUT
            while track.Length <= 0 and alive and os.clock() < limit do HeartbeatWait(1) end
            track.TimePosition = math.min(POSE_TIME, track.Length)
            HeartbeatWait(SETTLE_FRAMES)
        end

        SolveJoints(rig)
        model = Freeze(rig, entry.Display)
    end)

    if world then pcall(function() world:Destroy() end) end
    hostEntry.InUse = false
    inflight[entry.Instance] = nil

    if not ok then return nil, tostring(err) end
    if not model then return nil, "preview failed" end
    if not alive then
        model:Destroy()
        return nil, "unloaded"
    end

    cache[entry.Instance] = model
    return model
end

getgenv().MugiwaraRegisterCleanup(function()
    alive = false
    for instance, model in pairs(cache) do pcall(function() model:Destroy() end) cache[instance] = nil end
    if hostGui then pcall(function() hostGui:Destroy() end) hostGui = nil end
    table.clear(hosts)
end)

return Preview
