-- ==========================================================
-- MUGIWARA HUB | Games/Evade/AvatarChanger.lua  (v2)
--
-- Morph avatar by username. Jalurnya ngikutin rig ASLI karakter lu:
--
--   R15 -> "Skin Rig". Model avatar target dibuat utuh (rig R15), lengkap
--          sama sendi Motor6D, aksesoris, baju, dan layered clothing-nya.
--          Tiap frame pose karakter asli disalin ke sendi skin, jadi tiap
--          anggota badan nempel lewat sendinya sendiri. Proporsi beda
--          (R6 classic / Rthro / slender / scale) tetap rapi.
--
--   R6  -> swap asset langsung (CharacterMesh, face, head mesh, baju).
--
-- Kenapa v1 bug di R15: tiap part target di-weld ke part asli di titik
-- tengahnya. Kalau ukuran/proporsi part beda, sendinya pecah dan badan
-- jadi berantakan. Baju dan warna kulit juga ikut hilang karena part
-- clone di-rename, jadi nggak kena BodyColors/Shirt/Pants.
-- ==========================================================

local AvatarChanger = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local MORPH_TAG = "Mugiwara_Morph"
local PRELOAD_TIMEOUT = 5 -- detik, nunggu mesh/tekstur target ke-load

-- Tambahan manual (studs) kalau kaki skin keliatan melayang/nenggelam di game tertentu.
AvatarChanger.GroundOffset = 0

-- Cache asset asli, khusus jalur R6. Direset tiap Clear().
AvatarChanger.OriginalData = {}

local State = {
    Busy = false,
    Char = nil,   -- karakter yang lagi di-morph
    Skin = nil,   -- model skin (R15)
    Conn = nil,   -- koneksi Heartbeat (R15)
    Hidden = {},  -- [Instance] = Transparency asli
}

-- ==========================================
-- HELPERS
-- ==========================================
local function Notify(MugiwaraUI, title, content, duration)
    if not MugiwaraUI then return end
    pcall(function()
        MugiwaraUI:Notify({ Title = title, Content = content, Duration = duration or 3 })
    end)
end

-- Rig yang sedang dipakai main. Evade bisa punya dua rig bernama sama (inventory + in-game),
-- jadi pemilihannya diserahkan ke modul Rigs, bukan FindFirstChild(nama).
local RigsModule = getgenv().MugiwaraImport("Games/Evade/Rigs.lua")

local function GetCharacter()
    if RigsModule then return RigsModule.GetActive() end
    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then return character, humanoid end
    return nil, nil
end

-- Rig dibaca dari part yang ada, bukan cuma Humanoid.RigType (lebih bisa dipercaya).
local function DetectRig(char, hum)
    if char:FindFirstChild("UpperTorso") or char:FindFirstChild("LowerTorso") then return "R15" end
    if char:FindFirstChild("Torso") then return "R6" end
    if hum.RigType == Enum.HumanoidRigType.R15 then return "R15" end
    return "R6"
end

local function IsClothing(item)
    return item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("BodyColors")
end

-- Sembunyiin part/decal dan catat nilai aslinya biar restore-nya persis.
local function HideInstance(inst)
    if State.Hidden[inst] ~= nil then return end
    if inst:IsA("BasePart") or inst:IsA("Decal") then -- Texture turunan Decal
        State.Hidden[inst] = inst.Transparency
        inst.Transparency = 1
    end
end

-- hideBody = true  -> sembunyiin seluruh badan asli (R15, diganti skin)
-- hideBody = false -> cuma aksesoris asli (R6, badan di-swap in-place)
local function HideReal(char, hideBody)
    for _, child in ipairs(char:GetChildren()) do
        if hideBody and child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
            HideInstance(child)
            for _, d in ipairs(child:GetChildren()) do
                if d:IsA("Decal") then HideInstance(d) end
            end
        elseif child:IsA("Accessory") and not string.find(child.Name, MORPH_TAG, 1, true) then
            for _, d in ipairs(child:GetDescendants()) do
                if d:IsA("BasePart") or d:IsA("Decal") then HideInstance(d) end
            end
        end
    end
end

local function RestoreHidden()
    for inst, original in pairs(State.Hidden) do
        if inst.Parent then
            pcall(function() inst.Transparency = original end)
        end
    end
    State.Hidden = {}
end

