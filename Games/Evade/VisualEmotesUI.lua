local VisualEmotes = getgenv().MugiwaraImport("Games/Evade/VisualEmotes.lua")

-- Antarmuka Visual Emotes (premium): pilih emote Base dan Target, lalu Swap / Revert. Logikanya ada di
-- VisualEmotes.lua. Daftar tiap dropdown mengikuti aturan Visual-Emotes: emote yang dipilih di sisi
-- lain disembunyikan, dan emote berpasangan (whitelist) hanya menampilkan pasangannya.
local UI = {}

function UI.Build(Section, isPremiumUser, MugiwaraUI)
    if not VisualEmotes then return end

    local function Notify(title, content, duration)
        MugiwaraUI:Notify({ Title = title, Content = content, Duration = duration or 3 })
    end

    if VisualEmotes.Load() == 0 then
        Section:Paragraph({
            Title = "Visual Emotes Unavailable",
            Desc = "No emotes were found in this game. The game may have changed its emote folders.",
            Icon = "lucide:triangle-alert"
        })
        return
    end

    local base, target = nil, nil -- entry yang dipilih
    local notifiedWhitelist = false
    local BaseDropdown, TargetDropdown, SwapButton

    -- Item dropdown: emote yang sedang tertukar diberi tanda dan nama pasangannya.
    local function Items(allowedName, excluded)
        local items = {}
        for _, entry in ipairs(VisualEmotes.GetEmotes()) do
            if (not allowedName or entry.Name == allowedName) and entry ~= excluded then
                local partner = VisualEmotes.GetPartner(entry)
                table.insert(items, {
                    Title = entry.Display,
                    Desc = partner and ("Swapped with " .. partner.Display) or nil,
                    Icon = partner and "lucide:repeat" or "lucide:music",
                    IconColor = partner and "Success" or nil,
                })
            end
        end
        return items
    end

    local function EntryOf(display)
        if type(display) ~= "string" then return nil end
        for _, entry in ipairs(VisualEmotes.GetEmotes()) do
            if entry.Display == display then return entry end
        end
        return nil
    end

    local function UpdateButton()
        local state = VisualEmotes.GetState(base, target)
        if state == 3 then
            SwapButton:SetTitle("Revert")
            SwapButton:SetIcon("lucide:undo-2")
            SwapButton:SetDesc("Restore these two emotes to normal.")
        else
            SwapButton:SetTitle("Swap")
            SwapButton:SetIcon("lucide:repeat")
            SwapButton:SetDesc(state == 2 and "Swap the two emotes visually." or "Pick a Base and a Target emote first. An emote that is already swapped must be reverted before it can be swapped again.")
        end
    end

    -- Dua sisi saling menyaring; pilihan yang tidak cocok lagi dilepas.
    local function Refresh()
        local targetOnly = base and VisualEmotes.GetWhitelist(base) or nil
        local baseOnly = target and VisualEmotes.GetWhitelist(target) or nil

        if target and ((targetOnly and target.Name ~= targetOnly) or target == base) then target = nil end
        if base and ((baseOnly and base.Name ~= baseOnly) or base == target) then base = nil end

        BaseDropdown:Refresh(Items(baseOnly, target), false)
        TargetDropdown:Refresh(Items(targetOnly, base), false)
        BaseDropdown:Set(base and base.Display or nil, true)
        TargetDropdown:Set(target and target.Display or nil, true)
        UpdateButton()
    end

    local function Picked(entry)
        if entry and VisualEmotes.GetWhitelist(entry) and not notifiedWhitelist then
            notifiedWhitelist = true
            Notify("Visual Emotes", "Whitelist applied! This emote is restricted to a specific pair.", 4)
        end
        if not entry then notifiedWhitelist = false end
    end

    BaseDropdown = Section:Dropdown({
        Title = "Base Emote",
        Desc = "The emote you will change.",
        Icon = "lucide:music",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Values = Items(nil, nil),
        AllowNone = true,
        Searchable = true,
        Placeholder = "Select a base emote...",
        Callback = function(Option)
            base = EntryOf(Option)
            Picked(base)
            Refresh()
        end
    })

    TargetDropdown = Section:Dropdown({
        Title = "Target Emote",
        Desc = "The emote it will look like.",
        Icon = "lucide:drama",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Values = Items(nil, nil),
        AllowNone = true,
        Searchable = true,
        Placeholder = "Select a target emote...",
        Callback = function(Option)
            target = EntryOf(Option)
            Picked(target)
            Refresh()
        end
    })

    SwapButton = Section:Button({
        Title = "Swap",
        Desc = "Pick a Base and a Target emote first. An emote that is already swapped must be reverted before it can be swapped again.",
        Icon = "lucide:repeat",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            local state = VisualEmotes.GetState(base, target)
            if state == 1 then
                Notify("Swap Unavailable", "Please make sure you picked a valid Base and Target emote.", 3)
                return
            end

            local ok, message
            if state == 2 then
                ok, message = VisualEmotes.Swap(base, target)
                Notify(ok and "Swap Successful!" or "Swap Failed", message, 3)
            else
                ok, message = VisualEmotes.Revert(base, target)
                Notify(ok and "Revert Successful!" or "Revert Failed", message, 3)
            end

            base, target, notifiedWhitelist = nil, nil, false
            Refresh()
        end
    })

    Section:Button({
        Title = "Revert All",
        Desc = "Put every swapped emote back to normal.",
        Icon = "lucide:rotate-ccw",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            local restored = VisualEmotes.RevertAll()
            Notify("Visual Emotes", restored > 0 and ("Restored " .. restored .. " swapped pair(s).") or "Nothing is swapped.", 3)
            base, target, notifiedWhitelist = nil, nil, false
            Refresh()
        end
    })
end

return UI
