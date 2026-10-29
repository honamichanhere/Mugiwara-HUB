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
--   * Yang terlihat adalah rig di Workspace.Rigs, bukan Player.Character. Ada DUA rig dengan nama pemain yang sama
--     (rig inventory dan rig dalam game; lihat Rigs.lua), jadi efek dipasang ke keduanya. Bagian HumanoidRootPart
--     ditempel sekali ke HumanoidRootPart karakter (rig tidak punya).
-- Isi tiap Unusual disalin dulu ke memori (Capture) lalu ditempel dari salinan itu, jadi folder game tidak disentuh.
-- Pemeriksa latar belakang (Watch) mengecek semua efek di semua rig tiap 0.3 detik: efek yang dihapus game dipasang
-- lagi, dan rig baru (ronde baru, ganti avatar, inventory dibuka lagi) langsung dipasangi.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Rigs = getgenv().MugiwaraImport("Games/Evade/Rigs.lua")

local Unusual = {}

local entries = {}      -- { { Name, Display, Header, Rarity, Image, Id, Instance, Limbs, Data } } terurut menurut nama
local byInstance = {}   -- [instance] = entry
local applied = {}      -- [entry] = record { Entry, Subs = { [rig] = sub }, RootSub }; sub = { Host, Roots = { { Instance, Host } }, Missing }
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
        HasRoot = table.find(limbs, "HumanoidRootPart") ~= nil,
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

local function RigIsR6(rig)
    local humanoid = rig:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
end

-- Semua rig yang terlihat milik pemain lokal: Evade punya DUA dengan nama yang sama di Workspace.Rigs (rig
-- inventory/menu dan rig dalam game), keduanya dipasangi. Rigs.lua yang menentukan; tanpanya dipakai pencarian
-- sederhana dengan aturan yang sama (karakter biasa kalau tidak ada rig sama sekali).
local function Targets()
    local list = {}
    local entries = Rigs and Rigs.GetAll() or nil
    if entries then
        for _, entry in ipairs(entries) do
            if entry.Rig:FindFirstChild("Head") then table.insert(list, entry.Rig) end
        end
        return list
    end

    local container = workspace:FindFirstChild("Rigs")
    if container then
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") and child.Name == LocalPlayer.Name and child:FindFirstChild("Head") then
                table.insert(list, child)
            end
        end
    end
    local character = LocalPlayer.Character
    if #list == 0 and character and character:FindFirstChild("Head") then table.insert(list, character) end
    return list
end
Unusual.GetTargets = Targets

local function LimbOf(host, name)
    local limb = host:FindFirstChild(name)
    if limb and limb:IsA("BasePart") then return limb end
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

-- Menempelkan satu Unusual ke `host` (meniru applyCosmeticRig milik game, tanpa merusak isi rig). Mengembalikan sub:
-- { Host, Roots = { { Instance, Host } }, Missing }.
-- Rig game tidak punya HumanoidRootPart, jadi bagian untuk HumanoidRootPart dilewati di rig dan ditempel sekali ke
-- karakter (onlyRoot = true, host = karakter). Rig yang punya HumanoidRootPart (karakter biasa) memasangnya sendiri.
local function Attach(entry, host, onlyRoot)
    local data = Unusual.Capture(entry)
    local model = RigIsR6(host) and data.R6 or data.R15
    local sub = { Host = host, Roots = {}, Missing = 0 }
    if not model then
        sub.Missing = #entry.Limbs
        return sub
    end

    local clone = model:Clone()
    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("Script") then descendant.Enabled = true end
    end

    for _, stand in ipairs(clone:GetChildren()) do
        if stand:IsA("BasePart") then
            local isRootStand = stand.Name == "HumanoidRootPart"
            local wanted
            if onlyRoot then
                wanted = isRootStand
            else
                wanted = not isRootStand or host:FindFirstChild("HumanoidRootPart") ~= nil
            end

            if wanted then
                local limb = LimbOf(host, stand.Name)
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
                            table.insert(sub.Roots, { Instance = child, Host = limb })
                        end
                    end
                else
                    sub.Missing = sub.Missing + 1
                end
            end
        end
    end

    -- joint yang menunjuk part pengganti diarahkan ke anggota badan yang namanya sama
    for _, root in ipairs(sub.Roots) do
        local instance = root.Instance
        local list = instance:GetDescendants()
        table.insert(list, instance)
        for _, item in ipairs(list) do
            if (item:IsA("Weld") or item:IsA("Motor6D")) and not BODY_JOINTS[item.Name] then
                if item.Part0 and item.Part0.Parent == clone then item.Part0 = LimbOf(host, item.Part0.Name) end
                if item.Part1 and item.Part1.Parent == clone then item.Part1 = LimbOf(host, item.Part1.Name) end
            end
            Tame(item)
        end
    end

    clone:Destroy()
    return sub
