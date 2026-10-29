-- Visual Unusual untuk Evade: memasang efek Unusual (partikel, beam, part, weld, cahaya) milik game ke karakter
-- sendiri, hanya di client. Beda dengan Visual Emotes / Carry: tidak ada tukar-menukar, efeknya DITAMBAHKAN dan
-- bisa ditumpuk beberapa sekaligus, lalu dibersihkan lagi.
--
-- Cara kerja game (ReplicatedStorage.Services.Asset.RigService.AddCosmetics), ditiru di sini:
--   * Unusual adalah ModuleScript kosmetik dengan CosmeticInfo.Unusual = true (254 item, tersebar di ItemPacks dan
--     BaseItems; daftarnya dari Registry kategori "Cosmetics").
--   * Isinya model "Character" (R15) dan "CharacterClassic" (R6). Anak-anak model itu adalah part pengganti dengan
--     nama anggota badan (Head, UpperTorso, LeftFoot, HumanoidRootPart, ...). Isi tiap part pengganti (attachment,
--     partikel, beam, part, weld, cahaya) dipindah ke anggota badan yang namanya sama di rig, jadi satu Unusual bisa
--     berupa "paket": sebagian di kepala, sebagian di kaki, dan seterusnya.
--   * Yang terlihat adalah rig di Workspace.Rigs[NamaPlayer], bukan Player.Character. Bagian HumanoidRootPart
--     ditempel ke HumanoidRootPart karakter (rig tidak punya).
-- Isi tiap Unusual disalin dulu ke memori (Capture) lalu ditempel dari salinan itu, jadi folder game tidak disentuh.
-- Rig bisa dibuat ulang game (ronde baru, ganti avatar): efek yang terpasang dipasang ulang otomatis.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local Unusual = {}

local entries = {}      -- { { Name, Display, Header, Rarity, Image, Id, Instance, Limbs, Data } } terurut menurut nama
local byInstance = {}   -- [instance] = entry
local applied = {}      -- [entry] = record { Entry, Rig, Roots = { { Instance, Host } }, Missing, PendingRoot }
local loaded = false
local source = "none"
local watching = false

Unusual.OnChange = nil -- dipanggil (tanpa argumen) tiap daftar terpasang berubah, termasuk saat dipasang ulang

-- Nama anggota badan yang jointnya milik rig sendiri: tidak boleh ditimpa/dipindah (sama dengan game).
local BODY_JOINTS = {}
for _, name in ipairs({
    "Head", "Torso", "TorsoRot", "Left Arm", "Left Leg", "Right Arm", "Right Leg", "ArmRot", "Neck", "Root",
    "LeftAnkle", "RightAnkle", "LeftKnee", "RightKnee", "LeftElbow", "RightElbow", "LeftShoulder", "RightShoulder",
    "LeftHip", "RightHip", "LeftWrist", "RightWrist", "Waist",
}) do
    BODY_JOINTS[name] = true
end

local function Changed()
    if Unusual.OnChange then task.spawn(Unusual.OnChange) end
end

--// daftar item ------------------------------------------------------------------

local function AddEntry(module, id, info)
    if byInstance[module] then return end
    local character = module:FindFirstChild("Character")
    local classic = module:FindFirstChild("CharacterClassic")
    if not character and not classic then return end -- aura RELICS (menempel ke boombox) bukan efek karakter

    local appearance = type(info.AppearanceInfo) == "table" and info.AppearanceInfo or {}
    local ui = type(info.UIInfo) == "table" and info.UIInfo or {}
    local icon = appearance.Icon
    local limbs = {}
    for _, part in ipairs((character or classic):GetChildren()) do
        if part:IsA("BasePart") then table.insert(limbs, part.Name) end
    end
    if #limbs == 0 then return end -- item kosong ("Nothing")

    local entry = {
        Name = module.Name,
        Display = type(appearance.Name) == "string" and appearance.Name or module.Name,
        Header = type(ui.Header) == "string" and ui.Header or "Other",
        Rarity = type(ui.Rarity) == "string" and ui.Rarity or nil,
        Image = (type(icon) == "number" and icon ~= 0) and ("rbxassetid://" .. icon) or nil,
        Id = id,
        Instance = module,
        Limbs = limbs,
    }
    table.insert(entries, entry)
    byInstance[module] = entry
end

local function IsUnusual(info)
    return type(info) == "table" and type(info.CosmeticInfo) == "table" and info.CosmeticInfo.Unusual == true
end

local function LoadFromRegistry()
    local items = ReplicatedStorage:FindFirstChild("Items")
    local registryModule = items and items:FindFirstChild("Registry")
    if not registryModule then return false end

    local ok, Registry = pcall(require, registryModule)
    if not ok or type(Registry) ~= "table" or type(Registry.GetByCategory) ~= "function" then return false end

    local okList, list = pcall(Registry.GetByCategory, "Cosmetics")
    if not okList or type(list) ~= "table" then return false end

    for id, record in pairs(list) do
        local module = type(record) == "table" and record.Module
        if typeof(module) == "Instance" then
            local okInfo, info = pcall(require, module)
            if okInfo and IsUnusual(info) then AddEntry(module, id, info) end
        end
    end
    return #entries > 0
