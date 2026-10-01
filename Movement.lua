local Movement = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Variabel Data
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

-- Fungsi Update Data Asli Karakter
local function UpdateOriginalStats(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        Movement.OriginalSpeed = humanoid.WalkSpeed
        Movement.OriginalJump = humanoid.JumpPower
    end
end

if LocalPlayer.Character then task.spawn(UpdateOriginalStats, LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(UpdateOriginalStats)

-- Fungsi Restore (Reset)
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

-- Fungsi Mesin Terbang
function Movement.ToggleFly(state)
    Movement.FlyEnabled = state
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local hrp = char.HumanoidRootPart

    if state then
        -- Pasang jet pendorong
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        flyBodyVelocity.Velocity = Vector3.zero
        flyBodyVelocity.Parent = hrp

        -- Pasang setir biar karakter madep kamera
        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        flyBodyGyro.P = 9e4
        flyBodyGyro.CFrame = hrp.CFrame
        flyBodyGyro.Parent = hrp
    else
        -- Cabut mesin kalau dimatiin
        if flyBodyVelocity then flyBodyVelocity:Destroy() end
        if flyBodyGyro then flyBodyGyro:Destroy() end
    end
end

-- ==========================================
-- LOOPING UTAMA (Berjalan tiap frame)
-- ==========================================

-- 1. Heartbeat (Untuk Speed & Jump)
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

-- 2. RenderStepped (Khusus buat Fly biar pergerakan kamera halus)
RunService.RenderStepped:Connect(function()
    if Movement.FlyEnabled and flyBodyVelocity and flyBodyGyro then
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.zero

        -- Deteksi tombol navigasi PC
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
        -- Naik/Turun pakai Space & Ctrl
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end

        -- Kalo user main di Mobile (Pake Analog Joystick), kita narik data dari MoveDirection
        if moveDir.Magnitude == 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            moveDir = LocalPlayer.Character.Humanoid.MoveDirection
        end

        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end

        -- Tembak kecepatannya
        flyBodyVelocity.Velocity = moveDir * Movement.FlySpeed
        flyBodyGyro.CFrame = cam.CFrame
    end
end)

-- 3. Stepped (Khusus buat Noclip biar menipu mesin fisika)
RunService.Stepped:Connect(function()
    if Movement.NoclipEnabled then
        local character = LocalPlayer.Character
        if character then
            for _, part in pairs(character:GetDescendants()) do
                -- Matikan tabrakan tepat sebelum engine menghitung fisika
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- Infinite Jump Anti-Spam
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

return Movement
