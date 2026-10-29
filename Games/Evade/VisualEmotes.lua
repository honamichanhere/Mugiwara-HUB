-- Visual Emotes untuk Evade: menukar isi dua emote supaya satu emote tampil/bermain seperti yang lain.
-- Logikanya sama dengan repo Visual-Emotes (honamichanhere/Visual-Emotes): isi (anak) tiap emote di
-- ReplicatedStorage.Items disalin dulu, lalu ditukar silang; Revert mengembalikan isi aslinya. Hanya
-- terjadi di client. Modul ini tanpa UI; antarmukanya ada di VisualEmotesUI.lua.
local VisualEmotes = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Path seluruh emote (dari Visual-Emotes). Emote yang tidak ada di versi game ini dilewati.
local PATHS = {
    -- Shop
    "ReplicatedStorage.Items.BaseItems.Emotes.Addendum",
    "ReplicatedStorage.Items.BaseItems.Emotes.Aerobics",
    "ReplicatedStorage.Items.BaseItems.Emotes.Beg",
    "ReplicatedStorage.Items.BaseItems.Emotes.BoldMarch",
    "ReplicatedStorage.Items.BaseItems.Emotes.Breakdown",
    "ReplicatedStorage.Items.BaseItems.Emotes.BumperKart",
    "ReplicatedStorage.Items.BaseItems.Emotes.California",
    "ReplicatedStorage.Items.BaseItems.Emotes.Caramelldansen",
    "ReplicatedStorage.Items.BaseItems.Emotes.Carlton",
    "ReplicatedStorage.Items.BaseItems.Emotes.Catdown",
    "ReplicatedStorage.Items.BaseItems.Emotes.Clap",
    "ReplicatedStorage.Items.BaseItems.Emotes.ClubDance",
    "ReplicatedStorage.Items.BaseItems.Emotes.Conga",
    "ReplicatedStorage.Items.BaseItems.Emotes.Crabby",
    "ReplicatedStorage.Items.BaseItems.Emotes.CrouchDance",
    "ReplicatedStorage.Items.BaseItems.Emotes.Distraction",
    "ReplicatedStorage.Items.BaseItems.Emotes.Epicaricacy",
    "ReplicatedStorage.Items.BaseItems.Emotes.Facepalm",
    "ReplicatedStorage.Items.BaseItems.Emotes.Flexing",
    "ReplicatedStorage.Items.BaseItems.Emotes.Freestyle",
    "ReplicatedStorage.Items.BaseItems.Emotes.Gmod",
    "ReplicatedStorage.Items.BaseItems.Emotes.GoofyStride",
    "ReplicatedStorage.Items.BaseItems.Emotes.Gyrating",
    "ReplicatedStorage.Items.BaseItems.Emotes.Heaventaker",
    "ReplicatedStorage.Items.BaseItems.Emotes.Hired",
    "ReplicatedStorage.Items.BaseItems.Emotes.Infectious",
    "ReplicatedStorage.Items.BaseItems.Emotes.LittleJiggy",
    "ReplicatedStorage.Items.BaseItems.Emotes.Nostalgia",
    "ReplicatedStorage.Items.BaseItems.Emotes.PBJT",
    "ReplicatedStorage.Items.BaseItems.Emotes.PonPon",
    "ReplicatedStorage.Items.BaseItems.Emotes.Rambunctious",
    "ReplicatedStorage.Items.BaseItems.Emotes.RussianDance",
    "ReplicatedStorage.Items.BaseItems.Emotes.Sit",
    "ReplicatedStorage.Items.BaseItems.Emotes.Sleep",
    "ReplicatedStorage.Items.BaseItems.Emotes.Smug",
    "ReplicatedStorage.Items.BaseItems.Emotes.Stride",
    "ReplicatedStorage.Items.BaseItems.Emotes.SwagWalk",
    "ReplicatedStorage.Items.BaseItems.Emotes.TexasStyle",
    "ReplicatedStorage.Items.BaseItems.Emotes.ZenSerenity",

    -- Daily Shop
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.APose",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.BoogieDown",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.BringItAround",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.Catjam",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.CompanyMan",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.Fazbore",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.FlashingLights",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.Kickback",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.LineDance",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.LunarParty",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.MaracaTime",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.Mashle",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.Moonwalk",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.Nizmoo",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.ParkerPride",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.PawsClaws",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.Popipopi",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.Robot",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.RushinAround",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.SeeTinh",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.SeriousMarch",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.Smile",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.SpookyTime",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.StarPower",
    "ReplicatedStorage.Items.ItemPacks.Base.DailyShop.Emotes.TPose",

    -- Level Shop
    "ReplicatedStorage.Items.ItemPacks.Base.LevelShop.Emotes.Banger",
    "ReplicatedStorage.Items.ItemPacks.Base.LevelShop.Emotes.GalacticBound",
    "ReplicatedStorage.Items.ItemPacks.Base.LevelShop.Emotes.GamingTime",
    "ReplicatedStorage.Items.ItemPacks.Base.LevelShop.Emotes.HeliosChariot",
    "ReplicatedStorage.Items.ItemPacks.Base.LevelShop.Emotes.Outlaw",
    "ReplicatedStorage.Items.ItemPacks.Base.LevelShop.Emotes.StealthyBox",
    "ReplicatedStorage.Items.ItemPacks.Base.LevelShop.Emotes.TouchGrass",
    "ReplicatedStorage.Items.ItemPacks.Base.LevelShop.Emotes.Writhing",

    -- New Shop
    "ReplicatedStorage.Items.ItemPacks.Base.NewShop.Emotes.Popular",
    "ReplicatedStorage.Items.ItemPacks.Base.NewShop.Emotes.SightlessDance",

    -- Special
    "ReplicatedStorage.Items.ItemPacks.Base.Special.Emotes.Bhop",

    -- Collab ST
    "ReplicatedStorage.Items.ItemPacks.Collab.ST.Emotes.WinterOf85",

    -- Halloween 2022
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Halloween2022.Emotes.Broom",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Halloween2022.Emotes.FrightFunk",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Halloween2022.Emotes.PumpItUp",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Halloween2022.Emotes.Reanimated",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Halloween2022.Emotes.RockinStride",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Halloween2022.Emotes.Thriller",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Halloween2022.Emotes.WerewolfHowl",

    -- Halloween 2024
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Halloween2024.Emotes.CyberBroom",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Halloween2024.Emotes.DeadBoneStride",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Halloween2024.Emotes.GhastlyGrimoire",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Halloween2024.Emotes.GhoulishGalleon",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Halloween2024.Emotes.HeadlessBaller",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Halloween2024.Emotes.Xylobone",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Halloween2024.Emotes.ZombieStride",

    -- Halloween 2025
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Hlwn2025.Emotes.CuerdasDelAlma",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Hlwn2025.Emotes.GraveRider",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Hlwn2025.Emotes.HeadlessHorseman",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Hlwn2025.Emotes.MariachiBand",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Hlwn2025.Emotes.ScorchedEarth",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Hlwn2025.Emotes.SpiritedAway",

    -- Halloween 2026
    "ReplicatedStorage.Items.ItemPacks.Events.2026.HLWN2026.Emotes.GargoyleStand",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.HLWN2026.Emotes.GhostSymphony",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.HLWN2026.Emotes.LilCthulhu",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.HLWN2026.Emotes.OogaBooga",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.HLWN2026.Emotes.WickerBeast",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.HLWN2026.Emotes.ZombieRaptor",

    -- Xmas 2022
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Xmas2022.Emotes.CampfireDoze",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Xmas2022.Emotes.ChristmasBoogie",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Xmas2022.Emotes.FlyingSleigh",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Xmas2022.Emotes.Marching",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Xmas2022.Emotes.Nutcracker",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Xmas2022.Emotes.SnowmobileCruise",
    "ReplicatedStorage.Items.ItemPacks.Events.2022.Xmas2022.Emotes.WindupDance",

    -- Xmas 2024
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Xmas2024.Emotes.BobointheBox",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Xmas2024.Emotes.IceFishing",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Xmas2024.Emotes.RudolphMount",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Xmas2024.Emotes.SantaMech",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Xmas2024.Emotes.SledDrifting",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Xmas2024.Emotes.SnowmanConstruction",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Xmas2024.Emotes.ToyTrainRide",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Xmas2024.Emotes.WindUpPose",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Xmas2024.Emotes.WinterRide",

    -- Xmas 2025
    "ReplicatedStorage.Items.ItemPacks.Events.2025.XMAS25.Emotes.Battlepass.CozyChair",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.XMAS25.Emotes.Battlepass.FrostDrake",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.XMAS25.Emotes.Battlepass.RockingHorse",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.XMAS25.Emotes.Battlepass.SkiSpree",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.XMAS25.Emotes.Battlepass.WinterMelody",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.XMAS25.Emotes.DailyShop.SnowAngel",

    -- St Patricks 2024
    "ReplicatedStorage.Items.ItemPacks.Events.2024.StPatricks2024.Emotes.AvariceLounge",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.StPatricks2024.Emotes.IrishJig",

    -- St Patricks 2025
    "ReplicatedStorage.Items.ItemPacks.Events.2025.StPatricks2025.Emotes.AprilShower",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.StPatricks2025.Emotes.GoldRitual",

    -- St Patricks 2026
    "ReplicatedStorage.Items.ItemPacks.Events.2026.StPatricks2026.Emotes.AuspiciousWell",

    -- Valentines 2024
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Valentines2024.Emotes.AngelicWings",
    "ReplicatedStorage.Items.ItemPacks.Events.2024.Valentines2024.Emotes.HarpRecital",

    -- Valentines 2025
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Valentines2025.Emotes.SerenePerch",

    -- Valentines 2026
    "ReplicatedStorage.Items.ItemPacks.Events.2026.Valentines2026.Emotes.DreamyCloud",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.Valentines2026.Emotes.ValentineComputer",

    -- Summer 2025
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Summer2025.Emotes.BeachChairLounge",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Summer2025.Emotes.CasualSurfing",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Summer2025.Emotes.LemonadeStand",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Summer2025.Emotes.ManyFans",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Summer2025.Emotes.PoolTime",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Summer2025.Emotes.RowBoat",
    "ReplicatedStorage.Items.ItemPacks.Events.2025.Summer2025.Emotes.SummerDays",

    -- Summer 2026
    "ReplicatedStorage.Items.ItemPacks.Events.2026.SUMMER26.Emotes.AquaticDaydreamer",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.SUMMER26.Emotes.AstralMantaRay",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.SUMMER26.Emotes.ClamClamor",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.SUMMER26.Emotes.EncapsulatedBubble",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.SUMMER26.Emotes.FrutigerFloatie",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.SUMMER26.Emotes.LeapingDolphin",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.SUMMER26.Emotes.SubmarineRide",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.SUMMER26.Emotes.SummerLowrider",

    -- Spring 2026
    "ReplicatedStorage.Items.ItemPacks.Events.2026.Spring2026.Emotes.CoccoonRebirth",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.Spring2026.Emotes.HoneyPool",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.Spring2026.Emotes.LadybugFlight",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.Spring2026.Emotes.LotusSwing",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.Spring2026.Emotes.MegaflyJet",
    "ReplicatedStorage.Items.ItemPacks.Events.2026.Spring2026.Emotes.SnailMail",

    -- Lunar New Year
    "ReplicatedStorage.Items.ItemPacks.EventsDailyShop.LunarNewYear.Emotes.DynastyDrumming",

    -- New Years 2024
    "ReplicatedStorage.Items.ItemPacks.EventsDailyShop.NewYears2024.Emotes.FireworkBlast",

    -- Old Roblox
    "ReplicatedStorage.Items.ItemPacks.EventsDailyShop.OldRoblox.Emotes.ClassicDance",
    "ReplicatedStorage.Items.ItemPacks.EventsDailyShop.OldRoblox.Emotes.ClassicJeep",
    "ReplicatedStorage.Items.ItemPacks.EventsDailyShop.OldRoblox.Emotes.ClassicStride",
    "ReplicatedStorage.Items.ItemPacks.EventsDailyShop.OldRoblox.Emotes.FastFoodDelight",
    "ReplicatedStorage.Items.ItemPacks.EventsDailyShop.OldRoblox.Emotes.PotionMash",
    "ReplicatedStorage.Items.ItemPacks.EventsDailyShop.OldRoblox.Emotes.RainingTacos",
    "ReplicatedStorage.Items.ItemPacks.EventsDailyShop.OldRoblox.Emotes.SkateboardStroll",

    -- Thanks Giving 2025
    "ReplicatedStorage.Items.ItemPacks.EventsDailyShop.Thanksgiving2025.Emotes.TurkeyJockey",

    -- Bee Set
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.BeeSet.Emotes.QueensAppearance",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.BeeSet.Emotes.RegalWalk",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.BeeSet.Emotes.WingedRoyalSit",

    -- Posseidon Set
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.PoseidonSet.Emotes.MountedSeahorse",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.PoseidonSet.Emotes.NeptunesThrone",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.PoseidonSet.Emotes.ShellHermit",

    -- Relic Emotes New
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.RelicEmotesNew.Emotes.AstroSlide",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.RelicEmotesNew.Emotes.BananaDance",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.RelicEmotesNew.Emotes.CrabRave",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.RelicEmotesNew.Emotes.CuddleBearSit",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.RelicEmotesNew.Emotes.HitTheJackpot",

    -- Glorp Set
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.GlorpSet.Emotes.GlorpHoverboard",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.2026.GlorpSet.Emotes.GlorpMech",

    -- Military
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Legacy.Military.Emotes.Rocket",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Legacy.Military.Emotes.Tank",

    -- St Patricks 2023
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Legacy.StPatricks2023.Emotes.MarchShowcase",

    -- Animals
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.Animals.Emotes.DuckyMarch",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.Animals.Emotes.Sleepybara",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.Animals.Emotes.TurtleHobble",

    -- Cats
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.Cats.Emotes.CatParty",

    -- Dog Set
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.DogSet.Emotes.DogParty",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.DogSet.Emotes.FreshFlop",

    -- Eclipse Set
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.EclipseSet.Emotes.SolarBike",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.EclipseSet.Emotes.SolarConqueror",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.EclipseSet.Emotes.SolarSlayer",

    -- Emote Pack
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.EmotePack.Emotes.Boneless",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.EmotePack.Emotes.Gangnam",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.EmotePack.Emotes.Griddy",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.EmotePack.Emotes.LDance",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.EmotePack.Emotes.Macarena",

    -- Gems
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.Gems.Emotes.HoveringCrystal",

    -- Lunar New Year Set
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.LunarNewYearSet.Emotes.FlyingFish",

    -- Music Emote Pack 1
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.MusicEmotesPack1.Emotes.Caffeinated",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.MusicEmotesPack1.Emotes.CatDance",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.MusicEmotesPack1.Emotes.Frolic",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.MusicEmotesPack1.Emotes.OiiaOiia",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.MusicEmotesPack1.Emotes.Wess",

    -- Relic Emotes Vaulted
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.RelicEmotesVaulted.Emotes.Bumblebee",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.RelicEmotesVaulted.Emotes.RockefellerStreet",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.RelicEmotesVaulted.Emotes.ShubaDance",
    "ReplicatedStorage.Items.ItemPacks.Gamepass.Unorganized.RelicEmotesVaulted.Emotes.Twist",

    -- Megan
    "ReplicatedStorage.Items.ItemPacks.Integration.M3GAN.Emotes.M3GANDance",
    "ReplicatedStorage.Items.ItemPacks.Integration.M3GAN.Emotes.RobotM3GAN",
}

