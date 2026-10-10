-- ==========================================
-- REFLECTION MANAGER (GRAPHIC HACK)
-- ==========================================
local ReflectionManager = {}
ReflectionManager.Enabled = false
ReflectionManager.Transparency = 1.5
ReflectionManager.Offset = 0.5
ReflectionManager.Connection = nil

-- Fungsi pembersih agresif
local function StripVisuals(instance)
    for _, child in ipairs(instance:GetDescendants()) do
        -- Hancurkan segala jenis tekstur, decal, atau PBR (SurfaceAppearance)
        if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture") or child:IsA("ParticleEmitter") or child:IsA("Fire") or child:IsA("Smoke") or child:IsA("Sparkles") then
            child:Destroy()
        end
    end
end

function ReflectionManager.ApplyReflection(part)
    if part:GetAttribute("IsReflectionLayer") then return end
    
    local originalArchivable = part.Archivable
    part.Archivable = true
    local clone = part:Clone()
    part.Archivable = originalArchivable
    
    if not clone then return end
    
    -- Bersihkan semua embel-embel visual bawaan
    StripVisuals(clone)
    
    -- Hapus script/komponen fungsional lain agar tidak duplicate logic
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
    
    -- KALAU DIA UNION ATAU MESH, KITA PAKSA USEPARTCOLOR TRUE BIAR MATERIAL GLASS NYA MASUK
    if clone:IsA("UnionOperation") or clone:IsA("MeshPart") then
        clone.UsePartColor = true
    end
    
    clone.Size = part.Size + Vector3.new(ReflectionManager.Offset * 2, ReflectionManager.Offset * 2, ReflectionManager.Offset * 2)
    clone.CFrame = part.CFrame
    
    clone.Parent = part
    
    if not part.Anchored then
        clone.Anchored = false
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = part
        weld.Part1 = clone
        weld.Parent = clone
    else
        clone.Anchored = true
    end
    
    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 1
    highlight.Parent = clone
end

function ReflectionManager.Toggle(state)
    ReflectionManager.Enabled = state
    
    if state then
        print("[Mugiwara HUB] Initiating reflection layer generation. Processing all parts...")
        local count = 0
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and not v:IsA("Terrain") and v.Transparency < 1 then
                if not v:GetAttribute("IsReflectionLayer") then
                    ReflectionManager.ApplyReflection(v)
                    count = count + 1
                    
                    if count % 200 == 0 then
                        task.wait(1)
                    end
                end
            end
        end
        
        if not ReflectionManager.Connection then
            print("[Mugiwara HUB] Attaching DescendantAdded listener for new objects...")
            ReflectionManager.Connection = workspace.DescendantAdded:Connect(function(descendant)
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
        end
        print("[Mugiwara HUB] Reflection layers successfully generated.")
    else
        print("[Mugiwara HUB] Removing existing reflection layers and detaching listener...")
        if ReflectionManager.Connection then
            ReflectionManager.Connection:Disconnect()
            ReflectionManager.Connection = nil
        end
        
        local count = 0
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and v:GetAttribute("IsReflectionLayer") then
                v:Destroy()
                count = count + 1
                
                if count % 500 == 0 then
                    task.wait(0.5)
                end
            end
        end
        print("[Mugiwara HUB] Reflection layers completely removed.")
    end
end

function ReflectionManager.UpdateSettings(transparency, offset)
    if transparency then ReflectionManager.Transparency = transparency end
    if offset then ReflectionManager.Offset = offset end
    
    if not ReflectionManager.Enabled then return end
    
    local count = 0
    for _, v in ipairs(workspace:GetDescendants()) do
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
