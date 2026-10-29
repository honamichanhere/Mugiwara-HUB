local LightingModule = {}

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local ROOT = getgenv().MugiwaraFolder or "MugiwaraHub"
local PREFIX = "Mugiwara_" -- semua instance yang dibuat modul ini memakai prefix ini

if makefolder and isfolder then
    if not isfolder(ROOT) then makefolder(ROOT) end
    if not isfolder(ROOT .. "/Presets") then makefolder(ROOT .. "/Presets") end
end

LightingModule.BuiltInPresets = {
    ["Default Roblox"] = {
        Desc = "Roblox default Lighting.",
        Skybox = "18504982898",
        Values = {
            Lighting = {
                Ambient = Color3.fromRGB(70, 70, 70),
                Brightness = 3,
                ColorShift_Top = Color3.fromRGB(0, 0, 0),
                ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
                EnvironmentDiffuseScale = 1,
                EnvironmentSpecularScale = 1,
                GlobalShadows = true,
                OutdoorAmbient = Color3.fromRGB(70, 70, 70),
                ClockTime = 14.5,
                ExposureCompensation = 0
            },
            Atmosphere = {
                Density = 0.3,
                Offset = 0.25,
                Color = Color3.fromRGB(199, 199, 199),
                Decay = Color3.fromRGB(106, 112, 125),
                Glare = 0,
                Haze = 0
            },
            Bloom = {
                Enabled = true,
                Intensity = 1,
                Size = 24,
                Threshold = 2
            },
            Blur = {
                Enabled = false,
                Size = 24
            },
            DepthOfField = {
                Enabled = false,
                FarIntensity = 0.1,
                FocusDistance = 0.05,
                InFocusRadius = 30,
                NearIntensity = 0.75
            },
            SunRays = {
                Enabled = true,
                Intensity = 0.01,
                Spread = 0.1
            }
        }
    },
    ["Golden Sunset"] = {
        Desc = "Golden hour warm, thin fog of skybox colors.",
        Skybox = "5186800496",
        Values = {
            Lighting = {
                Ambient = Color3.fromRGB(105, 85, 92),
                Brightness = 2.4,
                ColorShift_Top = Color3.fromRGB(255, 170, 110),
                ColorShift_Bottom = Color3.fromRGB(70, 50, 80),
                EnvironmentDiffuseScale = 0.9,
                EnvironmentSpecularScale = 0.8,
                GlobalShadows = true,
                OutdoorAmbient = Color3.fromRGB(135, 108, 115),
                ShadowSoftness = 0.35,
                ClockTime = 17,
                GeographicLatitude = 15,
                ExposureCompensation = -0.1
            },
            Atmosphere = {
                Density = 0.36,
                Offset = 0.35,
                Color = Color3.fromRGB(225, 175, 150),
                Decay = Color3.fromRGB(150, 90, 80),
                Glare = 0.2,
                Haze = 0
            },
            Bloom = {
                Enabled = true,
                Intensity = 2,
                Size = 56,
                Threshold = 3
            },
            Blur = {
                Enabled = false,
                Size = 4
            },
            ColorCorrection = {
                Enabled = true,
                Brightness = 0,
                Contrast = 0.12,
                Saturation = -0.05,
                TintColor = Color3.fromRGB(255, 238, 225)
            },
            DepthOfField = {
                Enabled = true,
                FarIntensity = 0.15,
                FocusDistance = 50,
                InFocusRadius = 0,
                NearIntensity = 0
            },
            SunRays = {
                Enabled = true,
                Intensity = 0.08,
                Spread = 0.7
            }
        }
    },
    ["Toxic Haze"] = {
        Desc = "Poisonous green fog fills the atmosphere.",
        Skybox = "83611956387764",
        Values = {
            Lighting = {
                Ambient = Color3.fromRGB(100, 97, 96),
                Brightness = 2.6,
                ClockTime = 12,
                ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
                ColorShift_Top = Color3.fromRGB(0, 0, 0),
                EnvironmentDiffuseScale = 0.9,
                EnvironmentSpecularScale = 0.6,
                ExposureCompensation = 0.1,
                GeographicLatitude = 0,
                GlobalShadows = true,
                OutdoorAmbient = Color3.fromRGB(107, 103, 102),
                ShadowSoftness = 0.2,
            },
            Atmosphere = {
                Color = Color3.fromRGB(109, 139, 93),
                Decay = Color3.fromRGB(117, 125, 65),
                Density = 0.45,
                Glare = 0.1,
                Haze = 2.4,
                Offset = 0.3
            },
            Bloom = {
                Enabled = true,
                Intensity = 2,
                Size = 56,
                Threshold = 3
            },
            Blur = {
                Enabled = false,
                Size = 14
            },
            ColorCorrection = {
                Brightness = 0.01,
                Contrast = 0.07,
                Enabled = true,
                Saturation = 0.05,
                TintColor = Color3.fromRGB(255, 255, 255)
            },
            DepthOfField = {
                Enabled = true,
                FarIntensity = 0.15,
                FocusDistance = 50,
                InFocusRadius = 0,
                NearIntensity = 0
            },
            SunRays = {
                Enabled = false,
                Intensity = 0,
                Spread = 0
            },
            Sky = {
                CelestialBodiesShown = false,
                MoonAngularSize = 11,
                StarCount = 3000,
                SunAngularSize = 0,
            },
            Clouds = {
                Color = Color3.fromRGB(255, 255, 255),
                Cover = 0.5,
                Density = 0.7,
                Enabled = false
            }
        }
    },
    ["Arcane Mist"] = {
        Desc = "Mystical green mist infused with ancient magic.",
        Skybox = "106789459824445",
        Values = {
            Lighting = {
                Ambient = Color3.fromRGB(131, 126, 121),
                Brightness = 4,
                ClockTime = 21,
                ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
                ColorShift_Top = Color3.fromRGB(203, 190, 255),
                EnvironmentDiffuseScale = 0.9,
                EnvironmentSpecularScale = 0.6,
                ExposureCompensation = 0.15,
                GeographicLatitude = -13,
                GlobalShadows = true,
                OutdoorAmbient = Color3.fromRGB(126, 123, 122),
                ShadowSoftness = 0.2,
            },
            Atmosphere = {
                Color = Color3.fromRGB(82, 216, 104),
                Decay = Color3.fromRGB(8, 18, 212),
                Density = 0.39,
                Glare = 0.25,
                Haze = 2.1,
                Offset = 0.3
            },
            Bloom = {
                Enabled = true,
                Intensity = 2,
                Size = 56,
                Threshold = 3
            },
            Blur = {
                Enabled = false,
                Size = 14
            },
            ColorCorrection = {
                Brightness = 0.03,
                Contrast = 0.13,
                Enabled = true,
                Saturation = 0.1,
                TintColor = Color3.fromRGB(243, 249, 255)
            },
            DepthOfField = {
                Enabled = true,
                FarIntensity = 0.15,
                FocusDistance = 50,
                InFocusRadius = 0,
                NearIntensity = 0
            },
            SunRays = {
                Enabled = false,
                Intensity = 0.02,
                Spread = 0.4
            },
            Sky = {
                CelestialBodiesShown = false,
                MoonAngularSize = 20,
                StarCount = 1500,
                SunAngularSize = 0,
            },
            Clouds = {
                Color = Color3.fromRGB(255, 255, 255),
                Cover = 0.5,
                Density = 0.7,
                Enabled = false
            }
        }
    },
    ["Arctic Daylight"] = {
        Desc = "Crisp blue daylight illuminates a frozen landscape.",
        Skybox = "106789459824445",
        Values = {
            Lighting = {
                Ambient = Color3.fromRGB(92, 99, 107),
                Brightness = 2,
                ClockTime = 15.77,
                ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
                ColorShift_Top = Color3.fromRGB(0, 0, 0),
                EnvironmentDiffuseScale = 0.7,
                EnvironmentSpecularScale = 0.7,
                ExposureCompensation = 0.05,
                GeographicLatitude = -19.18,
                GlobalShadows = true,
                OutdoorAmbient = Color3.fromRGB(99, 105, 112),
                ShadowSoftness = 0.2,
            },
            Atmosphere = {
                Color = Color3.fromRGB(207, 225, 255),
                Decay = Color3.fromRGB(215, 230, 247),
                Density = 0.36,
                Glare = 0.1,
                Haze = 2.1,
                Offset = 0.25
            },
            Bloom = {
                Enabled = true,
                Intensity = 2,
                Size = 56,
                Threshold = 3
            },
            Blur = {
                Enabled = false,
                Size = 0
            },
            ColorCorrection = {
                Brightness = 0,
                Contrast = 0.08,
                Enabled = true,
                Saturation = 0.1,
                TintColor = Color3.fromRGB(216, 234, 255)
            },
            DepthOfField = {
                Enabled = true,
                FarIntensity = 0.15,
                FocusDistance = 50,
                InFocusRadius = 0,
                NearIntensity = 0
            },
            SunRays = {
                Enabled = true,
                Intensity = 0.05,
                Spread = 0.6
            },
            Sky = {
                CelestialBodiesShown = false,
                MoonAngularSize = 11,
                StarCount = 5000,
                SunAngularSize = 0,
            },
            Clouds = {
                Color = Color3.fromRGB(255, 255, 255),
                Cover = 0.5,
                Density = 0.7,
                Enabled = false
            }
        }
    },
    ["Glacial Nebula"] = {
        Desc = "A nebula glows over the frozen night.",
        Skybox = "90061645917520",
        Values = {
            Lighting = {
                Ambient = Color3.fromRGB(92, 99, 107),
                Brightness = 2,
                ClockTime = 7,
                ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
                ColorShift_Top = Color3.fromRGB(0, 0, 0),
                EnvironmentDiffuseScale = 0.7,
                EnvironmentSpecularScale = 0.7,
                ExposureCompensation = 0.2,
                GeographicLatitude = 0,
                GlobalShadows = true,
                OutdoorAmbient = Color3.fromRGB(99, 105, 112),
                ShadowSoftness = 0.2,
            },
            Atmosphere = {
                Color = Color3.fromRGB(207, 207, 255),
                Decay = Color3.fromRGB(217, 215, 247),
                Density = 0.4,
                Glare = 0.1,
                Haze = 2.1,
                Offset = 0
            },
            Bloom = {
                Enabled = true,
                Intensity = 2,
                Size = 56,
                Threshold = 3
            },
            Blur = {
                Enabled = false,
                Size = 0
            },
            ColorCorrection = {
                Brightness = 0,
                Contrast = 0.08,
                Enabled = true,
                Saturation = 0.1,
                TintColor = Color3.fromRGB(216, 216, 255)
            },
            DepthOfField = {
                Enabled = true,
                FarIntensity = 0.15,
                FocusDistance = 50,
                InFocusRadius = 0,
                NearIntensity = 0
            },
            SunRays = {
                Enabled = true,
                Intensity = 0.1,
                Spread = 1
            },
            Sky = {
                CelestialBodiesShown = false,
                MoonAngularSize = 11,
                StarCount = 3000,
                SunAngularSize = 0,
            },
            Clouds = {
                Color = Color3.fromRGB(255, 255, 255),
                Cover = 0.5,
                Density = 0.7,
                Enabled = false
            }
        }
    },
    ["Crimson Hell"] = {
        Desc = "Burning red fog under a meteor-filled sky.",
        Skybox = "138481177761557",
        Values = {
            Lighting = {
                Ambient = Color3.fromRGB(135, 103, 154),
                Brightness = 2,
                ClockTime = 12,
                ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
                ColorShift_Top = Color3.fromRGB(209, 159, 255),
                EnvironmentDiffuseScale = 0.8,
                EnvironmentSpecularScale = 0.8,
                ExposureCompensation = 0.15,
                GeographicLatitude = 0,
                GlobalShadows = true,
                OutdoorAmbient = Color3.fromRGB(86, 86, 86),
                ShadowSoftness = 0.2,
            },
            Atmosphere = {
                Color = Color3.fromRGB(66, 35, 71),
                Decay = Color3.fromRGB(144, 59, 59),
                Density = 0.38,
                Glare = 2,
                Haze = 2.2,
                Offset = 0.2
            },
            Bloom = {
                Enabled = true,
                Intensity = 2,
                Size = 56,
                Threshold = 3
            },
            Blur = {
                Enabled = false,
                Size = 14
            },
            ColorCorrection = {
                Brightness = 0,
                Contrast = 0.2,
                Enabled = true,
                Saturation = 0,
                TintColor = Color3.fromRGB(255, 249, 248)
            },
            DepthOfField = {
                Enabled = true,
                FarIntensity = 0.15,
                FocusDistance = 50,
                InFocusRadius = 0,
                NearIntensity = 0
            },
            SunRays = {
                Enabled = false,
                Intensity = 0,
                Spread = 0
            },
            Sky = {
                CelestialBodiesShown = false,
                MoonAngularSize = 11,
                StarCount = 5000,
                SunAngularSize = 0,
            },
            Clouds = {
                Color = Color3.fromRGB(255, 255, 255),
                Cover = 0.5,
                Density = 0.7,
                Enabled = false
            }
        }
    }
}

