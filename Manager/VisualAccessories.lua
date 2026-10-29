local VisualAccessories = {}
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

local LocalPlayer = Players.LocalPlayer

-- Modul visual karakter yang dipakai bersama oleh Universal dan Evade: accessories dari Marketplace,
-- Headless, dan Korblox. Logikanya sama di mana-mana, yang beda hanya rig mana yang diubah:
--   Universal: karakter bawaan Roblox (LocalPlayer.Character, R6 atau R15)
--   Evade    : rig kustom di Workspace.Rigs (lihat Games/Evade/VisualAccessories.lua, memasang SetRigProvider)
-- Satu modul = satu watcher dan satu cache, jadi tidak ada yang dipasang dobel.

VisualAccessories.Templates = {
    { Name = "Violet Valkyrie", ID = 1402432199 },
    { Name = "8-Bit Royal Crown", ID = 10159600649 },
    { Name = "Fiery Horns of the Netherworld", ID = 215718515 },
    { Name = "Frozen Horns of the Frigid Planes", ID = 74891470 },
    { Name = "Poisoned Horns of the Toxic Wasteland", ID = 1744060292 }
}

VisualAccessories.State = {
    Headless = false,
    LeftKorblox = false,
    RightKorblox = false,
    Accessories = {}
}

local Cache = { LoadedAccessories = {} }

-- Aset Korblox resmi; dipasang lewat HumanoidDescription jadi tidak butuh akun donor.
local KORBLOX_LEFT_LEG = 139607718
local KORBLOX_RIGHT_LEG = 139607673

local alive = true -- diset false oleh cleanup supaya loop di bawah berhenti

-- ---------- Rig yang diubah ----------
-- Penyedia daftar rig: fungsi yang mengembalikan { { Rig = model, Humanoid = humanoid }, ... }.
-- Default = karakter pemain. Setiap perubahan visual dipasang ke SEMUA rig yang dikembalikan.
local function DefaultRigs()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then return { { Rig = character, Humanoid = humanoid } } end
    return {}
end

local rigProvider = DefaultRigs

function VisualAccessories.SetRigProvider(provider)
    rigProvider = provider or DefaultRigs
end

local function GetAllRigs()
    local ok, list = pcall(rigProvider)
    return ok and type(list) == "table" and list or {}
end

local function FindBodyAttachment(character, attachmentName)
    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("Attachment") and object.Name == attachmentName and object.Parent:IsA("BasePart") then
            return object
        end
    end
    return nil
end

-- ---------- Headless ----------
local faceCache = setmetatable({}, { __mode = "k" }) -- rig -> face asli

local function SetHeadHidden(rig, hide)
    local head = rig and rig:FindFirstChild("Head")
    if not head then return end
    local face = head:FindFirstChild("face") or head:FindFirstChild("Decal")
    if hide then
        head.Transparency = 1
        if face then
            faceCache[rig] = face:Clone()
            face:Destroy()
        end
    else
        head.Transparency = 0
        if not face and faceCache[rig] then
            faceCache[rig]:Clone().Parent = head
        end
    end
end

-- ---------- Korblox ----------
local function ReconnectCustomParts(oldPart, newPart, rig)
    if not oldPart or not newPart or not rig then return end
    for _, obj in ipairs(rig:GetDescendants()) do
        if obj:IsA("JointInstance") then
            if not string.match(obj.Name, "Hip") and not string.match(obj.Name, "Knee") and not string.match(obj.Name, "Ankle") then
                if obj.Part0 == oldPart then obj.Part0 = newPart end
                if obj.Part1 == oldPart then obj.Part1 = newPart end
            end
        elseif obj:IsA("WeldConstraint") then
            if obj.Part0 == oldPart then obj.Part0 = newPart end
            if obj.Part1 == oldPart then obj.Part1 = newPart end
        end
    end

    for _, child in ipairs(oldPart:GetChildren()) do
        local skip = child:IsA("CharacterMesh") or child:IsA("WrapTarget") or child:IsA("TouchTransmitter")
            or (child:IsA("Motor6D") and (string.match(child.Name, "Hip") or string.match(child.Name, "Knee") or string.match(child.Name, "Ankle")))
        if not skip then
            if child:IsA("Attachment") and string.match(child.Name, "RigAttachment$") then
                local targetAtt = newPart:FindFirstChild(child.Name)
                if targetAtt then
                    for _, attChild in ipairs(child:GetChildren()) do attChild.Parent = targetAtt end
                end
            else
                child.Parent = newPart
            end
        end
    end