local function RestoreR6(char)
    local data = AvatarChanger.OriginalData

    if data.R6Meshes then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("CharacterMesh") then obj:Destroy() end
        end
        for _, mesh in ipairs(data.R6Meshes) do
            mesh:Clone().Parent = char
        end
    end

    local head = char:FindFirstChild("Head")
    if head then
        if data.FaceCache then
            local currentFace = head:FindFirstChildOfClass("Decal")
            if currentFace then currentFace:Destroy() end
            data.FaceCache:Clone().Parent = head
        end
        if data.HeadMeshCache then
            local currentMesh = head:FindFirstChildOfClass("SpecialMesh")
            if currentMesh then currentMesh:Destroy() end
            data.HeadMeshCache:Clone().Parent = head
        end
    end

    if data.ClothingCache then
        for _, item in ipairs(char:GetChildren()) do
            if IsClothing(item) then item:Destroy() end
        end
        for _, item in ipairs(data.ClothingCache) do
            item:Clone().Parent = char
        end
    end

    AvatarChanger.OriginalData = {}
end

-- ==========================================
-- R15: SKIN RIG
-- ==========================================

-- Pose `part` relatif ke `root` pas pose netral (Transform = identity), dihitung dari
-- C0/C1 sendi. Nggak bergantung posisi part, karena model belum tentu ada di workspace.
local function NeutralOffsetFromRoot(skin, root, part)
    local jointByPart1 = {}
    for _, m in ipairs(skin:GetDescendants()) do
        if m:IsA("Motor6D") and m.Part1 then jointByPart1[m.Part1] = m end
    end

    local cf = CFrame.new()
    local current = part
    for _ = 1, 24 do
        if current == root then return cf end
        local joint = jointByPart1[current]
        if not joint or not joint.Part0 then return nil end
        cf = (joint.C0 * joint.C1:Inverse()) * cf
        current = joint.Part0
    end
    return nil
end

-- Jarak dari tengah HRP skin ke telapak kaki (pose netral).
local function ComputeSkinDrop(skin, skinRoot, skinHum)
    local lowest = nil
    for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
        local foot = skin:FindFirstChild(name)
        if foot and foot:IsA("BasePart") then
            local cf = NeutralOffsetFromRoot(skin, skinRoot, foot)
            if cf then
                local bottom = cf.Y - foot.Size.Y / 2
                if not lowest or bottom < lowest then lowest = bottom end
            end
        end
    end
    if lowest then return -lowest end
    return skinHum.HipHeight + skinRoot.Size.Y / 2 -- fallback
end

