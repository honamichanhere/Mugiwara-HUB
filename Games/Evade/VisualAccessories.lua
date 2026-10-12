local VisualAccessories = {}
local Players = game:GetService("Players")

VisualAccessories.Templates = {
    { Name = "Violet Valkyrie", ID = 1402432199 },
    { Name = "8-Bit Royal Crown", ID = 10159600649 },
    { Name = "Fiery Horns of the Netherworld", ID = 215718515 },
    { Name = "Frozen Horns of the Frigid Planes", ID = 74891470 },
    { Name = "Poisoned Horns of the Toxic Wasteland", ID = 1744060292 }
}

VisualAccessories.OriginalData = {
    Head = {}, LeftLeg = {}, RightLeg = {}
}

task.spawn(function()
    local cacheFolder = workspace:FindFirstChild("Mugiwara_Bundle_Cache")
    if not cacheFolder then
        cacheFolder = Instance.new("Folder")
        cacheFolder.Name = "Mugiwara_Bundle_Cache"
        cacheFolder.Parent = workspace
    end

    local assetsToLoad = { Left = 398672920, Right = 398673196 }

    for side, id in pairs(assetsToLoad) do
        pcall(function()
            local objs = game:GetObjects("rbxassetid://" .. id)
            if objs and objs[1] then
                local asset = objs[1]
                asset.Parent = cacheFolder
                
                for _, part in ipairs(asset:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Anchored = true
                        part.CanCollide = false
                        part.CFrame = CFrame.new(5000, 5000, side == "Left" and 5000 or -5000)
                    end
                end
                VisualAccessories.OriginalData["Cache" .. side] = asset
                print("[Mugiwara HUB] Cached Korblox " .. side .. " Leg at Y=5000")
            end
        end)
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

function VisualAccessories.Apply(assetId, WindUI)
    local character, humanoid = GetCharacter()
    if not character or not humanoid then
        if WindUI then WindUI:Notify({ Title = "Error", Content = "Character or Humanoid not found!", Duration = 3 }) end
        return
    end

    if WindUI then WindUI:Notify({ Title = "Loading", Content = "Fetching asset from Marketplace...", Duration = 2 }) end

    local success, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(assetId))
    end)

    if not success or not objects or not objects[1] then
        if WindUI then WindUI:Notify({ Title = "Failed", Content = "Failed to load asset ID: " .. tostring(assetId), Duration = 3 }) end
        return
    end

    local loaded = objects[1]
    local accessory

    if loaded:IsA("Accessory") then
        accessory = loaded
    else
        accessory = loaded:FindFirstChildWhichIsA("Accessory", true)
    end

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

    local addSuccess, _ = pcall(function()
        humanoid:AddAccessory(accessory)
    end)

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

function VisualAccessories.ToggleHeadless(state)
    local character, humanoid = GetCharacter()
    if not character or not humanoid then return end

    local head = character:FindFirstChild("Head")
    if not head then return end

    if state then
        if not VisualAccessories.OriginalData.Head.Transparency then
            VisualAccessories.OriginalData.Head.Transparency = head.Transparency
        end
        head.Transparency = 1
        
        local face = head:FindFirstChildOfClass("Decal")
        if face then 
            VisualAccessories.OriginalData.Head.FaceCache = face:Clone()
            face:Destroy()
        end
    else
        if VisualAccessories.OriginalData.Head.Transparency then
            head.Transparency = VisualAccessories.OriginalData.Head.Transparency
        end
        
        local currentFace = head:FindFirstChildOfClass("Decal")
        if not currentFace and VisualAccessories.OriginalData.Head.FaceCache then
            VisualAccessories.OriginalData.Head.FaceCache:Clone().Parent = head
        end
    end
end

function VisualAccessories.ToggleKorblox(state, side)
    local character, humanoid = GetCharacter()
    if not character or not humanoid then return end

    local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15

    local targetParts = {}
    if side == "Left" then
        targetParts = isR15 and {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot"} or {"Left Leg"}
    else
        targetParts = isR15 and {"RightUpperLeg", "RightLowerLeg", "RightFoot"} or {"Right Leg"}
    end

    for _, partName in ipairs(targetParts) do
        local part = character:FindFirstChild(partName)
        if part then
            if state then
                if not VisualAccessories.OriginalData[side .. "Leg"][partName] then
                    VisualAccessories.OriginalData[side .. "Leg"][partName] = part.Transparency
                end
                
                part.Transparency = 1 
                part:SetAttribute("HasKorblox", true)
                
                local cachedBundle = VisualAccessories.OriginalData["Cache" .. side]
                local fakeLeg
                
                if cachedBundle and isR15 then
                    local cachedPart = cachedBundle:FindFirstChild(partName, true)
                    if cachedPart and cachedPart:IsA("MeshPart") then
                        fakeLeg = cachedPart:Clone()
                        fakeLeg.Name = "FakeKorblox" .. side .. partName
                        fakeLeg.Anchored = false
                        fakeLeg.CanCollide = false
                        fakeLeg.Massless = true
                        
                        for _, child in ipairs(fakeLeg:GetChildren()) do
                            if child:IsA("Attachment") or child:IsA("Motor6D") then
                                child:Destroy()
                            end
                        end
                    end
                end
                
                if not fakeLeg then
                    fakeLeg = Instance.new("Part")
                    fakeLeg.Name = "FakeKorblox" .. side .. partName
                    fakeLeg.Size = part.Size
                    fakeLeg.CanCollide = false
                    fakeLeg.Massless = true
                    fakeLeg.Transparency = 0
                    
                    local mesh = Instance.new("SpecialMesh")
                    mesh.MeshId = side == "Left" and "rbxassetid://902942093" or "rbxassetid://902942096"
                    mesh.Parent = fakeLeg
                end

                local bodyColor = character:FindFirstChildOfClass("BodyColors")
                if bodyColor then
                    fakeLeg.Color = side == "Left" and bodyColor.LeftLegColor3 or bodyColor.RightLegColor3
                else
                    fakeLeg.Color = part.Color
                end

                fakeLeg.Parent = character

                local weld = Instance.new("WeldConstraint")
                weld.Part0 = part
                weld.Part1 = fakeLeg
                weld.Parent = fakeLeg
                
                fakeLeg.CFrame = part.CFrame
            else
                if VisualAccessories.OriginalData[side .. "Leg"][partName] then
                    part.Transparency = VisualAccessories.OriginalData[side .. "Leg"][partName]
                else
                    part.Transparency = 0
                end
                part:SetAttribute("HasKorblox", nil)
                
                local fakeLeg = character:FindFirstChild("FakeKorblox" .. side .. partName)
                if fakeLeg then fakeLeg:Destroy() end
            end
        end
    end
end

return VisualAccessories
