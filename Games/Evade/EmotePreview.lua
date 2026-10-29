-- Pratinjau emote untuk Visual Emotes. Evade tidak punya gambar emote: tiap kotak di menu game adalah
-- ViewportFrame berisi rig (ReplicatedStorage.Assets.Items.VisualRigR15Emote / VisualRigClassic) yang
-- memainkan animasi emote, dibekukan di detik 0.5, ditambah model properti emote. Modul ini membuat hal
-- yang sama sendiri (mengikuti Emote.lua / ClientItemService milik game, tanpa require modul game: require
-- modul layanan game dari executor bisa menggantung).
--
-- Supaya ringan, ada tiga lapis:
--  1. POSE disimpan ke file (MugiwaraHub/EmotePoses.json), kuncinya animasi (R15/R6 + AnimationId). Hanya
--     sekali per animasi dihitung dengan benar-benar memainkan animasinya (lambat: animasi dimuat dari server);
--     sesudah itu model dibangun langsung dari data sendi, tanpa animasi, tanpa menunggu (instan). Karena
--     kuncinya animasi, emote yang ditukar otomatis memakai pose pasangannya.
--  2. Model hasilnya DIAM dan dibersihkan (tanpa sendi, attachment, partikel, trail, beam, lampu, dll).
--  3. Pengumpulan pose untuk semua emote berjalan pelan di latar belakang (Collect), satu per satu.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Preview = {}

local TRACK_TIMEOUT = 3   -- detik menunggu panjang animasi diketahui (sama seperti game: maksimal 5)
local SETTLE_FRAMES = 2   -- frame tambahan supaya pose benar-benar terpasang di sendi
local POSE_TIME = 0.5     -- detik animasi yang dibekukan, sama dengan game
local MAX_HOSTS = 3       -- pengambilan pose yang boleh berjalan bersamaan (animasi dimuat dari server)
local COLLECT_GAP = 0.12  -- jeda antar emote saat mengumpulkan pose di latar belakang

local POSE_FILE = (getgenv().MugiwaraFolder or "MugiwaraHub") .. "/EmotePoses.json"
local POSE_VERSION = 1

local alive = true
local hostGui = nil
local hosts = {}          -- { Frame, InUse }: ViewportFrame tersembunyi
local cache = {}          -- [modul emote] = model diam hasil render
local inflight = {}       -- [modul emote] = true selama model sedang dibangun
local inflightPose = {}   -- [kunci pose] = true selama pose sedang diambil
local poses = nil         -- [kunci pose] = { [jalur sendi] = komponen CFrame }
local poseToken = 0

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

-- ------------------------------------------
-- Penyimpanan pose
-- ------------------------------------------
local function LoadPoses()
    if poses then return poses end
    poses = {}
    if readfile and isfile and isfile(POSE_FILE) then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(POSE_FILE)) end)
        if ok and type(decoded) == "table" and decoded.Version == POSE_VERSION and type(decoded.Poses) == "table" then
            poses = decoded.Poses
        end
    end
    return poses
end

local function FlushPoses()
    poseToken = poseToken + 1
    if not (poses and writefile) then return end
    pcall(function()
        if makefolder and isfolder and not isfolder(getgenv().MugiwaraFolder or "MugiwaraHub") then makefolder(getgenv().MugiwaraFolder or "MugiwaraHub") end
        writefile(POSE_FILE, HttpService:JSONEncode({ Version = POSE_VERSION, Poses = poses }))
    end)
end

-- Menyimpan sekali setelah pengambilan pose berhenti sebentar (banyak pose datang beruntun).
local function SavePosesSoon()
    poseToken = poseToken + 1
    local mine = poseToken
    task.delay(3, function()
        if mine == poseToken then FlushPoses() end
    end)
end

-- Jalur sendi relatif ke rig, mis. "R15Visual/UpperTorso/RightShoulder".
local function JointPath(rig, joint)
    local names = {}
    local node = joint
    while node and node ~= rig do
        table.insert(names, 1, node.Name)
        node = node.Parent
    end
    return table.concat(names, "/")
end

local IDENTITY = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }

local function IsIdentity(components)
    for index, value in ipairs(IDENTITY) do
        if math.abs((components[index] or 0) - value) > 0.0001 then return false end
    end
    return true
end

-- Transform semua Motor6D rig (hasil animasi); sendi tanpa gerakan tidak disimpan.
local function CapturePose(rig)
    local pose = {}
    for _, descendant in ipairs(rig:GetDescendants()) do
        if descendant:IsA("Motor6D") then
            local components = { descendant.Transform:GetComponents() }
            if not IsIdentity(components) then pose[JointPath(rig, descendant)] = components end
        end
    end
    return pose