end

-- Cadangan: semua ModuleScript di folder Items yang bertanda Unusual.
local function LoadFromScan()
    local items = ReplicatedStorage:FindFirstChild("Items")
    if not items then return end
    for _, descendant in ipairs(items:GetDescendants()) do
        if descendant:IsA("ModuleScript") and (descendant:FindFirstChild("Character") or descendant:FindFirstChild("CharacterClassic")) then
            local ok, info = pcall(require, descendant)
            if ok and IsUnusual(info) then AddEntry(descendant, descendant:GetAttribute("ID"), info) end
        end
    end
end

-- Daftar ditemukan sekali; menunggu folder Items sebentar kalau game belum selesai memuat.
function Unusual.Load()
    if loaded then return #entries end
    loaded = true

    if not ReplicatedStorage:FindFirstChild("Items") then
        pcall(function() ReplicatedStorage:WaitForChild("Items", 8) end)
    end

    if LoadFromRegistry() then
        source = "registry"
    else
        table.clear(entries)
        table.clear(byInstance)
        LoadFromScan()
        source = "scan"
    end

    table.sort(entries, function(a, b)
        return string.lower(a.Display) < string.lower(b.Display)
    end)
    return #entries
end

function Unusual.GetSource() return source end
function Unusual.GetEntries() return entries end

--// memori -----------------------------------------------------------------------

local function SafeClone(instance)
    if not instance then return nil end
    local ok, clone = pcall(instance.Clone, instance)
    return ok and clone or nil
end

-- Menyalin isi Unusual (model R15 dan R6) ke memori. Dipanggil sekali per item; hasilnya di entry.Data.
function Unusual.Capture(entry)
    if entry.Data then return entry.Data end
    entry.Data = {
        R15 = SafeClone(entry.Instance:FindFirstChild("Character")),
        R6 = SafeClone(entry.Instance:FindFirstChild("CharacterClassic")),
    }
    return entry.Data
end

