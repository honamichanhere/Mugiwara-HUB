local Server = {}

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local JOB_ID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
local MAX_AUTO_REJOINS = 3 -- cegah loop rejoin tanpa akhir kalau akun memang diblokir

Server.HopModes = { "Random", "Low Population", "High Population" }

-- Dipanggil UI saat teleport gagal. Argumen: pesan error dari Roblox.
Server.OnTeleportFailed = nil

local pendingOnFail = nil -- aksi cadangan untuk teleport yang sedang berjalan
local connections = {}
local autoRejoinCount = 0
local alive = true

-- ==========================================
-- TELEPORT FAILURE ROUTER
-- ==========================================
table.insert(connections, TeleportService.TeleportInitFailed:Connect(function(player, _, message)
    if player ~= LocalPlayer then return end

    local handler = pendingOnFail
    pendingOnFail = nil
    if handler then
        pcall(handler, message)
    elseif Server.OnTeleportFailed then
        pcall(Server.OnTeleportFailed, message)
    end
end))

local function TeleportToNewServer()
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end

-- ==========================================
-- REJOIN / JOIN / HOP
-- ==========================================

-- Rejoin the current server. When the server is full, closed or private (or you are
-- the only player, so it would shut down the moment you leave) it falls back to a
-- fresh server of the same place.
function Server.Rejoin()
    pendingOnFail = TeleportToNewServer

    local ok, err = pcall(function()
        if #Players:GetPlayers() <= 1 then
            TeleportToNewServer()
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end)
    return ok, err
end

function Server.GetJobId()
    return game.JobId
end

function Server.IsValidJobId(jobId)
    return type(jobId) == "string" and string.match(jobId, JOB_ID_PATTERN) ~= nil
end

-- Join a public server of this place by Job ID. Private/reserved servers cannot be
-- joined this way because Roblox requires an access code that only the owner holds.
function Server.JoinJobId(jobId)
    jobId = tostring(jobId or ""):match("^%s*(.-)%s*$")
    if not Server.IsValidJobId(jobId) then
        return false, "That is not a valid Job ID."
    end
    if jobId == game.JobId then
        return false, "You are already in this server."
    end

    pendingOnFail = nil -- kegagalan dikirim ke Server.OnTeleportFailed
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
    end)
    return ok, err
end

-- Hop to another public server of this place.
-- mode: "Random", "Low Population" or "High Population".
function Server.Hop(mode)
    local order = (mode == "High Population") and "Desc" or "Asc"
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100",
        game.PlaceId, order
    )

    local okRequest, body = pcall(function() return game:HttpGet(url) end)
    if not okRequest then
        return false, "Could not reach the server list (rate limited or offline)."
    end

    local okDecode, decoded = pcall(function() return HttpService:JSONDecode(body) end)
    if not okDecode or type(decoded) ~= "table" or type(decoded.data) ~= "table" then
        return false, "The server list came back in an unexpected format."
    end

    local candidates = {}
    for _, info in ipairs(decoded.data) do
        if info.id ~= game.JobId and info.playing and info.maxPlayers and info.playing < info.maxPlayers then
            table.insert(candidates, info)
        end
    end
    if #candidates == 0 then
        return false, "No other open server was found."
    end

    local target = candidates[1]
    if mode == "Random" or mode == nil then
        target = candidates[math.random(1, #candidates)]
    end

    pendingOnFail = nil
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LocalPlayer)
    end)
    if not ok then return false, tostring(err) end
    return true, string.format("Joining a server with %d/%d players...", target.playing, target.maxPlayers)
end

-- ==========================================
-- ANTI-AFK (default ON)
-- ==========================================
Server.AntiAfkEnabled = true

table.insert(connections, LocalPlayer.Idled:Connect(function()
    if not Server.AntiAfkEnabled then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end))

function Server.SetAntiAfk(state)
    Server.AntiAfkEnabled = state
end

-- ==========================================
-- AUTO REJOIN ON DISCONNECT / KICK (default OFF)
-- ==========================================
Server.AutoRejoinEnabled = false

local function OnErrorPrompt(child)
    if child.Name ~= "ErrorPrompt" or not Server.AutoRejoinEnabled then return end

    if autoRejoinCount >= MAX_AUTO_REJOINS then
        warn("[Mugiwara HUB] Auto Rejoin stopped after " .. MAX_AUTO_REJOINS .. " attempts.")
        return
    end
    autoRejoinCount = autoRejoinCount + 1

    task.wait(2) -- kasih jeda biar tidak terasa seperti spam
    if Server.AutoRejoinEnabled then TeleportToNewServer() end
end

task.spawn(function()
    -- RobloxPromptGui baru ada di CoreGui setelah game load; tunggu dengan batas waktu.
    local ok = pcall(function()
        local promptGui = CoreGui:WaitForChild("RobloxPromptGui", 10)
        local overlay = promptGui and promptGui:WaitForChild("promptOverlay", 10)
        -- Kalau hub sudah di-unload selagi menunggu, jangan pasang koneksi baru.
        if overlay and alive then
            table.insert(connections, overlay.ChildAdded:Connect(OnErrorPrompt))
        end
    end)
    if not ok then warn("[Mugiwara HUB] Auto Rejoin could not attach to the disconnect prompt.") end
end)

function Server.SetAutoRejoin(state)
    Server.AutoRejoinEnabled = state
    if state then autoRejoinCount = 0 end
end

-- Full teardown on re-execute / unload.
getgenv().MugiwaraRegisterCleanup(function()
    alive = false
    Server.AntiAfkEnabled = false
    Server.AutoRejoinEnabled = false
    Server.OnTeleportFailed = nil
    pendingOnFail = nil
    for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    table.clear(connections)
end)

return Server