end

-- R15: mesh dan texture diganti DI TEMPAT. Part kaki tidak diganti atau dihapus dan joint tidak disentuh;
-- hanya tampilan (MeshId, TextureID, warna, material) yang disalin dari model cache. Cara lama (mengganti
-- part dan menyambung ulang joint) membuat kaki rusak di Evade.

-- Coba beberapa cara set properti; mengembalikan nama cara yang berhasil (atau nil).
local function SetMeshProp(part, prop, value)
    if pcall(function() part[prop] = value end) then return "direct" end
    if sethiddenproperty and pcall(sethiddenproperty, part, prop, value) then return "sethiddenproperty" end
    return nil
end

local function ApplyMeshById(part, meshId)
    local method = SetMeshProp(part, "MeshId", meshId)
    if method then return method end
    -- Cara terakhir: buat MeshPart dari mesh itu lalu salin meshnya.
    local okNew, newMesh = pcall(function()
        return InsertService:CreateMeshPartAsync(meshId, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
    end)
    if okNew and newMesh then
        local okApply = pcall(function() part:ApplyMesh(newMesh) end)
        newMesh:Destroy()
        if okApply then return "ApplyMesh" end
    end
    return nil
end

-- Tampilan sebuah MeshPart sebagai tabel, supaya bisa disimpan dan dipasang lagi nanti.
local function ReadLook(part)
    local look = { MeshId = part.MeshId, TextureID = part.TextureID, Color = part.Color, Material = part.Material, Transparency = part.Transparency, Appearance = {} }
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("SurfaceAppearance") then table.insert(look.Appearance, child:Clone()) end
    end
    return look
end

local function ApplyLook(dst, look)
    if not dst:IsA("MeshPart") then return false end

    local meshMethod, texMethod = "same", "same"
    if dst.MeshId ~= look.MeshId then meshMethod = ApplyMeshById(dst, look.MeshId) end
    if dst.TextureID ~= look.TextureID then texMethod = SetMeshProp(dst, "TextureID", look.TextureID) end
    if not meshMethod or not texMethod then
        warn("[Mugiwara HUB] Korblox " .. dst.Name .. ": could not change the look (mesh=" .. tostring(meshMethod) .. ", texture=" .. tostring(texMethod) .. ")")
        return false
    end

    for _, child in ipairs(dst:GetChildren()) do
        if child:IsA("SurfaceAppearance") then child:Destroy() end
    end
    for _, appearance in ipairs(look.Appearance) do appearance:Clone().Parent = dst end

    pcall(function()
        dst.Color = look.Color
        dst.Material = look.Material
        dst.Transparency = look.Transparency
    end)
    return true
end

local originalLooks = setmetatable({}, { __mode = "k" }) -- part R15 -> tampilan asli sebelum Korblox
local korbloxOn = setmetatable({}, { __mode = "k" })     -- rig -> { Left = true, Right = true } sisi yang sedang Korblox

-- side = "Left" / "Right"; useKorblox = true pasang Korblox, false kembalikan kaki asli.
local function ReplaceLegs(side, useKorblox, rig, hum)
    if not rig or not hum then return false end

    -- Mencopot hanya untuk kaki yang memang kita ganti; rig yang dibangun ulang game sudah asli.
    local sides = korbloxOn[rig]
    if not useKorblox and not (sides and sides[side]) then return true end

    local isR15 = hum.RigType == Enum.HumanoidRigType.R15
    local sourceRig
    if useKorblox then
        sourceRig = isR15 and Cache.KorbloxR15 or Cache.KorbloxR6
    else
        sourceRig = isR15 and Cache.OriR15 or Cache.OriR6
    end

    local replaced = false

    if isR15 then
        local count = 0
        for _, suffix in ipairs({ "UpperLeg", "LowerLeg", "Foot" }) do
            local dst = rig:FindFirstChild(side .. suffix)
            if dst and dst:IsA("MeshPart") then
                if useKorblox then
                    local src = sourceRig and sourceRig:FindFirstChild(side .. suffix)
                    if src then
                        if not originalLooks[dst] then originalLooks[dst] = ReadLook(dst) end
                        if ApplyLook(dst, ReadLook(src)) then count = count + 1 end
                    end
                else
                    local look = originalLooks[dst]
                    if not look then
                        local src = sourceRig and sourceRig:FindFirstChild(side .. suffix)
                        look = src and ReadLook(src)
                    end
                    if look and ApplyLook(dst, look) then
                        originalLooks[dst] = nil
                        count = count + 1
                    end
                end
            end
        end
        replaced = count > 0
        if not replaced then
            warn("[Mugiwara HUB] Korblox: R15 " .. side .. " leg did not change in " .. rig:GetFullName())
        end
    else
        if not sourceRig then return false end
        local noPhys = PhysicalProperties.new(0.01, 0, 0, 0, 0)

        local legName = side .. " Leg"
        local oldLeg = rig:FindFirstChild(legName)
        local joints = rig:FindFirstChild("Joints")
        local torso = rig:FindFirstChild("Torso")
        local hipMotor = (joints and joints:FindFirstChild(legName)) or (torso and torso:FindFirstChild(side .. " Hip")) or rig:FindFirstChild(side .. " Hip", true)
        local srcLeg = sourceRig:FindFirstChild(legName)

        if oldLeg and hipMotor and srcLeg then
            local newLeg = srcLeg:Clone()
            for _, v in ipairs(newLeg:GetChildren()) do if v:IsA("Motor6D") then v:Destroy() end end

            local bodyPart = side == "Left" and Enum.BodyPart.LeftLeg or Enum.BodyPart.RightLeg
            for _, mesh in ipairs(rig:GetChildren()) do
                if mesh:IsA("CharacterMesh") and mesh.BodyPart == bodyPart then mesh:Destroy() end
            end
            for _, mesh in ipairs(sourceRig:GetChildren()) do
                if mesh:IsA("CharacterMesh") and mesh.BodyPart == bodyPart then mesh:Clone().Parent = rig end
            end

            newLeg.Parent = rig
            hipMotor.Part1 = newLeg
            newLeg.Massless = true
            newLeg.CanCollide = false
            newLeg.CustomPhysicalProperties = noPhys
            if hipMotor.Parent == oldLeg then hipMotor.Parent = newLeg end

            local colors = rig:FindFirstChildOfClass("BodyColors")
            if colors then newLeg.Color = side == "Left" and colors.LeftLegColor3 or colors.RightLegColor3 end

            ReconnectCustomParts(oldLeg, newLeg, rig)
            oldLeg:Destroy()
            replaced = true
        else
            warn("[Mugiwara HUB] Korblox: R6 " .. side .. " leg parts missing in " .. rig:GetFullName())
        end
    end

    if replaced then
        korbloxOn[rig] = korbloxOn[rig] or {}
        korbloxOn[rig][side] = useKorblox or nil
    end
    return replaced
end

-- ---------- Cache model avatar sendiri ----------
-- Dibangun sekali, hanya saat Korblox pertama kali dipakai (pengguna gratis tidak memicunya). Modelnya tidak
-- punya parent di Workspace. Menunggu game dan karakter siap dulu: membuat model terlalu cepat setelah join
-- membuat Evade menendang pemain ("character not loaded").
local cacheState = "idle" -- idle | building | ready | failed

local function BuildCache()
    if not game:IsLoaded() then game.Loaded:Wait() end
    local waited = 0
    while alive and waited < 10 do
        local character = LocalPlayer.Character
        if #GetAllRigs() > 0 or (character and character:FindFirstChildOfClass("Humanoid")) then break end
        task.wait(0.5)
        waited = waited + 0.5
    end
    task.wait(2)
    if not alive then return end

    local okDesc, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId) end)
    if not okDesc or not desc then
        warn("[Mugiwara HUB] Korblox: could not fetch your avatar data.")
        cacheState = "failed"
        return
    end

    local korbloxDesc = desc:Clone()
    korbloxDesc.LeftLeg = KORBLOX_LEFT_LEG
    korbloxDesc.RightLeg = KORBLOX_RIGHT_LEG

    local function Make(key, description, rigType)
        local model = Players:CreateHumanoidModelFromDescription(description, rigType)
        model.Name = "Cache_" .. key
        Cache[key] = model
    end

    local ok, err = pcall(function()
        Make("OriR15", desc, Enum.HumanoidRigType.R15)
        Make("OriR6", desc, Enum.HumanoidRigType.R6)
        Make("KorbloxR15", korbloxDesc, Enum.HumanoidRigType.R15)
        Make("KorbloxR6", korbloxDesc, Enum.HumanoidRigType.R6)
    end)
    if ok then
        cacheState = "ready"
    else
        warn("[Mugiwara HUB] Korblox: could not build the avatar cache: " .. tostring(err))
        cacheState = "failed"
    end
