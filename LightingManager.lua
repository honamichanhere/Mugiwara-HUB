local LightingModule = {}

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- ==========================================
-- MESIN PEMBUAT FOLDER
-- ==========================================
if makefolder and isfolder then
    if not isfolder("HonamiHub") then makefolder("HonamiHub") end
    if not isfolder("HonamiHub/Presets") then makefolder("HonamiHub/Presets") end
end

-- ==========================================
-- DATABASE PRESET BAWAAN
-- ==========================================
LightingModule.BuiltInPresets = {
    ["Horor Vibe"] = {
        Desc = "Tema gelap, berkabut merah, dan mencekam.",
        Skybox = "5157589613",
        Values = {
            Lighting = { Brightness = 0.2, ClockTime = 0, Ambient = Color3.fromRGB(10, 0, 0), OutdoorAmbient = Color3.fromRGB(5,0,0), ColorShift_Top = Color3.fromRGB(0,0,0), ColorShift_Bottom = Color3.fromRGB(0,0,0), GlobalShadows = true },
            Atmosphere = { Density = 0.8, Color = Color3.fromRGB(20, 5, 5), Decay = Color3.fromRGB(10, 0, 0), Haze = 5, Glare = 0, Offset = 0 },
            ColorCorrection = { Enabled = true, Brightness = -0.1, Contrast = 0.5, Saturation = -0.5, TintColor = Color3.fromRGB(255,200,200) }
        }
    },
    ["Cozy Sunset"] = {
        Desc = "Hangat, estetik, cocok buat hangout sore.",
        Skybox = "5186800496",
        Values = {
            Lighting = { Brightness = 2.5, ClockTime = 17.5, ExposureCompensation = 0.2, Ambient = Color3.fromRGB(100, 80, 50), OutdoorAmbient = Color3.fromRGB(150, 100, 50), GlobalShadows = true },
            SunRays = { Enabled = true, Intensity = 0.2, Spread = 0.8 },
            Bloom = { Enabled = true, Intensity = 0.5, Size = 20, Threshold = 2 }
        }
    }
}

-- ==========================================
-- SYSTEM VARIABLES
-- ==========================================
LightingModule.LockEnabled = false
LightingModule.DefaultSkybox = nil 
LightingModule.ActiveSkybox = nil -- [BARU] Tracker buat ngelock Skybox

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
    SunRays = { Intensity = {Min = 0, Max = 1}, Spread = {Min = 0, Max = 1} }
}

LightingModule.TrackedProperties = {
    Lighting = {"Ambient", "Brightness", "ColorShift_Top", "ColorShift_Bottom", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows", "OutdoorAmbient", "ShadowSoftness", "ClockTime", "GeographicLatitude", "ExposureCompensation"},
    Atmosphere = {"Density", "Offset", "Color", "Decay", "Glare", "Haze"},
    Bloom = {"Enabled", "Intensity", "Size", "Threshold"},
    Blur = {"Enabled", "Size"},
    ColorCorrection = {"Enabled", "Brightness", "Contrast", "Saturation", "TintColor"},
    DepthOfField = {"Enabled", "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity"},
    SunRays = {"Enabled", "Intensity", "Spread"}
}

LightingModule.SkyboxDatabase = {
    ["Default Sky"] = "", ["Sunset"] = "5186800496", ["Vaporwave"] = "5157589613", 
    ["Starry Night"] = "143962526", ["Anime Sky"] = "14753835117"
}
LightingModule.SkyAnimEnabled = false
LightingModule.SkyAnimSpeed = 10

-- ==========================================
-- 1. INIT: VALIDASI & MIRRORING VALUE
-- ==========================================
function LightingModule.Init()
    local requiredEffects = { Atmosphere = "Atmosphere", Bloom = "BloomEffect", Blur = "BlurEffect", ColorCorrection = "ColorCorrectionEffect", DepthOfField = "DepthOfFieldEffect", SunRays = "SunRaysEffect" }

    for key, className in pairs(requiredEffects) do
        local effect = Lighting:FindFirstChildOfClass(className)
        if not effect then
            effect = Instance.new(className)
            effect.Name = "Honami_" .. className
            effect.Parent = Lighting
        end
        LightingModule.Objects[key] = effect
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
            SunTextureId = originalSky.SunTextureId, MoonTextureId = originalSky.MoonTextureId, StarCount = originalSky.StarCount
        }
        LightingModule.ActiveSkybox = LightingModule.DefaultSkybox
    end
