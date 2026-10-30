local Shortcuts = getgenv().MugiwaraImport("Manager/Shortcuts.lua")
local KeybindsModule = getgenv().MugiwaraImport("Manager/Keybinds.lua")
local UIExtras = getgenv().MugiwaraImport("Manager/UIExtras.lua")

-- Section "Keyboard Shortcuts" di tab Misc.
--   * "Show / Hide Hub" selalu ada (tidak bisa dihapus), hanya tombolnya yang bisa diganti.
--   * Di bawahnya shortcut buatan pengguna (maks Shortcuts.Max): tiap shortcut = satu Section kecil berisi nama, jenis
--     (Toggle / Slider / Button), kontrol hub yang dijalankan, nilai, tombol, dan tombol Delete. Semuanya disimpan
--     ke workspace (Manager/Shortcuts.lua). Elemen milik UI ini diberi NoShortcut supaya tidak muncul di daftar pilihan.
local UI = {}

local TYPE_DESC = {
    Toggle = "a switch in the hub",
    Slider = "a slider in the hub",
    Button = "a button in the hub",
}

function UI.Build(TabMisc, Window, isPremiumUser, MugiwaraUI)
    if not (Shortcuts and KeybindsModule) then return end

    local registry = (UIExtras and UIExtras.GetControls and UIExtras.GetControls(Window)) or { List = {}, Version = 0 }

    local function Notify(title, content, duration)
        MugiwaraUI:Notify({ Title = title, Content = content, Duration = duration or 3 })
    end

    local Section = TabMisc:Section({ Title = "Keyboard Shortcuts", Icon = "lucide:keyboard", Opened = false, Box = true })

    Section:Paragraph({
        Title = "How shortcuts work",
        Icon = "lucide:info",
        Desc = "Shortcuts are OFF by default. Turn them on below, then click a key box and press a key (Backspace clears it). Shortcuts do nothing while you type in chat, and mouse buttons are not supported. Add your own with Add Shortcut: pick a switch, slider or button from the hub and a key. Up to " .. Shortcuts.Max .. ". Saved to your workspace."
    })

    local enabled = KeybindsModule.GetEnabled()
    local RefreshUIKey

    Section:Toggle({
        NoShortcut = true,
        Title = "Enable Keyboard Shortcuts",
        Icon = "lucide:keyboard",
        Desc = "When off, none of the keys below do anything (including Show / Hide Hub).",
        Value = enabled,
        Callback = function(Value)
            enabled = Value
            KeybindsModule.SetEnabled(Value)
            if RefreshUIKey then RefreshUIKey() end
            Notify("Keyboard Shortcuts", Value and "Turned ON" or "Turned OFF", 2)
        end
    })

    local rows = {}
    local uiLast = KeybindsModule.Get("ToggleUI", "K")

    -- Pemakai tombol yang sama selain `except` (entri shortcut atau "ToggleUI"), untuk catatan bentrok.
    local function KeyConflict(key, except)
        if not key then return nil end
        if except ~= "ToggleUI" and uiLast == key then return "Show / Hide Hub" end
        for _, other in ipairs(Shortcuts.List) do
            if other ~= except and other.Key == key then return Shortcuts.TitleOf(other) end
        end
        return nil
    end

    -- Tombol buka/tutup dipasang ke Window hanya saat shortcut aktif; saat OFF dikosongkan.
    RefreshUIKey = function()
        if not Window.SetToggleKey then return end
        local keyCode = enabled and KeybindsModule.GetKeyCode(uiLast) or nil
        pcall(Window.SetToggleKey, Window, keyCode)
    end

    local uiKeybind
    uiKeybind = Section:Keybind({
        Title = "Show / Hide Hub",
        Desc = "Open or close this window. Always here: you can change its key but not remove it.",
        Icon = "lucide:app-window",
        Value = uiLast,
        OnChange = function(value)
            if not KeybindsModule.IsValidKey(value) then
                -- Tanpa tombol (atau bukan keyboard) hub tidak bisa dibuka lagi, jadi dikembalikan.
                if uiKeybind then uiKeybind:Set(uiLast, true) end
                Notify("Show / Hide Hub", "This shortcut needs a keyboard key.", 3)
                return
            end
            local conflict = KeyConflict(value, "ToggleUI")
            uiLast = value
            KeybindsModule.Set("ToggleUI", value)
            RefreshUIKey()
            if conflict then
                Notify("Shortcut Saved", "Show / Hide Hub = " .. value .. ". Note: " .. conflict .. " uses the same key.", 4)
            else
                Notify("Shortcut Saved", "Show / Hide Hub = " .. value, 2)
            end
        end
    })
    RefreshUIKey()

    Section:Divider({ Title = "My Shortcuts" })

    -- ---------- Baris shortcut ----------
    local function RefreshTitles()
        for _, row in ipairs(rows) do
            if row.Section and row.Section.SetTitle then pcall(function() row.Section:SetTitle(Shortcuts.TitleOf(row.Entry)) end) end
        end
    end

    -- Pilihan kontrol untuk satu entri: semua kontrol sejenis, ditambah pilihan tersimpan yang belum ada (mis. fitur
    -- game lain, atau modul game yang belum selesai dibangun) supaya pilihannya tetap tampil.
    local function TargetItems(entry)
        local items, found = {}, false
        for _, control in ipairs(Shortcuts.ControlsOfType(registry, entry.Type)) do
            table.insert(items, { Title = control.Display })
            if control.Display == entry.Target then found = true end
        end
        if entry.Target and not found then
            table.insert(items, 1, { Title = entry.Target, Desc = "Not available right now" })
        end
        return items
    end

    local function RangeText(entry)
        local control = Shortcuts.FindControl(registry, entry)
        local min, max = Shortcuts.SliderRange(control)
        if min then return "The value to set when you press the key. This slider goes from " .. min .. " to " .. max .. "." end
        return "The value to set when you press the key. Pick a slider first to see its range."
    end

    local Populate

    local function DestroyElements(row)
        for index = #row.Elements, 1, -1 do
            local element = row.Elements[index]
            local ok = element.Destroy and pcall(function() element:Destroy() end)
            if not ok and element.ElementFrame then pcall(function() element.ElementFrame:Destroy() end) end
        end
        row.Elements = {}
        row.Target, row.Value, row.Key = nil, nil, nil
    end

    local function DeleteRow(row)
        DestroyElements(row)
        for index, other in ipairs(rows) do
            if other == row then table.remove(rows, index) break end
        end
        Shortcuts.Remove(row.Entry)
        if row.Section and row.Section.Destroy then pcall(function() row.Section:Destroy() end) end
        RefreshTitles()
    end

    Populate = function(row)
        local entry = row.Entry
        local Box = row.Section

        local function Add(element)
            table.insert(row.Elements, element)
            return element
        end

        Add(Box:Input({
            NoShortcut = true,
            Title = "Name",
            Icon = "lucide:tag",
            Desc = "Shown as the title of this shortcut.",
            Placeholder = "Shortcut name",
            Value = entry.Name,
            Callback = function(Text)
                entry.Name = Shortcuts.CleanName(Text)
                Shortcuts.Save()
                RefreshTitles()
            end
        }))

        Add(Box:Dropdown({
            NoShortcut = true,
            Title = "Type",
            Icon = "lucide:shapes",
            Desc = "What this shortcut controls: a switch (toggle), a slider, or a button.",
            Values = Shortcuts.Types,
            Value = entry.Type,
            Callback = function(Option)
                if type(Option) ~= "string" or Option == entry.Type then return end
                entry.Type, entry.Target, entry.Value, entry.Mode = Option, nil, nil, "Toggle"
                Shortcuts.Save()
                -- Dibangun ulang setelah callback selesai (elemen yang sedang menjalankan callback tidak dihapus di tempat).
                task.delay(0.05, function()
                    DestroyElements(row)
                    Populate(row)
                end)
            end
        }))

        row.Target = Add(Box:Dropdown({
            NoShortcut = true,
            Title = "Feature",
            Icon = "lucide:crosshair",
            Desc = "Which " .. TYPE_DESC[entry.Type] .. " this key controls.",
            Values = TargetItems(entry),
            Value = entry.Target or "",
            Callback = function(Option)
                if type(Option) ~= "string" or Option == "" then return end
                entry.Target = Option
                if entry.Type == "Slider" then
                    local min, max, default = Shortcuts.SliderRange(Shortcuts.FindControl(registry, entry))
                    if min then
                        entry.Value = default and math.max(min, math.min(max, default)) or min
                        if row.Value then
                            row.Value:Set(tostring(entry.Value), true)
                            if row.Value.SetDesc then row.Value:SetDesc(RangeText(entry)) end
                        end
                    end
                end
                Shortcuts.Save()
            end
        }))

        if entry.Type == "Toggle" then
            Add(Box:Dropdown({
                NoShortcut = true,
                Title = "When pressed",
                Icon = "lucide:toggle-right",
                Desc = "Flip the switch, or always turn it on or off.",
                Values = Shortcuts.ToggleModes,
                Value = entry.Mode,
                Callback = function(Option)
                    if type(Option) == "string" then
                        entry.Mode = Option
                        Shortcuts.Save()
                    end
                end
            }))
        elseif entry.Type == "Slider" then
            row.Value = Add(Box:Input({
                NoShortcut = true,
                Title = "Value",
                Icon = "lucide:sliders-horizontal",
                Desc = RangeText(entry),
                Placeholder = "e.g. 50",
                Value = entry.Value ~= nil and tostring(entry.Value) or "",
                Callback = function(Text)
                    local number = tonumber(Text)
                    if not number then
                        Notify("Shortcut Value", "Type a number.", 3)
                        if row.Value then row.Value:Set(entry.Value ~= nil and tostring(entry.Value) or "", true) end
                        return
                    end
                    local min, max = Shortcuts.SliderRange(Shortcuts.FindControl(registry, entry))
                    if min then number = math.max(min, math.min(max, number)) end
                    entry.Value = number
                    if row.Value then row.Value:Set(tostring(number), true) end
                    Shortcuts.Save()
                end
            }))
        end

        row.Key = Add(Box:Keybind({
            Title = "Key",
            Icon = "lucide:keyboard",
            Desc = "Click, then press the key. Backspace clears it.",
            Value = entry.Key,
            Callback = function()
                if not enabled then return end
                local ok, message = Shortcuts.Run(registry, entry)
                Notify(Shortcuts.TitleOf(entry), tostring(message), ok and 1.5 or 3)
            end,
            OnChange = function(value)
                if value ~= nil and not KeybindsModule.IsValidKey(value) then
                    if row.Key then row.Key:Set(entry.Key, true) end
                    Notify("Unsupported Key", "Only keyboard keys can be used as shortcuts.", 3)
                    return
                end
                local conflict = KeyConflict(value, entry)
                entry.Key = value
                Shortcuts.Save()
                if value == nil then
                    Notify("Shortcut Saved", Shortcuts.TitleOf(entry) .. " has no key now.", 2)
                elseif conflict then
                    Notify("Shortcut Saved", Shortcuts.TitleOf(entry) .. " = " .. value .. ". Note: " .. conflict .. " uses the same key.", 4)
                else
                    Notify("Shortcut Saved", Shortcuts.TitleOf(entry) .. " = " .. value, 2)
                end
            end
        }))

        Add(Box:Button({
            NoShortcut = true,
            Title = "Delete Shortcut",
            Icon = "lucide:trash-2",
            Desc = "Remove this shortcut.",
            Callback = function()
                DeleteRow(row)
            end
        }))
    end

    local function BuildRow(entry, opened)
        local row = { Entry = entry, Elements = {} }
        row.Section = Section:Section({ Title = Shortcuts.TitleOf(entry), Opened = opened })
        table.insert(rows, row)
        Populate(row)
        return row
    end

    Section:Button({
        NoShortcut = true,
        Title = "Add Shortcut",
        Icon = "lucide:plus",
        Desc = "Create a shortcut for a switch, slider or button. Up to " .. Shortcuts.Max .. ".",
        Callback = function()
            local entry, reason = Shortcuts.Add()
            if not entry then
                Notify("Cannot Add Shortcut", tostring(reason), 3)
                return
            end
            BuildRow(entry, true)
            RefreshTitles()
            Notify("Shortcut Added", "Pick a feature and a key in the new shortcut at the bottom of this section.", 3)
        end
    })

    for _, entry in ipairs(Shortcuts.List) do
        BuildRow(entry, false)
    end

    -- Daftar kontrol bertambah saat tab lain selesai dibangun (modul game dibangun di thread sendiri), jadi pilihan
    -- tiap baris disegarkan kalau daftarnya berubah.
    local watching = true
    getgenv().MugiwaraRegisterCleanup(function() watching = false end)

    local seenVersion = registry.Version
    task.spawn(function()
        while watching do
            task.wait(1)
            if registry.Version ~= seenVersion then
                seenVersion = registry.Version
                for _, row in ipairs(rows) do
                    if row.Target and row.Target.Refresh then
                        pcall(function() row.Target:Refresh(TargetItems(row.Entry), true) end)
                    end
                end
            end
        end
    end)
end

return UI