-- Menyalin semua Unusual pelan-pelan di latar belakang. Mengembalikan jumlah yang disalin.
function Unusual.CaptureAll(onProgress)
    local count = 0
    for index, entry in ipairs(entries) do
        if not entry.Data then
            Unusual.Capture(entry)
            count = count + 1
        end
        if index % 6 == 0 then
            if onProgress then onProgress(index, #entries) end
            task.wait()
        end
    end
    return count
end

function Unusual.CapturedCount()
    local count = 0
    for _, entry in ipairs(entries) do
        if entry.Data then count = count + 1 end
    end
    return count
end

--// rig dan penempelan ----------------------------------------------------------------

-- Rig yang terlihat (Workspace.Rigs[NamaPlayer]); kalau game tidak punya, karakter biasa.
local function FindRig()
    local rigs = workspace:FindFirstChild("Rigs")
    local rig = rigs and rigs:FindFirstChild(LocalPlayer.Name)
    if rig and rig:FindFirstChild("Head") then return rig end
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("Head") then return character end
    return nil
end
Unusual.FindRig = FindRig

local function RigIsR6(rig)
    local humanoid = rig:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
end

-- Anggota badan bernama `name` di rig. Rig game tidak punya HumanoidRootPart: dipakai milik karakter.
local function FindLimb(rig, name)
    local limb = rig:FindFirstChild(name)
    if limb and limb:IsA("BasePart") then return limb end
    if name == "HumanoidRootPart" then
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then return root, true end
    end
    return nil
end

local function Tame(instance)
    if instance:IsA("BasePart") then
        instance.Anchored = false
        instance.Massless = true
        instance.CanCollide = false
        instance.CanQuery = false
        instance.CanTouch = false
    end
end

-- Menempelkan satu Unusual ke rig (meniru applyCosmeticRig milik game, tanpa merusak isi rig). Mengembalikan record.
local function Attach(entry, rig)
    local data = Unusual.Capture(entry)
    local model = (RigIsR6(rig) and data.R6 or data.R15) or nil
    local record = { Entry = entry, Rig = rig, Roots = {}, Missing = 0, PendingRoot = false }
    if not model then
        record.Missing = #entry.Limbs
        return record
    end

    local clone = model:Clone()
    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("Script") then descendant.Enabled = true end
    end

    for _, stand in ipairs(clone:GetChildren()) do
        if stand:IsA("BasePart") then
            local limb, isRoot = FindLimb(rig, stand.Name)
            if limb then
                if stand.Name == "Head" then
                    -- mesh/tekstur kepala pengganti tidak dipakai, kepala asli tetap
                    for _, child in ipairs(stand:GetChildren()) do
                        if child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceAppearance") then
                            child:Destroy()
                        end
                    end
                end
                for _, child in ipairs(stand:GetChildren()) do
                    if child:IsA("Attachment") then
                        -- attachment bernama sama dengan milik rig ikut posisinya (rig asli tidak diubah)
                        local own = limb:FindFirstChild(child.Name)
                        if own and own:IsA("Attachment") then child.CFrame = own.CFrame end
                    end
                    if not (child:IsA("Motor6D") and BODY_JOINTS[child.Name]) then
                        child.Parent = limb
                        table.insert(record.Roots, { Instance = child, Host = limb })
                    end
                end
            else
                record.Missing = record.Missing + 1
                if stand.Name == "HumanoidRootPart" then record.PendingRoot = true end
            end
        end
    end

    -- joint yang menunjuk part pengganti diarahkan ke anggota badan rig yang namanya sama
    for _, root in ipairs(record.Roots) do
        local instance = root.Instance
        local list = instance:GetDescendants()
        table.insert(list, instance)
        for _, item in ipairs(list) do
            if (item:IsA("Weld") or item:IsA("Motor6D")) and not BODY_JOINTS[item.Name] then
                if item.Part0 and item.Part0.Parent == clone then item.Part0 = FindLimb(rig, item.Part0.Name) end
                if item.Part1 and item.Part1.Parent == clone then item.Part1 = FindLimb(rig, item.Part1.Name) end
            end
            Tame(item)
        end
    end

    clone:Destroy()
    return record
end

local function Detach(record)
    for _, root in ipairs(record.Roots) do
        pcall(root.Instance.Destroy, root.Instance)
    end
    record.Roots = {}
end

-- Masih utuh: rig yang sama, semua akar masih menempel di tempatnya, dan bagian HumanoidRootPart yang tertunda
-- sudah bisa dipasang kalau karakternya sudah ada.
local function Intact(record, rig)
    if record.Rig ~= rig or not rig:IsDescendantOf(workspace) then return false end
    for _, root in ipairs(record.Roots) do
        if root.Instance.Parent ~= root.Host or not root.Host:IsDescendantOf(workspace) then return false end
    end
    if record.PendingRoot and FindLimb(rig, "HumanoidRootPart") then return false end
    return true
end

-- Pemeriksa latar belakang: hidup hanya selama ada yang terpasang.
local function Watch()
    if watching then return end
    watching = true
    task.spawn(function()
        while next(applied) ~= nil do
            task.wait(0.5)
            local rig = FindRig()
            if rig then
                local redone = false
                for entry, record in pairs(table.clone(applied)) do
                    if applied[entry] == record and not Intact(record, rig) then
                        Detach(record)
                        applied[entry] = Attach(entry, rig)
                        redone = true
                    end
                end
                if redone then Changed() end
            end
        end
        watching = false
    end)
end

--// API ---------------------------------------------------------------------------------

function Unusual.IsApplied(entry)
    return applied[entry] ~= nil
end

-- Daftar yang sedang terpasang, urut nama.
function Unusual.GetApplied()
    local list = {}
    for entry in pairs(applied) do table.insert(list, entry) end
    table.sort(list, function(a, b) return string.lower(a.Display) < string.lower(b.Display) end)
    return list
end

function Unusual.AppliedCount()
    local count = 0
    for _ in pairs(applied) do count = count + 1 end
    return count
end

-- Mengembalikan true, pesan atau false, alasan. Item yang sama dua kali tidak ditumpuk.
function Unusual.Apply(entry)
    if applied[entry] then return true, entry.Display .. " is already applied." end
    local rig = FindRig()
    if not rig then return false, "No character found. Spawn into a round first." end

    local ok, record = pcall(Attach, entry, rig)
    if not ok then return false, "Could not apply " .. entry.Display .. ": " .. tostring(record) end
    if #record.Roots == 0 and not record.PendingRoot then
        return false, entry.Display .. " has no effect for this character type."
    end

    applied[entry] = record
    Watch()
    Changed()
    return true, entry.Display .. " applied."
end

function Unusual.Remove(entry)
    local record = applied[entry]
    if not record then return false, entry.Display .. " is not applied." end
    applied[entry] = nil
    Detach(record)
    Changed()
    return true, entry.Display .. " removed."
end

-- Membersihkan semua. Mengembalikan jumlah yang dilepas.
function Unusual.Clear()
    local count = 0
    for entry, record in pairs(table.clone(applied)) do
        applied[entry] = nil
        Detach(record)
        count = count + 1
    end
    if count > 0 then Changed() end
    return count
end

-- Saat hub dimatikan semua efek dilepas.
getgenv().MugiwaraRegisterCleanup(function()
    Unusual.OnChange = nil
    pcall(Unusual.Clear)
end)

return Unusual
