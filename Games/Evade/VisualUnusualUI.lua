local VisualUnusual = getgenv().MugiwaraImport("Games/Evade/VisualUnusual.lua")

-- Antarmuka Visual Unusual (premium): pilih efek Unusual dari grid. Memilih = langsung dipasang, memilih lagi =
-- dilepas, dan beberapa bisa dipasang bersamaan (ditumpuk). Logikanya ada di VisualUnusual.lua.
-- Gambar tiap kotak adalah ikon Unusual dari game, jadi tidak ada viewport (ringan). Daftar dibagi per kategori
-- (Header milik game) dan per halaman (CHUNK), sama seperti Visual Emotes.
local UI = {}

local CHUNK = 24
local HEADER_ORDER = { "Normal", "Gamepasses", "Halloween", "Winter Holidays", "Summer", "Spring", "Valentines", "Event", "Special" }
local NAMES_SHOWN = 6 -- berapa nama ditulis di ringkasan "Applied"

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

function UI.Build(Section, isPremiumUser, MugiwaraUI)
    if not VisualUnusual then return end

    local locked = not isPremiumUser

    local function Notify(title, content, duration)
        MugiwaraUI:Notify({ Title = title, Content = content, Duration = duration or 3 })
    end

    if VisualUnusual.Load() == 0 then
        Section:Paragraph({
            Title = "Visual Unusual Unavailable",
            Desc = "No Unusual effects were found in this game. The game may have changed its item folders.",
            Icon = "lucide:triangle-alert"
        })
        return
    end

    local all = VisualUnusual.GetEntries()
    local groups = BuildGroups(all)
    local group = 1
    local lookup = {} -- judul kotak -> entry, untuk halaman yang sedang tampil
    local Grid

    local status = Section:Paragraph({
        Title = "Applied: none",
        Desc = "Pick an effect to wear it. Pick it again to take it off. You can stack as many as you like.",
        Icon = "lucide:sparkles"
    })

    local function UpdateStatus()
        local list = VisualUnusual.GetApplied()
        if #list == 0 then
            status:SetTitle("Applied: none")
            status:SetDesc("Pick an effect to wear it. Pick it again to take it off. You can stack as many as you like.")
            return
        end
        local names = {}
        for index, entry in ipairs(list) do
            if index > NAMES_SHOWN then break end
            table.insert(names, entry.Display)
        end
        local more = #list > NAMES_SHOWN and (" +" .. (#list - NAMES_SHOWN) .. " more") or ""
        status:SetTitle("Applied: " .. #list)
        status:SetDesc(table.concat(names, ", ") .. more)
    end
    VisualUnusual.OnChange = UpdateStatus

    -- Kotak halaman ini: judul = nama Unusual, gambar = ikon dari game (huruf pertama kalau tidak ada).
    local function PageItems()
        local items = {}
        table.clear(lookup)
        for _, entry in ipairs(groups[group].Entries) do
            lookup[entry.Display] = entry
            table.insert(items, {
                Title = entry.Display,
                Image = entry.Image,
                Icon = entry.Image == nil and "lucide:sparkles" or nil,
            })
        end
        return items
    end

    local function AppliedTitles()
        local titles = {}
        for _, entry in ipairs(groups[group].Entries) do
            if VisualUnusual.IsApplied(entry) then table.insert(titles, entry.Display) end
        end
        return titles
    end

    local function ShowPage()
        Grid:Refresh(PageItems())
        Grid:Set(AppliedTitles(), true)
    end

    local categoryTitles = {}
    for _, g in ipairs(groups) do table.insert(categoryTitles, g.Title) end

    Section:Dropdown({
        Title = "Category",
        Desc = "Where the game files this Unusual (event, shop, gamepass...).",
        Icon = "lucide:folder-open",
        Locked = locked,
        LockedTitle = "Premium Only",
        Values = categoryTitles,
        Value = categoryTitles[1],
        Callback = function(Option)
            if type(Option) ~= "string" then return end
            for index, g in ipairs(groups) do
                if g.Title == Option then group = index break end
            end
            ShowPage()
        end
    })

    Grid = Section:GridDropdown({
        Title = "Unusual Effects",
        Icon = "lucide:wand-sparkles",
        Locked = locked,
        LockedTitle = "Premium Only",
        Values = {},
        Multi = true,
        Searchable = true,
        Placeholder = "Select effects...",
        Columns = 4,
        CellHeight = 112,
        MaxHeight = 300,
        Callback = function(Selected)
            local want = {}
            for _, title in ipairs(type(Selected) == "table" and Selected or {}) do want[title] = true end

            local failed = false
            for title, entry in pairs(lookup) do
                local on = VisualUnusual.IsApplied(entry)
                if want[title] and not on then
                    local ok, message = VisualUnusual.Apply(entry)
                    if not ok then
                        failed = true
                        Notify("Visual Unusual", message, 4)
                    end
                elseif not want[title] and on then
                    VisualUnusual.Remove(entry)
                end
            end
            -- yang gagal dipasang dicabut lagi dari pilihan
            if failed then Grid:Set(AppliedTitles(), true) end
        end
    })

    Section:Button({
        Title = "Remove All",
        Desc = "Take off every Unusual effect you applied.",
        Icon = "lucide:eraser",
        Locked = locked,
        LockedTitle = "Premium Only",
        Callback = function()
            local count = VisualUnusual.Clear()
            Notify("Visual Unusual", count > 0 and ("Removed " .. count .. " effect(s).") or "Nothing is applied.", 3)
            Grid:Set({}, true)
        end
    })

    ShowPage()

    -- Isi semua Unusual disalin ke memori di latar belakang (sekali), jadi memasang tidak menunggu apa pun.
    task.spawn(function()
        local ok, err = pcall(VisualUnusual.CaptureAll)
        if not ok then warn("[Mugiwara HUB] Visual Unusual capture error: " .. tostring(err)) end
    end)
end

return UI
