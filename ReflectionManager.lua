-- ==========================================
-- REFLECTION MANAGER (GRAPHIC HACK)
-- ==========================================
local ReflectionManager = {}
ReflectionManager.Enabled = false
ReflectionManager.Transparency = 1.5
ReflectionManager.Offset = 0.5
ReflectionManager.Connections = {}
ReflectionManager.GlobalModel = nil

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
    -- Jangan proses bagian dari GlobalModel kita sendiri
    if ReflectionManager.GlobalModel and part:IsDescendantOf(ReflectionManager.GlobalModel) then return end
    
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
    clone:SetAttribute("OriginalSize", part.Size)
    
    clone.CanCollide = false
    clone.Massless = true
    clone.Material = Enum.Material.Glass
    clone.Transparency = ReflectionManager.Transparency
    
    if clone:IsA("UnionOperation") then
        pcall(function() clone.UsePartColor = true end)
    elseif clone:IsA("MeshPart") then
        pcall(function() clone.TextureID = "" end)
    end
    
    clone.Size = part.Size + Vector3.new(ReflectionManager.Offset * 2, ReflectionManager.Offset * 2, ReflectionManager.Offset * 2)
    clone.CFrame = part.CFrame
    
    -- Parenting ke Global Model agar cukup pakai 1 Highlight
    clone.Parent = ReflectionManager.GlobalModel
    
    if not part.Anchored then
        clone.Anchored = false
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = part
        weld.Part1 = clone
        weld.Parent = clone
    else
        clone.Anchored = true
    end
    
    -- Auto-cleanup: Jika part asli dihapus, hancurkan clone-nya
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

function ReflectionManager.Toggle(state)
    ReflectionManager.Enabled = state
    
    if state then
        print("[Mugiwara HUB] Initiating reflection layer generation. Processing all parts...")
        SetupGlobalModel()
        
        local count = 0
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and not v:IsA("Terrain") and v.Transparency < 1 then
                if not v:GetAttribute("IsReflectionLayer") and not v:IsDescendantOf(ReflectionManager.GlobalModel) then
                    ReflectionManager.ApplyReflection(v)
                    count = count + 1
                    
                    if count % 200 == 0 then
                        task.wait(1)
                    end
                end
            end
        end
        
        -- Event Listener untuk objek baru
        local addConn = workspace.DescendantAdded:Connect(function(descendant)
            if ReflectionManager.Enabled then
                task.spawn(function()
                    task.wait(0.5)
                    if descendant and descendant.Parent and descendant:IsA("BasePart") and not descendant:IsA("Terrain") then
                        if descendant.Transparency < 1 and not descendant:GetAttribute("IsReflectionLayer") then
                            ReflectionManager.ApplyReflection(descendant)
                        end
                    end
                end)
            end
        end)
        table.insert(ReflectionManager.Connections, addConn)
        
        print("[Mugiwara HUB] Reflection layers successfully generated.")
    else
        print("[Mugiwara HUB] Removing existing reflection layers...")
        -- Bersihkan semua event listener
        for _, conn in ipairs(ReflectionManager.Connections) do
            if conn then conn:Disconnect() end
        end
        table.clear(ReflectionManager.Connections)
        
        -- Hancurkan langsung Global Model beserta semua isinya (jauh lebih instan & anti-lag!)
        if ReflectionManager.GlobalModel then
            ReflectionManager.GlobalModel:Destroy()
            ReflectionManager.GlobalModel = nil
        end
        
        print("[Mugiwara HUB] Reflection layers completely removed.")
    end
end

function ReflectionManager.UpdateSettings(transparency, offset)
    if transparency then ReflectionManager.Transparency = transparency end
    if offset then ReflectionManager.Offset = offset end
    
    if not ReflectionManager.Enabled or not ReflectionManager.GlobalModel then return end
    
    local count = 0
    -- Kita cuma perlu nge-loop di dalam Global Model aja sekarang! Lebih ringan.
    for _, v in ipairs(ReflectionManager.GlobalModel:GetChildren()) do
        if v:IsA("BasePart") and v:GetAttribute("IsReflectionLayer") then
            local origSize = v:GetAttribute("OriginalSize")
            if origSize then
                v.Size = origSize + Vector3.new(ReflectionManager.Offset * 2, ReflectionManager.Offset * 2, ReflectionManager.Offset * 2)
            end
            v.Transparency = ReflectionManager.Transparency
            
            count = count + 1
            if count % 200 == 0 then
                task.wait(0.5)
            end
        end
    end
end

return ReflectionManager