end

local function ApplyPose(rig, pose)
    for _, descendant in ipairs(rig:GetDescendants()) do
        if descendant:IsA("Motor6D") then
            local components = pose[JointPath(rig, descendant)]
            descendant.Transform = components and CFrame.new(table.unpack(components)) or CFrame.new()
        end
    end
end

-- ------------------------------------------
-- Host tersembunyi (hanya dipakai saat animasi benar-benar dimainkan)
-- ------------------------------------------
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

local function PoseKey(animation, r15)
    return (r15 and "R15:" or "R6:") .. tostring(animation.AnimationId)
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
-- Model diam
-- ------------------------------------------
-- Menghitung ulang posisi tiap part dari sendi (Motor6D memakai Transform, Weld tidak), dimulai dari part
-- akar. Hasilnya tidak bergantung pada simulasi: model bisa ditaruh di ViewportFrame biasa.
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
-- Kamera game diletakkan relatif ke PrimaryPart rig (di depan karakter), tetapi rig bisa menghadap arah
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

-- Yang tidak berguna untuk gambar diam dibuang: sendi (posisi sudah dibakukan), attachment, partikel,
-- trail, beam, lampu, efek, script, suara. Tiap viewport menggambar ulang semuanya setiap frame, jadi
-- makin sedikit isinya makin ringan.
local STRIP_CLASSES = {
    "Motor6D", "Weld", "ManualWeld", "WeldConstraint", "Snap", "Constraint",
    "ParticleEmitter", "Trail", "Beam", "Fire", "Smoke", "Sparkles", "Explosion", "Highlight", "ForceField",
    "PointLight", "SpotLight", "SurfaceLight", "WrapTarget", "WrapLayer",
    "AnimationController", "Humanoid", "Animator", "LuaSourceContainer", "Sound",
}

local function ShouldStrip(instance)
    for _, class in ipairs(STRIP_CLASSES) do
        if instance:IsA(class) then return true end
    end
    return instance:IsA("Attachment") and not instance:IsA("Bone")
end

