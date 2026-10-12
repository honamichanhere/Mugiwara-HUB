local VisualAccessories = {}
local Players = game:GetService("Players")

VisualAccessories.Templates = {
    ["Violet Valkyrie"] = 1402432199,
    ["8-Bit Royal Crown"] = 10159600649,
    ["Fiery Horns of the Netherworld"] = 215718515,
    ["Frozen Horns of the Frigid Planes"] = 74891470,
    ["Poisoned Horns of the Toxic Wasteland"] = 1744060292,
}

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

return VisualAccessories
