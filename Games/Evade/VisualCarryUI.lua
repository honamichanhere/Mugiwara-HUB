local VisualCarry = getgenv().MugiwaraImport("Games/Evade/VisualCarry.lua")

-- Antarmuka Visual Carry (gratis): pilih carry Base dan Target, lalu Swap / Revert. Logikanya ada di
-- VisualCarry.lua (sama dengan Visual Emotes). Carry yang dipilih di satu sisi disembunyikan dari sisi
-- lain, dan carry yang sedang tertukar ditandai dengan nama pasangannya.
local UI = {}

function UI.Build(Section, MugiwaraUI)
    if not VisualCarry then return end

    local function Notify(title, content, duration)
        MugiwaraUI:Notify({ Title = title, Content = content, Duration = duration or 3 })
    end

    if VisualCarry.Load() == 0 then
        Section:Paragraph({
            Title = "Visual Carry Unavailable",
            Desc = "No carry animations were found in this game. The game may have changed its item folders.",
            Icon = "lucide:triangle-alert"
        })
        return
    end

    local entries = VisualCarry.GetEntries()
    local base, target = nil, nil -- entry yang dipilih
    local BaseDropdown, TargetDropdown, SwapButton
    local Refresh

    local function TitleOf(entry)
        local partner = VisualCarry.GetPartner(entry)
        return partner and (entry.Display .. " (" .. partner.Display .. ")") or entry.Display
    end

    -- Item dropdown: nama, kelompok di menu game, dan pasangan kalau sedang tertukar.
    local function Items(excluded)
        local items, lookup = {}, {}
        for _, entry in ipairs(entries) do
            if entry ~= excluded then
                local partner = VisualCarry.GetPartner(entry)
                local title = TitleOf(entry)
                lookup[title] = entry
                table.insert(items, {
                    Title = title,
                    Desc = partner and ("Swapped with " .. partner.Display) or entry.Header,
                    Icon = partner and "lucide:repeat" or "lucide:hand-helping",
                    IconColor = partner and "Success" or nil,
                })
            end
        end
        return items, lookup
    end

    local baseLookup, targetLookup = {}, {}

    local function UpdateButton()
        local state = VisualCarry.GetState(base, target)
        if state == 3 then
            SwapButton:SetTitle("Revert")
            SwapButton:SetIcon("lucide:undo-2")
            SwapButton:SetDesc("Restore these two carries to normal.")
        else
            SwapButton:SetTitle("Swap")
            SwapButton:SetIcon("lucide:repeat")
            SwapButton:SetDesc(state == 2 and "Swap the two carries visually." or "Pick a Base and a Target carry first. A carry that is already swapped must be reverted before it can be swapped again.")
        end
    end

    -- Dua sisi saling menyaring; pilihan yang tidak cocok lagi dilepas.
    Refresh = function()
        if target and target == base then target = nil end

        local baseItems, targetItems
        baseItems, baseLookup = Items(target)
        targetItems, targetLookup = Items(base)
        BaseDropdown:Refresh(baseItems, false)
        TargetDropdown:Refresh(targetItems, false)
        BaseDropdown:Set(base and TitleOf(base) or nil, true)
        TargetDropdown:Set(target and TitleOf(target) or nil, true)
        UpdateButton()
    end

    BaseDropdown = Section:Dropdown({
        Title = "Base Carry",
        Desc = "The carry you will change.",
        Icon = "lucide:hand-helping",
        Values = {},
        AllowNone = true,
        Searchable = true,
        Placeholder = "Select a base carry...",
        Callback = function(Option)
            base = type(Option) == "string" and baseLookup[Option] or nil
            Refresh()
        end
    })

    TargetDropdown = Section:Dropdown({
        Title = "Target Carry",
        Desc = "The carry it will look like.",
        Icon = "lucide:users",
        Values = {},
        AllowNone = true,
        Searchable = true,
        Placeholder = "Select a target carry...",
        Callback = function(Option)
            target = type(Option) == "string" and targetLookup[Option] or nil
            Refresh()
        end
    })

    SwapButton = Section:Button({
        Title = "Swap",
        Desc = "Pick a Base and a Target carry first. A carry that is already swapped must be reverted before it can be swapped again.",
        Icon = "lucide:repeat",
        Callback = function()
            local state = VisualCarry.GetState(base, target)
            if state == 1 then
                Notify("Swap Unavailable", "Please make sure you picked a valid Base and Target carry.", 3)
                return
            end

            local ok, message
            if state == 2 then
                ok, message = VisualCarry.Swap(base, target)
                Notify(ok and "Swap Successful!" or "Swap Failed", message, 3)
            else
                ok, message = VisualCarry.Revert(base, target)
                Notify(ok and "Revert Successful!" or "Revert Failed", message, 3)
            end

            base, target = nil, nil
            Refresh()
        end
    })

    Section:Button({
        Title = "Revert All",
        Desc = "Put every swapped carry back to normal.",
        Icon = "lucide:rotate-ccw",
        Callback = function()
            local restored = VisualCarry.RevertAll()
            Notify("Visual Carry", restored > 0 and ("Restored " .. restored .. " swapped pair(s).") or "Nothing is swapped.", 3)
            base, target = nil, nil
            Refresh()
        end
    })

    Refresh()
end

return UI
