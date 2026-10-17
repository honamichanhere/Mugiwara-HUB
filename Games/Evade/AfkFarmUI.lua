local AfkFarm = getgenv().MugiwaraImport("Games/Evade/AfkFarm.lua")
local VIPCommands = getgenv().MugiwaraImport("Games/Evade/VIPCommands.lua")

return function(TabMain, isPremiumUser, WindUI)
    if not AfkFarm or not VIPCommands then return end

    local function Notify(title, content, duration)
        WindUI:Notify({ Title = title, Content = content, Duration = duration or 3 })
    end

    local Section = TabMain:Section({
        Title = '<font color="#ffff82">AFK Farm</font>',
        Icon = "rbxassetid://74594159374416",
        Opened = false,
        Box = true
    })

    -- ==========================================
    -- AUTO FARM
    -- ==========================================
    Section:Divider({ Title = "Auto Farm" })

    Section:Toggle({
        Title = "Auto Farm",
        Desc = "Hold the AFK spot, floating with Fly.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Value = false,
        Callback = function(Value)
            AfkFarm.SetFarm(Value)
        end
    })

    local CoordinateInput
    local updatingInput = false

    CoordinateInput = Section:Input({
        Title = "AFK Coordinates",
        Desc = "Format: x, y, z. Empty = your current spot.",
        Placeholder = "x, y, z",
        Value = AfkFarm.FormatPosition(),
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Text)
            if updatingInput then return end
            local ok, result = AfkFarm.SetPositionFromText(Text)
            if ok then
                Notify("AFK Coordinates", result ~= "" and ("Saved: " .. result) or "Cleared. Your current spot will be used.", 2)
            else
                Notify("Invalid Coordinates", result, 4)
            end
        end
    })

    Section:Button({
        Title = "Use Current Position",
        Desc = "Save where you stand as the AFK spot.",
        Icon = "lucide:map-pin",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            local ok, result = AfkFarm.UseCurrentPosition()
            if not ok then
                Notify("Could Not Save", result, 3)
                return
            end

            updatingInput = true
            pcall(function() CoordinateInput:Set(result) end)
            updatingInput = false
            Notify("AFK Coordinates", "Saved: " .. result, 2)
        end
    })

    -- ==========================================
    -- AUTO EXECUTE COMMAND
    -- ==========================================
    Section:Divider({ Title = "Auto Execute Command" })

    Section:Toggle({
        Title = "Auto Execute Command",
        Desc = "Send the command when the trigger happens.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Value = false,
        Callback = function(Value)
            AfkFarm.SetAutoExec(Value)
        end
    })

    AfkFarm.OnResult = function(_, ok, message)
        Notify(ok and "Command Sent" or "Command Not Sent", tostring(message), ok and 2 or 4)
    end

    local rule = AfkFarm.GetRule(1)

    Section:Input({
        Title = "Command",
        Desc = "For example !timer 1",
        Placeholder = "!timer 1",
        Value = rule.Command,
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Text)
            AfkFarm.SetRule(1, "Command", tostring(Text or ""))
        end
    })

    Section:Button({
        Title = "Send Command",
        Desc = "Send the command above now.",
        Icon = "lucide:send",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            local ok, result = VIPCommands.RunText(AfkFarm.GetRule(1).Command)
            Notify(ok and "Command Sent" or "Command Not Sent", tostring(result), ok and 2 or 4)
        end
    })

    Section:Dropdown({
        Title = "Trigger",
        Desc = "The event that starts the command.",
        Values = AfkFarm.Triggers,
        Value = rule.Trigger,
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Option)
            if type(Option) == "string" then AfkFarm.SetRule(1, "Trigger", Option) end
        end
    })

    Section:Slider({
        Title = "Delay (seconds)",
        Desc = "Wait this long after the trigger.",
        Step = 0.5,
        Value = { Min = 0, Max = AfkFarm.MaxDelay, Default = rule.Delay },
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Value)
            AfkFarm.SetRule(1, "Delay", Value)
        end
    })
end
