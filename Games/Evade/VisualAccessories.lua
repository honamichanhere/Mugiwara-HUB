-- ==========================================
-- MODULE: VISUAL ACCESSORIES (EVADE)
-- ==========================================
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
    RightKorblox = false
}

VisualAccessories.OriginalData = {
    Head = {}
}

-- Database Cache Karakter (Disimpan di koordinat Y=5000)
local Cache = {
    KorbloxR15 = nil, KorbloxR6 = nil,
    OriR15 = nil, OriR6 = nil
}

-- ==========================================
-- BACKGROUND CACHE LOADER (SPAWN UTUH)
-- ==========================================
task.spawn(function()
    local cacheFolder = workspace:FindFirstChild("Mugiwara_Bundle_Cache")
    if not cacheFolder then
        cacheFolder = Instance.new("Folder")
        cacheFolder.Name = "Mugiwara_Bundle_Cache"
        cacheFolder.Parent = workspace
    end

    -- 1. Merakit Avatar Asli Player
    local myDesc = Instance.new("HumanoidDescription")
    pcall(function() 
        local desc = Players:GetHumanoidDescriptionFromUserId(Players.LocalPlayer.UserId)
        if desc then myDesc = desc end
    end)

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

    -- 2. Merakit Bundle Korblox Deathspeaker Secara Utuh (Pake ID Catalog Resmi)
    local kbDesc = Instance.new("HumanoidDescription")
    kbDesc.LeftLeg = 139607718
    kbDesc.RightLeg = 139607673
    kbDesc.Head = 139607677
    kbDesc.Torso = 139607693
    kbDesc.LeftArm = 139607684
    kbDesc.RightArm = 139607736

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

    print("[Mugiwara HUB] Korblox & Original Character Cached di Y=5000 secara utuh!")
end)

local function GetCharacter()
    local player = Players.LocalPlayer
    local rigs = workspace:FindFirstChild("Rigs")
    if rigs then
        local rig = rigs:FindFirstChild(player.Name)
        if rig then
            local humanoid = rig:FindFirstChildOfClass("Humanoid")
            if humanoid then return rig, humanoid end
        end
    end

    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then return character, humanoid end
    end
    return nil, nil
end

local function FindBodyAttachment(character, attachmentName)
    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("Attachment") and object.Name == attachmentName and object.Parent:IsA("BasePart") then
            return object
        end
    end
    return nil
end

-- ==========================================
-- LOGIC KORLESS VISUAL (ANTI-BUG PHASE 1)
-- ==========================================
local function hilangkanKepala(rigTarget, state)
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
        if child:IsA("CharacterMesh") or child:IsA("WrapTarget") or child:IsA("TouchTransmitter") then
            continue
        end
        if child:IsA("Motor6D") and (string.match(child.Name, "Hip") or string.match(child.Name, "Knee") or string.match(child.Name, "Ankle")) then
            continue
        end
        
        if child:IsA("Attachment") and string.match(child.Name, "RigAttachment$") then
            local targetAtt = newPart:FindFirstChild(child.Name)
            if targetAtt then
                for _, attChild in ipairs(child:GetChildren()) do
                    attChild.Parent = targetAtt
                end
            end
        else
            child.Parent = newPart
        end
    end
end

local function runTahap1(side, state, myRig, myHum)
    if not myRig or not myHum then return false end
    
    local isR15 = myHum.RigType == Enum.HumanoidRigType.R15
    local sourceRig
    
    -- Ambil referensi dari Cache di langit
    if state then
        sourceRig = isR15 and Cache.KorbloxR15 or Cache.KorbloxR6
    else
        sourceRig = isR15 and Cache.OriR15 or Cache.OriR6
    end
    
    if not sourceRig then return false end

    local sukses = false

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
            -- CLONE PART DARI CACHE AGAR CACHE TIDAK HILANG
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
                -- Hapus sendi bawaan hasil clone agar tidak menabrak sendi asli karakter
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

                newUpper.Massless = true
                newLower.Massless = true
                newFoot.Massless = true

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
                sukses = true
            end
        end
    else
        -- Eksekusi R6
        local legName = side .. " Leg"
        local myOldLeg = myRig:FindFirstChild(legName)
        local jointsFolder = myRig:FindFirstChild("Joints")
        local hipMotor = jointsFolder and jointsFolder:FindFirstChild(legName)
        local srcLeg = sourceRig:FindFirstChild(legName)

        if myOldLeg and hipMotor and srcLeg then
            local targetLeg = srcLeg:Clone()
            for _, v in ipairs(targetLeg:GetChildren()) do if v:IsA("Motor6D") then v:Destroy() end end

            local bPartEnum = side == "Left" and Enum.BodyPart.LeftLeg or Enum.BodyPart.RightLeg
            
            for _, obj in ipairs(sourceRig:GetChildren()) do
                if obj:IsA("CharacterMesh") and obj.BodyPart == bPartEnum then
                    for _, oldMesh in ipairs(myRig:GetChildren()) do
                        if oldMesh:IsA("CharacterMesh") and oldMesh.BodyPart == bPartEnum then
                            oldMesh:Destroy()
                        end
                    end
                    obj:Clone().Parent = myRig
                end
            end

            targetLeg.Parent = myRig
            hipMotor.Part1 = targetLeg
            targetLeg.Massless = true

            local myColors = myRig:FindFirstChildOfClass("BodyColors")
            if myColors then 
                targetLeg.Color = side == "Left" and myColors.LeftLegColor3 or myColors.RightLegColor3 
            end

            reconnectCustomParts(myOldLeg, targetLeg, myRig)

            myOldLeg:Destroy()
            sukses = true
        end
    end

    return sukses
