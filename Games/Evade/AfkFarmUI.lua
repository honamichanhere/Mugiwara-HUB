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

    Section:Paragraph({
        Title = "AFK Farm",
        Desc = "Farms tokens, points and XP while you are away. Auto Farm parks you at an AFK spot using Fly, and Auto Execute runs VIP commands (for example Timer to skip the intermission) when something happens in the game. Needs VIP command access, so it only works in a server you own (Community or Private). Commands that disable rewards are blocked automatically."
    })

    -- ==========================================
    -- AUTO FARM
    -- ==========================================
    Section:Divider({ Title = "Auto Farm" })

    Section:Toggle({
        Title = "Auto Farm",
        Desc = "Keeps you at the AFK coordinates below, floating with Fly. If no coordinates are saved, it holds the spot where you turned it on. Do not use it together with Auto Farm Tickets.",
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
        Desc = "Format: x, y, z (for example 0, 500, 0). Leave empty to hold your current spot.",
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
        Desc = "Save where you are standing right now as the AFK spot.",
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
    -- AUTO EXECUTE COMMANDS
    -- ==========================================
    Section:Divider({ Title = "Auto Execute Commands" })

    Section:Toggle({
        Title = "Auto Execute Commands",
        Desc = "Runs the rules below. Each rule: when the trigger happens, wait the delay, then send the command.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Value = false,
        Callback = function(Value)
            AfkFarm.SetAutoExec(Value)
        end
    })

    AfkFarm.OnResult = function(index, ok, message)
        Notify(
            ok and ("Rule " .. index .. ": Sent") or ("Rule " .. index .. ": Not Sent"),
            tostring(message),
            ok and 2 or 4
        )
    end

    for index = 1, AfkFarm.RuleCount do
        local rule = AfkFarm.GetRule(index)

        Section:Divider({ Title = "Rule " .. index })

        Section:Input({
            Title = "Command",
            Desc = "What to send, for example !timer 1",
            Placeholder = "!timer 1",
            Value = rule.Command,
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Callback = function(Text)
                AfkFarm.SetRule(index, "Command", tostring(Text or ""))
            end
        })

        Section:Dropdown({
            Title = "Trigger",
            Desc = "The event that starts this rule.",
            Values = AfkFarm.Triggers,
            Value = rule.Trigger,
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Callback = function(Option)
                if type(Option) == "string" then AfkFarm.SetRule(index, "Trigger", Option) end
            end
        })

        Section:Slider({
            Title = "Delay (seconds)",
            Desc = "How long to wait after the trigger before sending.",
            Step = 0.5,
            Value = { Min = 0, Max = AfkFarm.MaxDelay, Default = rule.Delay },
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Callback = function(Value)
                AfkFarm.SetRule(index, "Delay", Value)
            end
        })
    end

    -- ==========================================
    -- TOOLS
    -- ==========================================
    Section:Divider({ Title = "Tools" })

    Section:Toggle({
        Title = "Allow Reward-Disabling Commands",
        Desc = "Off by default. Commands marked as disabling rewards (God, Speed, Tool, and others) drop this server's reward multiplier to 0.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Value = false,
        Callback = function(Value)
            VIPCommands.AllowRewardDisabling = Value
        end
    })

    local consoleText = ""

    Section:Input({
        Title = "VIP Command Console",
        Desc = "Type a command the way you would in chat, then press Send Command.",
        Placeholder = "!timer 1",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Text)
            consoleText = tostring(Text or "")
        end
    })

    Section:Button({
        Title = "Send Command",
        Desc = "Sends the command above through the VIP menu channel.",
        Icon = "lucide:send",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            local ok, result = VIPCommands.RunText(consoleText)
            Notify(ok and "Command Sent" or "Command Not Sent", tostring(result), ok and 2 or 4)
        end
    })
end
