local VisualEmotes = getgenv().MugiwaraImport("Games/Evade/VisualEmotes.lua")
local Preview = getgenv().MugiwaraImport("Games/Evade/EmotePreview.lua")

-- Antarmuka Visual Emotes (premium): pilih emote Base dan Target dari grid, lalu Swap / Revert. Logikanya
-- ada di VisualEmotes.lua. Aturan daftar sama dengan Visual-Emotes: emote yang dipilih di sisi lain
-- disembunyikan, dan emote berpasangan (whitelist) hanya menampilkan pasangannya.
--
-- Tiap kotak grid menampilkan emote seperti di menu Evade (karakter dengan pose emote), tetapi DIAM:
-- model hasil render EmotePreview ditaruh di item Viewport milik GridDropdown dan tidak diputar.
-- Satu viewport = satu permukaan render, jadi daftar dibagi per kategori (Header milik game) dan per
-- halaman supaya yang tampil sekaligus tidak lebih dari CHUNK.
local UI = {}

local CHUNK = 30
local HEADER_ORDER = { "Normal", "Gamepasses", "Halloween", "Winter Holidays", "Summer", "Spring", "Valentines", "Event", "Special" }

-- Sudut kamera seperti menu game: dari depan, sedikit ke kanan dan di atas, FOV 30. Ubah di sini kalau perlu.
-- Rotate = false: tidak ada putaran saat kursor di atas kotak.
local LOOK = { Rotate = false, Yaw = 155, Pitch = 10, FieldOfView = 30, Zoom = 1 }

