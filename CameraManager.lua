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
CameraModule.FOVValue = Camera.FieldOfView
CameraModule.OriginalFOV = Camera.FieldOfView
CameraModule.SpectateTarget = nil

-- Memori untuk balik ke awal
local originalCameraType = Camera.CameraType
local originalCameraSubject = Camera.CameraSubject
local freecamCFrame = Camera.CFrame
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
-- 1. FOV OBSERVER ENGINE
-- ==========================================
Camera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
    if not CameraModule.FOVLocked then
        -- Jika tidak di-lock, ikuti FOV game dan update UI
        CameraModule.FOVValue = Camera.FieldOfView
        CameraModule.OriginalFOV = Camera.FieldOfView
        if CameraModule.OnFOVChanged then
            CameraModule.OnFOVChanged(CameraModule.FOVValue)
        end
    end
end)

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

        if not CameraModule.FreecamEnabled then
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

        if not CameraModule.FreecamEnabled then
            Camera.CameraSubject = targetPlayer.Character.Humanoid
            LocalPlayer.CameraMinZoomDistance = 0
            LocalPlayer.CameraMaxZoomDistance = 30
        end
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
-- 4. THE MASTER LOOP (RENDER STEPPED)
-- ==========================================
RunService.RenderStepped:Connect(function(deltaTime)
    Camera = workspace.CurrentCamera

    -- A. FORCE FOV LOCK
    if CameraModule.FOVLocked then
        Camera.FieldOfView = CameraModule.FOVValue
    end

    -- B. FREECAM MOVEMENT & ROTATION
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
            rotationX = rotationX - (mouseDelta.Y * 0.5) -- Sensitivitas vertikal
            rotationY = rotationY - (mouseDelta.X * 0.5) -- Sensitivitas horizontal
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            
            -- Arrow Keys Rotation (Sebagai alternatif mouse)
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
    else
        -- C. SPECTATE FAIL-SAFE
        if CameraModule.SpectateTarget then
            if not CameraModule.SpectateTarget.Parent or not CameraModule.SpectateTarget.Character or not CameraModule.SpectateTarget.Character:FindFirstChild("Humanoid") then
                CameraModule.SetSpectate(nil)
            end
        end
    end
end)

return CameraModule
