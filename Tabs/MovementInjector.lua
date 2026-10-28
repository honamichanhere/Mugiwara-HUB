local MovementModule = getgenv().MugiwaraImport("Manager/Movement.lua")
local Risk = getgenv().MugiwaraImport("Manager/Risk.lua") or { Desc = function(_, text) return text end, Warn = function() end }

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local defaultWalkSpeed = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.WalkSpeed or 16
local defaultJumpPower = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.JumpPower or 50

return function(TargetTab, isPremiumUser, MugiwaraUI)
    local MovementSection = TargetTab:Section({ Title = "Character Movement", Icon = "lucide:footprints", Opened = false, Box = true })
    
    local ToggleTweenSpeed
    local ToggleSpeed = MovementSection:Toggle({ Title = "Enable Speed Hack", Icon = "lucide:zap", Desc = Risk.Desc("SpeedHack"), Callback = function(Value) Risk.Warn(MugiwaraUI, "SpeedHack", Value); MovementModule.SpeedEnabled = Value; if not Value then MovementModule.RestoreSpeed() end; if Value and ToggleTweenSpeed then ToggleTweenSpeed:Set(false) end end })
    MovementSection:Slider({ Title = "Speed Hack Value", Icon = "lucide:gauge", Step = 1, Value = { Min = 0, Max = 200, Default = defaultWalkSpeed }, Callback = function(Value) MovementModule.SpeedValue = Value end })
    
    ToggleTweenSpeed = MovementSection:Toggle({ Title = "Enable Tween Speed", Icon = "lucide:route", Desc = Risk.Desc("TweenSpeed"), Callback = function(Value) Risk.Warn(MugiwaraUI, "TweenSpeed", Value); MovementModule.TweenSpeedEnabled = Value; if Value and ToggleSpeed then ToggleSpeed:Set(false) end end })
    MovementSection:Slider({ Title = "Tween Speed Value", Icon = "lucide:gauge", Step = 1, Value = { Min = 0, Max = 200, Default = defaultWalkSpeed }, Callback = function(Value) MovementModule.TweenSpeedValue = Value end })

    MovementSection:Divider({ Title = "Jump" })
    MovementSection:Toggle({ Title = "Enable Jump Power", Icon = "lucide:arrow-up", Desc = Risk.Desc("JumpPower"), Callback = function(Value) Risk.Warn(MugiwaraUI, "JumpPower", Value); MovementModule.JumpEnabled = Value; if not Value then MovementModule.RestoreJump() end end })
    MovementSection:Slider({ Title = "Jump Power Value", Icon = "lucide:move-up", Step = 1, Value = { Min = 0, Max = 200, Default = defaultJumpPower }, Callback = function(Value) MovementModule.JumpValue = Value end })
    local ToggleInfJump = MovementSection:Toggle({ Title = "Enable Infinite Jump", Icon = "lucide:chevrons-up", Desc = Risk.Desc("InfiniteJump"), Callback = function(Value) Risk.Warn(MugiwaraUI, "InfiniteJump", Value); MovementModule.InfJumpEnabled = Value end })
    MovementSection:Slider({ Title = "Infinite Jump Cap", Icon = "lucide:ruler", Step = 1, Value = { Min = 0, Max = 200, Default = 200 }, Callback = function(Value) MovementModule.InfJumpMax = Value end })

    MovementSection:Divider({ Title = "Flight" })
    local ToggleFly = MovementSection:Toggle({ Title = "Enable Fly", Icon = "lucide:plane", Desc = Risk.Desc("Fly"), Callback = function(Value) Risk.Warn(MugiwaraUI, "Fly", Value); MovementModule.ToggleFly(Value) end })
    MovementSection:Slider({ Title = "Fly Speed", Icon = "lucide:gauge", Step = 1, Value = { Min = 0, Max = 500, Default = 16 }, Callback = function(Value) MovementModule.FlySpeed = Value end })

    MovementSection:Divider({ Title = "Collision" })
    local ToggleNoclip = MovementSection:Toggle({ Title = "Enable Noclip", Icon = "lucide:ghost", Desc = Risk.Desc("Noclip"), Callback = function(Value) Risk.Warn(MugiwaraUI, "Noclip", Value); MovementModule.NoclipEnabled = Value end })

    MovementSection:Divider({ Title = "Animation Controls" })
    MovementSection:Input({ Title = "Animation Speed", Icon = "lucide:timer", Desc = "Speed multiplier for all your playing animations, kept on every frame. Enter 1 to reset, 0 to freeze.", Placeholder = "Number", Callback = function(Text) local num = tonumber(Text) if num then MovementModule.SetAnimSpeed(num) end end })

    -- Referensi toggle dipakai shortcut keyboard (tab Misc) supaya tombol UI ikut berubah.
    MovementModule.UI = { Speed = ToggleSpeed, InfJump = ToggleInfJump, Fly = ToggleFly, Noclip = ToggleNoclip }
end