end

local function PrepareCache()
    if cacheState == "idle" or cacheState == "failed" then
        cacheState = "building"
        task.spawn(BuildCache)
    end
end

-- Menunggu cache siap (dan memulainya kalau belum). true kalau siap.
local function WaitForCache(timeout)
    PrepareCache()
    local waited = 0
    while cacheState == "building" and alive and waited < timeout do
        task.wait(0.25)
        waited = waited + 0.25
    end
    return cacheState == "ready"
end

-- ---------- Rig baru ----------
-- Rig yang sudah diproses. Setiap rig BARU (respawn, atau rig yang dibuat ulang game) otomatis dapat
-- semua visual aktif. Weak table: rig yang dihapus game ikut hilang dari sini.
local handledRigs = setmetatable({}, { __mode = "k" })

local function ApplyActiveStates(rig)
    if not rig then return end
    local hum = rig:WaitForChild("Humanoid", 3)
    if not hum then return end

    if VisualAccessories.State.Headless then SetHeadHidden(rig, true) end
    if VisualAccessories.State.LeftKorblox or VisualAccessories.State.RightKorblox then
        if WaitForCache(20) then
            if VisualAccessories.State.LeftKorblox then ReplaceLegs("Left", true, rig, hum) end
            if VisualAccessories.State.RightKorblox then ReplaceLegs("Right", true, rig, hum) end
        end
    end

    for assetId, _ in pairs(VisualAccessories.State.Accessories) do
        VisualAccessories.Apply(assetId, nil, true)
    end
