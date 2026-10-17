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
    -- AUTO EXECUTE EVENTS
    -- ==========================================
    Section:Divider({ Title = "Auto Execute" })

    Section:Toggle({
        Title = "Auto Execute",
        Desc = "Send each event's command when its trigger happens.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Value = false,
        Callback = function(Value)
            AfkFarm.SetAutoExec(Value)
        end
    })

    AfkFarm.OnResult = function(rule, ok, message)
        Notify(
            "Event #" .. rule.Id .. (ok and ": Sent" or ": Not Sent"),
            tostring(message),
            ok and 2 or 4
        )
    end

    -- Tiap event punya UI sendiri. Elemen yang dibuat ditampung supaya bisa dihapus bersamaan.
    local eventCount = 0

    local function BuildEvent(rule)
        local elements = {}
        local label = "Event #" .. rule.Id

        local function Track(element)
            table.insert(elements, element)
            return element
        end

        Track(Section:Divider({ Title = label }))

        Track(Section:Input({
            Title = label .. ": Command",
            Desc = "For example !timer 1",
            Placeholder = "!timer 1",
            Value = rule.Command,
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Callback = function(Text)
                AfkFarm.UpdateRule(rule, "Command", tostring(Text or ""))
            end
        }))

        Track(Section:Button({
            Title = "Send Command",
            Desc = "Send the command above now.",
            Icon = "lucide:send",
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Callback = function()
                local ok, result = VIPCommands.RunText(rule.Command)
                Notify(ok and "Command Sent" or "Command Not Sent", tostring(result), ok and 2 or 4)
            end
        }))

        Track(Section:Dropdown({
            Title = label .. ": Trigger",
            Desc = "The event that starts the command.",
            Values = AfkFarm.Triggers,
            Value = rule.Trigger,
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Callback = function(Option)
                if type(Option) == "string" then AfkFarm.UpdateRule(rule, "Trigger", Option) end
            end
        }))

        Track(Section:Slider({
            Title = label .. ": Delay (seconds)",
            Desc = "Wait this long after the trigger.",
            Step = 0.5,
            Value = { Min = 0, Max = AfkFarm.MaxDelay, Default = rule.Delay },
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Callback = function(Value)
                AfkFarm.UpdateRule(rule, "Delay", Value)
            end
        }))

        Track(Section:Button({
            Title = "Delete " .. label,
            Desc = "Remove this event.",
            Icon = "lucide:trash-2",
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Callback = function()
                AfkFarm.RemoveRule(rule)
                eventCount = eventCount - 1

                -- Dihapus dari yang terakhir ke yang pertama supaya urutan internal WindUI tetap benar.
                for index = #elements, 1, -1 do
                    local element = elements[index]
                    local ok = element.Destroy and pcall(function() element:Destroy() end)
                    if not ok and element.ElementFrame then pcall(function() element.ElementFrame:Destroy() end) end
                end
                table.clear(elements)
            end
        }))
    end

    Section:Button({
        Title = "Create New Event",
        Desc = "Add another Command, Trigger and Delay. Up to " .. AfkFarm.MaxRules .. ".",
        Icon = "lucide:plus",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            local rule, reason = AfkFarm.AddRule()
            if not rule then
                Notify("Cannot Add Event", tostring(reason), 3)
                return
            end

            eventCount = eventCount + 1
            BuildEvent(rule)
            Notify("Event Created", "Event #" .. rule.Id .. " was added at the bottom of this section.", 3)
        end
    })

    for _, rule in ipairs(AfkFarm.GetRules()) do
        eventCount = eventCount + 1
        BuildEvent(rule)
    end
end
