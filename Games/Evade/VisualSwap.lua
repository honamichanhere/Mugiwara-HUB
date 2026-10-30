-- Inti Visual Emotes dan Visual Carry: menukar isi dua item Evade supaya satu item tampil/bermain seperti
-- yang lain. Logikanya sama dengan repo Visual-Emotes: isi (anak) tiap item di ReplicatedStorage.Items
-- disalin dulu, lalu ditukar silang; Revert mengembalikan isi aslinya. Hanya terjadi di client. Modul ini
-- tanpa UI; dipakai lewat pabrik di bawah, satu instance per jenis item:
--   VisualSwap({ Category = "Emotes", Paths = {...}, Whitelist = {...}, Noun = "emote" })
--   VisualSwap({ Category = "CarryAnimations", Noun = "carry" })
return function(config)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local Swap = {}

    local CATEGORY = config.Category
    local PATHS = config.Paths or {}
    local WHITELIST = config.Whitelist or {}
    local NOUN = config.Noun or "item"

    local entries = {}        -- { { Name, Display, Header, Id, Instance } } terurut menurut nama tampilan
    local byInstance = {}     -- [instance] = entry
    local swapped = {}        -- [instance] = instance pasangannya (sedang tertukar)
    local originals = {}      -- [instance] = isi asli (salinan anak-anaknya)

    -- "RockinStride" -> "Rockin Stride"
    local function SpacedName(name)
        return (name:gsub("(%l)(%u)", "%1 %2"))
    end
    Swap.SpacedName = SpacedName

    local function ResolvePath(path)
        local current = game
        for _, name in ipairs(string.split(path, ".")) do
            if name == "ReplicatedStorage" then
                current = ReplicatedStorage
            else
                current = current:FindFirstChild(name)
            end
            if not current then return nil end
        end
        return current
    end

    local loaded = false
    local source = "none"

    -- Nama tampilan dan Header (kelompok di menu game: "Normal", "Halloween", ...) dibaca dari modul data item.
    local function AddEntry(instance, id)
        if byInstance[instance] then return end

        local info
        local ok, result = pcall(require, instance)
        if ok and type(result) == "table" then info = result end
        local display = info and info.AppearanceInfo and info.AppearanceInfo.Name
        local header = info and info.UIInfo and info.UIInfo.Header

        local entry = {
            Name = instance.Name,
            Display = type(display) == "string" and display or SpacedName(instance.Name),
            Header = type(header) == "string" and header or "Other",
            Id = id,
            Instance = instance,
        }
        table.insert(entries, entry)
        byInstance[instance] = entry
    end

    -- Sumber utama: Registry milik game. Kategorinya adalah nama folder induk, jadi item yang tersebar di
    -- BaseItems dan ItemPacks (juga di dalam sub-folder) semuanya ikut.
    local function LoadFromRegistry()
        local items = ReplicatedStorage:FindFirstChild("Items")
        local registryModule = items and items:FindFirstChild("Registry")
        if not registryModule then return false end

        local ok, Registry = pcall(require, registryModule)
        if not ok or type(Registry) ~= "table" or type(Registry.GetByCategory) ~= "function" then return false end

        local okList, list = pcall(Registry.GetByCategory, CATEGORY)
        if not okList or type(list) ~= "table" then return false end

        for id, record in pairs(list) do
            local module = type(record) == "table" and record.Module
            if typeof(module) == "Instance" then AddEntry(module, id) end
        end
        return #entries > 0
    end

    -- Cadangan 1: daftar path bawaan hub (kalau ada).
    local function LoadFromPaths()
        for _, path in ipairs(PATHS) do
            local instance = ResolvePath(path)
            if instance then AddEntry(instance) end
        end
    end

    -- Cadangan 2: semua ModuleScript ber-ID di bawah folder yang bernama CATEGORY.
    local function LoadFromScan()
        local items = ReplicatedStorage:FindFirstChild("Items")
        if not items then return end
        for _, descendant in ipairs(items:GetDescendants()) do
            if descendant:IsA("ModuleScript") then
                local inCategory = false
                local parent = descendant.Parent
                while parent and parent ~= items do
                    if parent:IsA("Folder") and parent.Name == CATEGORY then
                        inCategory = true
                        break
                    end
                    parent = parent.Parent
                end
                if inCategory then AddEntry(descendant) end
            end
        end
    end

    -- Daftar ditemukan sekali; menunggu folder Items sebentar kalau game belum selesai memuat.
    function Swap.Load()
        if loaded then return #entries end
        loaded = true

        if not ReplicatedStorage:FindFirstChild("Items") then
            pcall(function() ReplicatedStorage:WaitForChild("Items", 8) end)
        end

        if LoadFromRegistry() then
            source = "registry"
        else
            table.clear(entries)
            table.clear(byInstance)
            LoadFromPaths()
            source = "paths"
            if #entries == 0 then
                LoadFromScan()
                source = "scan"
            end
        end

        table.sort(entries, function(a, b)
            return string.lower(a.Display) < string.lower(b.Display)
        end)
        return #entries
    end

    -- "registry" (daftar dari game), "paths" (daftar bawaan hub), "scan" (pencarian folder) atau "none"
    function Swap.GetSource()
        return source
    end

    function Swap.GetEntries()
        return entries
    end

    -- Nama pasangan wajib dari item ini, atau nil kalau bebas.
    function Swap.GetWhitelist(entry)
        return entry and WHITELIST[entry.Name] or nil
    end

    -- Item yang sedang tertukar dengan `entry` (entry atau nil).
    function Swap.GetPartner(entry)
        local partner = entry and swapped[entry.Instance]
        return partner and byInstance[partner] or nil
    end

    -- 1 = belum bisa (pilihan kurang / salah satu sudah tertukar dengan item lain)
    -- 2 = bisa ditukar
    -- 3 = pasangan yang sudah tertukar (tombol berubah jadi Revert)
    function Swap.GetState(base, target)
        if not base or not target or base == target then return 1 end
        if swapped[base.Instance] == target.Instance then return 3 end
        if swapped[base.Instance] ~= nil or swapped[target.Instance] ~= nil then return 1 end
        return 2
    end

    local function CacheOriginal(item)
        if not originals[item] then
            originals[item] = {}
            for _, child in ipairs(item:GetChildren()) do
                table.insert(originals[item], child:Clone())
            end
        end
    end

    -- Isi `targetItem` diganti dengan isi asli `sourceItem`.
    local function InjectContents(targetItem, sourceItem)
        for _, child in ipairs(targetItem:GetChildren()) do
            child:Destroy()
        end
        for _, child in ipairs(originals[sourceItem]) do
            child:Clone().Parent = targetItem
        end
    end

    -- Mengembalikan true, pesan atau false, alasan.
    function Swap.Swap(base, target)
        if Swap.GetState(base, target) ~= 2 then
            return false, "Please make sure you picked a valid Base and Target " .. NOUN .. "."
        end

        local ok, err = pcall(function()
            CacheOriginal(base.Instance)
            CacheOriginal(target.Instance)
            InjectContents(base.Instance, target.Instance)
            InjectContents(target.Instance, base.Instance)
        end)
        if not ok then return false, "The swap failed: " .. tostring(err) end

        swapped[base.Instance] = target.Instance
        swapped[target.Instance] = base.Instance
        return true, base.Display .. " ⇌ " .. target.Display
    end

    function Swap.Revert(base, target)
        if Swap.GetState(base, target) ~= 3 then
            return false, "These two " .. NOUN .. "s are not swapped."
        end

        local ok, err = pcall(function()
            InjectContents(base.Instance, base.Instance)
            InjectContents(target.Instance, target.Instance)
        end)
        if not ok then return false, "The revert failed: " .. tostring(err) end

        swapped[base.Instance] = nil
        swapped[target.Instance] = nil
        return true, base.Display .. " and " .. target.Display .. " were restored."
    end

    -- Mengembalikan semua item yang tertukar. Hasil: jumlah pasangan yang dipulihkan, dan daftar item-nya.
    function Swap.RevertAll()
        local restored, touched = 0, {}
        for instance, partner in pairs(table.clone(swapped)) do
            if swapped[instance] == partner then
                local entry, other = byInstance[instance], byInstance[partner]
                if entry and other and Swap.Revert(entry, other) then
                    restored = restored + 1
                    table.insert(touched, entry)
                    table.insert(touched, other)
                end
            end
        end
        return restored, touched
    end

    function Swap.SwappedCount()
        local count = 0
        for _ in pairs(swapped) do count = count + 1 end
        return math.floor(count / 2)
    end

    -- Saat hub dimatikan semua item dikembalikan, supaya tidak ada yang tertinggal tertukar.
    getgenv().MugiwaraRegisterCleanup(function()
        pcall(Swap.RevertAll)
    end)

    return Swap
end
