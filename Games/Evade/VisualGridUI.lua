local Preview = getgenv().MugiwaraImport("Games/Evade/EmotePreview.lua")

-- Antarmuka bersama Visual Emotes dan Visual Carry: pilih item Base dan Target dari grid, lalu Swap / Revert.
-- Logikanya ada di modul tukar (VisualEmotes / VisualCarry, sama-sama VisualSwap). Aturan daftar sama dengan
-- Visual-Emotes: item yang dipilih di sisi lain disembunyikan, dan item berpasangan (whitelist, kalau ada)
-- hanya menampilkan pasangannya.
--
-- Tiap kotak grid menampilkan item seperti di menu Evade (karakter dengan pose), tetapi DIAM: model hasil
-- render EmotePreview ditaruh di item Viewport milik GridDropdown dan tidak diputar. Satu viewport = satu
-- permukaan render yang digambar ulang setiap frame, jadi:
--   * daftar dibagi per kategori (Header milik game) dan per halaman (CHUNK);
--   * hanya grid yang sedang DIBUKA yang memegang viewport, grid tertutup menampilkan ikon biasa;
--   * pose dihitung sekali dan disimpan ke file (lihat EmotePreview.lua).
local UI = {}

local CHUNK = 24
local HEADER_ORDER = { "Normal", "Gamepasses", "Halloween", "Winter Holidays", "Summer", "Spring", "Valentines", "Event", "Special" }

-- Sudut kamera seperti menu game: dari depan, sedikit ke kanan dan di atas, FOV 30. Ubah di sini kalau perlu.
-- Rotate = false: tidak ada putaran saat kursor di atas kotak.
local LOOK = { Rotate = false, Yaw = 155, Pitch = 10, FieldOfView = 30, Zoom = 1 }

local function BuildGroups(entries)
    local byHeader = {}
    for _, entry in ipairs(entries) do
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

