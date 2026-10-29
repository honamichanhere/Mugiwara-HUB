-- Visual Emotes untuk Evade: menukar isi dua emote supaya satu emote tampil/bermain seperti yang lain.
-- Logikanya ada di VisualSwap.lua (dipakai juga oleh Visual Carry); di sini hanya daftar cadangan dan aturan
-- khusus emote. Modul ini tanpa UI; antarmukanya ada di VisualEmotesUI.lua.
local VisualSwap = getgenv().MugiwaraImport("Games/Evade/VisualSwap.lua")

-- Path seluruh emote (dari Visual-Emotes), dipakai kalau Registry game tidak bisa dibaca. Emote yang tidak
-- ada di versi game ini dilewati.
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

local VisualEmotes = VisualSwap({ Category = "Emotes", Paths = PATHS, Whitelist = WHITELIST, Noun = "emote" })

-- Nama lama yang dipakai UI Visual Emotes.
VisualEmotes.GetEmotes = VisualEmotes.GetEntries

return VisualEmotes
