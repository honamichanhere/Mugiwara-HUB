local Rigs = {}

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- Evade bisa punya DUA rig dengan nama pemain yang sama di Workspace.Rigs: satu dari
-- inventory/menu, satu dari dalam game. Modul ini jadi satu-satunya tempat yang menentukan
-- rig mana yang dipakai, supaya fitur lain tidak asal mengambil FindFirstChild(nama).

local function RootOf(rig, humanoid)
    return rig:FindFirstChild("HumanoidRootPart") or humanoid.RootPart
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

-- Skor tiap rig dari beberapa petunjuk; rig dengan skor tertinggi dianggap rig yang
-- sedang dipakai main. Seri -> rig yang lebih dulu ada di Workspace.Rigs.
local function Score(entry)
    local score = 0
    local camera = workspace.CurrentCamera

    if camera and camera.CameraSubject == entry.Humanoid then score = score + 4 end -- kamera mengikuti rig ini
    if entry.Rig == LocalPlayer.Character then score = score + 2 end
    if entry.Humanoid.Health > 0 then score = score + 1 end

    local root = RootOf(entry.Rig, entry.Humanoid)
    if root and not root.Anchored then score = score + 1 end -- rig preview biasanya di-anchor

    return score
end

-- Rig yang sedang aktif. Mengembalikan rig, humanoid (atau nil, nil).
function Rigs.GetActive()
    local all = Rigs.GetAll()
    local best, bestScore = nil, -1

    for _, entry in ipairs(all) do
        local score = Score(entry)
        if score > bestScore then best, bestScore = entry, score end
    end

    if not best then return nil, nil end
    return best.Rig, best.Humanoid
end

function Rigs.GetActiveRoot()
    local rig, humanoid = Rigs.GetActive()
    if not rig then return nil, nil end
    return RootOf(rig, humanoid), humanoid
end

return Rigs
