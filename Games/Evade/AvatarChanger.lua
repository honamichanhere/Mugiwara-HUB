local AvatarChanger = {}
local Players = game:GetService("Players")

AvatarChanger.OriginalData = {}

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

function AvatarChanger.Apply(username, WindUI)
    local char, hum = GetCharacter()
    if not char or not hum then return end

    if WindUI then WindUI:Notify({Title = "Memproses", Content = "Mengambil data avatar " .. username .. "...", Duration = 2}) end

    local success, userId = pcall(function() return Players:GetUserIdFromNameAsync(username) end)
    if not success or not userId then
        if WindUI then WindUI:Notify({Title = "Error", Content = "Username tidak valid atau tidak ditemukan!", Duration = 3}) end
        return
    end

    local successDesc, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(userId) end)
    if not successDesc or not desc then
        if WindUI then WindUI:Notify({Title = "Error", Content = "Gagal mengambil rincian avatar target!", Duration = 3}) end
        return
    end

    -- Hapus morph sebelumnya biar ga numpuk
    AvatarChanger.Clear(false)

    local isR15 = hum.RigType == Enum.HumanoidRigType.R15
    local dummy = Players:CreateHumanoidModelFromDescription(desc, hum.RigType)
    dummy.Name = "Mugiwara_Target_Clone"
    dummy:PivotTo(CFrame.new(5000, 5000, 5000))
    dummy.Parent = workspace
    
    task.wait(0.3)

    local noPhys = PhysicalProperties.new(0.01, 0, 0, 0, 0)

    -- ==========================================
    -- LOGIC R15: KOSTUM HOLOGRAFIK (WELD)
    -- ==========================================
    if isR15 then
        if not AvatarChanger.OriginalData.Transparencies then
            AvatarChanger.OriginalData.Transparencies = {}
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    AvatarChanger.OriginalData.Transparencies[part.Name] = part.Transparency
                end
            end
        end

        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 1
                for _, face in ipairs(part:GetChildren()) do
                    if face:IsA("Decal") and face.Name == "face" then
                        face.Transparency = 1
                    end
                end
            end
        end

        for _, dummyPart in ipairs(dummy:GetChildren()) do
            if dummyPart:IsA("BasePart") and dummyPart.Name ~= "HumanoidRootPart" then
                local oriPart = char:FindFirstChild(dummyPart.Name)
                if oriPart then
                    local clone = dummyPart:Clone()
                    clone.Name = "Mugiwara_Morph_" .. clone.Name
                    clone.Anchored = false
                    clone.CanCollide = false
                    clone.Massless = true
                    clone.CustomPhysicalProperties = noPhys
                    
                    for _, child in ipairs(clone:GetChildren()) do
                        if child:IsA("Motor6D") or child:IsA("Attachment") or child:IsA("Script") or child:IsA("Weld") or child:IsA("WeldConstraint") then
                            child:Destroy()
                        end
                    end
                    
                    clone.CFrame = oriPart.CFrame
                    clone.Parent = char
                    
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = oriPart
                    weld.Part1 = clone
                    weld.Parent = clone
                end
            end
        end

    -- ==========================================
    -- LOGIC R6: DIRECT ASSET SWAP (MURNI 1:1)
    -- ==========================================
    else
        -- 1. Backup & Ganti CharacterMesh (Bentuk Tubuh/Package)
        if not AvatarChanger.OriginalData.R6Meshes then
            AvatarChanger.OriginalData.R6Meshes = {}
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("CharacterMesh") then
                    table.insert(AvatarChanger.OriginalData.R6Meshes, obj:Clone())
                end
            end
        end
        
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("CharacterMesh") then obj:Destroy() end
        end

        for _, obj in ipairs(dummy:GetChildren()) do
            if obj:IsA("CharacterMesh") then
                obj:Clone().Parent = char
            end
        end

        -- 2. Backup & Ganti Muka + Bentuk Kepala (SpecialMesh)
        local myHead = char:FindFirstChild("Head")
        local dummyHead = dummy:FindFirstChild("Head")
        
        if myHead and dummyHead then
            local myFace = myHead:FindFirstChildOfClass("Decal")
            local dummyFace = dummyHead:FindFirstChildOfClass("Decal")
            local myMesh = myHead:FindFirstChildOfClass("SpecialMesh")
            local dummyMesh = dummyHead:FindFirstChildOfClass("SpecialMesh")
            
            if not AvatarChanger.OriginalData.FaceCache and myFace then AvatarChanger.OriginalData.FaceCache = myFace:Clone() end
            if not AvatarChanger.OriginalData.HeadMeshCache and myMesh then AvatarChanger.OriginalData.HeadMeshCache = myMesh:Clone() end
            
            if myFace then myFace:Destroy() end
            if myMesh then myMesh:Destroy() end
            
            if dummyFace then dummyFace:Clone().Parent = myHead end
            if dummyMesh then dummyMesh:Clone().Parent = myHead end
        end
    end

    -- ==========================================
    -- LOGIC GLOBAL (AKSESORIS, BAJU, WARNA KULIT)
    -- ==========================================
    
    -- Sembunyikan aksesoris asli (Berlaku untuk R6 & R15)
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("Accessory") then
            local handle = part:FindFirstChild("Handle")
            if handle then handle.Transparency = 1 end
        end
    end

    -- Clone Aksesoris Target
    for _, dummyAcc in ipairs(dummy:GetChildren()) do
        if dummyAcc:IsA("Accessory") then
            local cloneAcc = dummyAcc:Clone()
            cloneAcc.Name = "Mugiwara_Morph_Acc"
            local handle = cloneAcc:FindFirstChild("Handle")
            if handle then
                handle.Anchored = false
                handle.CanCollide = false
                handle.Massless = true
                handle.CustomPhysicalProperties = noPhys
                
                local itemAtt = handle:FindFirstChildWhichIsA("Attachment")
                if itemAtt then
                    local bodyAtt = nil
                    for _, p in ipairs(char:GetChildren()) do
                        if p:IsA("BasePart") then
                            bodyAtt = p:FindFirstChild(itemAtt.Name)
                            if bodyAtt then break end
                        end
                    end
                    
                    if bodyAtt then
                        cloneAcc.Parent = char
                        local weld = Instance.new("Weld")
                        weld.Name = "AccessoryWeld"
                        weld.Part0 = bodyAtt.Parent
                        weld.Part1 = handle
                        weld.C0 = bodyAtt.CFrame
                        weld.C1 = itemAtt.CFrame
                        weld.Parent = handle
                    end
                else
                    -- Fallback untuk aksesoris jadul R6 yang ga pake attachment
                    pcall(function() hum:AddAccessory(cloneAcc) end)
                end
            end
        end
    end

    -- Replace Pakaian & Warna Kulit
    if not AvatarChanger.OriginalData.ClothingCache then
        AvatarChanger.OriginalData.ClothingCache = {}
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("BodyColors") then
                table.insert(AvatarChanger.OriginalData.ClothingCache, item:Clone())
                item:Destroy() 
            end
        end
    else
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("BodyColors") then
                item:Destroy()
            end
        end
    end

    for _, item in ipairs(dummy:GetChildren()) do
        if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("BodyColors") then
            item:Clone().Parent = char
        end
    end

    dummy:Destroy()
    if WindUI then WindUI:Notify({Title = "Berhasil", Content = "Wujud diubah 100% menjadi " .. username, Duration = 3}) end
