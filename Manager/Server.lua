local Server = {}

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

local failedConnection = nil

-- Rejoin the current server. When the server is full, closed or private (or you are
-- the only player, so it would shut down the moment you leave) it falls back to a
-- fresh server of the same place.
function Server.Rejoin()
    if failedConnection then failedConnection:Disconnect() end

    failedConnection = TeleportService.TeleportInitFailed:Connect(function(player)
        if player ~= LocalPlayer then return end
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end)

    local ok, err = pcall(function()
        if #Players:GetPlayers() <= 1 then
            -- Server kosong setelah kita keluar, jadi pindah ke server baru langsung.
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end)

    return ok, err
end

-- Full teardown on re-execute.
getgenv().MugiwaraRegisterCleanup(function()
    if failedConnection then failedConnection:Disconnect() failedConnection = nil end
end)

return Server