-- Pasangan khusus: emote ini hanya boleh ditukar dengan pasangannya (kunci = nama instance).
local WHITELIST = {
    RockinStride = "Kickback",
    Kickback = "RockinStride",
    ZombieStride = "ClassicDance",
    ClassicDance = "ZombieStride",
}

local emotes = {}         -- { { Name, Display, Instance } } terurut menurut nama
local byInstance = {}     -- [instance] = entry
local swapped = {}        -- [instance] = instance pasangannya (sedang tertukar)
local originals = {}      -- [instance] = isi asli (salinan anak-anaknya)

-- "RockinStride" -> "Rockin Stride"
local function SpacedName(name)
    return (name:gsub("(%l)(%u)", "%1 %2"))
end
VisualEmotes.SpacedName = SpacedName

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

-- Daftar emote ditemukan sekali. Sumber utama adalah Registry milik game (kategori "Emotes"): daftarnya
-- selalu mengikuti update game, nama tampilannya sama dengan di menu, dan tiap emote punya Header
-- ("Normal", "Halloween", ...). Kalau Registry tidak bisa dipakai (executor tanpa require, game
-- berubah), dipakai daftar PATHS di atas.
local loaded = false
local source = "none"

local function AddEntry(instance, display, header, id)
    if byInstance[instance] then return end
    local entry = { Name = instance.Name, Display = display or SpacedName(instance.Name), Header = header or "Other", Id = id, Instance = instance }
    table.insert(emotes, entry)
    byInstance[instance] = entry
