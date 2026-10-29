local VisualEmotes = getgenv().MugiwaraImport("Games/Evade/VisualEmotes.lua")
local VisualGridUI = getgenv().MugiwaraImport("Games/Evade/VisualGridUI.lua")

-- Antarmuka Visual Emotes (premium). Semuanya ada di VisualGridUI.lua, dipakai bersama Visual Carry.
local UI = {}

function UI.Build(Section, isPremiumUser, MugiwaraUI)
    if not (VisualEmotes and VisualGridUI) then return end

    VisualGridUI.Build(Section, {
        Swap = VisualEmotes,
        Kind = "Emote",
        Name = "Visual Emotes",
        Noun = "emote",
        Locked = true, -- premium saja
        IsPremium = isPremiumUser,
        Icons = { Item = "lucide:music", Base = "lucide:music", Target = "lucide:drama" },
    }, MugiwaraUI)
end

return UI