end
LightingModule.Init()

-- ==========================================
-- 2. FUNGSI UPDATE DARI UI
-- ==========================================
function LightingModule.UpdateValue(category, property, value)
    if LightingModule.TargetValues[category] then
        LightingModule.TargetValues[category][property] = value
        if not LightingModule.LockEnabled then
            local obj = LightingModule.Objects[category]
            if obj then pcall(function() obj[property] = value end) end
        end
    end
end

function LightingModule.ToggleEffect(category, isEnabled)
    LightingModule.UpdateValue(category, "Enabled", isEnabled)
end

-- ==========================================
-- 3. MESIN SKYBOX & PRESET (ANTI DUPLIKAT)
-- ==========================================
function LightingModule.LoadSkybox(id)
    if id == "" or id == "Default" then return end
    local success, result = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
    if success and result and result[1] then
        local asset = result[1]
        local skyObject = asset:IsA("Sky") and asset or asset:FindFirstChildOfClass("Sky")
        
        if skyObject then
            -- [FIX] Track di memori ActiveSkybox, jangan di-parent langsung!
            LightingModule.ActiveSkybox = {
                SkyboxBk = skyObject.SkyboxBk, SkyboxDn = skyObject.SkyboxDn, SkyboxFt = skyObject.SkyboxFt,
                SkyboxLf = skyObject.SkyboxLf, SkyboxRt = skyObject.SkyboxRt, SkyboxUp = skyObject.SkyboxUp,
                SunTextureId = skyObject.SunTextureId, MoonTextureId = skyObject.MoonTextureId, StarCount = skyObject.StarCount
            }
            
            local currentSky = Lighting:FindFirstChildOfClass("Sky")
            if not currentSky then
                currentSky = Instance.new("Sky")
                currentSky.Name = "Honami_Sky"
                currentSky.Parent = Lighting
            end
            
            for k, v in pairs(LightingModule.ActiveSkybox) do
                pcall(function() currentSky[k] = v end)
            end
            
            -- [FIX] Hancurkan objek aslinya biar ngga numpuk
            pcall(function() asset:Destroy() end) 
        end
    end
end

function LightingModule.GetPresetsList()
    local list = {}
    table.insert(list, { Title = "Default", Desc = "Kembali ke cuaca map asli", Icon = "lucide:sun" })
    table.insert(list, { Type = "Divider" })
    for name, data in pairs(LightingModule.BuiltInPresets) do
        table.insert(list, { Title = name, Desc = data.Desc, Icon = "lucide:cloudy" })
    end
    if listfiles then
        local files = listfiles("HonamiHub/Presets")
        if #files > 0 then
            table.insert(list, { Type = "Divider" })
            for _, file in pairs(files) do
                local name = file:match("([^/\\]+)%.json$")
                if name then table.insert(list, { Title = name, Desc = "Custom Preset (Saved)", Icon = "lucide:save" }) end
            end
        end
    end
    return list
end

function LightingModule.SavePreset(presetName)
    if presetName == "" then return false, "Nama kosong" end
    local path = "HonamiHub/Presets/" .. presetName .. ".json"
    local isOverwrite = (isfile and isfile(path))
    
    local dataToSave = {}
    for cat, props in pairs(LightingModule.TargetValues) do dataToSave[cat] = props end
    
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if sky then
        dataToSave.CustomSkybox = {
            SkyboxBk = sky.SkyboxBk, SkyboxDn = sky.SkyboxDn, SkyboxFt = sky.SkyboxFt,
            SkyboxLf = sky.SkyboxLf, SkyboxRt = sky.SkyboxRt, SkyboxUp = sky.SkyboxUp,
            SunTextureId = sky.SunTextureId, MoonTextureId = sky.MoonTextureId, StarCount = sky.StarCount
        }
    end

    local data = HttpService:JSONEncode(dataToSave)
    if writefile then 
        writefile(path, data) 
        return true, isOverwrite and "Overwrite" or "New"
    end
    return false, "Executor tidak support writefile"
end

