local AfkFarm = getgenv().MugiwaraImport("Games/Evade/AfkFarm.lua")
local VIPCommands = getgenv().MugiwaraImport("Games/Evade/VIPCommands.lua")
local Risk = getgenv().MugiwaraImport("Manager/Risk.lua") or { Desc = function(_, text) return text end, Warn = function() end }

-- Dua bagian UI, dipanggil terpisah oleh Init.lua supaya urutan section bisa diatur di sana:
--   BuildFarm(Section, ...)    : AFK Farm (premium), ditaruh di dalam section Premium Features
--   BuildCommands(TabMain, ...) : section "Auto Commands" (gratis), event Command > Trigger > Delay
local UI = {}

local function MakeNotify(MugiwaraUI)
    return function(title, content, duration)
        MugiwaraUI:Notify({ Title = title, Content = content, Duration = duration or 3 })
    end
end

-- ==========================================
-- AFK FARM (premium)
-- ==========================================
function UI.BuildFarm(Section, isPremiumUser, MugiwaraUI)
    if not AfkFarm then return end
    local Notify = MakeNotify(MugiwaraUI)

    Section:Toggle({
        Title = "AFK Farm",
        Icon = "lucide:moon",
        Desc = Risk.Desc("AfkFarm", "Hold the AFK spot, floating with Fly."),
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Value = false,
        Callback = function(Value)
            Risk.Warn(MugiwaraUI, "AfkFarm", Value)
            AfkFarm.SetFarm(Value)
        end
    })

    local CoordinateInput
    local updatingInput = false

    CoordinateInput = Section:Input({
        Title = "AFK Coordinates",
        Icon = "lucide:map",
        Desc = "Format: x, y, z. Empty = your current spot.",
        Placeholder = "x, y, z",
        Value = AfkFarm.FormatPosition(),
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Text)
            if updatingInput then return end
            -- Library lama (WindUI) memanggil callback saat elemen dibuat dengan nilai awalnya; tanpa
            -- perubahan nilai tidak ada yang perlu disimpan atau diberi notifikasi.
            if Text == AfkFarm.FormatPosition() then return end
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
end

-- ==========================================
-- AUTO COMMANDS (gratis)
-- ==========================================
function UI.BuildCommands(TabMain, isPremiumUser, MugiwaraUI)
    if not AfkFarm or not VIPCommands then return end
    local Notify = MakeNotify(MugiwaraUI)

    local Section = TabMain:Section({
        Title = "Auto Commands",
        Icon = "lucide:terminal",
        Opened = false,
        Box = true
    })

    Section:Paragraph({
        Title = "Requires VIP access",
        Desc = "This feature only works if you have access to VIP Commands, or if you own the Private Server / Community. Without that access the game rejects the commands and nothing happens.",
        Icon = "lucide:shield-alert"
    })

    Section:Toggle({
        Title = "Auto Execute",
        Icon = "lucide:play",
        Desc = Risk.Desc("AutoCommands", "Send each event's command when its trigger happens."),
        Value = false,
        Callback = function(Value)
            Risk.Warn(MugiwaraUI, "AutoCommands", Value)
            AfkFarm.SetAutoExec(Value)
        end
    })

    -- Event diberi nomor menurut urutannya sekarang (1, 2, 3...). Saat ada yang dihapus,
    -- judul sisanya diberi nomor ulang, jadi event baru setelah semuanya dihapus mulai dari #1.
    local events = {} -- { Rule = rule, Elements = {...}, Titled = { Command, Trigger, Delay, Delete } }

    local function PositionOf(rule)
        for index, event in ipairs(events) do
            if event.Rule == rule then return index end
        end
        return nil
    end

    local function SetTitle(element, title)
        if element and element.SetTitle then pcall(function() element:SetTitle(title) end) end
    end

    local function RefreshLabels()
        for index, event in ipairs(events) do
            local label = "Event #" .. index
            SetTitle(event.Titled.Command, label .. ": Command")
            SetTitle(event.Titled.Trigger, label .. ": Trigger")
            SetTitle(event.Titled.Delay, label .. ": Delay (seconds)")
            SetTitle(event.Titled.Delete, "Delete " .. label)
        end
    end

    AfkFarm.OnResult = function(rule, ok, message)
        local position = PositionOf(rule)
        Notify(
            "Event #" .. tostring(position or "?") .. (ok and ": Sent" or ": Not Sent"),
            tostring(message),
            ok and 2 or 4
        )
    end

    local function BuildEvent(rule)
        local event = { Rule = rule, Elements = {}, Titled = {} }
        table.insert(events, event)

        local label = "Event #" .. #events

        local function Track(element)
            table.insert(event.Elements, element)
            return element
        end

        Track(Section:Divider({ Title = label }))

        event.Titled.Command = Track(Section:Input({
            Title = label .. ": Command",
            Icon = "lucide:terminal",
            Desc = "For example !timer 1",
            Placeholder = "!timer 1",
            Value = rule.Command,
            Callback = function(Text)
                AfkFarm.UpdateRule(rule, "Command", tostring(Text or ""))
            end
        }))

        Track(Section:Button({
            Title = "Send Command",
            Desc = "Send the command above now.",
            Icon = "lucide:send",
            Callback = function()
                local ok, result = VIPCommands.RunText(rule.Command)
                Notify(ok and "Command Sent" or "Command Not Sent", tostring(result), ok and 2 or 4)
            end
        }))

        event.Titled.Trigger = Track(Section:Dropdown({
            Title = label .. ": Trigger",
            Icon = "lucide:zap",
            Desc = "The event that starts the command.",
            Values = AfkFarm.Triggers,
            Value = rule.Trigger,
            Callback = function(Option)
                if type(Option) == "string" then AfkFarm.UpdateRule(rule, "Trigger", Option) end
            end
        }))

        event.Titled.Delay = Track(Section:Slider({
            Title = label .. ": Delay (seconds)",
            Icon = "lucide:timer",
            Desc = "Wait this long after the trigger.",
            Step = 0.5,
            Value = { Min = 0, Max = AfkFarm.MaxDelay, Default = rule.Delay },
            Callback = function(Value)
                AfkFarm.UpdateRule(rule, "Delay", Value)
            end
        }))

        event.Titled.Delete = Track(Section:Button({
            Title = "Delete " .. label,
            Desc = "Remove this event.",
            Icon = "lucide:trash-2",
            Callback = function()
                AfkFarm.RemoveRule(rule)

                local position = PositionOf(rule)
                if position then table.remove(events, position) end

                -- Dihapus dari yang terakhir ke yang pertama supaya urutan internal library tetap benar.
                for index = #event.Elements, 1, -1 do
                    local element = event.Elements[index]
                    local ok = element.Destroy and pcall(function() element:Destroy() end)
                    if not ok and element.ElementFrame then pcall(function() element.ElementFrame:Destroy() end) end
                end
                table.clear(event.Elements)

                RefreshLabels()
            end
        }))

        return label
    end

    Section:Button({
        Title = "Create New Event",
        Desc = "Add another Command, Trigger and Delay. Up to " .. AfkFarm.MaxRules .. ".",
        Icon = "lucide:plus",
        Callback = function()
            local rule, reason = AfkFarm.AddRule()
            if not rule then
                Notify("Cannot Add Event", tostring(reason), 3)
                return
            end

            local label = BuildEvent(rule)
            Notify("Event Created", label .. " was added at the bottom of this section.", 3)
        end
    })

    for _, rule in ipairs(AfkFarm.GetRules()) do
        BuildEvent(rule)
    end
end

return UI