end

local function LoadFromRegistry()
    local items = ReplicatedStorage:FindFirstChild("Items")
    local registryModule = items and items:FindFirstChild("Registry")
    if not registryModule then return false end

    local ok, Registry = pcall(require, registryModule)
    if not ok or type(Registry) ~= "table" or type(Registry.GetByCategory) ~= "function" then return false end

    local okList, list = pcall(Registry.GetByCategory, "Emotes")
    if not okList or type(list) ~= "table" then return false end

    for id, record in pairs(list) do
        local module = type(record) == "table" and record.Module
        if typeof(module) == "Instance" then
            local info
            local okInfo, result = pcall(require, module)
            if okInfo and type(result) == "table" then info = result end
            local display = info and info.AppearanceInfo and info.AppearanceInfo.Name
            local header = info and info.UIInfo and info.UIInfo.Header
            AddEntry(module, type(display) == "string" and display or nil, type(header) == "string" and header or nil, id)
        end
    end
    return #emotes > 0
end

local function LoadFromPaths()
    for _, path in ipairs(PATHS) do
        local instance = ResolvePath(path)
        if instance then AddEntry(instance) end
    end
end

function VisualEmotes.Load()
    if loaded then return #emotes end
    loaded = true

    if not ReplicatedStorage:FindFirstChild("Items") then
        pcall(function() ReplicatedStorage:WaitForChild("Items", 8) end)
    end

    if LoadFromRegistry() then
        source = "registry"
    else
        table.clear(emotes)
        table.clear(byInstance)
        LoadFromPaths()
        source = "paths"
    end

    table.sort(emotes, function(a, b)
        return string.lower(a.Display) < string.lower(b.Display)
    end)
    return #emotes
