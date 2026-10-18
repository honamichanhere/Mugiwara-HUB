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

local currentJumps = 0
local lastJumpTime = 0
local flyBodyVelocity = nil
local flyBodyGyro = nil

local connections = {}

local function UpdateOriginalStats(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        Movement.OriginalSpeed = humanoid.WalkSpeed
        Movement.OriginalJump = humanoid.JumpPower
    end
end

if LocalPlayer.Character then task.spawn(UpdateOriginalStats, LocalPlayer.Character) end

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

local function DestroyFlyObjects()
    if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
    if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
end

function Movement.ToggleFly(state)
    Movement.FlyEnabled = state
    -- Always remove old objects first so toggling ON repeatedly never stacks BodyVelocity.
    DestroyFlyObjects()
    if not state then return end

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local hrp = char.HumanoidRootPart

    do
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        flyBodyVelocity.Velocity = Vector3.zero
        flyBodyVelocity.Parent = hrp

        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        flyBodyGyro.P = 9e4
        flyBodyGyro.CFrame = hrp.CFrame
        flyBodyGyro.Parent = hrp
    end
end

-- Respawn: fly objects die with the old character; recreate them if Fly is still ON.
table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(character)
    UpdateOriginalStats(character)
    flyBodyVelocity, flyBodyGyro = nil, nil
    if Movement.FlyEnabled then
        character:WaitForChild("HumanoidRootPart", 5)
        Movement.ToggleFly(true)
    end
end))

table.insert(connections, RunService.Heartbeat:Connect(function(deltaTime)
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
end))

table.insert(connections, RunService.RenderStepped:Connect(function()
    if Movement.FlyEnabled and flyBodyVelocity and flyBodyGyro then
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.zero

        -- Ignore key input while the user is typing in chat or a textbox.
        if not UserInputService:GetFocusedTextBox() then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        end

        if moveDir.Magnitude == 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            moveDir = LocalPlayer.Character.Humanoid.MoveDirection
        end

        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end

        flyBodyVelocity.Velocity = moveDir * Movement.FlySpeed
        flyBodyGyro.CFrame = cam.CFrame
    end
end))

table.insert(connections, RunService.Stepped:Connect(function()
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
end))

table.insert(connections, UserInputService.JumpRequest:Connect(function()
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
end))

-- Full teardown on re-execute: stop every loop, release fly, restore speed/jump.
getgenv().MugiwaraRegisterCleanup(function()
    for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    table.clear(connections)
    Movement.FlyEnabled = false
    DestroyFlyObjects()
    if Movement.SpeedEnabled then Movement.RestoreSpeed() end
    if Movement.JumpEnabled then Movement.RestoreJump() end
    Movement.SpeedEnabled, Movement.TweenSpeedEnabled = false, false
    Movement.JumpEnabled, Movement.InfJumpEnabled, Movement.NoclipEnabled = false, false, false
end)

function Movement.SetAnimSpeed(value)
    pcall(function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            local animator = char.Humanoid:FindFirstChild("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    track:AdjustSpeed(value)
                end
            end
        end
    end)
end

return Movement