function LightingModule.LoadPreset(presetName)
    -- ========================================
    -- 1. JIKA PILIH DEFAULT
    -- ========================================
    if presetName == "Default" then
        local currentSky = Lighting:FindFirstChildOfClass("Sky")
        if LightingModule.DefaultSkybox then
            LightingModule.ActiveSkybox = LightingModule.DefaultSkybox
            if not currentSky then
                currentSky = Instance.new("Sky", Lighting)
                currentSky.Name = "Honami_Sky"
            end
            for k, v in pairs(LightingModule.DefaultSkybox) do pcall(function() currentSky[k] = v end) end
        else
            LightingModule.ActiveSkybox = nil
            if currentSky then currentSky:Destroy() end
        end

        for cat, props in pairs(LightingModule.Defaults) do
            if LightingModule.TargetValues[cat] then
                local obj = LightingModule.Objects[cat]
                for k, v in pairs(props) do 
                    LightingModule.TargetValues[cat][k] = v 
                    if obj then pcall(function() obj[k] = v end) end -- [FIX] Maksa langsung terapin ke game!
                end
            end
        end
        return
    end

    -- ========================================
    -- 2. JIKA PRESET BAWAAN (BUILT-IN)
    -- ========================================
    if LightingModule.BuiltInPresets[presetName] then
        local presetData = LightingModule.BuiltInPresets[presetName]
        if presetData.Skybox and presetData.Skybox ~= "" then 
            LightingModule.LoadSkybox(presetData.Skybox) 
        else
            -- [FIX] Kalo preset bawaan ga punya skybox, reset ke default map
            local currentSky = Lighting:FindFirstChildOfClass("Sky")
            if LightingModule.DefaultSkybox then
                LightingModule.ActiveSkybox = LightingModule.DefaultSkybox
                if not currentSky then
                    currentSky = Instance.new("Sky", Lighting)
                    currentSky.Name = "Honami_Sky"
                end
                for k, v in pairs(LightingModule.DefaultSkybox) do pcall(function() currentSky[k] = v end) end
            else
                LightingModule.ActiveSkybox = nil
                if currentSky then currentSky:Destroy() end
            end
        end
        
        for cat, props in pairs(presetData.Values) do
            if LightingModule.TargetValues[cat] then
                local obj = LightingModule.Objects[cat]
                for k, v in pairs(props) do 
                    LightingModule.TargetValues[cat][k] = v 
                    if obj then pcall(function() obj[k] = v end) end -- [FIX] Maksa langsung terapin ke game!
                end
            end
        end
        return
    end

    -- ========================================
    -- 3. JIKA CUSTOM PRESET (DARI FOLDER USER)
    -- ========================================
    local path = "HonamiHub/Presets/" .. presetName .. ".json"
    if readfile and isfile and isfile(path) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if success and decoded then
            
            -- [FIX] Logika Skybox buat file Custom
            if decoded.CustomSkybox then
                LightingModule.ActiveSkybox = decoded.CustomSkybox
                local sky = Lighting:FindFirstChildOfClass("Sky")
                if not sky then
                    sky = Instance.new("Sky", Lighting)
                    sky.Name = "Honami_Sky"
                end
                for key, value in pairs(decoded.CustomSkybox) do pcall(function() sky[key] = value end) end
                decoded.CustomSkybox = nil 
            else
                -- [FIX CRUCIAL] Jika user save preset tanpa skybox, WAJIB reset langitnya ke awal!
                local currentSky = Lighting:FindFirstChildOfClass("Sky")
                if LightingModule.DefaultSkybox then
                    LightingModule.ActiveSkybox = LightingModule.DefaultSkybox
                    if not currentSky then
                        currentSky = Instance.new("Sky", Lighting)
                        currentSky.Name = "Honami_Sky"
                    end
                    for k, v in pairs(LightingModule.DefaultSkybox) do pcall(function() currentSky[k] = v end) end
                else
                    LightingModule.ActiveSkybox = nil
                    if currentSky then currentSky:Destroy() end
                end
            end

            -- Terapin nilai warna dan efek lighting
            for cat, props in pairs(decoded) do
                if LightingModule.TargetValues[cat] then
                    local obj = LightingModule.Objects[cat]
                    for k, v in pairs(props) do 
                        LightingModule.TargetValues[cat][k] = v 
                        if obj then pcall(function() obj[k] = v end) end -- [FIX] Maksa langsung terapin ke game!
                    end
                end
            end
        end
    end