end

function AvatarChanger.Clear(showNotif, WindUI)
    local char, hum = GetCharacter()
    if not char then return end

    -- Bersihkan Limb Morph (R15) & Aksesoris
    for _, child in ipairs(char:GetChildren()) do
        if string.match(child.Name, "Mugiwara_Morph") then
            child:Destroy()
        end
    end

    -- Restore R15 Transparency
    if AvatarChanger.OriginalData.Transparencies then
        for partName, trans in pairs(AvatarChanger.OriginalData.Transparencies) do
            local part = char:FindFirstChild(partName)
            if part then
                part.Transparency = trans
                for _, face in ipairs(part:GetChildren()) do
                    if face:IsA("Decal") and face.Name == "face" then
                        face.Transparency = 0
                    end
                end
            end
        end
    end

    -- Restore R6 Body Packages (CharacterMesh)
    if AvatarChanger.OriginalData.R6Meshes then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("CharacterMesh") then obj:Destroy() end
        end
        for _, mesh in ipairs(AvatarChanger.OriginalData.R6Meshes) do
            mesh:Clone().Parent = char
        end
        AvatarChanger.OriginalData.R6Meshes = nil
    end

    -- Restore R6 Head & Face
    local myHead = char:FindFirstChild("Head")
    if myHead then
        if AvatarChanger.OriginalData.FaceCache then
            local currentFace = myHead:FindFirstChildOfClass("Decal")
            if currentFace then currentFace:Destroy() end
            AvatarChanger.OriginalData.FaceCache:Clone().Parent = myHead
            AvatarChanger.OriginalData.FaceCache = nil
        end
        
        if AvatarChanger.OriginalData.HeadMeshCache then
            local currentMesh = myHead:FindFirstChildOfClass("SpecialMesh")
            if currentMesh then currentMesh:Destroy() end
            AvatarChanger.OriginalData.HeadMeshCache:Clone().Parent = myHead
            AvatarChanger.OriginalData.HeadMeshCache = nil
        end
    end

    -- Munculkan kembali aksesoris asli
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("Accessory") and not string.match(part.Name, "Mugiwara_Morph") then
            local handle = part:FindFirstChild("Handle")
            if handle then handle.Transparency = 0 end
        end
    end

    -- Restore Baju & Warna Kulit
    if AvatarChanger.OriginalData.ClothingCache then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("BodyColors") then
                item:Destroy()
            end
        end
        for _, item in ipairs(AvatarChanger.OriginalData.ClothingCache) do
            item:Clone().Parent = char
        end
        AvatarChanger.OriginalData.ClothingCache = nil 
    end

    if showNotif and WindUI then
        WindUI:Notify({Title = "Dibersihkan", Content = "Wujud dikembalikan ke aslinya.", Duration = 3})
    end
end

return AvatarChanger