end

-- "registry" (daftar dari game), "paths" (daftar bawaan hub) atau "none"
function VisualEmotes.GetSource()
    return source
end

function VisualEmotes.GetEmotes()
    return emotes
end

-- Nama pasangan wajib dari emote ini, atau nil kalau bebas.
function VisualEmotes.GetWhitelist(entry)
    return entry and WHITELIST[entry.Name] or nil
end

-- Emote yang sedang tertukar dengan `entry` (entry atau nil).
function VisualEmotes.GetPartner(entry)
    local partner = entry and swapped[entry.Instance]
    return partner and byInstance[partner] or nil
end

-- 1 = belum bisa (pilihan kurang / salah satu sudah tertukar dengan emote lain)
-- 2 = bisa ditukar
-- 3 = pasangan yang sudah tertukar (tombol berubah jadi Revert)
function VisualEmotes.GetState(base, target)
    if not base or not target or base == target then return 1 end
    if swapped[base.Instance] == target.Instance then return 3 end
    if swapped[base.Instance] ~= nil or swapped[target.Instance] ~= nil then return 1 end
    return 2
end

local function CacheOriginal(emote)
    if not originals[emote] then
        originals[emote] = {}
        for _, child in ipairs(emote:GetChildren()) do
            table.insert(originals[emote], child:Clone())
        end
    end
