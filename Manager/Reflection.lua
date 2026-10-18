local ReflectionManager = {}
ReflectionManager.Enabled = false
ReflectionManager.Transparency = 10 -- sengaja >1: bug engine Roblox yang membuat kaca punya reflection "deep"
ReflectionManager.Offset = 0.1 
ReflectionManager.Connections = {}
ReflectionManager.GlobalModel = nil
ReflectionManager.Intensity = 0 -- 0..1; 0 = objek asli tidak diubah

-- Intensity bekerja lewat transparency OBJEK ASLI, dihitung relatif terhadap nilai default tiap
-- objek (bukan nilai mutlak): transparency = default + (1 - default) * intensity. Objek yang
-- aslinya 0.5 (kaca, dsb) jadi 0.5 saat intensity 0 dan 1 saat intensity penuh, tidak pernah
-- lebih rendah dari default-nya. Default dicatat sebelum objek pertama kali diubah dan dipulihkan
-- saat reflection dimatikan.
local Defaults = setmetatable({}, { __mode = "k" }) -- part -> transparency asli
local Applied = setmetatable({}, { __mode = "k" })  -- part -> nilai yang terakhir kita tulis
local TOLERANCE = 0.002
local BATCH_SIZE = 1500
local applying = false

local function Calculate(default)
    return math.clamp(default + (1 - default) * ReflectionManager.Intensity, 0, 1)
end

local function ApplyIntensity(part)
    local default = Defaults[part]
    if default == nil or not part.Parent then return end

    local current = part.Transparency
    local applied = Applied[part]
    -- Game mengubah transparency-nya sendiri sejak tulisan terakhir kita: nilai barunya dianggap
    -- default yang baru, jadi tidak ditimpa nilai basi.
    if applied ~= nil and math.abs(current - applied) > TOLERANCE then
        default = current
        Defaults[part] = default
    end

    local target = Calculate(default)
    if math.abs(current - target) > 0.0005 then part.Transparency = target end
    Applied[part] = (math.abs(target - default) > 0.0005) and target or nil
end

local function RestorePart(part)
    local default = Defaults[part]
    local applied = Applied[part]
    Applied[part] = nil
    if default == nil or applied == nil or not part.Parent then return end
    -- Hanya dipulihkan kalau nilainya masih yang kita tulis; kalau game sudah mengubahnya, dibiarkan.
    if math.abs(part.Transparency - applied) <= TOLERANCE then part.Transparency = default end
end

