-- ==========================================
-- CAMERA MANAGER MODULE
-- ==========================================
local CameraModule = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Variables State
CameraModule.FreecamEnabled = false
CameraModule.FreecamSpeed = 16
CameraModule.FOVLocked = false
CameraModule.FOVValue = 70
CameraModule.SpectateTarget = nil

-- Memori untuk balik ke awal
local originalCameraType = Camera.CameraType
local originalCameraSubject = Camera.CameraSubject
local freecamCFrame = Camera.CFrame

-- Variabel Rotasi Kamera
local rotationX = 0
local rotationY = 0

-- ==========================================
-- 1. FREECAM ENGINE
-- ==========================================
function CameraModule.ToggleFreecam(state)
    CameraModule.FreecamEnabled = state
    if state then
        -- Simpan state kamera original
        originalCameraType = Camera.CameraType
        originalCameraSubject = Camera.CameraSubject
        
        -- Override jadi Scriptable
        Camera.CameraType = Enum.CameraType.Scriptable
        freecamCFrame = Camera.CFrame
        
        -- Konversi CFrame rotasi saat ini ke derajat biar transisi mulus
        local rx, ry, rz = freecamCFrame:ToOrientation()
        rotationX = math.deg(rx)
        rotationY = math.deg(ry)
    else
        -- Kembalikan ke state asli (Bersih 100%)
        Camera.CameraType = originalCameraType or Enum.CameraType.Custom
        Camera.CameraSubject = originalCameraSubject or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid"))
    end
end

-- ==========================================
-- 2. SPECTATE ENGINE
-- ==========================================
function CameraModule.SetSpectate(playerName)
    -- Reset Spectate kalau pilih nama sendiri atau kosong
    if not playerName or playerName == "" or playerName == LocalPlayer.Name then
        CameraModule.SpectateTarget = nil
        if not CameraModule.FreecamEnabled then
            Camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            LocalPlayer.CameraMinZoomDistance = 0.5
            LocalPlayer.CameraMaxZoomDistance = 400 -- Default normal Roblox
        end
        return true, "Stopped spectating. Returned to local character."
    end

    local targetPlayer = Players:FindFirstChild(playerName)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        CameraModule.SpectateTarget = targetPlayer
        if not CameraModule.FreecamEnabled then
            Camera.CameraSubject = targetPlayer.Character.Humanoid
            
            -- Set Limit Scroll sesuai instruksi (Min: 0 [First Person], Max: 30)
            LocalPlayer.CameraMinZoomDistance = 0
            LocalPlayer.CameraMaxZoomDistance = 30
        end
        return true, "Now spectating: " .. playerName
    else
        return false, "Failed to spectate. Player or character not found."
    end
end

-- Fungsi tambahan buat narik list pemain (Dipakai UI nanti)
function CameraModule.GetPlayerList()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(list, player.Name)
    end
    return list
end

-- ==========================================
-- 3. THE MASTER LOOP (RENDER STEPPED)
-- ==========================================
RunService.RenderStepped:Connect(function(deltaTime)
    -- Pastikan referensi kamera selalu terupdate (jaga-jaga kalau game bikin kamera baru)
    Camera = workspace.CurrentCamera

    -- A. FORCE FOV LOCK
    if CameraModule.FOVLocked then
        Camera.FieldOfView = CameraModule.FOVValue
    end

    -- B. FREECAM MOVEMENT & ROTATION
    if CameraModule.FreecamEnabled then
        Camera.CameraType = Enum.CameraType.Scriptable
        
        -- Kalkulasi Gerakan (W,A,S,D,Q,E)
        local moveVector = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector + Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector + Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + Vector3.new(1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveVector = moveVector + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveVector = moveVector + Vector3.new(0, -1, 0) end

        -- Kalkulasi Rotasi (Arrow Keys) -> 120 derajat per detik
        local rotSpeed = 120 * deltaTime 
        if UserInputService:IsKeyDown(Enum.KeyCode.Up) then rotationX = rotationX + rotSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.Down) then rotationX = rotationX - rotSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.Left) then rotationY = rotationY + rotSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.Right) then rotationY = rotationY - rotSpeed end

        -- Clamp sumbu X biar gak terbalik (Kejengkang)
        rotationX = math.clamp(rotationX, -89, 89)

        -- Rakit arah kamera baru
        local camRotation = CFrame.Angles(0, math.rad(rotationY), 0) * CFrame.Angles(math.rad(rotationX), 0, 0)
        
        -- Terapkan pergerakan mengikuti arah hadap kamera (LookVector)
        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit * CameraModule.FreecamSpeed * deltaTime
            local relativeMove = camRotation * moveVector
            freecamCFrame = freecamCFrame + relativeMove
        end

        -- Update Posisi Fisik Kamera
        Camera.CFrame = CFrame.new(freecamCFrame.Position) * camRotation
    else
        -- C. SPECTATE AUTO-DISCONNECT (Fail-Safe)
        -- Kalau target yang di-spectate mati atau disconnect, otomatis lepas
        if CameraModule.SpectateTarget then
            if not CameraModule.SpectateTarget.Parent or not CameraModule.SpectateTarget.Character or not CameraModule.SpectateTarget.Character:FindFirstChild("Humanoid") then
                CameraModule.SetSpectate(nil)
            end
        end
    end
end)

return CameraModule