end

task.spawn(function()
    while task.wait(1) and alive do
        for _, entry in ipairs(GetAllRigs()) do
            if not handledRigs[entry.Rig] then
                handledRigs[entry.Rig] = true
                task.wait(0.5)
                if entry.Rig.Parent then ApplyActiveStates(entry.Rig) end
            end
        end
    end
end)

function VisualAccessories.ToggleHeadless(state)
    VisualAccessories.State.Headless = state
    for _, entry in ipairs(GetAllRigs()) do
        SetHeadHidden(entry.Rig, state)
    end
end

-- true kalau cache avatar untuk Korblox sudah siap (toggle pertama perlu beberapa detik untuk menyiapkannya).
function VisualAccessories.IsKorbloxReady()
    return cacheState == "ready"
end

-- side = "Left" / "Right". Mengembalikan false kalau Korblox tidak bisa dipasang (cache gagal atau rig tidak cocok).
-- State tetap tersimpan, jadi rig baru tetap dapat Korblox otomatis.
function VisualAccessories.ToggleKorblox(state, side)
    VisualAccessories.State[side .. "Korblox"] = state
    if state and not WaitForCache(20) then return false end

    local any = false
    for _, entry in ipairs(GetAllRigs()) do
        if ReplaceLegs(side, state, entry.Rig, entry.Humanoid) then any = true end
    end
    return any or not state
end

