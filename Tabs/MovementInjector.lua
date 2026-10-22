local MovementModule = getgenv().MugiwaraImport("Manager/Movement.lua")
local Risk = getgenv().MugiwaraImport("Manager/Risk.lua") or { Desc = function(_, text) return text end, Warn = function() end }

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local defaultWalkSpeed = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.WalkSpeed or 16
local defaultJumpPower = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.JumpPower or 50

return function(TargetTab, isPremiumUser, WindUI)
    local MovementSection = TargetTab:Section({ Title = "Character Movement", Icon = "lucide:footprints", Opened = false, Box = true })
    
    local ToggleTweenSpeed
    local ToggleSpeed = MovementSection:Toggle({ Title = "Enable Speed Hack", Desc = Risk.Desc("SpeedHack"), Callback = function(Value) Risk.Warn(WindUI, "SpeedHack", Value); MovementModule.SpeedEnabled = Value; if not Value then MovementModule.RestoreSpeed() end; if Value and ToggleTweenSpeed then ToggleTweenSpeed:Set(false) end end })
    MovementSection:Slider({ Title = "Speed Hack Value", Step = 1, Value = { Min = 0, Max = 200, Default = defaultWalkSpeed }, Callback = function(Value) MovementModule.SpeedValue = Value end })
    
    ToggleTweenSpeed = MovementSection:Toggle({ Title = "Enable Tween Speed", Desc = Risk.Desc("TweenSpeed"), Callback = function(Value) Risk.Warn(WindUI, "TweenSpeed", Value); MovementModule.TweenSpeedEnabled = Value; if Value and ToggleSpeed then ToggleSpeed:Set(false) end end })
    MovementSection:Slider({ Title = "Tween Speed Value", Step = 1, Value = { Min = 0, Max = 200, Default = defaultWalkSpeed }, Callback = function(Value) MovementModule.TweenSpeedValue = Value end })

    MovementSection:Divider({ Title = "Jump" })
    MovementSection:Toggle({ Title = "Enable Jump Power", Desc = Risk.Desc("JumpPower"), Callback = function(Value) Risk.Warn(WindUI, "JumpPower", Value); MovementModule.JumpEnabled = Value; if not Value then MovementModule.RestoreJump() end end })
    MovementSection:Slider({ Title = "Jump Power Value", Step = 1, Value = { Min = 0, Max = 200, Default = defaultJumpPower }, Callback = function(Value) MovementModule.JumpValue = Value end })
    local ToggleInfJump = MovementSection:Toggle({ Title = "Enable Infinite Jump", Desc = Risk.Desc("InfiniteJump"), Callback = function(Value) Risk.Warn(WindUI, "InfiniteJump", Value); MovementModule.InfJumpEnabled = Value end })
    MovementSection:Slider({ Title = "Infinite Jump Cap", Step = 1, Value = { Min = 0, Max = 200, Default = 200 }, Callback = function(Value) MovementModule.InfJumpMax = Value end })

    MovementSection:Divider({ Title = "Flight" })
    local ToggleFly = MovementSection:Toggle({ Title = "Enable Fly", Desc = Risk.Desc("Fly"), Callback = function(Value) Risk.Warn(WindUI, "Fly", Value); MovementModule.ToggleFly(Value) end })
    MovementSection:Slider({ Title = "Fly Speed", Step = 1, Value = { Min = 0, Max = 500, Default = 16 }, Callback = function(Value) MovementModule.FlySpeed = Value end })

    MovementSection:Divider({ Title = "Collision" })
    local ToggleNoclip = MovementSection:Toggle({ Title = "Enable Noclip", Desc = Risk.Desc("Noclip"), Callback = function(Value) Risk.Warn(WindUI, "Noclip", Value); MovementModule.NoclipEnabled = Value end })

    MovementSection:Divider({ Title = "Animation Controls" })
    MovementSection:Input({ Title = "Animation Speed", Desc = "Speed multiplier for all your playing animations, kept on every frame. Enter 1 to reset, 0 to freeze.", Placeholder = "Number", Callback = function(Text) local num = tonumber(Text) if num then MovementModule.SetAnimSpeed(num) end end })

    -- Referensi toggle dipakai shortcut keyboard (tab Misc) supaya tombol UI ikut berubah.
    MovementModule.UI = { Speed = ToggleSpeed, InfJump = ToggleInfJump, Fly = ToggleFly, Noclip = ToggleNoclip }
end