LightingModule.LockEnabled = false
LightingModule.DefaultSkybox = nil 
LightingModule.ActiveSkybox = nil 
LightingModule.OnPresetLoaded = nil
LightingModule.OnPropertyChanged = nil
LightingModule.LastObserve = 0

LightingModule.Objects = { Lighting = Lighting }
LightingModule.Defaults = {} 
LightingModule.TargetValues = {} 

LightingModule.Limits = {
    Lighting = { Brightness = {Min = 0, Max = 10}, EnvironmentDiffuseScale = {Min = 0, Max = 1}, EnvironmentSpecularScale = {Min = 0, Max = 1}, ShadowSoftness = {Min = 0, Max = 1}, ClockTime = {Min = 0, Max = 24}, GeographicLatitude = {Min = -90, Max = 90}, ExposureCompensation = {Min = -3, Max = 3} },
    Atmosphere = { Density = {Min = 0, Max = 1}, Offset = {Min = 0, Max = 1}, Glare = {Min = 0, Max = 10}, Haze = {Min = 0, Max = 10} },
    Bloom = { Intensity = {Min = 0, Max = 10}, Size = {Min = 0, Max = 56}, Threshold = {Min = 0, Max = 10} },
    Blur = { Size = {Min = 0, Max = 56} },
    ColorCorrection = { Brightness = {Min = -1, Max = 1}, Contrast = {Min = -1, Max = 1}, Saturation = {Min = -1, Max = 1} },
    DepthOfField = { FarIntensity = {Min = 0, Max = 1}, FocusDistance = {Min = 0, Max = 500}, InFocusRadius = {Min = 0, Max = 50}, NearIntensity = {Min = 0, Max = 1} },
    SunRays = { Intensity = {Min = 0, Max = 1}, Spread = {Min = 0, Max = 1} },
    Clouds = { Cover = {Min = 0, Max = 1}, Density = {Min = 0, Max = 1} }
}

