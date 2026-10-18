local Rigs = {}

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- Evade bisa punya DUA rig dengan nama pemain yang sama di Workspace.Rigs: satu dari
-- inventory/menu, satu dari dalam game. Modul ini jadi satu-satunya tempat yang menentukan
-- rig mana yang dipakai, supaya fitur lain tidak asal mengambil FindFirstChild(nama).
--
-- Hasil pengamatan langsung (Halloween update):
--   rig inventory : tanpa attribute, 14 child
--   rig in-game   : attribute "Tag" (angka), 15 child
--   keduanya      : tidak punya HumanoidRootPart, kamera tidak mengikuti rig, dan
--                   bukan LocalPlayer.Character -> petunjuk itu tidak bisa dipakai.
-- Karakter yang benar-benar dikendalikan pemain adalah LocalPlayer.Character
-- (Workspace.Players.<nama>, punya HumanoidRootPart). Rig di sini hanya salinan VISUAL:
-- cocok untuk accessories/avatar, tapi jangan digerakkan untuk fitur gameplay.
local IN_GAME_ATTRIBUTE = "Tag"

local function RootOf(rig, humanoid)
    return rig:FindFirstChild("HumanoidRootPart") or humanoid.RootPart or rig.PrimaryPart
end

-- Semua rig milik pemain lokal. Urutan = urutan di Workspace.Rigs.
-- Player.Character hanya dipakai kalau tidak ada rig sama sekali di Workspace.Rigs.
function Rigs.GetAll()
    local list = {}

    local container = workspace:FindFirstChild("Rigs")
    if container then
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") and child.Name == LocalPlayer.Name then
                local humanoid = child:FindFirstChildOfClass("Humanoid")
                if humanoid then table.insert(list, { Rig = child, Humanoid = humanoid }) end
            end
        end
    end

    if #list == 0 then
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then table.insert(list, { Rig = character, Humanoid = humanoid }) end
    end

    return list
end

-- true kalau rig ini rig in-game (punya attribute penanda).
function Rigs.IsInGame(rig)
    return rig:GetAttribute(IN_GAME_ATTRIBUTE) ~= nil
end

-- Skor tiap rig; skor tertinggi = rig yang dipakai main. Seri -> yang lebih dulu di Workspace.Rigs.
local function Score(entry)
    local score = 0
    local camera = workspace.CurrentCamera

    if Rigs.IsInGame(entry.Rig) then score = score + 10 end -- penanda yang terbukti membedakan
    if camera and camera.CameraSubject == entry.Humanoid then score = score + 4 end
    if entry.Rig == LocalPlayer.Character then score = score + 2 end
    if entry.Humanoid.Health > 0 then score = score + 1 end

    return score
end

-- Rig yang sedang aktif. Mengembalikan rig, humanoid (atau nil, nil).
function Rigs.GetActive()
    local best, bestScore = nil, -1

    for _, entry in ipairs(Rigs.GetAll()) do
        local score = Score(entry)
        if score > bestScore then best, bestScore = entry, score end
    end

    if not best then return nil, nil end
    return best.Rig, best.Humanoid
end

-- Posisi sebuah rig lewat pivot model (rig ini tidak punya HumanoidRootPart).
function Rigs.GetPosition(rig)
    local ok, pivot = pcall(function() return rig:GetPivot() end)
    return ok and pivot.Position or nil
end

function Rigs.GetRoot(rig, humanoid)
    return RootOf(rig, humanoid)
end

return Rigs