end

-- Isi `targetEmote` diganti dengan isi asli `sourceEmote`.
local function InjectContents(targetEmote, sourceEmote)
    for _, child in ipairs(targetEmote:GetChildren()) do
        child:Destroy()
    end
    for _, child in ipairs(originals[sourceEmote]) do
        child:Clone().Parent = targetEmote
    end
end

-- Mengembalikan true, pesan atau false, alasan.
function VisualEmotes.Swap(base, target)
    if VisualEmotes.GetState(base, target) ~= 2 then
        return false, "Please make sure you picked a valid Base and Target emote."
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

function VisualEmotes.Revert(base, target)
    if VisualEmotes.GetState(base, target) ~= 3 then
        return false, "These two emotes are not swapped."
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

-- Mengembalikan semua emote yang tertukar. Hasil: jumlah pasangan yang dipulihkan, dan daftar emote-nya.
function VisualEmotes.RevertAll()
    local restored, touched = 0, {}
    for instance, partner in pairs(table.clone(swapped)) do
        if swapped[instance] == partner then
            local entry, other = byInstance[instance], byInstance[partner]
            if entry and other and VisualEmotes.Revert(entry, other) then
                restored = restored + 1
                table.insert(touched, entry)
                table.insert(touched, other)
            end
        end
    end
    return restored, touched
end

function VisualEmotes.SwappedCount()
    local count = 0
    for _ in pairs(swapped) do count = count + 1 end
    return count // 2
end

-- Saat hub dimatikan semua emote dikembalikan, supaya tidak ada yang tertinggal tertukar.
getgenv().MugiwaraRegisterCleanup(function()
    pcall(VisualEmotes.RevertAll)
end)

return VisualEmotes
