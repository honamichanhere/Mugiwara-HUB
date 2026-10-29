-- Pratinjau emote untuk Visual Emotes. Evade tidak punya gambar emote: tiap kotak di menu adalah
-- ViewportFrame yang dirender oleh ClientItemService:CreateViewport (rig + animasi emote dibekukan di
-- detik 0.5 + model properti). Modul ini memakai fungsi game itu di ViewportFrame tersembunyi, mengambil
-- hasilnya sebagai MODEL DIAM (pose dibakukan), dan menyimpannya. Model itulah yang dipakai Mugiwara UI
-- (GridDropdown, item Viewport), jadi tidak ada animasi yang berjalan di UI hub: hemat sumber daya.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Preview = {}

local POSE_TIMEOUT = 3   -- detik menunggu animasi emote siap (game memasang pose setelah panjang animasi diketahui)
local SETTLE_FRAMES = 2  -- frame tambahan supaya pose benar-benar terpasang di part

local alive = true
local ClientItemService = nil
local hostGui, host = nil, nil
local cache = {}         -- [modul emote] = model diam hasil render
local busy = false       -- satu render dalam satu waktu (host dipakai bersama)

local function HeartbeatWait(frames)
    for _ = 1, frames or 1 do RunService.Heartbeat:Wait() end
end

-- Fungsi render milik game; nil kalau executor tidak bisa require atau game berubah. Game sudah
-- memuatnya sebelum hub dijalankan, jadi hanya dicari (tidak ditunggu lama).
local function GetItemService()
    if ClientItemService then return ClientItemService end
    local ok, result = pcall(function()
        local services = ReplicatedStorage:FindFirstChild("Services") or ReplicatedStorage:WaitForChild("Services", 3)
        local items = services and services:FindFirstChild("Items")
        local module = items and items:FindFirstChild("ClientItemService")
        return module and require(module)
    end)
    if ok and type(result) == "table" and type(result.CreateViewport) == "function" then
        ClientItemService = result
    end
    return ClientItemService
end

function Preview.Available()
    return GetItemService() ~= nil
end

-- ViewportFrame kecil hampir tidak terlihat; namanya berawalan "Mugiwara" supaya Hide GUI tidak menyentuhnya.
local function GetHost()
    if host and host.Parent then return host end

    local parent
    pcall(function() parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not parent then parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end

    hostGui = Instance.new("ScreenGui")
    hostGui.Name = "MugiwaraEmotePreview"
    hostGui.ResetOnSpawn = false
    hostGui.DisplayOrder = -10
    hostGui.IgnoreGuiInset = true
    hostGui.Parent = parent

    host = Instance.new("ViewportFrame")
    host.Name = "Host"
    host.Size = UDim2.fromOffset(8, 8)
    host.Position = UDim2.fromOffset(0, 0)
    host.BackgroundTransparency = 1
    host.ImageTransparency = 0.98
    host.Parent = hostGui
    return host
end

-- Animator milik rig preview (rig pakai AnimationController, bukan Humanoid).
local function FindAnimator(rig)
    local controller = rig:FindFirstChildWhichIsA("AnimationController", true) or rig:FindFirstChildWhichIsA("Humanoid", true)
    return controller and controller:FindFirstChildOfClass("Animator")
end

-- Game memasang pose dengan: Play, AdjustSpeed(0), TimePosition = min(0.5, panjang). Siap kalau ada track begitu.
local function PoseReady(rig)
    local animator = FindAnimator(rig)
    if not animator then return false end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if track.Speed == 0 and track.TimePosition > 0 then return true end
    end
    return false
end

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

-- Salinan diam dari rig: tanpa Animator / controller / script, semua part Anchored.
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

-- Merender satu emote (menunggu sampai selesai; boleh yield). Mengembalikan model atau nil, alasan.
function Preview.Bake(entry)
    if not alive then return nil, "unloaded" end
    local cached = cache[entry.Instance]
    if cached then return cached end

    local service = GetItemService()
    if not service then return nil, "ClientItemService is not available" end

    while busy do
        task.wait(0.05)
        if not alive then return nil, "unloaded" end
    end
    cached = cache[entry.Instance]
    if cached then return cached end
    busy = true

    local frame = GetHost()
    local model, failure
    local ok, err = pcall(function()
        service:CreateViewport(entry.Instance, frame)

        local world = frame:FindFirstChildOfClass("WorldModel")
        local rig
        local deadline = os.clock() + 1
        while os.clock() < deadline do
            rig = world and world:FindFirstChildWhichIsA("Model")
            if rig then break end
            HeartbeatWait(1)
            world = world or frame:FindFirstChildOfClass("WorldModel")
        end
        if not rig then
            failure = "the game did not build a preview"
            return
        end

        local limit = os.clock() + POSE_TIMEOUT
        while alive and os.clock() < limit and not PoseReady(rig) do HeartbeatWait(1) end
        HeartbeatWait(SETTLE_FRAMES)

        SolveJoints(rig)
        model = Freeze(rig, entry.Display)
    end)

    pcall(function() service:ClearViewport(frame) end)
    busy = false

    if not ok then return nil, tostring(err) end
    if not model then return nil, failure or "preview failed" end
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
    if hostGui then pcall(function() hostGui:Destroy() end) hostGui, host = nil, nil end
end)

return Preview
