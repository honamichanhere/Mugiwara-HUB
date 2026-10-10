-- ==========================================
-- REFLECTION MANAGER (GRAPHIC HACK)
-- ==========================================
local ReflectionManager = {}
ReflectionManager.Enabled = false
ReflectionManager.Transparency = 1.5
ReflectionManager.Offset = 0.5
ReflectionManager.Connection = nil -- Menyimpan event listener

local function ClearChildren(instance)
    for _, child in ipairs(instance:GetChildren()) do
        child:Destroy()
    end
end

function ReflectionManager.ApplyReflection(part)
    -- Anti-loop check: Jangan menduplikasi objek yang sudah menjadi reflection layer
    if part:GetAttribute("IsReflectionLayer") then return end
    
    local clone = part:Clone()
    ClearChildren(clone)
    
    clone.Name = part.Name .. "_reflection"
    clone:SetAttribute("IsReflectionLayer", true)
    clone:SetAttribute("OriginalSize", part.Size)
    
    clone.CanCollide = false
    clone.Massless = true -- Wajib agar tidak merusak physics part unanchored
    clone.Material = Enum.Material.Glass
    clone.Transparency = ReflectionManager.Transparency
    clone.Size = part.Size + Vector3.new(ReflectionManager.Offset * 2, ReflectionManager.Offset * 2, ReflectionManager.Offset * 2)
    clone.CFrame = part.CFrame
    
    -- Parenting ke dalam objek asli.
    -- Keuntungan: Jika objek asli dihapus (Destroy), clone ini akan otomatis ikut terhapus.
    clone.Parent = part
    
    -- Proses Welding jika part tidak di-anchor
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
        
        -- Event Listener untuk objek yang baru spawn
        if not ReflectionManager.Connection then
            print("[Mugiwara HUB] Attaching DescendantAdded listener for new objects...")
            ReflectionManager.Connection = workspace.DescendantAdded:Connect(function(descendant)
                if ReflectionManager.Enabled then
                    -- task.defer digunakan untuk memastikan semua property part baru sudah termuat
                    task.defer(function()
                        if descendant and descendant.Parent and descendant:IsA("BasePart") and not descendant:IsA("Terrain") and descendant.Transparency < 1 then
                            if not descendant:GetAttribute("IsReflectionLayer") then
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
        -- Matikan listener saat fitur di-off
        if ReflectionManager.Connection then
            ReflectionManager.Connection:Disconnect()
            ReflectionManager.Connection = nil
        end
        
        local count = 0
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and v:GetAttribute("IsReflectionLayer") then
                v:Destroy()
                count = count + 1
                
                if count % 200 == 0 then
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
            if count % 500 == 0 then
                task.wait(0.5) -- Update lebih cepat daripada pembuatan
            end
        end
    end
end

return ReflectionManager
