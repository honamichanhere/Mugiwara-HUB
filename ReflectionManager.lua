-- ==========================================
-- REFLECTION MANAGER (GRAPHIC HACK)
-- ==========================================
local ReflectionManager = {}
ReflectionManager.Enabled = false
ReflectionManager.Transparency = 1.5
ReflectionManager.Offset = 0.5

local function ClearChildren(instance)
    for _, child in ipairs(instance:GetChildren()) do
        child:Destroy()
    end
end

function ReflectionManager.ApplyReflection(part)
    local clone = part:Clone()
    ClearChildren(clone)
    
    clone.Name = part.Name .. "_reflection"
    clone:SetAttribute("IsReflectionLayer", true)
    clone:SetAttribute("OriginalSize", part.Size)
    
    clone.CanCollide = false
    clone.Anchored = true
    clone.Material = Enum.Material.Glass
    clone.Transparency = ReflectionManager.Transparency
    clone.Size = part.Size + Vector3.new(ReflectionManager.Offset * 2, ReflectionManager.Offset * 2, ReflectionManager.Offset * 2)
    clone.CFrame = part.CFrame
    
    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 1
    highlight.Parent = clone
    
    clone.Parent = part.Parent
end

function ReflectionManager.Toggle(state)
    ReflectionManager.Enabled = state
    
    if state then
        print("[Mugiwara HUB] Initiating reflection layer generation. This process may take a moment to prevent performance drops.")
        local count = 0
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and not v:IsA("Terrain") and v.Anchored and v.Transparency < 1 then
                if not v:GetAttribute("IsReflectionLayer") then
                    ReflectionManager.ApplyReflection(v)
                    count = count + 1
                    
                    if count % 200 == 0 then
                        task.wait(1)
                    end
                end
            end
        end
        print("[Mugiwara HUB] Reflection layers successfully generated.")
    else
        print("[Mugiwara HUB] Removing existing reflection layers...")
        local count = 0
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and v:GetAttribute("IsReflectionLayer") then
                v:Destroy()
                count = count + 1
                
                if count % 200 == 0 then
                    task.wait(0.5) -- Sedikit lebih cepat saat menghapus
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
