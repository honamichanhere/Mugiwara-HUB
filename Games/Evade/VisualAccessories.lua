-- Accessories, Headless dan Korblox dipakai bersama dengan Universal, jadi logikanya ada di
-- Manager/VisualAccessories.lua. Di sini hanya menentukan rig mana yang diubah: semua rig pemain di
-- Workspace.Rigs (inventory + in-game), lewat Games/Evade/Rigs.lua.
local VisualAccessories = getgenv().MugiwaraImport("Manager/VisualAccessories.lua")
local RigsModule = getgenv().MugiwaraImport("Games/Evade/Rigs.lua")

if VisualAccessories and RigsModule then
    VisualAccessories.SetRigProvider(RigsModule.GetAll)
end

return VisualAccessories