end

-- ==========================================
-- APLIKASI STATE OTOMATIS SAAT RESPAWN
-- ==========================================
local function ApplyActiveStates(rig)
    if not rig then return end
    local hum = rig:WaitForChild("Humanoid", 3)
    if not hum then return end
    
    if VisualAccessories.State.Headless then hilangkanKepala(rig, true) end
    if VisualAccessories.State.LeftKorblox then runTahap1("Left", true, rig, hum) end
    if VisualAccessories.State.RightKorblox then runTahap1("Right", true, rig, hum) end
end

task.spawn(function()
    local rigsFolder = workspace:WaitForChild("Rigs", 10)
    if rigsFolder then
        rigsFolder.ChildAdded:Connect(function(child)
            if child.Name == Players.LocalPlayer.Name then
                task.wait(0.5) 
                ApplyActiveStates(child)
            end
        end)
    end
    
    Players.LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        ApplyActiveStates(char)
    end)
end)

-- ==========================================
-- EXPORTED FUNCTIONS BUAT UI
-- ==========================================
function VisualAccessories.ToggleHeadless(state)
    VisualAccessories.State.Headless = state
    local character, _ = GetCharacter()
    hilangkanKepala(character, state)
end

function VisualAccessories.ToggleKorblox(state, side)
    VisualAccessories.State[side .. "Korblox"] = state
    local character, humanoid = GetCharacter()
    runTahap1(side, state, character, humanoid)
end

function VisualAccessories.Apply(assetId, WindUI)
    local character, humanoid = GetCharacter()
    if not character or not humanoid then
        if WindUI then WindUI:Notify({ Title = "Error", Content = "Character or Humanoid not found!", Duration = 3 }) end
        return
    end

    if WindUI then WindUI:Notify({ Title = "Loading", Content = "Fetching asset from Marketplace...", Duration = 2 }) end

    local success, objects = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(assetId)) end)

    if not success or not objects or not objects[1] then
        if WindUI then WindUI:Notify({ Title = "Failed", Content = "Failed to load asset ID.", Duration = 3 }) end
        return
    end

    local loaded = objects[1]
    local accessory = loaded:IsA("Accessory") and loaded or loaded:FindFirstChildWhichIsA("Accessory", true)

    if not accessory then
        if WindUI then WindUI:Notify({ Title = "Invalid Asset", Content = "Asset is not an Accessory.", Duration = 3 }) end
        loaded:Destroy()
        return
    end

    accessory.Parent = nil
    if loaded ~= accessory then loaded:Destroy() end

    local handle = accessory:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        accessory:Destroy()
        return
    end

    handle.CanCollide = false
    handle.CanTouch = false
    handle.CanQuery = false
    handle.Massless = true
    accessory:SetAttribute("IsCustomAccessory", true)

    local itemAttachment = handle:FindFirstChildWhichIsA("Attachment")
    if itemAttachment then
        local bodyAttachment = FindBodyAttachment(character, itemAttachment.Name)
        if bodyAttachment then
            local bodyPart = bodyAttachment.Parent
            accessory.Parent = character
            local oldWeld = handle:FindFirstChild("AccessoryWeld")
            if oldWeld then oldWeld:Destroy() end

            local weld = Instance.new("Weld")
            weld.Name = "AccessoryWeld"
            weld.Part0 = bodyPart
            weld.Part1 = handle
            weld.C0 = bodyAttachment.CFrame
            weld.C1 = itemAttachment.CFrame
            weld.Parent = handle

            if WindUI then WindUI:Notify({ Title = "Success", Content = "Accessory equipped perfectly!", Duration = 3 }) end
            return
        end
    end

    local addSuccess, _ = pcall(function() humanoid:AddAccessory(accessory) end)
    if addSuccess then
        if WindUI then WindUI:Notify({ Title = "Success", Content = "Accessory equipped via Humanoid fallback.", Duration = 3 }) end
        pcall(function() humanoid:BuildRigFromAttachments() end)
    else
        accessory:Destroy()
        if WindUI then WindUI:Notify({ Title = "Failed", Content = "Could not attach accessory to rig.", Duration = 3 }) end
    end
end

function VisualAccessories.Clear(WindUI)
    local character, _ = GetCharacter()
    if character then
        local count = 0
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Accessory") and child:GetAttribute("IsCustomAccessory") then
                child:Destroy()
                count = count + 1
            end
        end
        if WindUI then WindUI:Notify({ Title = "Cleaned", Content = "Removed " .. count .. " custom accessories.", Duration = 3 }) end
    end
end

return VisualAccessories
