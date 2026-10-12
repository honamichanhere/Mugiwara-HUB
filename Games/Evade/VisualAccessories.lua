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

-- Database untuk Toggle State & Data Asli
VisualAccessories.State = {
    Headless = false,
    LeftKorblox = false,
    RightKorblox = false
}

VisualAccessories.OriginalData = {
    Head = {}, 
    AvatarDesc = nil
}

-- Ambil data Avatar asli player di background saat module di-load
task.spawn(function()
    local success, desc = pcall(function() 
        return Players:GetHumanoidDescriptionFromUserId(Players.LocalPlayer.UserId) 
    end)
    if success and desc then
        VisualAccessories.OriginalData.AvatarDesc = desc
        print("[Mugiwara HUB] Original Avatar Description cached successfully.")
    end
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

-- Menyambungkan ulang part custom/script game ke tulang baru
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

-- Mesin utama perakit tulang (Support R6 & R15, Kiri & Kanan, On & Off)
local function runTahap1(side, state, myRig, myHum)
    if not myRig or not myHum then return false end
    if not VisualAccessories.OriginalData.AvatarDesc then return false end

    -- Clone deskripsi asli, manipulasi ID Kakinya dengan Bundle ID Korblox
    local dummyDesc = VisualAccessories.OriginalData.AvatarDesc:Clone()
    if state then
        if side == "Left" then dummyDesc.LeftLeg = 398672920 end
        if side == "Right" then dummyDesc.RightLeg = 398673196 end
    end

    local isR15 = myHum.RigType == Enum.HumanoidRigType.R15
    local dummyRig = Players:CreateHumanoidModelFromDescription(dummyDesc, myHum.RigType)
    dummyRig.Name = "TumbalKorblox_" .. side
    dummyRig.Parent = workspace 
    task.wait(0.1) -- Beri waktu sedikit untuk physics joint Roblox memuat
    
    local sukses = false

    if isR15 then
        local upperName = side .. "UpperLeg"
        local lowerName = side .. "LowerLeg"
        local footName = side .. "Foot"

        local oldUpper = myRig:FindFirstChild(upperName)
        local oldLower = myRig:FindFirstChild(lowerName)
        local oldFoot = myRig:FindFirstChild(footName)

        local newUpper = dummyRig:FindFirstChild(upperName)
        local newLower = dummyRig:FindFirstChild(lowerName)
        local newFoot = dummyRig:FindFirstChild(footName)

        if oldUpper and oldLower and oldFoot and newUpper and newLower and newFoot then
            local joints = myRig:FindFirstChild("Joints")
            local hipName = side .. "Hip"
            local kneeName = side .. "Knee"
            local ankleName = side .. "Ankle"

            local hip = (joints and joints:FindFirstChild(hipName)) or (myRig:FindFirstChild("LowerTorso") and myRig.LowerTorso:FindFirstChild(hipName)) or oldUpper:FindFirstChild(hipName)
            local knee = (joints and joints:FindFirstChild(kneeName)) or oldLower:FindFirstChild(kneeName)
            local ankle = (joints and joints:FindFirstChild(ankleName)) or oldFoot:FindFirstChild(ankleName)

            if hip and knee and ankle then
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
        local targetLeg = dummyRig:FindFirstChild(legName)

        if myOldLeg and hipMotor and targetLeg then
            local bPartEnum = side == "Left" and Enum.BodyPart.LeftLeg or Enum.BodyPart.RightLeg
            
            for _, obj in ipairs(dummyRig:GetChildren()) do
                if obj:IsA("CharacterMesh") and obj.BodyPart == bPartEnum then
                    for _, oldMesh in ipairs(myRig:GetChildren()) do
                        if oldMesh:IsA("CharacterMesh") and oldMesh.BodyPart == bPartEnum then
                            oldMesh:Destroy()
                        end
                    end
                    obj.Parent = myRig
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

    dummyRig:Destroy()
    return sukses
end

-- ==========================================
-- APLIKASI STATE OTOMATIS
-- ==========================================
local function ApplyActiveStates(rig)
    if not rig then return end
    local hum = rig:WaitForChild("Humanoid", 3)
    if not hum then return end
    
    if VisualAccessories.State.Headless then 
        hilangkanKepala(rig, true) 
    end
    if VisualAccessories.State.LeftKorblox then 
        runTahap1("Left", true, rig, hum) 
    end
    if VisualAccessories.State.RightKorblox then 
        runTahap1("Right", true, rig, hum) 
    end
end

-- Event Listener: Auto-Apply saat karakter spawn ulang di Evade
task.spawn(function()
    local rigsFolder = workspace:WaitForChild("Rigs", 10)
    if rigsFolder then
        rigsFolder.ChildAdded:Connect(function(child)
            if child.Name == Players.LocalPlayer.Name then
                task.wait(0.5) -- Beri waktu sedikit untuk load dari server
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
    
    if not VisualAccessories.OriginalData.AvatarDesc then
        warn("[Mugiwara HUB] Avatar Data belum termuat sepenuhnya!")
        return
    end

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
        if WindUI then WindUI:Notify({ Title = "Failed", Content = "Failed to load asset ID: " .. tostring(assetId), Duration = 3 }) end
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
