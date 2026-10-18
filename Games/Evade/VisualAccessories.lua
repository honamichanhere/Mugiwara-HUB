local VisualAccessories = {}
local Players = game:GetService("Players")

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

VisualAccessories.OriginalData = {
    Head = {}, 
    AvatarDesc = nil
}

local Cache = {
    KorbloxR15 = nil, KorbloxR6 = nil,
    OriR15 = nil, OriR6 = nil,
    LoadedAccessories = {}
}

local KORBLOX_LEFT_LEG = 139607718
local KORBLOX_RIGHT_LEG = 139607673

local CACHE_FOLDER_NAME = "Mugiwara_Bundle_Cache"

-- Folder cache sisa sesi sebelumnya dibuang dulu supaya model cache tidak dobel.
do
    local stale = workspace:FindFirstChild(CACHE_FOLDER_NAME)
    if stale then stale:Destroy() end
end

task.spawn(pcall, function()
    local cacheFolder = Instance.new("Folder")
    cacheFolder.Name = CACHE_FOLDER_NAME
    cacheFolder.Parent = workspace

    local myDesc = Instance.new("HumanoidDescription")
    pcall(function() 
        local desc = Players:GetHumanoidDescriptionFromUserId(Players.LocalPlayer.UserId)
        if desc then myDesc = desc end
    end)
    VisualAccessories.OriginalData.AvatarDesc = myDesc

    Cache.OriR15 = Players:CreateHumanoidModelFromDescription(myDesc, Enum.HumanoidRigType.R15)
    Cache.OriR15.Name = "Cache_OriR15"
    Cache.OriR15.Parent = cacheFolder
    Cache.OriR15:PivotTo(CFrame.new(5000, 5000, 5000))
    if Cache.OriR15:FindFirstChild("HumanoidRootPart") then Cache.OriR15.HumanoidRootPart.Anchored = true end

    Cache.OriR6 = Players:CreateHumanoidModelFromDescription(myDesc, Enum.HumanoidRigType.R6)
    Cache.OriR6.Name = "Cache_OriR6"
    Cache.OriR6.Parent = cacheFolder
    Cache.OriR6:PivotTo(CFrame.new(5010, 5000, 5000))
    if Cache.OriR6:FindFirstChild("HumanoidRootPart") then Cache.OriR6.HumanoidRootPart.Anchored = true end

    local kbDesc = myDesc:Clone()
    kbDesc.LeftLeg = KORBLOX_LEFT_LEG
    kbDesc.RightLeg = KORBLOX_RIGHT_LEG

    Cache.KorbloxR15 = Players:CreateHumanoidModelFromDescription(kbDesc, Enum.HumanoidRigType.R15)
    Cache.KorbloxR15.Name = "Cache_KorbloxR15"
    Cache.KorbloxR15.Parent = cacheFolder
    Cache.KorbloxR15:PivotTo(CFrame.new(5020, 5000, 5000))
    if Cache.KorbloxR15:FindFirstChild("HumanoidRootPart") then Cache.KorbloxR15.HumanoidRootPart.Anchored = true end

    Cache.KorbloxR6 = Players:CreateHumanoidModelFromDescription(kbDesc, Enum.HumanoidRigType.R6)
    Cache.KorbloxR6.Name = "Cache_KorbloxR6"
    Cache.KorbloxR6.Parent = cacheFolder
    Cache.KorbloxR6:PivotTo(CFrame.new(5030, 5000, 5000))
    if Cache.KorbloxR6:FindFirstChild("HumanoidRootPart") then Cache.KorbloxR6.HumanoidRootPart.Anchored = true end
end)

local RigsModule = getgenv().MugiwaraImport("Games/Evade/Rigs.lua")

-- Semua rig pemain lokal (bisa dua: inventory + in-game). Setiap perubahan visual dipasang
-- ke SEMUA rig supaya tampilan konsisten di mana pun rig itu terlihat.
local function GetAllRigs()
    return RigsModule and RigsModule.GetAll() or {}
end

local function FindBodyAttachment(character, attachmentName)
    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("Attachment") and object.Name == attachmentName and object.Parent:IsA("BasePart") then
            return object
        end
    end
    return nil
end

local function SetHeadHidden(rigTarget, state)
    if not rigTarget then return end
    local head = rigTarget:FindFirstChild("Head")
    if not head then return end
    
    if state then
        head.Transparency = 1
        local face = head:FindFirstChild("face") or head:FindFirstChild("Decal")
        if face then 
            VisualAccessories.OriginalData.Head.FaceCache = face:Clone()
            face:Destroy() 
        end
    else
        head.Transparency = 0
        local face = head:FindFirstChild("face") or head:FindFirstChild("Decal")
        if not face and VisualAccessories.OriginalData.Head.FaceCache then
            VisualAccessories.OriginalData.Head.FaceCache:Clone().Parent = head
        end
    end