-- Salinan diam dari rig: bersih, semua part Anchored, menghadap depan.
local function Freeze(rig, name)
    local copy = rig:Clone()
    copy.Name = name
    for _, descendant in ipairs(copy:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CastShadow = false
            descendant.CanCollide = false
            descendant.CanQuery = false
            descendant.CanTouch = false
        end
    end
    for _, descendant in ipairs(copy:GetDescendants()) do
        if ShouldStrip(descendant) then pcall(function() descendant:Destroy() end) end
    end
    Orient(copy)
    return copy
end

-- Model dari rig kosong + properti emote + pose (tanpa animasi, tanpa menunggu).
local function BuildModel(entry, r15, template, pose)
    local rig = template:Clone()
    AttachProps(rig, entry.Instance, r15)
    if pose then ApplyPose(rig, pose) end
    SolveJoints(rig)
    local model = Freeze(rig, entry.Display)
    pcall(function() rig:Destroy() end)
    return model
end

-- ------------------------------------------
-- Pengambilan pose (satu-satunya bagian yang lambat)
-- ------------------------------------------
-- Pose animasi emote ini: dari file kalau sudah pernah dihitung, kalau belum dihitung dengan memainkan
-- animasinya di host tersembunyi (menunggu animasi dimuat dari server) lalu disimpan.
-- Mengembalikan pose, atau nil (tanpa alasan) kalau emote tidak punya animasi, atau nil + alasan kalau gagal.
local function EnsurePose(entry, r15, template)
    local animation = FindAnimation(entry.Instance, r15)
    if not animation then return nil end

    local key = PoseKey(animation, r15)
    local store = LoadPoses()
    if store[key] then return store[key] end

    -- animasi yang sama sedang diambil (mis. oleh emote lain): tunggu hasilnya
    while inflightPose[key] do
        task.wait(0.03)
        if not alive then return nil, "unloaded" end
    end
    if store[key] then return store[key] end
    inflightPose[key] = true

    local hostEntry = AcquireHost()
    if not hostEntry then
        inflightPose[key] = nil
        return nil, "unloaded"
    end

    local pose, failure
    local world
    local ok, err = pcall(function()
        world = Instance.new("WorldModel")
        world.Parent = hostEntry.Frame

        local rig = template:Clone()
        rig.Parent = world

        local animator = GetAnimator(rig)
        if not animator then
            failure = "the preview rig has no animator"
            return
        end

        local track = animator:LoadAnimation(animation)
        track.Priority = Enum.AnimationPriority.Action3
        track:Play(0)
        track:AdjustSpeed(0)

        local limit = os.clock() + TRACK_TIMEOUT
        while track.Length <= 0 and alive and os.clock() < limit do HeartbeatWait(1) end
        if track.Length <= 0 then
            failure = "the animation did not load"
            return
        end

        track.TimePosition = math.min(POSE_TIME, track.Length)
        HeartbeatWait(SETTLE_FRAMES)
        pose = CapturePose(rig)
    end)

    if world then pcall(function() world:Destroy() end) end
    hostEntry.InUse = false
    inflightPose[key] = nil

    if not ok then return nil, tostring(err) end
    if not pose then return nil, failure or "preview failed" end

    store[key] = pose
    SavePosesSoon()
    return pose
end

-- ------------------------------------------
-- API
-- ------------------------------------------
-- Model diam emote ini dari cache, atau nil kalau belum dibangun.
function Preview.Get(entry)
    return entry and cache[entry.Instance] or nil
end

-- true kalau pose emote ini sudah ada di file (membangun modelnya instan).
function Preview.PoseKnown(entry)
    local animation = FindAnimation(entry.Instance, IsR15())
    return animation == nil or LoadPoses()[PoseKey(animation, IsR15())] ~= nil
end

-- Membuang model lama (dipakai setelah emote ditukar: isinya berubah, jadi gambarnya ikut berubah).
function Preview.Invalidate(entry)
    local model = entry and cache[entry.Instance]
    if model then
        cache[entry.Instance] = nil
        pcall(function() model:Destroy() end)
    end
end

-- Memuat animasi emote yang posenya belum ada, serentak, di latar belakang (mempercepat pengambilan pose).
function Preview.Preload(entries)
    local r15 = IsR15()
    local store = LoadPoses()
    local list = {}
    for _, entry in ipairs(entries) do
        local animation = FindAnimation(entry.Instance, r15)
        if animation and not store[PoseKey(animation, r15)] then table.insert(list, animation) end
    end
    if #list == 0 then return end
    task.spawn(function()
        pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
    end)
end

-- Membangun model diam satu emote (menunggu kalau posenya belum ada; boleh yield). Mengembalikan model
-- atau nil, alasan. Kalau posenya sudah tersimpan, hasilnya langsung ada tanpa menunggu.
function Preview.Bake(entry)
    if not alive then return nil, "unloaded" end
    local cached = cache[entry.Instance]
    if cached then return cached end

    local r15 = IsR15()
    local template = RigTemplate(r15)
    if not template then return nil, "the game's preview rig was not found" end

    -- emote yang sama sedang dibangun (mis. oleh sisi grid lain): tunggu hasilnya
    while inflight[entry.Instance] do
        task.wait(0.03)
        if not alive then return nil, "unloaded" end
    end
    cached = cache[entry.Instance]
    if cached then return cached end
    inflight[entry.Instance] = true

    local model, failure
    local ok, err = pcall(function()
        local pose, reason = EnsurePose(entry, r15, template)
        if reason then
            failure = reason
            return
        end
        model = BuildModel(entry, r15, template, pose)
    end)
    inflight[entry.Instance] = nil

    if not ok then return nil, tostring(err) end
    if not model then return nil, failure or "preview failed" end
    if not alive then
        model:Destroy()
        return nil, "unloaded"
    end

    cache[entry.Instance] = model
    return model
end

-- Mengumpulkan pose semua emote ini di latar belakang, pelan-pelan (satu per satu, ada jeda), supaya
-- membuka kategori mana pun nanti langsung instan. Hanya jalan sekali per animasi (hasilnya disimpan).
-- Mengembalikan jumlah pose baru yang berhasil diambil.
function Preview.Collect(entries)
    local r15 = IsR15()
    local template = RigTemplate(r15)
    if not template then return 0 end

    local store = LoadPoses()
    local collected = 0
    for _, entry in ipairs(entries) do
        if not alive then break end
        local animation = FindAnimation(entry.Instance, r15)
        if animation and not store[PoseKey(animation, r15)] then
            if EnsurePose(entry, r15, template) then collected = collected + 1 end
            task.wait(COLLECT_GAP)
        end
    end
    return collected
end

getgenv().MugiwaraRegisterCleanup(function()
    alive = false
    FlushPoses()
    for instance, model in pairs(cache) do pcall(function() model:Destroy() end) cache[instance] = nil end
    if hostGui then pcall(function() hostGui:Destroy() end) hostGui = nil end
    table.clear(hosts)
end)

return Preview
