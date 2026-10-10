local Movement = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

Movement.SpeedEnabled = false
Movement.SpeedValue = 16
Movement.OriginalSpeed = 16

Movement.TweenSpeedEnabled = false
Movement.TweenSpeedValue = 16

Movement.JumpEnabled = false
Movement.JumpValue = 50
Movement.OriginalJump = 50

Movement.InfJumpEnabled = false
Movement.InfJumpMax = 200

Movement.FlyEnabled = false
Movement.FlySpeed = 16

Movement.NoclipEnabled = false

MovementModule.AnimSpeedLocked = false
MovementModule.AnimSpeedValue = 1

local currentJumps = 0
local lastJumpTime = 0
local flyBodyVelocity = nil
local flyBodyGyro = nil

local function UpdateOriginalStats(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        Movement.OriginalSpeed = humanoid.WalkSpeed
        Movement.OriginalJump = humanoid.JumpPower
    end
end

if LocalPlayer.Character then task.spawn(UpdateOriginalStats, LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(UpdateOriginalStats)

function Movement.RestoreSpeed()
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid").WalkSpeed = Movement.OriginalSpeed
    end
end

function Movement.RestoreJump()
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid").JumpPower = Movement.OriginalJump
    end
end

function Movement.ToggleFly(state)
    Movement.FlyEnabled = state
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local hrp = char.HumanoidRootPart

    if state then
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        flyBodyVelocity.Velocity = Vector3.zero
        flyBodyVelocity.Parent = hrp

        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        flyBodyGyro.P = 9e4
        flyBodyGyro.CFrame = hrp.CFrame
        flyBodyGyro.Parent = hrp
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy() end
        if flyBodyGyro then flyBodyGyro:Destroy() end
    end
end

RunService.Heartbeat:Connect(function(deltaTime)
    local character = LocalPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not rootPart then return end

    if humanoid.FloorMaterial ~= Enum.Material.Air then
        currentJumps = 0
    end

    if Movement.SpeedEnabled then
        humanoid.WalkSpeed = Movement.SpeedValue
    end

    if Movement.TweenSpeedEnabled then
        if humanoid.MoveDirection.Magnitude > 0 then
            local extraSpeed = math.max(0, Movement.TweenSpeedValue - humanoid.WalkSpeed)
            local pushVector = humanoid.MoveDirection * extraSpeed * deltaTime
            rootPart.CFrame = rootPart.CFrame + pushVector
        end
    end

    if Movement.JumpEnabled then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Movement.JumpValue
    end
end)

RunService.RenderStepped:Connect(function()
    if Movement.FlyEnabled and flyBodyVelocity and flyBodyGyro then
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end

        if moveDir.Magnitude == 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            moveDir = LocalPlayer.Character.Humanoid.MoveDirection
        end

        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end

        flyBodyVelocity.Velocity = moveDir * Movement.FlySpeed
        flyBodyGyro.CFrame = cam.CFrame
    end
end)

RunService.Stepped:Connect(function()
    if Movement.NoclipEnabled then
        local character = LocalPlayer.Character
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if Movement.InfJumpEnabled then
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if tick() - lastJumpTime > 0.2 then
                    if Movement.InfJumpMax >= 200 or currentJumps < Movement.InfJumpMax then
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        currentJumps = currentJumps + 1
                        lastJumpTime = tick()
                    end
                end
            end
        end
    end
end)

local trackData = {}
setmetatable(trackData, {__mode = "k"})
local isModifyingAnim = false

local function HookTrack(track)
    if not trackData[track] then
        trackData[track] = { originalSpeed = track.Speed }
        
        track:GetPropertyChangedSignal("Speed"):Connect(function()
            if isModifyingAnim then return end
            
            if MovementModule.AnimSpeedLocked then
                if track.Speed ~= MovementModule.AnimSpeedValue then
                    trackData[track].originalSpeed = track.Speed 
                    isModifyingAnim = true
                    track:AdjustSpeed(MovementModule.AnimSpeedValue)
                    isModifyingAnim = false
                end
            else
                trackData[track].originalSpeed = track.Speed
            end
        end)
    end
    
    if MovementModule.AnimSpeedLocked then
        isModifyingAnim = true
        track:AdjustSpeed(MovementModule.AnimSpeedValue)
        isModifyingAnim = false
    end
end

local function SetupAnimator(character)
    if not character then return end
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    local animator = humanoid:WaitForChild("Animator", 5)
    if not animator then return end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        HookTrack(track)
    end

    animator.AnimationPlayed:Connect(function(track)
        HookTrack(track)
    end)
end

LocalPlayer.CharacterAdded:Connect(SetupAnimator)
if LocalPlayer.Character then
    task.spawn(SetupAnimator, LocalPlayer.Character)
end

function MovementModule.SetAnimSpeed(value)
    MovementModule.AnimSpeedValue = value
    if MovementModule.AnimSpeedLocked then
        isModifyingAnim = true
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator") then
            for _, track in ipairs(char.Humanoid.Animator:GetPlayingAnimationTracks()) do
                track:AdjustSpeed(value)
            end
        end
        isModifyingAnim = false
    end
end

function MovementModule.RestoreAnimSpeed()
    isModifyingAnim = true
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator") then
        for _, track in ipairs(char.Humanoid.Animator:GetPlayingAnimationTracks()) do
            if trackData[track] and trackData[track].originalSpeed then
                track:AdjustSpeed(trackData[track].originalSpeed)
            end
        end
    end
    isModifyingAnim = false
end

return Movement
