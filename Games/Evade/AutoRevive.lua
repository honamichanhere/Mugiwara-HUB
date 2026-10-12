-- ==========================================
-- MODULE: AUTO REVIVE AURA (EVADE)
-- ==========================================
local AutoRevive = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

AutoRevive.Enabled = false
AutoRevive.LoopConnection = nil

-- Cari RemoteEvent Interact dari ReplicatedStorage
local InteractEvent = ReplicatedStorage:WaitForChild("Events", 10)
if InteractEvent then 
    InteractEvent = InteractEvent:WaitForChild("Interact", 10) 
end

-- Fungsi rahasia mencari ID Target Revive (Berdasarkan Ticket/Node)
local function GetDownedPlayers()
    local targets = {}
    
    -- Di Evade, setiap player yang main dimasukkan ke dalam workspace.Game.Players
    -- Atau langsung di workspace. Jika mereka jatuh, biasanya ada atribut khusus 
    -- atau kita bisa menebak ID mereka dari properti Ticket/Node.
    local gameFolder = workspace:FindFirstChild("Game")
    local playersFolder = gameFolder and gameFolder:FindFirstChild("Players")
    
    if not playersFolder then return targets end
    
    for _, char in ipairs(playersFolder:GetChildren()) do
        if char:IsA("Model") and char.Name ~= Players.LocalPlayer.Name then
            -- Cek status Down. Evade biasanya menggunakan Atribut "Downed" atau "Revive"
            local isDown = char:GetAttribute("Downed") or char:GetAttribute("ReviveState")
            
            -- Jika atribut tidak ditemukan, kita cek apakah ada ProximityPrompt di badannya
            if not isDown then
                local prompt = char:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and (string.match(string.lower(prompt.ActionText), "revive") or string.match(string.lower(prompt.ActionText), "help")) then
                    isDown = true
                end
            end
            
            if isDown then
                -- Target ditemukan! Sekarang kita cari Ticket ID-nya (angka seperti 25, 9, dll)
                local targetId = char:GetAttribute("Ticket") or char:GetAttribute("ID") or char:GetAttribute("Node")
                
                -- Fallback: Jika tidak ada atribut, kita ekstrak dari nama atau posisi (butuh trial & error di Evade)
                -- Untuk sementara, jika kita mendapat ID, kita simpan
                if targetId then
                    table.insert(targets, { Name = char.Name, ID = targetId })
                end
            end
        end
    end
    
    return targets
end

local function ProcessReviveAura(WindUI)
    if not InteractEvent then return end

    local downedPlayers = GetDownedPlayers()
    
    for _, target in ipairs(downedPlayers) do
        -- Tembak RemoteEvent persis seperti tangkapan Cobalt lu
        -- Event:FireServer("Revive", <TargetID>, true)
        pcall(function()
            InteractEvent:FireServer("Revive", target.ID, true)
        end)
        
        if WindUI then 
            WindUI:Notify({ Title = "Aura Revive", Content = "Sending revive signal to " .. target.Name, Duration = 2 }) 
        end
    end
end

function AutoRevive.Toggle(state, WindUI)
    AutoRevive.Enabled = state
    
    if not InteractEvent then
        if WindUI then WindUI:Notify({ Title = "Error", Content = "Interact Event not found! Game might have updated.", Duration = 3 }) end
        return
    end

    if state then
        if WindUI then WindUI:Notify({ Title = "Aura Revive", Content = "Remote Scanner Activated.", Duration = 2 }) end
        
        -- Loop scanner setiap 1 detik
        AutoRevive.LoopConnection = RunService.Heartbeat:Connect(function()
            if not AutoRevive.LastScan then AutoRevive.LastScan = 0 end
            if tick() - AutoRevive.LastScan >= 1 then
                AutoRevive.LastScan = tick()
                task.spawn(function()
                    ProcessReviveAura(WindUI)
                end)
            end
        end)
    else
        if AutoRevive.LoopConnection then
            AutoRevive.LoopConnection:Disconnect()
            AutoRevive.LoopConnection = nil
        end
        if WindUI then WindUI:Notify({ Title = "Aura Revive", Content = "Scanner Deactivated.", Duration = 2 }) end
    end
end

return AutoRevive