-- config: Swap (modul tukar), Kind ("Emote" | "Carry"), Name ("Visual Emotes"), Noun ("emote"),
--         Locked (true = premium saja), Icons = { Item, Base, Target }
function UI.Build(Section, config, MugiwaraUI)
    local Swap = config.Swap
    if not Swap then return end

    local kind, noun, name = config.Kind, config.Noun, config.Name
    local Capital = string.upper(string.sub(noun, 1, 1)) .. string.sub(noun, 2)
    local locked = config.Locked == true

    local function Notify(title, content, duration)
        MugiwaraUI:Notify({ Title = title, Content = content, Duration = duration or 3 })
    end

    if Swap.Load() == 0 then
        Section:Paragraph({
            Title = name .. " Unavailable",
            Desc = "No " .. noun .. "s were found in this game. The game may have changed its item folders.",
            Icon = "lucide:triangle-alert"
        })
        return
    end

    local all = Swap.GetEntries()
    local groups = BuildGroups(all)
    local byName = {}
    for _, entry in ipairs(all) do byName[entry.Name] = entry end

    -- Fungsi render game baru dicari saat pertama dibutuhkan (bukan saat hub memuat).
    local previewState = nil
    local previewWarned = false
    local function PreviewsOn()
        if previewState == nil then
            previewState = (Preview and Preview.Available(kind)) and true or false
            if not previewState then Notify(name, "Previews are not available in this game version, showing icons instead.", 4) end
        end
        return previewState
    end
    local failedPreview = {} -- item yang gagal dirender: tidak dicoba lagi sampai ditukar / dikembalikan

    local base, target = nil, nil -- entry yang dipilih
    local notifiedWhitelist = false
    local sides = {}
    local SwapButton
    local Refresh -- didefinisikan di bawah; dipakai juga oleh Bake

    local function TitleOf(entry)
        local partner = Swap.GetPartner(entry)
        return partner and (entry.Display .. " (" .. partner.Display .. ")") or entry.Display
    end

    -- Item grid: model diam hanya untuk grid yang sedang DIBUKA dan kalau modelnya sudah ada; selain itu ikon
    -- biasa.
    local function ItemFor(entry, withView)
        local item = { Title = TitleOf(entry) }
        local model = withView and Preview and Preview.Get(entry) or nil
        if model then
            item.Viewport = model
        else
            item.Icon = config.Icons.Item
        end
        return item
    end

    -- Entry yang tampil di sisi ini: pasangan wajib (whitelist), atau halaman kategori saat ini,
    -- tanpa item yang dipilih di sisi lain.
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
            local item = ItemFor(entry, side.IsOpen)
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

    -- Membangun model diam untuk item yang tampil dan belum punya. Beberapa item dikerjakan serentak (animasi
    -- dimuat dari server, jadi menunggu satu-satu lama) dan grid diperbarui bertahap: tile yang sudah jadi
    -- langsung muncul, urutannya sesuai tampilan (kiri atas dulu). Kalau posenya sudah tersimpan, semuanya instan.
    local WORKERS = 3
    local REFRESH_AFTER = { [6] = true, [14] = true, [24] = true } -- jumlah item selesai yang memicu pembaruan grid

    local function Bake(side)
        if not PreviewsOn() then return end
        side.Token = side.Token + 1
        local mine = side.Token

        local pending = {}
        for _, entry in ipairs(side.Entries or {}) do
            if not Preview.Get(entry) and not failedPreview[entry] then table.insert(pending, entry) end
        end
        if #pending == 0 then
            Refresh() -- semua sudah ada di cache: cukup tampilkan
            return
        end

        if #pending > 6 then Notify(name, "Rendering " .. #pending .. " previews...", 2) end
        Preview.Preload(pending, kind)

        local nextIndex, done, active = 1, 0, 0

        local function Worker()
            while mine == side.Token and nextIndex <= #pending do
                local entry = pending[nextIndex]
                nextIndex = nextIndex + 1

                local model, reason = Preview.Bake(entry, kind)
                if not model then
                    failedPreview[entry] = true
                    if reason ~= "unloaded" then
                        warn("[Mugiwara HUB] " .. Capital .. " preview failed for " .. entry.Name .. ": " .. tostring(reason))
                        if not previewWarned then
                            previewWarned = true
                            Notify(name, "Could not render a preview: " .. tostring(reason), 5)
                        end
                    end
                end

                done = done + 1
                if mine == side.Token and REFRESH_AFTER[done] then Refresh() end
            end

            active = active - 1
            if active == 0 and mine == side.Token then Refresh() end
        end

        for _ = 1, math.min(WORKERS, #pending) do
            active = active + 1
            task.spawn(Worker)
        end
    end

    local function UpdateButton()
        local state = Swap.GetState(base, target)
        if state == 3 then
            SwapButton:SetTitle("Revert")
            SwapButton:SetIcon("lucide:undo-2")
            SwapButton:SetDesc("Restore these two " .. noun .. "s to normal.")
        else
            SwapButton:SetTitle("Swap")
            SwapButton:SetIcon("lucide:repeat")
            SwapButton:SetDesc(state == 2 and ("Swap the two " .. noun .. "s visually.") or ("Pick a Base and a Target " .. noun .. " first. " .. (Capital == "Carry" and "A carry" or "An " .. noun) .. " that is already swapped must be reverted before it can be swapped again."))
        end
    end

    -- Dua sisi saling menyaring; pilihan yang tidak cocok lagi dilepas.
    Refresh = function()
        local targetOnly = base and Swap.GetWhitelist(base) or nil
        local baseOnly = target and Swap.GetWhitelist(target) or nil

        if target and ((targetOnly and target.Name ~= targetOnly) or target == base) then target = nil end
        if base and ((baseOnly and base.Name ~= baseOnly) or base == target) then base = nil end

        Present(sides.Base, VisibleEntries(sides.Base, baseOnly, target))
        Present(sides.Target, VisibleEntries(sides.Target, targetOnly, base))
        UpdateButton()
    end

    local function Picked(entry)
        if entry and Swap.GetWhitelist(entry) and not notifiedWhitelist then
            notifiedWhitelist = true
            Notify(name, "Whitelist applied! This " .. noun .. " is restricted to a specific pair.", 4)
        end
        if not entry then notifiedWhitelist = false end
    end

    local function CategoryItems()
        local items = {}
        for _, group in ipairs(groups) do
            table.insert(items, { Title = group.Title, Desc = #group.Entries .. " " .. noun .. "s", Icon = "lucide:folder" })
        end
        return items
    end

    local function GroupIndexOf(title)
        for index, group in ipairs(groups) do
            if group.Title == title then return index end
        end
        return 1
    end

    -- Satu sisi = pilihan kategori + grid. Grid mulai dengan ikon biasa; model dibangun saat grid dibuka.
    local function BuildSide(sideName, titleText, descText, icon, isBase)
        local side = { Name = sideName, Group = 1, Token = 0, Signature = nil, Entries = {}, Lookup = {}, IsOpen = false }
        sides[sideName] = side

        Section:Dropdown({
            Title = titleText .. " Category",
            Desc = descText,
            Icon = "lucide:folder-open",
            Locked = locked and not config.IsPremium,
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
            Locked = locked and not config.IsPremium,
            LockedTitle = "Premium Only",
            Values = {},
            AllowNone = true,
            Searchable = true,
            Placeholder = "Select " .. (Capital == "Carry" and "a carry" or "an " .. noun) .. "...",
            Columns = 4,
            CellHeight = 124,
            MaxHeight = 300,
            Viewport = LOOK,
            Callback = function(Option)
                side.IsOpen = false -- memilih satu item menutup grid (pilihan tunggal)
                local entry = type(Option) == "string" and side.Lookup[Option] or nil
                if isBase then base = entry else target = entry end
                Picked(entry)
                Refresh()
            end
        })

        -- Grid dibuka: viewport baru dipasang sekarang (dan dilepas lagi saat ditutup).
        side.Grid.Top.MouseButton1Click:Connect(function()
            if side.Grid.Locked then return end
            side.IsOpen = not side.IsOpen
            if side.IsOpen then
                -- yang gagal dirender sebelumnya (misalnya animasinya lambat dimuat) dicoba lagi sekali saat dibuka
                for _, entry in ipairs(side.Entries) do failedPreview[entry] = nil end
                previewWarned = false
                Bake(side)
            else
                Refresh()
            end
        end)
        return side
    end

    BuildSide("Base", "Base " .. Capital, "Category of the " .. noun .. " you will change.", config.Icons.Base, true)
    BuildSide("Target", "Target " .. Capital, "Category of the " .. noun .. " it will look like.", config.Icons.Target, false)

    -- Pose semua item dikumpulkan pelan-pelan di latar belakang (sekali saja: hasilnya disimpan di file),
    -- jadi kategori mana pun yang dibuka nanti langsung instan.
    local collecting = false
    local function StartCollector()
        if collecting or not PreviewsOn() then return end
        collecting = true
        task.spawn(function()
            local list, missing = {}, 0
            for _, group in ipairs(groups) do
                for _, entry in ipairs(group.Entries) do
                    table.insert(list, entry)
                    if not Preview.PoseKnown(entry, kind) then missing = missing + 1 end
                end
            end
            if missing == 0 then return end
            if missing > 20 then Notify(name, "Preparing " .. missing .. " " .. noun .. " previews in the background (one time only)...", 4) end
            local collected = Preview.Collect(list, kind)
            if missing > 20 and collected > 0 then Notify(name, Capital .. " previews are ready.", 3) end
        end)
    end

    -- Persiapan dimulai begitu section dibuka (kebanyakan orang membuka grid sesudahnya), tanpa menunggu
    -- grid dibuka.
    local warmed = false
    local header = Section.Frame and Section.Frame:FindFirstChild("Header", true)
    if header then
        header.MouseButton1Click:Connect(function()
            if not warmed then
                warmed = true
                Bake(sides.Base)
                StartCollector()
            end
        end)
    end

    local function Forget(entries)
        if not Preview then return end
        for _, entry in ipairs(entries) do
            Preview.Invalidate(entry)
            failedPreview[entry] = nil
        end
    end

    SwapButton = Section:Button({
        Title = "Swap",
        Desc = "Pick a Base and a Target " .. noun .. " first.",
        Icon = "lucide:repeat",
        Locked = locked and not config.IsPremium,
        LockedTitle = "Premium Only",
        Callback = function()
            local state = Swap.GetState(base, target)
            if state == 1 then
                Notify("Swap Unavailable", "Please make sure you picked a valid Base and Target " .. noun .. ".", 3)
                return
            end

            local pair = { base, target }
            local ok, message
            if state == 2 then
                ok, message = Swap.Swap(base, target)
                Notify(ok and "Swap Successful!" or "Swap Failed", message, 3)
            else
                ok, message = Swap.Revert(base, target)
                Notify(ok and "Revert Successful!" or "Revert Failed", message, 3)
            end

            -- Gambarnya ikut berubah seperti di game: bangun ulang model kedua item.
            if ok then Forget(pair) end

            base, target, notifiedWhitelist = nil, nil, false
            Refresh()
            Bake(sides.Base)
            Bake(sides.Target)
        end
    })

    Section:Button({
        Title = "Revert All",
        Desc = "Put every swapped " .. noun .. " back to normal.",
        Icon = "lucide:rotate-ccw",
        Locked = locked and not config.IsPremium,
        LockedTitle = "Premium Only",
        Callback = function()
            local restored, touched = Swap.RevertAll()
            Notify(name, restored > 0 and ("Restored " .. restored .. " swapped pair(s).") or "Nothing is swapped.", 3)
            Forget(touched)
            base, target, notifiedWhitelist = nil, nil, false
            Refresh()
            Bake(sides.Base)
            Bake(sides.Target)
        end
    })

    Refresh() -- kedua grid diisi untuk pertama kali (ikon biasa; model dibangun saat dibuka)
end

return UI
