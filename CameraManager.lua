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

-- Variables Stabilizer (Orbit Engine)
CameraModule.PositionStabilizer = 0
CameraModule.RotationStabilizer = 0

-- Variables Zoom
CameraModule.ZoomLocked = false
CameraModule.ZoomValue = Camera and (Camera.CFrame.Position - Camera.Focus.Position).Magnitude or 12.5
CameraModule.CurrentZoom = CameraModule.ZoomValue

-- Anti-Loop Debounce
local isModifyingFOV = false

-- Connections & Tasks
local fovConnection
local subjectConnection
local cameraChangeConnection
local streamingTask = nil

-- Memori State Awal
local originalCameraType = Camera and Camera.CameraType or Enum.CameraType.Custom
local originalCameraSubject = Camera and Camera.CameraSubject
local originalMouseBehavior = Enum.MouseBehavior.Default
local freecamCFrame = Camera and Camera.CFrame or CFrame.new()
local rotationX = 0
local rotationY = 0

-- Memori Orbit Stabilizer
local smoothFocus = nil
local smoothRot = nil
local smoothDist = 0

-- Callbacks untuk UI Sinkronisasi
CameraModule.OnFOVChanged = nil
CameraModule.OnZoomChanged = nil

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
    if not Camera or isModifyingFOV then return end
    local currentCamFOV = Camera.FieldOfView
    
    if CameraModule.FOVLocked then
        if currentCamFOV ~= CameraModule.FOVValue then
            CameraModule.GameIntendedFOV = currentCamFOV
            isModifyingFOV = true
            Camera.FieldOfView = CameraModule.FOVValue
            isModifyingFOV = false
        end
    else
        if currentCamFOV ~= CameraModule.FOVValue then
            CameraModule.FOVValue = currentCamFOV
            CameraModule.GameIntendedFOV = currentCamFOV
            if CameraModule.OnFOVChanged then
                CameraModule.OnFOVChanged(currentCamFOV)
            end
        end
    end
end

function CameraModule.SetFOV(value)
    CameraModule.FOVValue = value
    if Camera then
        if not CameraModule.FOVLocked then CameraModule.GameIntendedFOV = value end
        isModifyingFOV = true
        Camera.FieldOfView = value
        isModifyingFOV = false
    end
end

function CameraModule.RestoreFOV()
    if Camera then
        isModifyingFOV = true
        Camera.FieldOfView = CameraModule.GameIntendedFOV
        isModifyingFOV = false
    end
end

local function LockSubject()
    if not Camera then return end
    if CameraModule.SpectateTarget and not CameraModule.FreecamEnabled then
        local targetChar = CameraModule.SpectateTarget.Character
        if targetChar and targetChar:FindFirstChild("Humanoid") then
            if Camera.CameraSubject ~= targetChar.Humanoid then
                Camera.CameraType = Enum.CameraType.Custom
                Camera.CameraSubject = targetChar.Humanoid
            end
        else
            CameraModule.SetSpectate(nil)
        end
    end
end

local function ConnectCameraEvents()
    if fovConnection then fovConnection:Disconnect() end
    if subjectConnection then subjectConnection:Disconnect() end
    if Camera then
        fovConnection = Camera:GetPropertyChangedSignal("FieldOfView"):Connect(LockFOV)
        subjectConnection = Camera:GetPropertyChangedSignal("CameraSubject"):Connect(LockSubject)
        LockFOV()
        LockSubject()
    end
end

cameraChangeConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
    ConnectCameraEvents()
end)

ConnectCameraEvents()

-- ==========================================
-- 2. ZOOM CONTROLLER
-- ==========================================
function CameraModule.SetZoom(value)
    CameraModule.ZoomValue = value
    if not CameraModule.FreecamEnabled then
        LocalPlayer.CameraMinZoomDistance = value
        LocalPlayer.CameraMaxZoomDistance = value
        
        -- Restore scroll ability if not locked
        if not CameraModule.ZoomLocked then
            task.delay(0.1, function()
                if not CameraModule.ZoomLocked then
                    LocalPlayer.CameraMinZoomDistance = 0.5
                    LocalPlayer.CameraMaxZoomDistance = 400
                end
            end)
        end
    end
end

-- ==========================================
-- 3. FREECAM ENGINE (WITH STREAMING SYNC)
-- ==========================================
function CameraModule.ToggleFreecam(state)
    CameraModule.FreecamEnabled = state
    UpdateCharacterAnchor()

    if state then
        originalCameraType = Camera.CameraType
        originalCameraSubject = Camera.CameraSubject
        originalMouseBehavior = UserInputService.MouseBehavior
        
        Camera.CameraType = Enum.CameraType.Scriptable
        freecamCFrame = Camera.CFrame
        local rx, ry, rz = freecamCFrame:ToOrientation()
        rotationX = math.deg(rx)
        rotationY = math.deg(ry)

        if Workspace.StreamingEnabled then
            streamingTask = task.spawn(function()
                while CameraModule.FreecamEnabled do
                    pcall(function() LocalPlayer:RequestStreamAroundAsync(freecamCFrame.Position) end)
                    task.wait(0.5)
                end
            end)
        end
    else
        Camera.CameraType = originalCameraType or Enum.CameraType.Custom
        Camera.CameraSubject = originalCameraSubject or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid"))
        UserInputService.MouseBehavior = originalMouseBehavior
        if streamingTask then
            task.cancel(streamingTask)
            streamingTask = nil
        end
    end