local function ApplyR15(char, hum, desc)
    local ok, skin = pcall(function()
        return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    end)
    if not ok or not skin then return false, "Failed to build the target avatar model!" end

    -- Tunggu mesh/tekstur target ke-load (ada batas waktu biar nggak nyangkut).
    local loaded = false
    task.spawn(function()
        pcall(function() ContentProvider:PreloadAsync({ skin }) end)
        loaded = true
    end)
    local t0 = os.clock()
    while not loaded and os.clock() - t0 < PRELOAD_TIMEOUT do task.wait() end

    -- Karakter bisa ganti selama nunggu di atas.
    if not char.Parent then
        skin:Destroy()
        return false, "Your character changed while processing, please try again."
    end

    local skinHum = skin:FindFirstChildOfClass("Humanoid")
    local skinRoot = skin:FindFirstChild("HumanoidRootPart")
    local realRoot = char:FindFirstChild("HumanoidRootPart") or hum.RootPart
    if not (skinHum and skinRoot and realRoot) then
        skin:Destroy()
        return false, "The target rig is incomplete!"
    end

    -- Pasangan sendi: sendi asli -> sendi skin, dicocokin lewat nama Part1.
    local realByPart = {}
    for _, m in ipairs(char:GetDescendants()) do
        if m:IsA("Motor6D") and m.Part0 and m.Part1 and m.Part1.Parent == char then
            realByPart[m.Part1.Name] = m
        end
    end
    local links = {}
    for _, m in ipairs(skin:GetDescendants()) do
        if m:IsA("Motor6D") and m.Part0 and m.Part1 then
            local real = realByPart[m.Part1.Name]
            if real then links[#links + 1] = { skin = m, real = real } end
        end
    end
    if #links == 0 then
        skin:Destroy()
        return false, "Your rig joints do not match the target skin."
    end

    local skinDrop = ComputeSkinDrop(skin, skinRoot, skinHum)

    -- Netralin skin: cuma visual, jangan ganggu fisika/hitbox/UI karakter asli.
    skin.Name = MORPH_TAG .. "_Skin"
    skinHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    skinHum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    skinHum.BreakJointsOnDeath = false
    skinHum.RequiresNeck = false
    pcall(function() skinHum.EvaluateStateMachine = false end)

    for _, d in ipairs(skin:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = false
            d.CanCollide = false
            d.CanTouch = false
            d.CanQuery = false
            d.Massless = true
        elseif d:IsA("BaseScript") then
            d:Destroy()
        end
    end
    skinRoot.Anchored = true -- cuma root yang di-anchor, sisanya ngikut lewat Motor6D

    local function Step()
        if not (char.Parent and skin.Parent and realRoot.Parent) then return false end

        for i = 1, #links do
            local rm, sm = links[i].real, links[i].skin
            local p0, p1 = rm.Part0, rm.Part1
            if p0 and p1 then
                -- Transform = pose sendi asli yang lagi kepake (animasi, emote, dll).
                local rel = p0.CFrame:ToObjectSpace(p1.CFrame)
                sm.Transform = rm.C0:Inverse() * rel * rm.C1
            end
        end

        -- Telapak kaki skin disejajarin ke tanah lewat HipHeight karakter asli.
        local realDrop = hum.HipHeight + realRoot.Size.Y / 2
        local dy = skinDrop - realDrop + AvatarChanger.GroundOffset
        skinRoot.CFrame = realRoot.CFrame * CFrame.new(0, dy, 0)
        return true
    end

    HideReal(char, true)
    skin.Parent = char
    State.Skin = skin
    Step()

    State.Conn = RunService.Heartbeat:Connect(function()
        local okStep, alive = pcall(Step)
        if not okStep or not alive then
            -- Karakter asli ilang (respawn / ganti rig): bersihin diam-diam.
            AvatarChanger.Clear(false)
        end
    end)

    return true
end

-- ==========================================
-- R6: DIRECT ASSET SWAP
-- ==========================================
local function ApplyR6(char, hum, desc)
    local ok, dummy = pcall(function()
        return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
    end)
    if not ok or not dummy then return false, "Failed to build the target avatar model!" end

    local data = AvatarChanger.OriginalData
    local noPhys = PhysicalProperties.new(0.01, 0, 0, 0, 0)

    -- 1. Bentuk tubuh (CharacterMesh)
    if not data.R6Meshes then
        data.R6Meshes = {}
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("CharacterMesh") then
                table.insert(data.R6Meshes, obj:Clone())
            end
        end
    end
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("CharacterMesh") then obj:Destroy() end
    end
    for _, obj in ipairs(dummy:GetChildren()) do
        if obj:IsA("CharacterMesh") then obj:Clone().Parent = char end
    end

    -- 2. Muka + bentuk kepala
    local myHead = char:FindFirstChild("Head")
    local dummyHead = dummy:FindFirstChild("Head")
    if myHead and dummyHead then
        local myFace = myHead:FindFirstChildOfClass("Decal")
        local dummyFace = dummyHead:FindFirstChildOfClass("Decal")
        local myMesh = myHead:FindFirstChildOfClass("SpecialMesh")
        local dummyMesh = dummyHead:FindFirstChildOfClass("SpecialMesh")

        if not data.FaceCache and myFace then data.FaceCache = myFace:Clone() end
        if not data.HeadMeshCache and myMesh then data.HeadMeshCache = myMesh:Clone() end

        if myFace then myFace:Destroy() end
        if myMesh then myMesh:Destroy() end

        if dummyFace then dummyFace:Clone().Parent = myHead end
        if dummyMesh then dummyMesh:Clone().Parent = myHead end
    end

    -- 3. Aksesoris
    HideReal(char, false)
    for _, dummyAcc in ipairs(dummy:GetChildren()) do
        if dummyAcc:IsA("Accessory") then
            local cloneAcc = dummyAcc:Clone()
            cloneAcc.Name = MORPH_TAG .. "_Acc"
            local handle = cloneAcc:FindFirstChild("Handle")
            if handle then
                handle.Anchored = false
                handle.CanCollide = false
                handle.Massless = true
                handle.CustomPhysicalProperties = noPhys

                local itemAtt = handle:FindFirstChildWhichIsA("Attachment")
                if itemAtt then
                    local bodyAtt = nil
                    for _, p in ipairs(char:GetChildren()) do
                        if p:IsA("BasePart") then
                            bodyAtt = p:FindFirstChild(itemAtt.Name)
                            if bodyAtt then break end
                        end
                    end

                    if bodyAtt then
                        cloneAcc.Parent = char
                        local weld = Instance.new("Weld")
                        weld.Name = "AccessoryWeld"
                        weld.Part0 = bodyAtt.Parent
                        weld.Part1 = handle
                        weld.C0 = bodyAtt.CFrame
                        weld.C1 = itemAtt.CFrame
                        weld.Parent = handle
                    end
                else
                    -- Aksesoris jadul R6 tanpa attachment
                    pcall(function() hum:AddAccessory(cloneAcc) end)
                end
            end
        end
    end

    -- 4. Baju + warna kulit
    if not data.ClothingCache then
        data.ClothingCache = {}
        for _, item in ipairs(char:GetChildren()) do
            if IsClothing(item) then
                table.insert(data.ClothingCache, item:Clone())
                item:Destroy()
            end
        end
    end
    for _, item in ipairs(dummy:GetChildren()) do
        if IsClothing(item) then item:Clone().Parent = char end
    end

    dummy:Destroy()
    return true
end

-- ==========================================
-- PUBLIC API  (signature sama kayak v1)
-- ==========================================
function AvatarChanger.Clear(showNotif, MugiwaraUI)
    if State.Conn then
        State.Conn:Disconnect()
        State.Conn = nil
    end
    if State.Skin then
        pcall(function() State.Skin:Destroy() end)
        State.Skin = nil
    end

    local char = State.Char
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if string.find(child.Name, MORPH_TAG, 1, true) then child:Destroy() end
        end
    end
    RestoreHidden()
    if char then RestoreR6(char) end
    AvatarChanger.OriginalData = {}
    State.Char = nil

    if showNotif then
        Notify(MugiwaraUI, "Reverted", "Your original avatar has been restored.", 3)
    end
end

local function DoApply(username, MugiwaraUI)
    username = string.match(tostring(username or ""), "^%s*(.-)%s*$")
    if username == "" then return end

    local char, hum = GetCharacter()
    if not char or not hum then
        Notify(MugiwaraUI, "Error", "Your character was not found, please try again in a moment.", 3)
        return
    end

    Notify(MugiwaraUI, "Processing", "Fetching avatar data for " .. username .. "...", 2)

    local okId, userId = pcall(function() return Players:GetUserIdFromNameAsync(username) end)
    if not okId or not userId then
        Notify(MugiwaraUI, "Error", "Invalid or unknown username!", 3)
        return
    end

    local okDesc, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(userId) end)
    if not okDesc or not desc then
        Notify(MugiwaraUI, "Error", "Failed to fetch the target avatar details!", 3)
        return
    end

    -- Hapus morph sebelumnya biar nggak numpuk.
    AvatarChanger.Clear(false)

    -- Request di atas yield, karakter bisa udah ganti.
    char, hum = GetCharacter()
    if not char or not hum then return end

    local rig = DetectRig(char, hum)
    State.Char = char

    local ok, err
    if rig == "R15" then
        ok, err = ApplyR15(char, hum, desc)
    else
        ok, err = ApplyR6(char, hum, desc)
    end

    if not ok then
        AvatarChanger.Clear(false)
        Notify(MugiwaraUI, "Error", err or "Avatar morph failed.", 4)
        return
    end

    Notify(MugiwaraUI, "Success", "Your avatar is now a 1:1 copy of " .. username .. " (" .. rig .. ")", 3)
end

function AvatarChanger.Apply(username, MugiwaraUI)
    if State.Busy then
        Notify(MugiwaraUI, "Please wait", "The previous morph is still processing.", 2)
        return
    end
    State.Busy = true
    local ok, err = pcall(DoApply, username, MugiwaraUI)
    State.Busy = false

    if not ok then
        warn("[Mugiwara] AvatarChanger error: " .. tostring(err))
        pcall(AvatarChanger.Clear, false)
        Notify(MugiwaraUI, "Error", "Morph failed, changes were rolled back.", 3)
    end
end

-- Full teardown on re-execute: remove the morph and its Heartbeat connection.
getgenv().MugiwaraRegisterCleanup(function()
    pcall(AvatarChanger.Clear, false)
end)

return AvatarChanger
