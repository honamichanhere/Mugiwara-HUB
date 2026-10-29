-- Visual Carry untuk Evade: menukar isi dua animasi carry supaya satu carry tampil/bermain seperti yang lain.
-- Sama dengan Visual Emotes (logika di VisualSwap.lua). Carry adalah ModuleScript di folder bernama
-- "CarryAnimations" yang tersebar di BaseItems dan ItemPacks (juga di sub-folder seperti DailyShop /
-- Battlepass). Isinya (anak) yang ditukar: Animation "Carry" (pembawa), Animation "Carried" (yang dibawa),
-- folder "Classic" (versi R6) dan model "Character" (properti). Nama tampilan dan Header diambil dari modul
-- data tiap carry, jadi namanya tidak ikut tertukar. Modul ini tanpa UI; antarmukanya VisualCarryUI.lua.
local VisualSwap = getgenv().MugiwaraImport("Games/Evade/VisualSwap.lua")

return VisualSwap({ Category = "CarryAnimations", Noun = "carry" })