LightingModule.TrackedProperties = {
    Lighting = {"Ambient", "Brightness", "ColorShift_Top", "ColorShift_Bottom", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows", "OutdoorAmbient", "ShadowSoftness", "ClockTime", "GeographicLatitude", "ExposureCompensation"},
    Atmosphere = {"Density", "Offset", "Color", "Decay", "Glare", "Haze"},
    Bloom = {"Enabled", "Intensity", "Size", "Threshold"},
    Blur = {"Enabled", "Size"},
    ColorCorrection = {"Enabled", "Brightness", "Contrast", "Saturation", "TintColor"},
    DepthOfField = {"Enabled", "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity"},
    SunRays = {"Enabled", "Intensity", "Spread"},
    Clouds = {"Enabled", "Cover", "Density", "Color"}
}

-- Daftar skybox untuk dropdown, urutannya dipakai apa adanya. Id-nya adalah model Sky (dimuat lewat GetObjects).
local SKYBOXES = {
    { "Default Sky", "" },
    { "Sunset", "5186800496" },
    { "Starry Night", "143962526" },
    { "Red Castle", "15832476802" },
    { "Red Night", "5834531764" },
    { "Red Meteor", "138481177761557" },
    { "Dark Green", "83611956387764" },
    { "Sunless Blue", "591067775" },
    { "Cartoon", "15387348852" },
    { "Cartoon Clouds", "90729405148185" },
    { "Anime Stylized", "99154845659277" },
    { "Sky Blue Cartoon", "106789459824445" },
    { "Clear Sky", "96508044206629" },
    { "Space Blue", "90061645917520" },
    { "Space Rock", "106776038523022" },
    { "Dark Pink", "129373192920324" },
    { "Galaxy Stars", "140207311615666" },
}
LightingModule.SkyboxOrder = {}    -- nama, sesuai urutan di atas
LightingModule.SkyboxDatabase = {} -- nama -> id
for _, entry in ipairs(SKYBOXES) do
    table.insert(LightingModule.SkyboxOrder, entry[1])
    LightingModule.SkyboxDatabase[entry[1]] = entry[2]
end
LightingModule.SkyAnimEnabled = false
LightingModule.SkyAnimSpeed = 10
LightingModule.SunHidden = false

-- Volumetric clouds: objek Clouds hidup di Workspace.Terrain (bukan di Lighting). Hanya satu objek
-- yang dipakai dan itu SELALU buatan hub (Mugiwara_Clouds, default Enabled = false). Clouds milik game
-- (yang bisa membawa attribute/skrip lokal yang menimpa nilainya) dibuang begitu ketemu, termasuk yang
-- muncul belakangan; objeknya disimpan (clone) dan dikembalikan saat hub di-unload.
local function GetTerrain()
    return workspace:FindFirstChildOfClass("Terrain")
end

local function IsOurs(instance)
    return string.sub(instance.Name, 1, #PREFIX) == PREFIX
end

LightingModule.RemovedClouds = nil -- clone Clouds milik game pertama yang dibuang

local function RemoveForeignClouds(child)
    if not LightingModule.RemovedClouds then
        pcall(function()
            local wasArchivable = child.Archivable
            child.Archivable = true
            LightingModule.RemovedClouds = child:Clone()
            child.Archivable = wasArchivable
        end)
    end
    child:Destroy()
end

-- Membuat Clouds hub. Kalau user sudah mengatur nilainya (TargetValues), nilai itu dipasang lagi
-- supaya pengaturan tidak hilang saat objeknya dibuat ulang.
local function CreateOurClouds(terrain)
    local clouds = Instance.new("Clouds")
    clouds.Name = PREFIX .. "Clouds"
    clouds.Enabled = false

    local target = LightingModule.TargetValues.Clouds
    if target then
        for propName, value in pairs(target) do
            pcall(function() clouds[propName] = value end)
        end
    end

    clouds.Parent = terrain
    return clouds
end

function LightingModule.Init()
    local requiredEffects = { Atmosphere = "Atmosphere", Bloom = "BloomEffect", Blur = "BlurEffect", ColorCorrection = "ColorCorrectionEffect", DepthOfField = "DepthOfFieldEffect", SunRays = "SunRaysEffect" }

    for key, className in pairs(requiredEffects) do
        local effect = Lighting:FindFirstChildOfClass(className)
        if not effect then
            effect = Instance.new(className)
            effect.Name = PREFIX .. className
            if effect:IsA("PostEffect") then 
                effect.Enabled = false 
            end
            effect.Parent = Lighting
        end
        LightingModule.Objects[key] = effect
    end

    local terrain = GetTerrain()
    if terrain then
        local ours = nil
        for _, child in ipairs(terrain:GetChildren()) do
            if child.ClassName == "Clouds" then
                if IsOurs(child) and not ours then
                    ours = child
                elseif IsOurs(child) then
                    child:Destroy()
                else
                    RemoveForeignClouds(child)
                end
            end
        end
        LightingModule.Objects.Clouds = ours or CreateOurClouds(terrain)
    end

    for category, properties in pairs(LightingModule.TrackedProperties) do
        LightingModule.Defaults[category] = {}
        LightingModule.TargetValues[category] = {}

        local obj = LightingModule.Objects[category]
        if obj then
            for _, propName in ipairs(properties) do
                LightingModule.Defaults[category][propName] = obj[propName]
                LightingModule.TargetValues[category][propName] = obj[propName]
            end
        end
    end

    local originalSky = Lighting:FindFirstChildOfClass("Sky")
    if originalSky then
        LightingModule.DefaultSkybox = {
            SkyboxBk = originalSky.SkyboxBk, SkyboxDn = originalSky.SkyboxDn, SkyboxFt = originalSky.SkyboxFt,
            SkyboxLf = originalSky.SkyboxLf, SkyboxRt = originalSky.SkyboxRt, SkyboxUp = originalSky.SkyboxUp,
            SunTextureId = originalSky.SunTextureId, MoonTextureId = originalSky.MoonTextureId, StarCount = originalSky.StarCount,
            CelestialBodiesShown = originalSky.CelestialBodiesShown, SunAngularSize = originalSky.SunAngularSize, MoonAngularSize = originalSky.MoonAngularSize
        }
        LightingModule.ActiveSkybox = LightingModule.DefaultSkybox
    end
end
LightingModule.Init()

function LightingModule.UpdateValue(category, property, value)
    if LightingModule.TargetValues[category] then
        LightingModule.TargetValues[category][property] = value
        
        if not LightingModule.IsSyncing and not LightingModule.LockEnabled then
            local obj = LightingModule.Objects[category]
            if obj then pcall(function() obj[property] = value end) end
        end
    end
end

function LightingModule.ToggleEffect(category, isEnabled)
    LightingModule.UpdateValue(category, "Enabled", isEnabled)
end

-- Hide Sun: Sky.CelestialBodiesShown = false (matahari dan bulan tidak digambar) ditambah
-- SunAngularSize = 0 dan SunTextureId kosong. Nilainya dijaga tiap frame di loop render (skybox
-- lain, preset, Lock Lighting, atau game bisa menimpanya). Sun Rays adalah efek terpisah dan tidak
-- ikut disembunyikan.
local DEFAULT_SUN_SIZE = 21
local DEFAULT_SUN_TEXTURE = "rbxasset://sky/sun.jpg"

local function GetOrCreateSky()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then
        sky = Instance.new("Sky")
        sky.Name = PREFIX .. "Sky"
        sky.Parent = Lighting
    end
    return sky
end

-- Nilai matahari yang SEHARUSNYA (tanpa efek Hide Sun): dari skybox aktif, atau default Roblox.
-- Mengembalikan: ukuran, tekstur, CelestialBodiesShown.
local function UnhiddenSunValues()
    local source = LightingModule.ActiveSkybox or LightingModule.DefaultSkybox
    local bodies = true
    if source and source.CelestialBodiesShown ~= nil then bodies = source.CelestialBodiesShown end
    return (source and source.SunAngularSize) or DEFAULT_SUN_SIZE, (source and source.SunTextureId) or DEFAULT_SUN_TEXTURE, bodies
end

function LightingModule.SetSunHidden(state)
    state = state == true
    LightingModule.SunHidden = state

    local sky = state and GetOrCreateSky() or Lighting:FindFirstChildOfClass("Sky")
    if not sky then return end

    pcall(function()
        if state then
            sky.CelestialBodiesShown = false
            sky.SunAngularSize = 0
            sky.SunTextureId = ""
        else
            local size, texture, bodies = UnhiddenSunValues()
            sky.CelestialBodiesShown = bodies
            sky.SunAngularSize = size
            sky.SunTextureId = texture
        end
    end)
end

-- ---------- Sinkron nilai milik game ----------
-- TargetValues / Defaults / ActiveSkybox adalah snapshot. Snapshot yang basi lalu dipaksakan oleh
-- Lock Lighting membuat langit atau efek berubah sendiri, jadi snapshot diambil ulang saat perlu.

local function SnapshotSky(sky)
    local snapshot = {
        SkyboxBk = sky.SkyboxBk, SkyboxDn = sky.SkyboxDn, SkyboxFt = sky.SkyboxFt,
        SkyboxLf = sky.SkyboxLf, SkyboxRt = sky.SkyboxRt, SkyboxUp = sky.SkyboxUp,
        SunTextureId = sky.SunTextureId, MoonTextureId = sky.MoonTextureId, StarCount = sky.StarCount,
        CelestialBodiesShown = sky.CelestialBodiesShown, SunAngularSize = sky.SunAngularSize, MoonAngularSize = sky.MoonAngularSize
    }
    -- Matahari yang sedang disembunyikan tidak boleh ikut tersimpan sebagai nilai aslinya.
    if LightingModule.SunHidden then
        snapshot.SunAngularSize, snapshot.SunTextureId, snapshot.CelestialBodiesShown = UnhiddenSunValues()
    end
    return snapshot
end

-- Ambil nilai objek yang sekarang untuk satu kategori. updateDefaults = true juga memperbarui nilai
-- default (dipakai preset "Default" dan pemulihan saat hub di-unload). UI diberi tahu lewat OnPropertyChanged.
local function ResyncCategory(category, updateDefaults, notify)
    local obj = LightingModule.Objects[category]
    local properties = LightingModule.TrackedProperties[category]
    if not obj or not properties then return end

    LightingModule.TargetValues[category] = LightingModule.TargetValues[category] or {}
    LightingModule.Defaults[category] = LightingModule.Defaults[category] or {}

    for _, propName in ipairs(properties) do
        local ok, value = pcall(function() return obj[propName] end)
        if ok and value ~= nil then
            LightingModule.TargetValues[category][propName] = value
            if updateDefaults then LightingModule.Defaults[category][propName] = value end
            if notify and LightingModule.OnPropertyChanged then
                pcall(LightingModule.OnPropertyChanged, category, propName, value)
            end
        end
    end
end

-- Objek untuk satu kategori diganti. Kalau yang lama buatan hub (prefix Mugiwara_) dan yang baru milik
-- game, nilai milik game yang dipakai; snapshot lama dari objek buatan hub tidak boleh ditimpakan
-- ke objek game (itu yang membuat awan/efek game berubah sendiri saat Lock Lighting menyala).
local function AdoptObject(category, newObj)
    local previous = LightingModule.Objects[category]
    if previous == newObj then return end
    LightingModule.Objects[category] = newObj

    if previous and string.sub(previous.Name, 1, #PREFIX) == PREFIX and string.sub(newObj.Name, 1, #PREFIX) ~= PREFIX then
        ResyncCategory(category, true, true)
    end
end

-- Lock Lighting. Saat dinyalakan, kondisi yang sedang terlihat diambil dulu supaya yang dikunci adalah
-- tampilan sekarang, bukan snapshot lama dari saat hub di-execute.
function LightingModule.SetLock(state)
    state = state == true
    if state and not LightingModule.LockEnabled then
        for category in pairs(LightingModule.TrackedProperties) do
            ResyncCategory(category, false, false)
        end

        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then LightingModule.ActiveSkybox = SnapshotSky(sky) end
    end
    LightingModule.LockEnabled = state
end

-- ---------- Skybox ----------
local SKY_FIELDS = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId", "StarCount", "CelestialBodiesShown", "SunAngularSize", "MoonAngularSize" }

local function SnapshotFields(source)
    local snapshot = {}
    for _, field in ipairs(SKY_FIELDS) do snapshot[field] = source[field] end
    return snapshot
end

-- Muat model Sky dari Roblox lewat asset id dan ambil nilainya. nil kalau gagal (id salah, offline, bukan Sky).
local function SkyDataFromAsset(id)
    id = tostring(id or ""):match("^%s*(%d+)%s*$") -- hanya angka; buang input aneh
    if not id then return nil end
    local success, result = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
    if not (success and result and result[1]) then return nil end

    local asset = result[1]
    local skyObject = asset:IsA("Sky") and asset or asset:FindFirstChildOfClass("Sky")
    local data = skyObject and SnapshotFields(skyObject) or nil
    pcall(function() asset:Destroy() end)
    return data
end

-- Nama skybox di daftar dropdown untuk satu asset id (nil kalau id itu tidak ada di daftar).
local function SkyNameForId(id)
    id = tostring(id or "")
    if id == "" then return nil end
    for _, name in ipairs(LightingModule.SkyboxOrder) do
        if LightingModule.SkyboxDatabase[name] == id then return name end
    end
    return nil
end

-- skyName = nama di daftar skybox (supaya UI bisa menunjukkan yang aktif); nil kalau langitnya dari tempat lain.
local function ApplySkyData(skyData, skyName)
    LightingModule.ActiveSkybox = skyData
    LightingModule.ActiveSkyName = skyName
    local sky = GetOrCreateSky()
    for k, v in pairs(skyData) do pcall(function() sky[k] = v end) end
end

-- Kembali ke langit asli peta (atau tanpa langit kalau petanya memang tidak punya).
local function RestoreDefaultSky()
    if LightingModule.DefaultSkybox then
        ApplySkyData(LightingModule.DefaultSkybox, "Default Sky")
    else
        LightingModule.ActiveSkybox = nil
        LightingModule.ActiveSkyName = "Default Sky"
        local currentSky = Lighting:FindFirstChildOfClass("Sky")
        if currentSky then currentSky:Destroy() end
    end
end

function LightingModule.LoadSkybox(id)
    local data = SkyDataFromAsset(id)
    if data then ApplySkyData(data, SkyNameForId(id)) end
end

-- Gambar pratinjau skybox (thumbnail toko Roblox) untuk dropdown. Satu request untuk semua id.
-- Mengembalikan { [id teks] = url gambar }; kosong kalau gagal. Bisa yield (jalankan di task.spawn).
function LightingModule.FetchSkyboxThumbnails()
    local ids = {}
    for _, name in ipairs(LightingModule.SkyboxOrder) do
        local id = LightingModule.SkyboxDatabase[name]
        if id and id ~= "" then table.insert(ids, id) end
    end
    local thumbnails = {}
    if #ids == 0 then return thumbnails end

    local url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. table.concat(ids, ",") .. "&size=150x150&format=Png&isCircular=false"
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or type(body) ~= "string" then return thumbnails end
    local decodedOk, decoded = pcall(function() return HttpService:JSONDecode(body) end)
    if not (decodedOk and type(decoded) == "table" and type(decoded.data) == "table") then return thumbnails end

    for _, item in ipairs(decoded.data) do
        -- targetId adalah angka: string.format menjaga id panjang (tostring memotong di 14 digit)
        if type(item) == "table" and item.state == "Completed" and type(item.targetId) == "number"
            and type(item.imageUrl) == "string" and item.imageUrl:match("^https://[%w%.]*rbxcdn%.com/") then
            thumbnails[string.format("%.0f", item.targetId)] = item.imageUrl
        end
    end
    return thumbnails
end

-- ---------- Preset ----------
-- Nama preset dipakai sebagai nama file. Buang karakter path ("../", "\", dll) supaya
-- user nggak bisa nulis/baca file di luar folder MugiwaraHub/Presets.
local function SanitizePresetName(name)
    name = tostring(name or ""):gsub("[^%w _%-%.]", ""):gsub("%.%.+", "."):match("^%s*(.-)%s*$")
    return string.sub(name, 1, 40)
end

local function PresetPath(name)
    return ROOT .. "/Presets/" .. name .. ".json"
end

-- Daftar preset untuk dropdown: preset milik user dulu (kalau ada), lalu "Default" (peta asli) dan
-- preset bawaan. Tiap item { Title, Desc, Icon }; dropdown mengembalikan Title-nya. Dropdown Mugiwara UI
-- tidak punya pemisah antar kelompok, jadi urutan saja yang membedakan.
function LightingModule.GetPresetsList()
    local list = {}

    if listfiles then
        local ok, files = pcall(listfiles, ROOT .. "/Presets")
        if ok and type(files) == "table" then
            local saved = {}
            for _, file in pairs(files) do
                local name = file:match("([^/\\]+)%.json$")
                if name and name ~= "Default" and not LightingModule.BuiltInPresets[name] then table.insert(saved, name) end
            end
            table.sort(saved)
            for _, name in ipairs(saved) do
                table.insert(list, { Title = name, Desc = "Custom Preset (Saved)", Icon = "lucide:save" })
            end
        end
    end

    table.insert(list, { Title = "Default", Desc = "Restore the map's original lighting.", Icon = "lucide:sun" })

    local builtIn = {}
    for name in pairs(LightingModule.BuiltInPresets) do table.insert(builtIn, name) end
    table.sort(builtIn)
    for _, name in ipairs(builtIn) do
        table.insert(list, { Title = name, Desc = LightingModule.BuiltInPresets[name].Desc, Icon = "lucide:cloudy" })
    end
    return list
end

-- Data preset dalam bentuk seragam: { Values = { kategori = { properti = nilai } }, Sky = tabel langit | nil, KeepSky = bool }.
-- Sky nil berarti "langit asli peta"; KeepSky berarti langit dibiarkan apa adanya (skybox bawaan gagal dimuat).
-- Bisa yield untuk preset bawaan (memuat model Sky). Gagal: nil, pesan.
function LightingModule.GetPresetData(presetName)
    local function CopyValues(source)
        local copy = {}
        for cat, props in pairs(source) do
            copy[cat] = {}
            for k, v in pairs(props) do copy[cat][k] = v end
        end
        return copy
    end

    if presetName == "Default" then
        return { Values = CopyValues(LightingModule.Defaults), Sky = LightingModule.DefaultSkybox, SkyName = "Default Sky" }
    end

    local builtIn = LightingModule.BuiltInPresets[presetName]
    if builtIn then
        local data = { Values = CopyValues(builtIn.Values) }
        if builtIn.Skybox and builtIn.Skybox ~= "" then
            data.Sky = SkyDataFromAsset(builtIn.Skybox)
            data.SkyName = SkyNameForId(builtIn.Skybox)
            data.KeepSky = data.Sky == nil
        end
        return data
    end

    presetName = SanitizePresetName(presetName)
    if presetName == "" then return nil, "Invalid preset name." end
    local path = PresetPath(presetName)
    if not (readfile and isfile and isfile(path)) then return nil, "Preset not found." end
    local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not (success and type(decoded) == "table") then return nil, "The preset file is corrupted." end

    local data = { Values = {}, Sky = decoded.CustomSkybox }
    decoded.CustomSkybox = nil
    -- nama skybox yang dicatat saat preset disimpan (hanya dipakai kalau masih ada di daftar)
    if type(decoded.SkyboxName) == "string" and LightingModule.SkyboxDatabase[decoded.SkyboxName] then
        data.SkyName = decoded.SkyboxName
    end
    for cat, props in pairs(decoded) do
        if type(props) == "table" then
            data.Values[cat] = {}
            for k, v in pairs(props) do
                if type(v) == "table" and v.isColor3 then v = Color3.new(v.R, v.G, v.B) end
                data.Values[cat][k] = v
            end
        end
    end
    return data
end

function LightingModule.ApplyPresetData(data)
    if data.Sky then
        ApplySkyData(data.Sky, data.SkyName)
    elseif not data.KeepSky then
        RestoreDefaultSky()
    end

    for cat, props in pairs(data.Values) do
        if LightingModule.TargetValues[cat] then
            local obj = LightingModule.Objects[cat]
            for k, v in pairs(props) do
                LightingModule.TargetValues[cat][k] = v
                if obj then pcall(function() obj[k] = v end) end
            end
        end
    end
    if LightingModule.OnPresetLoaded then pcall(LightingModule.OnPresetLoaded) end
end

-- Mengembalikan nama skybox (di daftar dropdown) yang sekarang aktif, atau nil kalau tidak diketahui.
function LightingModule.LoadPreset(presetName)
    local data = LightingModule.GetPresetData(presetName)
    if data then LightingModule.ApplyPresetData(data) end
    return LightingModule.ActiveSkyName
end

-- Bentuk file preset: Color3 ditulis { isColor3, R, G, B }, langit di CustomSkybox.
local function ToFileTable(values, skyData)
    local out = {}
    for cat, props in pairs(values) do
        out[cat] = {}
        for k, v in pairs(props) do
            if typeof(v) == "Color3" then
                out[cat][k] = { isColor3 = true, R = v.R, G = v.G, B = v.B }
            else
                out[cat][k] = v
            end
        end
    end
    if skyData then out.CustomSkybox = skyData end
    return out
end

-- Hapus preset tersimpan milik user. Default dan preset bawaan tidak bisa dihapus. Mengembalikan: berhasil, nama (atau pesan gagal).
function LightingModule.DeletePreset(presetName)
    if presetName == "Default" or LightingModule.BuiltInPresets[presetName] then
        return false, "Default and built-in presets cannot be deleted."
    end
    presetName = SanitizePresetName(presetName)
    local path = PresetPath(presetName)
    if presetName == "" or not (isfile and isfile(path)) then return false, "Preset not found." end
    if not delfile then return false, "Your executor does not support delfile." end
    pcall(delfile, path)
    if isfile(path) then return false, "Could not delete the preset file." end
    return true, presetName
end

-- Mengembalikan: berhasil, "New" | "Overwrite" (atau pesan gagal), nama akhir.
function LightingModule.SavePreset(presetName)
    presetName = SanitizePresetName(presetName)
    if presetName == "" then return false, "Invalid preset name." end
    local path = PresetPath(presetName)
    local isOverwrite = (isfile and isfile(path))

    -- SnapshotSky tidak menyimpan matahari yang sedang disembunyikan (Hide Sun adalah toggle sendiri).
    local sky = Lighting:FindFirstChildOfClass("Sky")
    local fileTable = ToFileTable(LightingModule.TargetValues, sky and SnapshotSky(sky) or nil)
    -- nama skybox dari daftar ikut disimpan, tapi hanya kalau langit yang terlihat masih yang itu
    local active = LightingModule.ActiveSkybox
    if sky and active and LightingModule.ActiveSkyName and sky.SkyboxBk == active.SkyboxBk then
        fileTable.SkyboxName = LightingModule.ActiveSkyName
    end
    local data = HttpService:JSONEncode(fileTable)
    if writefile then
        writefile(path, data)
        return true, isOverwrite and "Overwrite" or "New", presetName
    end
    return false, "Your executor does not support writefile."
end

-- ---------- Kode preset (share) ----------
-- Kode = "MWL1:" + base64 (URL-safe, tanpa padding) dari JSON [nama, [nilai...], [langit...] | 0].
-- Nilai disusun menurut posisi di WIRE_LAYOUT / WIRE_SKY, jadi urutan dua daftar ini TIDAK BOLEH diubah:
-- properti baru berarti versi baru (MWL2). Nilai kosong "" = tidak diatur. Kode dari orang lain tidak dipercaya:
-- tiap nilai dicek tipenya, dibatasi rentangnya, dan texture hanya boleh asset id angka atau rbxasset:// bawaan Roblox.
local WIRE_PREFIX = "MWL1:"
local WIRE_LAYOUT = {
    { "Lighting", "Ambient", "c" }, { "Lighting", "Brightness", "n" }, { "Lighting", "ColorShift_Top", "c" },
    { "Lighting", "ColorShift_Bottom", "c" }, { "Lighting", "EnvironmentDiffuseScale", "n" },
    { "Lighting", "EnvironmentSpecularScale", "n" }, { "Lighting", "GlobalShadows", "b" }, { "Lighting", "OutdoorAmbient", "c" },
    { "Lighting", "ShadowSoftness", "n" }, { "Lighting", "ClockTime", "n" }, { "Lighting", "GeographicLatitude", "n" },
    { "Lighting", "ExposureCompensation", "n" },
    { "Atmosphere", "Density", "n" }, { "Atmosphere", "Offset", "n" }, { "Atmosphere", "Color", "c" },
    { "Atmosphere", "Decay", "c" }, { "Atmosphere", "Glare", "n" }, { "Atmosphere", "Haze", "n" },
    { "Bloom", "Enabled", "b" }, { "Bloom", "Intensity", "n" }, { "Bloom", "Size", "n" }, { "Bloom", "Threshold", "n" },
    { "Blur", "Enabled", "b" }, { "Blur", "Size", "n" },
    { "ColorCorrection", "Enabled", "b" }, { "ColorCorrection", "Brightness", "n" }, { "ColorCorrection", "Contrast", "n" },
    { "ColorCorrection", "Saturation", "n" }, { "ColorCorrection", "TintColor", "c" },
    { "DepthOfField", "Enabled", "b" }, { "DepthOfField", "FarIntensity", "n" }, { "DepthOfField", "FocusDistance", "n" },
    { "DepthOfField", "InFocusRadius", "n" }, { "DepthOfField", "NearIntensity", "n" },
    { "SunRays", "Enabled", "b" }, { "SunRays", "Intensity", "n" }, { "SunRays", "Spread", "n" },
    { "Clouds", "Enabled", "b" }, { "Clouds", "Cover", "n" }, { "Clouds", "Density", "n" }, { "Clouds", "Color", "c" },
}
-- { properti Sky, jenis, min, max }; jenis: t = texture, n = angka, b = boolean
local WIRE_SKY = {
    { "SkyboxBk", "t" }, { "SkyboxDn", "t" }, { "SkyboxFt", "t" }, { "SkyboxLf", "t" }, { "SkyboxRt", "t" }, { "SkyboxUp", "t" },
    { "SunTextureId", "t" }, { "MoonTextureId", "t" }, { "StarCount", "n", 0, 5000 }, { "CelestialBodiesShown", "b" },
    { "SunAngularSize", "n", 0, 120 }, { "MoonAngularSize", "n", 0, 120 },
}
LightingModule.PresetCodePrefix = WIRE_PREFIX
LightingModule.PresetCodeLayout = WIRE_LAYOUT

local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local B64_INDEX = {}
for i = 1, #B64_CHARS do B64_INDEX[string.sub(B64_CHARS, i, i)] = i - 1 end

local function Base64Encode(text)
    local out = {}
    for i = 1, #text, 3 do
        local a, b, c = string.byte(text, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local sextets = { math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64 }
        for k = 1, (c and 4) or (b and 3) or 2 do
            out[#out + 1] = string.sub(B64_CHARS, sextets[k] + 1, sextets[k] + 1)
        end
    end
    return table.concat(out)
end

local function Base64Decode(text)
    if #text % 4 == 1 then return nil end
    local out = {}
    for i = 1, #text, 4 do
        local n, count = 0, 0
        for k = 0, 3 do
            local char = string.sub(text, i + k, i + k)
            if char ~= "" then
                local value = B64_INDEX[char]
                if not value then return nil end
                n = n * 64 + value
                count = count + 1
            else
                n = n * 64
            end
        end
        local b1, b2, b3 = math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
        out[#out + 1] = count == 4 and string.char(b1, b2, b3) or (count == 3 and string.char(b1, b2) or string.char(b1))
    end
    return table.concat(out)
end

local function RoundNumber(value)
    return math.floor(value * 10000 + 0.5) / 10000
end

local function ColorToHex(color)
    return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function HexToColor(text)
    local r, g, b = text:match("^#(%x%x)(%x%x)(%x%x)$")
    if not r then return nil end
    return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

local function IsBuiltInContent(text)
    return text:match("^rbxasset://[%w_/%.%-]+$") ~= nil and not text:find("..", 1, true)
end

local function TextureToWire(value)
    if type(value) ~= "string" then return "" end
    local id = value:match("^rbxassetid://(%d+)$") or value:match("[%?&]id=(%d+)") or value:match("^(%d+)$")
    if id then return id end
    return IsBuiltInContent(value) and value or ""
end

local function TextureFromWire(value)
    if type(value) ~= "string" then return "" end
    if value:match("^%d+$") and #value <= 20 then return "rbxassetid://" .. value end
    return IsBuiltInContent(value) and value or ""
end

-- Angka dari kode: harus angka biasa (bukan NaN / tak hingga), lalu dibatasi ke rentang slider-nya.
local function CleanNumber(value, minimum, maximum)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
    if minimum then value = math.max(minimum, math.min(maximum, value)) end
    return value
end

-- Kode untuk satu preset (nama yang ada di dropdown Load Presets). Gagal: nil, pesan. Bisa yield.
function LightingModule.ExportPreset(presetName)
    local data, message = LightingModule.GetPresetData(presetName)
    if not data then return nil, message or "Preset not found." end

    local values = {}
    for index, spec in ipairs(WIRE_LAYOUT) do
        local value = data.Values[spec[1]] and data.Values[spec[1]][spec[2]]
        local encoded = ""
        if spec[3] == "c" and typeof(value) == "Color3" then
            encoded = ColorToHex(value)
        elseif spec[3] == "n" and type(value) == "number" and value == value then
            encoded = RoundNumber(value)
        elseif spec[3] == "b" and type(value) == "boolean" then
            encoded = value
        end
        values[index] = encoded
    end

    local sky = 0
    if data.Sky then
        sky = {}
        for index, spec in ipairs(WIRE_SKY) do
            local value = data.Sky[spec[1]]
            local encoded = ""
            if spec[2] == "t" then
                encoded = TextureToWire(value)
            elseif spec[2] == "n" and type(value) == "number" and value == value then
                encoded = RoundNumber(value)
            elseif spec[2] == "b" and type(value) == "boolean" then
                encoded = value
            end
            sky[index] = encoded
        end
    end

    return WIRE_PREFIX .. Base64Encode(HttpService:JSONEncode({ SanitizePresetName(presetName), values, sky }))
end

-- Baca kode preset menjadi data (bentuk yang sama dengan GetPresetData, plus Name). Gagal: nil, pesan.
function LightingModule.DecodePresetCode(code)
    code = tostring(code or ""):gsub("%s+", "") -- kode yang disalin dari chat sering terpotong baris
    if code:sub(1, #WIRE_PREFIX) ~= WIRE_PREFIX then return nil, "That is not a Mugiwara preset code." end

    local damaged = "The code is damaged. Copy it again."
    local json = Base64Decode(code:sub(#WIRE_PREFIX + 1))
    if not json then return nil, damaged end
    local ok, wire = pcall(function() return HttpService:JSONDecode(json) end)
    if not (ok and type(wire) == "table" and type(wire[2]) == "table") then return nil, damaged end

    local data = { Name = SanitizePresetName(type(wire[1]) == "string" and wire[1] or ""), Values = {} }
    for index, spec in ipairs(WIRE_LAYOUT) do
        local raw, value = wire[2][index], nil
        if spec[3] == "c" then
            if type(raw) == "string" then value = HexToColor(raw) end
        elseif spec[3] == "n" then
            local limits = LightingModule.Limits[spec[1]] and LightingModule.Limits[spec[1]][spec[2]]
            value = CleanNumber(raw, limits and limits.Min, limits and limits.Max)
        elseif type(raw) == "boolean" then
            value = raw
        end
        if value ~= nil then
            data.Values[spec[1]] = data.Values[spec[1]] or {}
            data.Values[spec[1]][spec[2]] = value
        end
    end

    if type(wire[3]) == "table" then
        data.Sky = {}
        for index, spec in ipairs(WIRE_SKY) do
            local raw, value = wire[3][index], nil
            if spec[2] == "t" then
                value = TextureFromWire(raw)
            elseif spec[2] == "n" then
                value = CleanNumber(raw, spec[3], spec[4])
            elseif type(raw) == "boolean" then
                value = raw
            end
            if value ~= nil then data.Sky[spec[1]] = value end
        end
    end
    return data
end

local function PresetNameTaken(name)
    return name == "Default" or LightingModule.BuiltInPresets[name] ~= nil or (isfile ~= nil and isfile(PresetPath(name)) == true)
end

-- Nama yang belum dipakai (preset sendiri tidak pernah ditimpa oleh preset dari orang lain).
local function UniquePresetName(name)
    if name == "" then name = "Shared Preset" end
    if not PresetNameTaken(name) then return name end
    for number = 2, 99 do
        local suffix = " " .. number
        local candidate = string.sub(name, 1, 40 - #suffix) .. suffix
        if not PresetNameTaken(candidate) then return candidate end
    end
    return string.sub(name, 1, 25) .. " " .. os.time()
end

-- Pasang preset dari kode, lalu simpan ke daftar preset user dengan nama unik (kalau executor bisa menulis file).
-- Mengembalikan: berhasil, nama preset (atau pesan gagal), tersimpan.
function LightingModule.ImportPreset(code)
    local data, message = LightingModule.DecodePresetCode(code)
    if not data then return false, message end

    LightingModule.ApplyPresetData(data)

    local name = data.Name ~= "" and data.Name or "Shared Preset"
    if writefile then
        local savedName = UniquePresetName(data.Name)
        local saved = pcall(writefile, PresetPath(savedName), HttpService:JSONEncode(ToFileTable(data.Values, data.Sky)))
        if saved then return true, savedName, true end
    end
    return true, name, false
end

function LightingModule.CopySkybox()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then return false, "This map has no built-in skybox!" end
    local skyData = { SkyboxBk = sky.SkyboxBk, SkyboxDn = sky.SkyboxDn, SkyboxFt = sky.SkyboxFt, SkyboxLf = sky.SkyboxLf, SkyboxRt = sky.SkyboxRt, SkyboxUp = sky.SkyboxUp, SunTextureId = sky.SunTextureId, MoonTextureId = sky.MoonTextureId, StarCount = sky.StarCount, CelestialBodiesShown = sky.CelestialBodiesShown, SunAngularSize = sky.SunAngularSize, MoonAngularSize = sky.MoonAngularSize }
    if LightingModule.SunHidden then
        skyData.SunAngularSize, skyData.SunTextureId, skyData.CelestialBodiesShown = UnhiddenSunValues()
    end
    if writefile then
        writefile(ROOT .. "/CopiedSky.json", HttpService:JSONEncode(skyData))
        return true, "Skybox copied!"
    end
    return false, "Your executor does not support writefile!"
end

function LightingModule.PasteSkybox()
    local path = ROOT .. "/CopiedSky.json"
    if not (readfile and isfile and isfile(path)) then return false, "No skybox has been copied yet!" end
    local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if success and decoded then
        LightingModule.ActiveSkybox = decoded
        LightingModule.ActiveSkyName = nil
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if not sky then
            sky = Instance.new("Sky", Lighting)
            sky.Name = PREFIX .. "Sky"
        end
        for key, value in pairs(decoded) do pcall(function() sky[key] = value end) end
        return true, "Skybox pasted!"
    end
    return false, "The copied skybox data is corrupted!"
end

local renderConnection
renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
    local counts = {}
    for _, child in ipairs(Lighting:GetChildren()) do
        local cls = child.ClassName
        if cls == "Sky" or cls == "Atmosphere" or cls == "BloomEffect" or cls == "BlurEffect" or cls == "ColorCorrectionEffect" or cls == "DepthOfFieldEffect" or cls == "SunRaysEffect" then
            -- Hanya objek buatan hub (prefix Mugiwara_) yang boleh dihapus saat duplikat.
            -- Efek milik game dibiarkan; kalau ada dua, versi game yang dipakai.
            local isOurs = string.sub(child.Name, 1, #PREFIX) == PREFIX
            local current = counts[cls]
            if not current then
                counts[cls] = child
            elseif isOurs then
                child:Destroy()
            elseif string.sub(current.Name, 1, #PREFIX) == PREFIX then
                current:Destroy()
                counts[cls] = child
            end
        end
    end

    local trackedClasses = { Atmosphere = "Atmosphere", Bloom = "BloomEffect", Blur = "BlurEffect", ColorCorrection = "ColorCorrectionEffect", DepthOfField = "DepthOfFieldEffect", SunRays = "SunRaysEffect" }
    for cat, clsName in pairs(trackedClasses) do
        if counts[clsName] then
            AdoptObject(cat, counts[clsName])
        else
            if LightingModule.LockEnabled then
                local newObj = Instance.new(clsName)
                newObj.Name = PREFIX .. clsName
                newObj.Parent = Lighting
                if newObj:IsA("PostEffect") then newObj.Enabled = false end
                LightingModule.Objects[cat] = newObj
                counts[clsName] = newObj
            end
        end
    end

    -- Clouds ada di Terrain: hanya satu, dan harus buatan hub. Clouds asing (milik game, termasuk yang
    -- baru muncul atau menggantikan yang lama) langsung dibuang; kalau punya hub hilang, dibuat lagi
    -- dengan nilai yang sudah diatur user.
    local terrain = GetTerrain()
    if terrain then
        local ours = nil
        for _, child in ipairs(terrain:GetChildren()) do
            if child.ClassName == "Clouds" then
                if IsOurs(child) and not ours then
                    ours = child
                elseif IsOurs(child) then
                    child:Destroy()
                else
                    RemoveForeignClouds(child)
                end
            end
        end
        LightingModule.Objects.Clouds = ours or CreateOurClouds(terrain)
    end

    local currentSky = counts["Sky"]

    if LightingModule.LockEnabled then
        for category, properties in pairs(LightingModule.TargetValues) do
            local obj = LightingModule.Objects[category]
            if obj then
                for propName, targetVal in pairs(properties) do
                    pcall(function() if obj[propName] ~= targetVal then obj[propName] = targetVal end end)
                end
            end
        end
        
        if currentSky and LightingModule.ActiveSkybox then
            for k, v in pairs(LightingModule.ActiveSkybox) do
                pcall(function() if currentSky[k] ~= v then currentSky[k] = v end end)
            end
        end
    else
        LightingModule.LastObserve = (LightingModule.LastObserve or 0) + deltaTime
        if LightingModule.LastObserve >= 0.5 then
            LightingModule.LastObserve = 0
            LightingModule.IsSyncing = true

            for category, properties in pairs(LightingModule.TargetValues) do
                local obj = LightingModule.Objects[category]
                if obj then
                    for propName, targetVal in pairs(properties) do
                        local success, realVal = pcall(function() return obj[propName] end)
                        if success and realVal ~= nil then
                            local isDifferent = false
                            
                            if type(realVal) == "number" and type(targetVal) == "number" then
                                if math.abs(realVal - targetVal) > 0.01 then isDifferent = true end
                            elseif typeof(realVal) == "Color3" and typeof(targetVal) == "Color3" then
                                if math.abs(realVal.R - targetVal.R) > 0.01 or math.abs(realVal.G - targetVal.G) > 0.01 or math.abs(realVal.B - targetVal.B) > 0.01 then isDifferent = true end
                            elseif realVal ~= targetVal then
                                isDifferent = true
                            end

                            if isDifferent then
                                LightingModule.TargetValues[category][propName] = realVal
                                if LightingModule.OnPropertyChanged then
                                    pcall(LightingModule.OnPropertyChanged, category, propName, realVal)
                                end
                            end
                        end
                    end
                end
            end
            LightingModule.IsSyncing = false
        end
    end

    -- Hide Sun dijaga tiap frame, setelah Lock Lighting / skybox menimpa nilai matahari.
    if LightingModule.SunHidden then
        currentSky = currentSky or GetOrCreateSky()
        pcall(function()
            if currentSky.CelestialBodiesShown ~= false then currentSky.CelestialBodiesShown = false end
            if currentSky.SunAngularSize ~= 0 then currentSky.SunAngularSize = 0 end
            if currentSky.SunTextureId ~= "" then currentSky.SunTextureId = "" end
        end)
    end

    if LightingModule.SkyAnimEnabled and currentSky then
        local currentRot = currentSky.SkyboxOrientation
        currentSky.SkyboxOrientation = currentRot + Vector3.new(0, LightingModule.SkyAnimSpeed * deltaTime, 0)
    end
end)

-- Full teardown on re-execute: stop the loop, then put the map's original lighting back.
-- Restoring matters because the next session snapshots the current lighting as its default.
getgenv().MugiwaraRegisterCleanup(function()
    if renderConnection then renderConnection:Disconnect() renderConnection = nil end
    LightingModule.LockEnabled = false
    LightingModule.SkyAnimEnabled = false
    LightingModule.SunHidden = false
    LightingModule.OnPresetLoaded = nil
    LightingModule.OnPropertyChanged = nil
    pcall(LightingModule.LoadPreset, "Default")

    -- Hapus objek yang dibuat hub sendiri (prefix Mugiwara_); milik game tidak disentuh.
    for _, child in ipairs(Lighting:GetChildren()) do
        if string.sub(child.Name, 1, #PREFIX) == PREFIX then child:Destroy() end
    end
    local terrain = GetTerrain()
    if terrain then
        for _, child in ipairs(terrain:GetChildren()) do
            if child.ClassName == "Clouds" and string.sub(child.Name, 1, #PREFIX) == PREFIX then child:Destroy() end
        end

        -- Kembalikan Clouds milik game yang tadi dibuang (kalau belum ada Clouds lain di Terrain).
        local removed = LightingModule.RemovedClouds
        LightingModule.RemovedClouds = nil
        if removed and not terrain:FindFirstChildOfClass("Clouds") then
            pcall(function() removed.Parent = terrain end)
        end
    end
end)

return LightingModule
