-- ==========================================
-- CAMERA MANAGER MODULE
-- ==========================================
local CameraModule = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Variables State
CameraModule.FreecamEnabled = false
CameraModule.FreecamSpeed = 16
CameraModule.FOVLocked = false
CameraModule.FOVValue = Camera and Camera.FieldOfView or 70
CameraModule.GameIntendedFOV = Camera and Camera.FieldOfView or 70
CameraModule.SpectateTarget = nil

-- Connections
local fovConnection
local subjectConnection
local cameraChangeConnection

-- Memori untuk balik ke awal
local originalCameraType = Camera and Camera.CameraType or Enum.CameraType.Custom
local originalCameraSubject = Camera and Camera.CameraSubject
local freecamCFrame = Camera and Camera.CFrame or CFrame.new()
local rotationX = 0
local rotationY = 0

-- Callback untuk UI Sinkronisasi
CameraModule.OnFOVChanged = nil

-- ==========================================
-- FUNGSI PEMBANTU (ANCHOR CHARACTER)
-- ==========================================
local function UpdateCharacterAnchor()
    local shouldAnchor = (CameraModule.FreecamEnabled or CameraModule.SpectateTarget ~= nil)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.Anchored = shouldAnchor
    end
end

-- ==========================================
-- 1. REACTIONARY LOCK SYSTEM (FOV & SPECTATE)
-- ==========================================
local function LockFOV()
    if not Camera then return end
    
    local currentCamFOV = Camera.FieldOfView
    
    if CameraModule.FOVLocked then
        -- Jika game merubah FOV pas lagi di-lock, kita rekam nilai aslinya
        if currentCamFOV ~= CameraModule.FOVValue then
            CameraModule.GameIntendedFOV = currentCamFOV
            -- Langsung timpa paksa balik ke nilai force
            Camera.FieldOfView = CameraModule.FOVValue
        end
    else
        -- Mode Observer (Mirroring ke UI)
        if currentCamFOV ~= CameraModule.FOVValue then
            CameraModule.FOVValue = currentCamFOV
            CameraModule.GameIntendedFOV = currentCamFOV
            -- Kirim sinyal ke UI buat geser slider otomatis
            if CameraModule.OnFOVChanged then
                CameraModule.OnFOVChanged(currentCamFOV)
            end
        end
    end
end

local function LockSubject()
    if not Camera then return end
    
    if CameraModule.SpectateTarget and not CameraModule.FreecamEnabled then
        local targetChar = CameraModule.SpectateTarget.Character
        if targetChar and targetChar:FindFirstChild("Humanoid") then
            -- Kalau game mindahin Subject, paksa balik ke target Spectate
            if Camera.CameraSubject ~= targetChar.Humanoid then
                Camera.CameraType = Enum.CameraType.Custom
                Camera.CameraSubject = targetChar.Humanoid
                LocalPlayer.CameraMinZoomDistance = 0
                LocalPlayer.CameraMaxZoomDistance = 30
            end
        else
            -- Target mati atau hilang, otomatis lepas spectate
            CameraModule.SetSpectate(nil)
        end
    end
end

local function ConnectCameraEvents()
    if fovConnection then fovConnection:Disconnect() end
    if subjectConnection then subjectConnection:Disconnect() end
    
    if Camera then
        -- Pasang event listener ala brute-force
        fovConnection = Camera:GetPropertyChangedSignal("FieldOfView"):Connect(LockFOV)
        subjectConnection = Camera:GetPropertyChangedSignal("CameraSubject"):Connect(LockSubject)
        
        -- Eksekusi sekali buat mastiin kondisi awal aman
        LockFOV()
        LockSubject()
    end
end

-- Pantau kalau game bikin kamera baru (Misal pas respawn)
cameraChangeConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
    ConnectCameraEvents()
end)

-- Inisialisasi koneksi pertama kali
ConnectCameraEvents()

-- ==========================================
-- 2. FREECAM ENGINE
-- ==========================================
function CameraModule.ToggleFreecam(state)
    CameraModule.FreecamEnabled = state
    UpdateCharacterAnchor()

    if state then
        originalCameraType = Camera.CameraType
        originalCameraSubject = Camera.CameraSubject
        Camera.CameraType = Enum.CameraType.Scriptable
        freecamCFrame = Camera.CFrame
        
        local rx, ry, rz = freecamCFrame:ToOrientation()
        rotationX = math.deg(rx)
        rotationY = math.deg(ry)
    else
        Camera.CameraType = originalCameraType or Enum.CameraType.Custom
        Camera.CameraSubject = originalCameraSubject or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid"))
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end

-- ==========================================
-- 3. SPECTATE ENGINE
-- ==========================================
function CameraModule.SetSpectate(playerName)
    if not playerName or playerName == "" or playerName == LocalPlayer.Name then
        CameraModule.SpectateTarget = nil
        UpdateCharacterAnchor()

        if not CameraModule.FreecamEnabled and Camera then
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            LocalPlayer.CameraMinZoomDistance = 0.5
            LocalPlayer.CameraMaxZoomDistance = 400
        end
        return true, "Stopped spectating. Returned to local character."
    end

    local targetPlayer = Players:FindFirstChild(playerName)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        CameraModule.SpectateTarget = targetPlayer
        UpdateCharacterAnchor()
        
        -- Panggil LockSubject untuk langsung mengeksekusi perpindahan kamera
        LockSubject()
        return true, "Now spectating: " .. playerName
    else
        CameraModule.SpectateTarget = nil
        UpdateCharacterAnchor()
        return false, "Player not found or has left the game."
    end
end

function CameraModule.GetPlayerList()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name ~= LocalPlayer.Name then
            table.insert(list, player.Name)
        end
    end
    return list
end

-- ==========================================
-- 4. FREECAM MOVEMENT LOOP
-- ==========================================
RunService.RenderStepped:Connect(function(deltaTime)
    if not Camera then return end

    if CameraModule.FreecamEnabled then
        Camera.CameraType = Enum.CameraType.Scriptable
        
        local moveVector = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector + Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector + Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + Vector3.new(1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveVector = moveVector + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveVector = moveVector + Vector3.new(0, -1, 0) end

        -- Mouse Rotation Logic (Hold Right Click)
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
            local mouseDelta = UserInputService:GetMouseDelta()
            rotationX = rotationX - (mouseDelta.Y * 0.5)
            rotationY = rotationY - (mouseDelta.X * 0.5)
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            -- Arrow Keys Rotation
            local rotSpeed = 120 * deltaTime 
            if UserInputService:IsKeyDown(Enum.KeyCode.Up) then rotationX = rotationX + rotSpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.Down) then rotationX = rotationX - rotSpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.Left) then rotationY = rotationY + rotSpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.Right) then rotationY = rotationY - rotSpeed end
        end

        rotationX = math.clamp(rotationX, -89, 89)
        local camRotation = CFrame.Angles(0, math.rad(rotationY), 0) * CFrame.Angles(math.rad(rotationX), 0, 0)
        
        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit * CameraModule.FreecamSpeed * deltaTime
            local relativeMove = camRotation * moveVector
            freecamCFrame = freecamCFrame + relativeMove
        end

        Camera.CFrame = CFrame.new(freecamCFrame.Position) * camRotation
    end
end)

return CameraModule