-- ---------- Accessories ----------
-- Pasang satu accessory ke satu rig. Mengembalikan true kalau benar-benar dipasang.
local function EquipOnRig(character, humanoid, cachedAcc, assetId)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory") and child:GetAttribute("AssetId") == assetId then
            return false
        end
    end

    local newAcc = cachedAcc:Clone()
    local handle = newAcc:FindFirstChild("Handle")
    local itemAtt = handle:FindFirstChildWhichIsA("Attachment")

    if itemAtt then
        local bodyAtt = FindBodyAttachment(character, itemAtt.Name)
        if bodyAtt then
            local bodyPart = bodyAtt.Parent
            newAcc.Parent = character

            local oldWeld = handle:FindFirstChild("AccessoryWeld")
            if oldWeld then oldWeld:Destroy() end

            local weld = Instance.new("Weld")
            weld.Name = "AccessoryWeld"
            weld.Part0 = bodyPart
            weld.Part1 = handle
            weld.C0 = bodyAtt.CFrame
            weld.C1 = itemAtt.CFrame
            weld.Parent = handle
        else
            pcall(function() humanoid:AddAccessory(newAcc) end)
            pcall(function() humanoid:BuildRigFromAttachments() end)
        end
    else
        pcall(function() humanoid:AddAccessory(newAcc) end)
        pcall(function() humanoid:BuildRigFromAttachments() end)
    end

    return true
end

function VisualAccessories.Apply(assetId, MugiwaraUI, isAutoApply)
    local rigs = GetAllRigs()
    if #rigs == 0 then return end

    local cachedAcc = Cache.LoadedAccessories[assetId]

    if not cachedAcc then
        if MugiwaraUI and not isAutoApply then MugiwaraUI:Notify({ Title = "Loading", Content = "Fetching asset from Marketplace...", Duration = 2 }) end
        local success, objects = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(assetId)) end)
        if success and objects and objects[1] then
            local loaded = objects[1]
            local acc = loaded:IsA("Accessory") and loaded or loaded:FindFirstChildWhichIsA("Accessory", true)
            if acc then
                local handle = acc:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    handle.CanCollide = false
                    handle.CanTouch = false
                    handle.CanQuery = false
                    handle.Massless = true
                    handle.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)
                    acc:SetAttribute("IsCustomAccessory", true)
                    acc:SetAttribute("AssetId", assetId)

                    Cache.LoadedAccessories[assetId] = acc:Clone()
                    cachedAcc = Cache.LoadedAccessories[assetId]
                end
            end
            if loaded then loaded:Destroy() end
        end
    end

    if not cachedAcc then
        if MugiwaraUI and not isAutoApply then MugiwaraUI:Notify({ Title = "Failed", Content = "Failed to load asset ID.", Duration = 3 }) end
        return
    end

    local equipped = false
    for _, entry in ipairs(rigs) do
        if EquipOnRig(entry.Rig, entry.Humanoid, cachedAcc, assetId) then equipped = true end
    end

    VisualAccessories.State.Accessories[assetId] = true
    if equipped and MugiwaraUI and not isAutoApply then MugiwaraUI:Notify({ Title = "Success", Content = "Accessory equipped!", Duration = 3 }) end
end

function VisualAccessories.Clear(MugiwaraUI)
    VisualAccessories.State.Accessories = {}
    local count = 0
    for _, entry in ipairs(GetAllRigs()) do
        for _, child in ipairs(entry.Rig:GetChildren()) do
            if child:IsA("Accessory") and child:GetAttribute("IsCustomAccessory") then
                child:Destroy()
                count = count + 1
            end
        end
    end
    if MugiwaraUI then MugiwaraUI:Notify({ Title = "Cleaned", Content = "Removed " .. count .. " custom accessories.", Duration = 3 }) end
end

-- Full teardown on re-execute: stop the watcher loop, undo visual changes, drop the cache.
getgenv().MugiwaraRegisterCleanup(function()
    alive = false

    pcall(function()
        local state = VisualAccessories.State
        -- Kaki dikembalikan sebelum cache dihapus, karena kaki R6 diambil dari model asli di cache.
        for _, side in ipairs({ "Left", "Right" }) do
            state[side .. "Korblox"] = false
            for _, entry in ipairs(GetAllRigs()) do ReplaceLegs(side, false, entry.Rig, entry.Humanoid) end
        end
        if state.Headless then VisualAccessories.ToggleHeadless(false) end
        VisualAccessories.Clear()
    end)

    for key, model in pairs(Cache) do
        if key ~= "LoadedAccessories" then pcall(function() model:Destroy() end) end
    end
end)

return VisualAccessories