end

-- ==========================================
-- MESIN COPY-PASTE SKYBOX 
-- ==========================================
function LightingModule.CopySkybox()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then return false, "Tidak ada Skybox bawaan di map ini!" end
    local skyData = { SkyboxBk = sky.SkyboxBk, SkyboxDn = sky.SkyboxDn, SkyboxFt = sky.SkyboxFt, SkyboxLf = sky.SkyboxLf, SkyboxRt = sky.SkyboxRt, SkyboxUp = sky.SkyboxUp, SunTextureId = sky.SunTextureId, MoonTextureId = sky.MoonTextureId, StarCount = sky.StarCount }
    if writefile then
        writefile("HonamiHub/CopiedSky.json", HttpService:JSONEncode(skyData))
        return true, "Skybox berhasil dicopy!"
    end
    return false, "Executor tidak support writefile!"
end

function LightingModule.PasteSkybox()
    local path = "HonamiHub/CopiedSky.json"
    if not (readfile and isfile and isfile(path)) then return false, "Belum ada Skybox yang disalin!" end
    local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if success and decoded then
        LightingModule.ActiveSkybox = decoded
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if not sky then
            sky = Instance.new("Sky", Lighting)
            sky.Name = "Honami_Sky"
        end
        for key, value in pairs(decoded) do pcall(function() sky[key] = value end) end
        return true, "Skybox berhasil dipaste!"
    end
    return false, "Data CopiedSky rusak!"
end

-- ==========================================
-- 4. KASTA TERTINGGI: SINGULARITY ENGINE & LOCK
-- ==========================================
RunService.RenderStepped:Connect(function(deltaTime)
    -- [1] ANTI-DUPLIKAT (SINGULARITY)
    local counts = {}
    for _, child in ipairs(Lighting:GetChildren()) do
        local cls = child.ClassName
        if cls == "Sky" or cls == "Atmosphere" or cls == "BloomEffect" or cls == "BlurEffect" or cls == "ColorCorrectionEffect" or cls == "DepthOfFieldEffect" or cls == "SunRaysEffect" then
            if counts[cls] then
                child:Destroy() -- Basmi duplikat ciptaan game!
            else
                counts[cls] = child
            end
        end
    end

    -- Update tracker supaya selalu nyambung ke objek yg bener
    local trackedClasses = { Atmosphere = "Atmosphere", Bloom = "BloomEffect", Blur = "BlurEffect", ColorCorrection = "ColorCorrectionEffect", DepthOfField = "DepthOfFieldEffect", SunRays = "SunRaysEffect" }
    for cat, clsName in pairs(trackedClasses) do
        if counts[clsName] then
            LightingModule.Objects[cat] = counts[clsName]
        else
            -- Kalo game ngapus objek kita secara brutal, paksa bikin baru saat Lock!
            if LightingModule.LockEnabled then
                local newObj = Instance.new(clsName)
                newObj.Name = "Honami_" .. clsName
                newObj.Parent = Lighting
                LightingModule.Objects[cat] = newObj
                counts[clsName] = newObj
            end
        end
    end

    local currentSky = counts["Sky"]

    -- [2] FORCE LOCK VALUES
    if LightingModule.LockEnabled then
        -- Kunci Slider/Warna
        for category, properties in pairs(LightingModule.TargetValues) do
            local obj = LightingModule.Objects[category]
            if obj then
                for propName, targetVal in pairs(properties) do
                    pcall(function() if obj[propName] ~= targetVal then obj[propName] = targetVal end end)
                end
            end
        end
        
        -- Kunci Skybox Texture
        if currentSky and LightingModule.ActiveSkybox then
            for k, v in pairs(LightingModule.ActiveSkybox) do
                pcall(function() if currentSky[k] ~= v then currentSky[k] = v end end)
            end
        end
    end

    -- [3] ANIMASI ROTASI SKYBOX
    if LightingModule.SkyAnimEnabled and currentSky then
        local currentRot = currentSky.SkyboxOrientation
        currentSky.SkyboxOrientation = currentRot + Vector3.new(0, LightingModule.SkyAnimSpeed * deltaTime, 0)
    end
end)

return LightingModule