local function SnapshotParts()
    local list = {}
    for part in pairs(Defaults) do list[#list + 1] = part end
    return list
end

local CharacterPartsFilter = {
    ["Head"] = true, ["Torso"] = true, ["HumanoidRootPart"] = true,
    ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
    ["UpperTorso"] = true, ["LowerTorso"] = true,
    ["LeftUpperArm"] = true, ["LeftLowerArm"] = true, ["LeftHand"] = true,
    ["RightUpperArm"] = true, ["RightLowerArm"] = true, ["RightHand"] = true,
    ["LeftUpperLeg"] = true, ["LeftLowerLeg"] = true, ["LeftFoot"] = true,
    ["RightUpperLeg"] = true, ["RightLowerLeg"] = true, ["RightFoot"] = true
}

local function StripVisuals(instance)
    for _, child in ipairs(instance:GetDescendants()) do
        if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture") or child:IsA("ParticleEmitter") or child:IsA("Fire") or child:IsA("Smoke") or child:IsA("Sparkles") then
            child:Destroy()
        end
    end
end

local function SetupGlobalModel()
    if ReflectionManager.GlobalModel then return end
    
    ReflectionManager.GlobalModel = Instance.new("Model")
    ReflectionManager.GlobalModel.Name = "Mugiwara_Reflection_Global"
    
    local globalHighlight = Instance.new("Highlight")
    globalHighlight.FillTransparency = 1
    globalHighlight.OutlineTransparency = 1
    globalHighlight.Parent = ReflectionManager.GlobalModel
    
    ReflectionManager.GlobalModel.Parent = workspace
end

function ReflectionManager.ApplyReflection(part)
    if part:GetAttribute("IsReflectionLayer") then return end
    if not ReflectionManager.GlobalModel then return end
    if part:IsDescendantOf(ReflectionManager.GlobalModel) then return end
    if CharacterPartsFilter[part.Name] then return end

    -- Catat transparency asli SEBELUM apa pun diubah (clone di bawah ditimpa nilainya sendiri).
    if Defaults[part] == nil then Defaults[part] = part.Transparency end

    local originalArchivable = part.Archivable
    part.Archivable = true
    local clone = part:Clone()
    part.Archivable = originalArchivable
    
    if not clone then return end
    
    StripVisuals(clone)
    
    for _, child in ipairs(clone:GetChildren()) do
        if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ProximityPrompt") or child:IsA("ClickDetector") then
            child:Destroy()
        end
    end
    
    clone.Name = part.Name .. "_reflection"
    clone:SetAttribute("IsReflectionLayer", true)
    
    clone.CanCollide = false
    clone.Massless = true
    clone.Material = Enum.Material.Glass
    clone.Transparency = ReflectionManager.Transparency
    
    local totalOffset = ReflectionManager.Offset * 2
    
    if clone:IsA("WedgePart") then
        clone.Size = part.Size + Vector3.new(totalOffset, totalOffset, totalOffset)
        clone.CFrame = part.CFrame * CFrame.new(0, ReflectionManager.Offset * 0.4, -ReflectionManager.Offset * 0.4)
        
    elseif clone:IsA("CornerWedgePart") then
        clone.Size = part.Size + Vector3.new(totalOffset, totalOffset, totalOffset)
        clone.CFrame = part.CFrame * CFrame.new(ReflectionManager.Offset * 0.4, ReflectionManager.Offset * 0.4, -ReflectionManager.Offset * 0.4)
        
    elseif clone:IsA("MeshPart") or clone:IsA("UnionOperation") then
        pcall(function() 
            if clone:IsA("UnionOperation") then clone.UsePartColor = true 
            else clone.TextureID = "" end 
        end)
        local maxAxis = math.max(part.Size.X, part.Size.Y, part.Size.Z)
        local scale = (maxAxis + totalOffset) / maxAxis
        clone.Size = part.Size * scale
        clone.CFrame = part.CFrame * CFrame.new(0.01, 0.01, 0.01)
        
    else
        clone.Size = part.Size + Vector3.new(totalOffset, totalOffset, totalOffset)
        if clone:IsA("Part") and clone.Shape ~= Enum.PartType.Block then
            clone.CFrame = part.CFrame * CFrame.new(0.01, 0.01, 0.01)
        else
            clone.CFrame = part.CFrame
        end
    end
    
    clone.Parent = ReflectionManager.GlobalModel

    if ReflectionManager.Intensity > 0 then ApplyIntensity(part) end

    if not part.Anchored then
        clone.Anchored = false
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = part
        weld.Part1 = clone
        weld.Parent = clone
    else
        clone.Anchored = true
    end
    
    local cleanConn
    cleanConn = part.AncestryChanged:Connect(function(_, newParent)
        if not newParent then
            if clone and clone.Parent then
                clone:Destroy()
            end
            if cleanConn then cleanConn:Disconnect() end
        end
    end)
    table.insert(ReflectionManager.Connections, cleanConn)
end

-- Slider intensity (0..1). Diterapkan bertahap supaya menggeser slider di map besar tidak membuat
-- game freeze; kalau nilainya berubah lagi di tengah jalan, penerapan diulang dengan nilai terbaru.
function ReflectionManager.SetIntensity(value)
    ReflectionManager.Intensity = math.clamp(tonumber(value) or 0, 0, 1)
    if applying or not ReflectionManager.GlobalModel then return end

    applying = true
    task.spawn(function()
        local target
        repeat
            target = ReflectionManager.Intensity
            for index, part in ipairs(SnapshotParts()) do
                if ReflectionManager.Intensity ~= target then break end
                ApplyIntensity(part)
                if index % BATCH_SIZE == 0 then task.wait() end
            end
        until target == ReflectionManager.Intensity or not ReflectionManager.GlobalModel
        applying = false
    end)
end

function ReflectionManager.Toggle(state)
    -- Toggle ON dua kali berturut-turut bikin layer dobel dan koneksi bocor.
    if state and ReflectionManager.GlobalModel then return end
    ReflectionManager.Enabled = state

    if state then
        print("[Mugiwara HUB] Initiating reflection layer generation. Processing all valid parts...")
        SetupGlobalModel()
        
        local count = 0
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and not v:IsA("Terrain") and v.Transparency < 1 then
                if not v:GetAttribute("IsReflectionLayer") and not v:IsDescendantOf(ReflectionManager.GlobalModel) then
                    if not CharacterPartsFilter[v.Name] then
                        ReflectionManager.ApplyReflection(v)
                        count = count + 1
                        
                        if count % 1000 == 0 then
                            task.wait(0.5)
                            -- User bisa matiin toggle selama generate; berhenti biar nggak
                            -- lanjut nge-clone ke model yang sudah dihapus.
                            if not ReflectionManager.Enabled or not ReflectionManager.GlobalModel then return end
                        end
                    end
                end
            end
        end
        
        local addConn = workspace.DescendantAdded:Connect(function(descendant)
            if ReflectionManager.Enabled then
                task.spawn(function()
                    task.wait(0.5)
                    if descendant and descendant.Parent and descendant:IsA("BasePart") and not descendant:IsA("Terrain") then
                        if descendant.Transparency < 1 and not descendant:GetAttribute("IsReflectionLayer") then
                            if not CharacterPartsFilter[descendant.Name] then
                                ReflectionManager.ApplyReflection(descendant)
                            end
                        end
                    end
                end)
            end
        end)
        table.insert(ReflectionManager.Connections, addConn)
        
        print("[Mugiwara HUB] Reflection layers successfully generated.")
    else
        print("[Mugiwara HUB] Removing existing reflection layers...")
        for _, conn in ipairs(ReflectionManager.Connections) do
            if conn then conn:Disconnect() end
        end
        table.clear(ReflectionManager.Connections)

        -- Kembalikan transparency objek asli (tanpa yield: cleanup re-execute berjalan sinkron).
        for _, part in ipairs(SnapshotParts()) do RestorePart(part) end
        Defaults = setmetatable({}, { __mode = "k" })
        Applied = setmetatable({}, { __mode = "k" })

        if ReflectionManager.GlobalModel then
            ReflectionManager.GlobalModel:Destroy()
            ReflectionManager.GlobalModel = nil
        end

        print("[Mugiwara HUB] Reflection layers completely removed.")
    end
end

-- Remove every reflection layer and connection when the hub is re-executed.
getgenv().MugiwaraRegisterCleanup(function()
    ReflectionManager.Toggle(false)
    if ReflectionManager.GlobalModel then
        ReflectionManager.GlobalModel:Destroy()
        ReflectionManager.GlobalModel = nil
    end
end)

return ReflectionManager
