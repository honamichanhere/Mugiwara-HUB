local MovementModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/Movement.lua"))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local defaultWalkSpeed = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.WalkSpeed or 16
local defaultJumpPower = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.JumpPower or 50

return function(TargetTab, isPremiumUser, WindUI)
    local MovementSection = TargetTab:Section({ Title = "Character Movements", Icon = "lucide:footprints", Opened = false, Box = true })
    
    local ToggleTweenSpeed
    local ToggleSpeed = MovementSection:Toggle({ Title = "Enable Speed Hack", Callback = function(Value) MovementModule.SpeedEnabled = Value; if not Value then MovementModule.RestoreSpeed() end; if Value and ToggleTweenSpeed then ToggleTweenSpeed:Set(false) end end })
    MovementSection:Slider({ Title = "Speed Hack Value", Step = 1, Value = { Min = 0, Max = 200, Default = defaultWalkSpeed }, Callback = function(Value) MovementModule.SpeedValue = Value end })
    
    ToggleTweenSpeed = MovementSection:Toggle({ Title = "Enable Tween Speed", Callback = function(Value) MovementModule.TweenSpeedEnabled = Value; if Value and ToggleSpeed then ToggleSpeed:Set(false) end end })
    MovementSection:Slider({ Title = "Tween Speed Value", Step = 1, Value = { Min = 0, Max = 200, Default = defaultWalkSpeed }, Callback = function(Value) MovementModule.TweenSpeedValue = Value end })

    MovementSection:Divider({ Title = "Jump" })
    MovementSection:Toggle({ Title = "Enable Jump Power", Callback = function(Value) MovementModule.JumpEnabled = Value; if not Value then MovementModule.RestoreJump() end end })
    MovementSection:Slider({ Title = "Jump Power Value", Step = 1, Value = { Min = 0, Max = 200, Default = defaultJumpPower }, Callback = function(Value) MovementModule.JumpValue = Value end })
    MovementSection:Toggle({ Title = "Enable Infinite Jump", Callback = function(Value) MovementModule.InfJumpEnabled = Value end })
    MovementSection:Slider({ Title = "Infinite Jump Cap", Step = 1, Value = { Min = 0, Max = 200, Default = 200 }, Callback = function(Value) MovementModule.InfJumpMax = Value end })

    MovementSection:Divider({ Title = "Flight" })
    MovementSection:Toggle({ Title = "Enable Fly", Callback = function(Value) MovementModule.ToggleFly(Value) end })
    MovementSection:Slider({ Title = "Fly Speed", Step = 1, Value = { Min = 0, Max = 500, Default = 16 }, Callback = function(Value) MovementModule.FlySpeed = Value end })

    MovementSection:Divider({ Title = "Collision" })
    MovementSection:Toggle({ Title = "Enable Noclip", Callback = function(Value) MovementModule.NoclipEnabled = Value end })
end
