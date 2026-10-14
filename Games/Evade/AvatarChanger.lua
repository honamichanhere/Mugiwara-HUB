-- ==========================================
-- MODULE: AVATAR CHANGER (EVADE)
-- ==========================================
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

    -- 1. Cari UserId dari Username
    local success, userId = pcall(function() return Players:GetUserIdFromNameAsync(username) end)
    if not success or not userId then
        if WindUI then WindUI:Notify({Title = "Error", Content = "Username tidak valid atau tidak ditemukan!", Duration = 3}) end
        return
    end

    -- 2. Ambil Blueprint Avatar Target
    local successDesc, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(userId) end)
    if not successDesc or not desc then
        if WindUI then WindUI:Notify({Title = "Error", Content = "Gagal mengambil rincian avatar target!", Duration = 3}) end
        return
    end

    -- Hapus morph sebelumnya jika lu udah pakai kostum lain
    AvatarChanger.Clear(false)

    -- 3. Render Avatar Target di Y=5000
    local dummy = Players:CreateHumanoidModelFromDescription(desc, hum.RigType)
    dummy.Name = "Mugiwara_Target_Clone"
    dummy:PivotTo(CFrame.new(5000, 5000, 5000))
    dummy.Parent = workspace
    
    task.wait(0.5) -- Tunggu asset loading sempurna

    -- Simpan transparansi part asli sebagai backup
    if not AvatarChanger.OriginalData.Transparencies then
        AvatarChanger.OriginalData.Transparencies = {}
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                AvatarChanger.OriginalData.Transparencies[part.Name] = part.Transparency
            end
        end
    end

    -- 4. Sembunyikan Karakter Asli Lu
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Transparency = 1
            -- Hilangkan decal muka asli
            for _, face in ipairs(part:GetChildren()) do
                if face:IsA("Decal") and face.Name == "face" then
                    face.Transparency = 1
                end
            end
        elseif part:IsA("Accessory") then
            -- Sembunyikan aksesoris asli
            local handle = part:FindFirstChild("Handle")
            if handle then handle.Transparency = 1 end
        end
    end

    -- 5. Jadikan Dummy sebagai Kostum Visual 1:1
    local noPhys = PhysicalProperties.new(0.01, 0, 0, 0, 0)

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
                
                -- Bersihkan hal yang ga perlu dari clone agar fisik Evade tidak rusak
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
        elseif dummyPart:IsA("Accessory") then
            local cloneAcc = dummyPart:Clone()
            cloneAcc.Name = "Mugiwara_Morph_Acc"
            local handle = cloneAcc:FindFirstChild("Handle")
            if handle then
                handle.Anchored = false
                handle.CanCollide = false
                handle.Massless = true
                handle.CustomPhysicalProperties = noPhys
                
                local itemAtt = handle:FindFirstChildWhichIsA("Attachment")
                if itemAtt then
                    -- Cari bagian tubuh di karakter asli untuk menempelkan aksesoris
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
                end
            end
        end
    end

    -- 6. Replace Warna Kulit dan Pakaian 2D (Sempurna)
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

    -- Pasang warna kulit dan pakaian dari target ke badan lu
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

    -- Hapus Kostum dan Aksesoris Clone
    for _, child in ipairs(char:GetChildren()) do
        if string.match(child.Name, "Mugiwara_Morph") then
            child:Destroy()
        end
    end

    -- Kembalikan transparansi wujud asli lu
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

    -- Munculkan kembali aksesoris asli
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("Accessory") and not string.match(part.Name, "Mugiwara_Morph") then
            local handle = part:FindFirstChild("Handle")
            if handle then handle.Transparency = 0 end
        end
    end

    -- Kembalikan Warna Kulit dan Pakaian Asli Lu
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
