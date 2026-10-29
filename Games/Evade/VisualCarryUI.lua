local VisualCarry = getgenv().MugiwaraImport("Games/Evade/VisualCarry.lua")
local VisualGridUI = getgenv().MugiwaraImport("Games/Evade/VisualGridUI.lua")

-- Antarmuka Visual Carry (gratis). Semuanya ada di VisualGridUI.lua, dipakai bersama Visual Emotes.
local UI = {}

function UI.Build(Section, MugiwaraUI)
    if not (VisualCarry and VisualGridUI) then return end

    VisualGridUI.Build(Section, {
        Swap = VisualCarry,
        Kind = "Carry",
        Name = "Visual Carry",
        Noun = "carry",
        Locked = false, -- gratis
        Icons = { Item = "lucide:hand-helping", Base = "lucide:hand-helping", Target = "lucide:users" },
    }, MugiwaraUI)
end

return UI