end

-- ==========================================
-- 4. SPECTATE ENGINE
-- ==========================================
function CameraModule.SetSpectate(playerName)
    if not playerName or playerName == "" or playerName == LocalPlayer.Name then
        CameraModule.SpectateTarget = nil
        UpdateCharacterAnchor()
        if not CameraModule.FreecamEnabled and Camera then
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        end
        return true, "Stopped spectating. Returned to local character."
    end

    local targetPlayer = Players:FindFirstChild(playerName)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        CameraModule.SpectateTarget = targetPlayer
        UpdateCharacterAnchor()
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
        if player.Name ~= LocalPlayer.Name then table.insert(list, player.Name) end
    end
    return list
end

-- ==========================================
-- 5. THE MASTER LOOP (FREECAM, ZOOM OBSERVER & STABILIZER)
-- ==========================================
-- Prioritas paling akhir (2002) untuk menumbangkan script Evade sepenuhnya
RunService:BindToRenderStep("MugiwaraCameraMaster", Enum.RenderPriority.Last.Value + 2, function(deltaTime)
    if not Camera then return end

    -- A. FREECAM MOVEMENT
    if CameraModule.FreecamEnabled then
        Camera.CameraType = Enum.CameraType.Scriptable
        
        local moveVector = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector + Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector + Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + Vector3.new(1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveVector = moveVector + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveVector = moveVector + Vector3.new(0, -1, 0) end

        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
            local mouseDelta = UserInputService:GetMouseDelta()
            rotationX = rotationX - (mouseDelta.Y * 0.5)
            rotationY = rotationY - (mouseDelta.X * 0.5)
        else
            UserInputService.MouseBehavior = originalMouseBehavior
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
        -- Manipulasi Focus bayangan agar Stabilizer tetap bekerja mulus di Freecam
        Camera.Focus = CFrame.new(freecamCFrame.Position + (camRotation.LookVector * 10))
    end

    -- B. ZOOM OBSERVER & FORCE ENGINE
    if not CameraModule.FreecamEnabled then
        if CameraModule.ZoomLocked then
            LocalPlayer.CameraMinZoomDistance = CameraModule.ZoomValue
            LocalPlayer.CameraMaxZoomDistance = CameraModule.ZoomValue
        else
            local currentDist = (Camera.CFrame.Position - Camera.Focus.Position).Magnitude
            if CameraModule.OnZoomChanged and math.abs(CameraModule.CurrentZoom - currentDist) > 0.5 then
                CameraModule.CurrentZoom = currentDist
                CameraModule.OnZoomChanged(currentDist)
            end
        end
    end

    -- C. ORBIT STABILIZER ENGINE
    if CameraModule.PositionStabilizer == 0 and CameraModule.RotationStabilizer == 0 then
        smoothFocus = nil
        return
    end

    local targetCF = Camera.CFrame
    local targetFocus = Camera.Focus.Position

    if not smoothFocus or (smoothFocus - targetFocus).Magnitude > 100 then
        smoothFocus = targetFocus
        smoothRot = targetCF.Rotation
        smoothDist = (targetCF.Position - targetFocus).Magnitude
    end

    local targetDist = (targetCF.Position - targetFocus).Magnitude
    local targetRot = targetCF.Rotation
    
    local blendSpeed = 60
    local baseAlpha = 1 - math.exp(-blendSpeed * deltaTime)
    
    -- Konversi slider UI (0-1) menjadi faktor pengali kecepatan
    local posSpeedFactor = 1 - (CameraModule.PositionStabilizer * 0.9)
    local rotSpeedFactor = 1 - (CameraModule.RotationStabilizer * 0.9)
    
    local posAlpha = math.clamp(baseAlpha * posSpeedFactor, 0, 1)
    local rotAlpha = math.clamp(baseAlpha * rotSpeedFactor, 0, 1)

    smoothFocus = smoothFocus:Lerp(targetFocus, posAlpha)
    smoothRot = smoothRot:Lerp(targetRot, rotAlpha)
    smoothDist = smoothDist + (targetDist - smoothDist) * rotAlpha

    local newPos = smoothFocus + (smoothRot.LookVector * -smoothDist)
    Camera.CFrame = CFrame.new(newPos) * smoothRot

end)

return CameraModule