end

local function reconnectCustomParts(oldPart, newPart, rig)
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
        if child:IsA("CharacterMesh") or child:IsA("WrapTarget") or child:IsA("TouchTransmitter") then continue end
        if child:IsA("Motor6D") and (string.match(child.Name, "Hip") or string.match(child.Name, "Knee") or string.match(child.Name, "Ankle")) then continue end
        
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

local function ReplaceLegs(side, state, myRig, myHum)
    if not myRig or not myHum then return false end
    local isR15 = myHum.RigType == Enum.HumanoidRigType.R15
    local sourceRig = state and (isR15 and Cache.KorbloxR15 or Cache.KorbloxR6) or (isR15 and Cache.OriR15 or Cache.OriR6)
    if not sourceRig then return false end

    local replaced = false

    if isR15 then
        local upperName = side .. "UpperLeg"
        local lowerName = side .. "LowerLeg"
        local footName = side .. "Foot"

        local oldUpper = myRig:FindFirstChild(upperName)
        local oldLower = myRig:FindFirstChild(lowerName)
        local oldFoot = myRig:FindFirstChild(footName)
        local srcUpper = sourceRig:FindFirstChild(upperName)
        local srcLower = sourceRig:FindFirstChild(lowerName)
        local srcFoot = sourceRig:FindFirstChild(footName)

        if oldUpper and oldLower and oldFoot and srcUpper and srcLower and srcFoot then
            local newUpper = srcUpper:Clone()
            local newLower = srcLower:Clone()
            local newFoot = srcFoot:Clone()

            local joints = myRig:FindFirstChild("Joints")
            local hipName = side .. "Hip"
            local kneeName = side .. "Knee"
            local ankleName = side .. "Ankle"

            local hip = (joints and joints:FindFirstChild(hipName)) or (myRig:FindFirstChild("LowerTorso") and myRig.LowerTorso:FindFirstChild(hipName)) or oldUpper:FindFirstChild(hipName)
            local knee = (joints and joints:FindFirstChild(kneeName)) or oldLower:FindFirstChild(kneeName)
            local ankle = (joints and joints:FindFirstChild(ankleName)) or oldFoot:FindFirstChild(ankleName)

            if hip and knee and ankle then
                for _, v in ipairs(newUpper:GetChildren()) do if v:IsA("Motor6D") then v:Destroy() end end
                for _, v in ipairs(newLower:GetChildren()) do if v:IsA("Motor6D") then v:Destroy() end end
                for _, v in ipairs(newFoot:GetChildren()) do if v:IsA("Motor6D") then v:Destroy() end end

                newUpper.Parent = myRig
                newLower.Parent = myRig
                newFoot.Parent = myRig

                hip.Part1 = newUpper
                knee.Part0 = newUpper
                knee.Part1 = newLower
                ankle.Part0 = newLower
                ankle.Part1 = newFoot

                if hip.Parent == oldUpper then hip.Parent = newUpper end
                if knee.Parent == oldUpper or knee.Parent == oldLower then knee.Parent = newUpper end
                if ankle.Parent == oldLower or ankle.Parent == oldFoot then ankle.Parent = newLower end

                local noPhys = PhysicalProperties.new(0.01, 0, 0, 0, 0)
                for _, p in ipairs({newUpper, newLower, newFoot}) do
                    p.Massless = true
                    p.CanCollide = false
                    p.CustomPhysicalProperties = noPhys
                end

                local myColors = myRig:FindFirstChildOfClass("BodyColors")
                if myColors then
                    local legColor = side == "Left" and myColors.LeftLegColor3 or myColors.RightLegColor3
                    newUpper.Color = legColor
                    newLower.Color = legColor
                    newFoot.Color = legColor
                end

                reconnectCustomParts(oldUpper, newUpper, myRig)
                reconnectCustomParts(oldLower, newLower, myRig)
                reconnectCustomParts(oldFoot, newFoot, myRig)

                oldUpper:Destroy()
                oldLower:Destroy()
                oldFoot:Destroy()
                replaced = true
            end
        end
    else
        local legName = side .. " Leg"
        local myOldLeg = myRig:FindFirstChild(legName)
        local jointsFolder = myRig:FindFirstChild("Joints")
        local hipMotor = jointsFolder and jointsFolder:FindFirstChild(legName)
        local srcLeg = sourceRig:FindFirstChild(legName)

        if myOldLeg and hipMotor and srcLeg then
            local targetLeg = srcLeg:Clone()
            for _, v in ipairs(targetLeg:GetChildren()) do if v:IsA("Motor6D") then v:Destroy() end end

            local bPartEnum = side == "Left" and Enum.BodyPart.LeftLeg or Enum.BodyPart.RightLeg
            
            for _, oldMesh in ipairs(myRig:GetChildren()) do
                if oldMesh:IsA("CharacterMesh") and oldMesh.BodyPart == bPartEnum then
                    oldMesh:Destroy()
                end
            end
            
            for _, obj in ipairs(sourceRig:GetChildren()) do
                if obj:IsA("CharacterMesh") and obj.BodyPart == bPartEnum then
                    obj:Clone().Parent = myRig
                end
            end

            targetLeg.Parent = myRig
            hipMotor.Part1 = targetLeg
            
            targetLeg.Massless = true
            targetLeg.CanCollide = false
            targetLeg.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)
            
            if hipMotor.Parent == myOldLeg then hipMotor.Parent = targetLeg end

            local myColors = myRig:FindFirstChildOfClass("BodyColors")
            if myColors then targetLeg.Color = side == "Left" and myColors.LeftLegColor3 or myColors.RightLegColor3 end

            reconnectCustomParts(myOldLeg, targetLeg, myRig)

            myOldLeg:Destroy()
            replaced = true
        end
    end

    return replaced