end

local function Detach(sub)
    for _, root in ipairs(sub.Roots) do
        pcall(root.Instance.Destroy, root.Instance)
    end
    sub.Roots = {}
end

-- Masih utuh: host-nya masih ada di game dan semua akar masih menempel di tempatnya (kalau game menghapus atau
-- memindahkan salah satu, sub ini dipasang ulang).
local function Intact(sub)
    if not sub.Host:IsDescendantOf(workspace) then return false end
    for _, root in ipairs(sub.Roots) do
        if root.Instance.Parent ~= root.Host or not root.Host:IsDescendantOf(workspace) then return false end
    end
    return true
end

local function SafeAttach(entry, host, onlyRoot)
    local ok, sub = pcall(Attach, entry, host, onlyRoot)
    if ok then return sub end
    warn("[Mugiwara HUB] Visual Unusual: " .. entry.Display .. ": " .. tostring(sub))
    return { Host = host, Roots = {}, Missing = 0 }
end

-- Menyamakan satu record dengan keadaan sekarang: rig yang hilang dilepas, rig baru dipasangi, dan yang efeknya
-- terhapus oleh game dipasang ulang. Mengembalikan true kalau ada yang berubah.
local function Sync(record, rigs)
    local changed = false

    local present = {}
    for _, rig in ipairs(rigs) do present[rig] = true end
    for host, sub in pairs(table.clone(record.Subs)) do
        if not present[host] then
            Detach(sub)
            record.Subs[host] = nil
            changed = true
        end
    end

    local rootCovered = false
    for _, rig in ipairs(rigs) do
        if rig:FindFirstChild("HumanoidRootPart") then rootCovered = true end
        local sub = record.Subs[rig]
        if not sub or not Intact(sub) then
            if sub then Detach(sub) end
            record.Subs[rig] = SafeAttach(record.Entry, rig, false)
            changed = true
        end
    end

    -- bagian HumanoidRootPart: satu kali di karakter, kalau tidak ada rig yang punya HumanoidRootPart sendiri
    local character = LocalPlayer.Character
    local wantRoot = record.Entry.HasRoot and not rootCovered and character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
    if wantRoot then
        local sub = record.RootSub
        if not sub or sub.Host ~= character or not Intact(sub) then
            if sub then Detach(sub) end
            record.RootSub = SafeAttach(record.Entry, character, true)
            changed = true
        end
    elseif record.RootSub and not (record.Entry.HasRoot and not rootCovered) then
        Detach(record.RootSub)
        record.RootSub = nil
        changed = true
    end

    return changed
end

local function DetachAll(record)
    for _, sub in pairs(record.Subs) do Detach(sub) end
    record.Subs = {}
    if record.RootSub then
        Detach(record.RootSub)
        record.RootSub = nil
    end
end

local function RootCount(record)
    local count = record.RootSub and #record.RootSub.Roots or 0
    for _, sub in pairs(record.Subs) do count = count + #sub.Roots end
    return count
end

-- Pemeriksa latar belakang: hidup hanya selama ada yang terpasang. Tiap 0.3 detik semua efek dicek di semua rig.
local function Watch()
    if watching then return end
    watching = true
    task.spawn(function()
        while next(applied) ~= nil do
            task.wait(0.3)
            local rigs = Targets()
            local redone = false
            for entry, record in pairs(table.clone(applied)) do
                if applied[entry] == record then
                    local ok, changed = pcall(Sync, record, rigs)
                    if ok and changed then redone = true end
                end
            end
            if redone then Changed() end
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
    local rigs = Targets()
    if #rigs == 0 then return false, "No character found. Spawn into a round first." end

    local record = { Entry = entry, Subs = {}, RootSub = nil }
    local ok, err = pcall(Sync, record, rigs)
    if not ok then
        DetachAll(record)
        return false, "Could not apply " .. entry.Display .. ": " .. tostring(err)
    end
    if RootCount(record) == 0 and not entry.HasRoot then
        DetachAll(record)
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
    DetachAll(record)
    Changed()
    return true, entry.Display .. " removed."
end

-- Membersihkan semua. Mengembalikan jumlah yang dilepas.
function Unusual.Clear()
    local count = 0
    for entry, record in pairs(table.clone(applied)) do
        applied[entry] = nil
        DetachAll(record)
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