local function BuildGroups(emotes)
    local byHeader = {}
    for _, entry in ipairs(emotes) do
        byHeader[entry.Header] = byHeader[entry.Header] or {}
        table.insert(byHeader[entry.Header], entry)
    end

    local order, seen = {}, {}
    for _, header in ipairs(HEADER_ORDER) do
        if byHeader[header] then
            table.insert(order, header)
            seen[header] = true
        end
    end
    local rest = {}
    for header in pairs(byHeader) do
        if not seen[header] then table.insert(rest, header) end
    end
    table.sort(rest)
    for _, header in ipairs(rest) do table.insert(order, header) end

    local groups = {}
    for _, header in ipairs(order) do
        local list = byHeader[header]
        local pages = math.ceil(#list / CHUNK)
        for page = 1, pages do
            local from = (page - 1) * CHUNK + 1
            table.insert(groups, {
                Title = pages > 1 and (header .. " " .. page .. "/" .. pages) or header,
                Entries = table.move(list, from, math.min(from + CHUNK - 1, #list), 1, {}),
            })
        end
    end
    return groups
end

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

    local emotes = VisualEmotes.GetEmotes()
    local groups = BuildGroups(emotes)
    local byName = {}
    for _, entry in ipairs(emotes) do byName[entry.Name] = entry end

    -- Fungsi render game baru dicari saat grid pertama dibuka (bukan saat hub memuat): require modul game
    -- bisa lambat atau gagal, dan itu tidak boleh menahan pembuatan tab Main.
    local previewState = nil
    local previewWarned = false
    local function PreviewsOn()
        if previewState == nil then
            previewState = (Preview and Preview.Available()) and true or false
            if not previewState then Notify("Visual Emotes", "Previews are not available in this game version, showing icons instead.", 4) end
        end
        return previewState
    end
    local failedPreview = {} -- emote yang gagal dirender: tidak dicoba lagi sampai ditukar / dikembalikan

    local base, target = nil, nil -- entry yang dipilih
    local notifiedWhitelist = false
    local sides = {}
    local SwapButton
    local Refresh -- definida di bawah; dipakai juga oleh Bake

    local function TitleOf(entry)
        local partner = VisualEmotes.GetPartner(entry)
        return partner and (entry.Display .. " (" .. partner.Display .. ")") or entry.Display
    end

    -- Item grid: model diam kalau sudah dirender, kalau belum ikon biasa.
    local function ItemFor(entry)
        local item = { Title = TitleOf(entry) }
        local model = Preview and Preview.Get(entry) or nil
        if model then
            item.Viewport = model
        else
            item.Icon = "lucide:music"
        end
        return item
    end

    -- Entry yang tampil di sisi ini: pasangan wajib (whitelist), atau halaman kategori saat ini,
    -- tanpa emote yang dipilih di sisi lain.
    local function VisibleEntries(side, onlyName, excluded)
        local source = onlyName and { byName[onlyName] } or groups[side.Group].Entries
        local entries = {}
        for _, entry in ipairs(source) do
            if entry ~= excluded then table.insert(entries, entry) end
        end
        return entries
    end

    -- Menampilkan daftar di grid sisi ini; dilewati kalau tidak ada yang berubah (rebuild grid mahal).
    local function Present(side, entries)
        local items, lookup, signature = {}, {}, {}
        for _, entry in ipairs(entries) do
            local item = ItemFor(entry)
            table.insert(items, item)
            lookup[item.Title] = entry
            table.insert(signature, item.Title .. (item.Viewport and "+" or "-"))
        end
        side.Entries = entries

        local key = table.concat(signature, "|")
        if key ~= side.Signature then
            side.Signature = key
            side.Lookup = lookup
            side.Grid:Refresh(items, false)
        else
            side.Lookup = lookup
        end

        -- Set membangun ulang grid: hanya kalau pilihan yang tampil memang berbeda.
        local chosen
        if side == sides.Base then chosen = base else chosen = target end
        local wanted = chosen and TitleOf(chosen) or nil
        if side.Grid:Get() ~= wanted then side.Grid:Set(wanted, true) end
    end

    -- Merender model diam untuk emote yang tampil dan belum punya, satu per satu di latar belakang.
    local function Bake(side)
        if not PreviewsOn() then return end
        side.Token = side.Token + 1
        local mine = side.Token

        local pending = {}
        for _, entry in ipairs(side.Entries or {}) do
            if not Preview.Get(entry) and not failedPreview[entry] then table.insert(pending, entry) end
        end
        if #pending == 0 then return end

        task.spawn(function()
            if #pending > 6 then Notify("Visual Emotes", "Rendering " .. #pending .. " previews...", 2) end
            for _, entry in ipairs(pending) do
                if mine ~= side.Token then return end
                local model, reason = Preview.Bake(entry)
                if not model then
                    failedPreview[entry] = true
                    if reason ~= "unloaded" then
                        warn("[Mugiwara HUB] Emote preview failed for " .. entry.Name .. ": " .. tostring(reason))
                        if not previewWarned then
                            previewWarned = true
                            Notify("Visual Emotes", "Could not render a preview: " .. tostring(reason), 5)
                        end
                    end
                end
            end
            if mine ~= side.Token then return end
            Refresh()
        end)
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
    Refresh = function()
        local targetOnly = base and VisualEmotes.GetWhitelist(base) or nil
        local baseOnly = target and VisualEmotes.GetWhitelist(target) or nil

        if target and ((targetOnly and target.Name ~= targetOnly) or target == base) then target = nil end
        if base and ((baseOnly and base.Name ~= baseOnly) or base == target) then base = nil end

        Present(sides.Base, VisibleEntries(sides.Base, baseOnly, target))
        Present(sides.Target, VisibleEntries(sides.Target, targetOnly, base))
        UpdateButton()
    end

    local function Picked(entry)
        if entry and VisualEmotes.GetWhitelist(entry) and not notifiedWhitelist then
            notifiedWhitelist = true
            Notify("Visual Emotes", "Whitelist applied! This emote is restricted to a specific pair.", 4)
        end
        if not entry then notifiedWhitelist = false end
    end

    local function CategoryItems()
        local items = {}
        for _, group in ipairs(groups) do
            table.insert(items, { Title = group.Title, Desc = #group.Entries .. " emotes", Icon = "lucide:folder" })
        end
        return items
    end

    local function GroupIndexOf(title)
        for index, group in ipairs(groups) do
            if group.Title == title then return index end
        end
        return 1
    end

    -- Satu sisi = pilihan kategori + grid. Grid mulai dengan ikon biasa; model dirender saat grid pertama dibuka.
    local function BuildSide(name, titleText, descText, icon, isBase)
        local side = { Name = name, Group = 1, Token = 0, Signature = nil, Entries = {}, Lookup = {}, Opened = false }
        sides[name] = side

        Section:Dropdown({
            Title = titleText .. " Category",
            Desc = descText,
            Icon = "lucide:folder-open",
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Values = CategoryItems(),
            Value = groups[1].Title,
            Callback = function(Option)
                if type(Option) ~= "string" then return end
                side.Group = GroupIndexOf(Option)
                if isBase then base = nil else target = nil end
                Picked(nil)
                Refresh()
                Bake(side)
            end
        })

        side.Grid = Section:GridDropdown({
            Title = titleText,
            Icon = icon,
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Values = {},
            AllowNone = true,
            Searchable = true,
            Placeholder = "Select an emote...",
            Columns = 4,
            CellHeight = 124,
            MaxHeight = 300,
            Viewport = LOOK,
            Callback = function(Option)
                local entry = type(Option) == "string" and side.Lookup[Option] or nil
                if isBase then base = entry else target = entry end
                Picked(entry)
                Refresh()
            end
        })

        side.Grid.Top.MouseButton1Click:Connect(function()
            if not side.Opened then
                side.Opened = true
                Bake(side)
            end
        end)
        return side
    end

    BuildSide("Base", "Base Emote", "Category of the emote you will change.", "lucide:music", true)
    BuildSide("Target", "Target Emote", "Category of the emote it will look like.", "lucide:drama", false)

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

            local pair = { base, target }
            local ok, message
            if state == 2 then
                ok, message = VisualEmotes.Swap(base, target)
                Notify(ok and "Swap Successful!" or "Swap Failed", message, 3)
            else
                ok, message = VisualEmotes.Revert(base, target)
                Notify(ok and "Revert Successful!" or "Revert Failed", message, 3)
            end

            -- Gambarnya ikut berubah seperti di game: render ulang kedua emote.
            if ok and Preview then
                for _, entry in ipairs(pair) do
                    Preview.Invalidate(entry)
                    failedPreview[entry] = nil
                end
            end

            base, target, notifiedWhitelist = nil, nil, false
            Refresh()
            Bake(sides.Base)
            Bake(sides.Target)
        end
    })

    Section:Button({
        Title = "Revert All",
        Desc = "Put every swapped emote back to normal.",
        Icon = "lucide:rotate-ccw",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            local restored, touched = VisualEmotes.RevertAll()
            Notify("Visual Emotes", restored > 0 and ("Restored " .. restored .. " swapped pair(s).") or "Nothing is swapped.", 3)
            if Preview then
                for _, entry in ipairs(touched) do
                    Preview.Invalidate(entry)
                    failedPreview[entry] = nil
                end
            end
            base, target, notifiedWhitelist = nil, nil, false
            Refresh()
            Bake(sides.Base)
            Bake(sides.Target)
        end
    })

    Refresh() -- kedua grid diisi untuk pertama kali (ikon biasa; model dirender saat dibuka)
end

return UI