end

local function ApplyActiveStates(rig)
    if not rig then return end
    local hum = rig:WaitForChild("Humanoid", 3)
    if not hum then return end
    
    if VisualAccessories.State.Headless then SetHeadHidden(rig, true) end
    if VisualAccessories.State.LeftKorblox then ReplaceLegs("Left", true, rig, hum) end
    if VisualAccessories.State.RightKorblox then ReplaceLegs("Right", true, rig, hum) end

    for assetId, _ in pairs(VisualAccessories.State.Accessories) do
        VisualAccessories.Apply(assetId, nil, true)
    end
end

local alive = true -- diset false oleh cleanup supaya loop di bawah berhenti

-- Rig yang sudah diproses. Setiap rig BARU (respawn, atau rig inventory yang dibuat ulang
-- saat inventory dibuka) otomatis dapat semua visual aktif. Weak table: rig yang dihapus
-- game ikut hilang dari sini.
local handledRigs = setmetatable({}, { __mode = "k" })

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

function VisualAccessories.ToggleKorblox(state, side)
    VisualAccessories.State[side .. "Korblox"] = state
    for _, entry in ipairs(GetAllRigs()) do
        ReplaceLegs(side, state, entry.Rig, entry.Humanoid)
    end
end

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

function VisualAccessories.Apply(assetId, WindUI, isAutoApply)
    local rigs = GetAllRigs()
    if #rigs == 0 then return end

    local cachedAcc = Cache.LoadedAccessories[assetId]

    if not cachedAcc then
        if WindUI and not isAutoApply then WindUI:Notify({ Title = "Loading", Content = "Fetching asset from Marketplace...", Duration = 2 }) end
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
        if WindUI and not isAutoApply then WindUI:Notify({ Title = "Failed", Content = "Failed to load asset ID.", Duration = 3 }) end
        return
    end

    local equipped = false
    for _, entry in ipairs(rigs) do
        if EquipOnRig(entry.Rig, entry.Humanoid, cachedAcc, assetId) then equipped = true end
    end

    VisualAccessories.State.Accessories[assetId] = true
    if equipped and WindUI and not isAutoApply then WindUI:Notify({ Title = "Success", Content = "Accessory equipped!", Duration = 3 }) end
end

function VisualAccessories.Clear(WindUI)
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
    if WindUI then WindUI:Notify({ Title = "Cleaned", Content = "Removed " .. count .. " custom accessories.", Duration = 3 }) end
end

-- Full teardown on re-execute: stop the watcher loop, undo visual changes, drop the cache.
getgenv().MugiwaraRegisterCleanup(function()
    alive = false

    pcall(function()
        local state = VisualAccessories.State
        -- Kaki dikembalikan sebelum cache dihapus, karena ReplaceLegs mengambil model asli dari cache.
        if state.LeftKorblox then VisualAccessories.ToggleKorblox(false, "Left") end
        if state.RightKorblox then VisualAccessories.ToggleKorblox(false, "Right") end
        if state.Headless then VisualAccessories.ToggleHeadless(false) end
        VisualAccessories.Clear()
    end)

    local cacheFolder = workspace:FindFirstChild(CACHE_FOLDER_NAME)
    if cacheFolder then cacheFolder:Destroy() end
end)

return VisualAccessories
