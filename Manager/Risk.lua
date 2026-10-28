local Risk = {}

-- Fitur yang berisiko tinggi kena ban di Evade. Daftar di bawah hanya menandai dan memperingatkan;
-- tidak ada yang diblokir. Fitur ditandai karena posisi, kecepatan, dan pemanggilan remote karakter
-- dicek di sisi server, jadi perubahannya mudah terbaca anti-cheat atau dilaporkan pemain lain.
-- Fitur visual (Lighting, Korless, kamera, dan sebagainya) hanya mengubah tampilan di client dan tidak
-- ditandai.
Risk.Features = {
    SpeedHack = { Name = "Speed Hack", Reason = "Walk speed is checked by the server. Abnormal speed is a common ban trigger." },
    TweenSpeed = { Name = "Tween Speed", Reason = "Moving much faster than normal is easily flagged by the server." },
    JumpPower = { Name = "Jump Power", Reason = "Abnormal jump height is easily flagged by the server." },
    InfiniteJump = { Name = "Infinite Jump", Reason = "Jumping in mid-air is easily flagged by the server." },
    Fly = { Name = "Fly", Reason = "Flying or hovering is easily flagged, and other players can report you." },
    Noclip = { Name = "Noclip", Reason = "Walking through walls is easily flagged by the server." },
    AfkFarm = { Name = "AFK Farm", Reason = "Builds a platform at your AFK coordinates and teleports your character onto it. Teleporting is easily flagged by the server." },
    AutoCommands = { Name = "Auto Execute", Reason = "Sends VIP commands automatically. Without VIP Commands access or a Private Server/Community you own, the game may treat this as exploiting." },
    TicketFarm = { Name = "Auto Farm Tickets", Reason = "Teleports your character between tickets. Teleporting is easily flagged by the server." },
    AvoidNextBots = { Name = "Avoid NextBots", Reason = "Teleports your character away from NextBots. Teleporting is easily flagged by the server." },
}

local TAG = "[HIGH RISK] "

-- Deskripsi elemen: "[HIGH RISK] " + deskripsi asli (atau alasan risikonya kalau tidak ada deskripsi).
function Risk.Desc(key, description)
    local feature = Risk.Features[key]
    local text = description or (feature and feature.Reason) or ""
    return TAG .. text
end

-- Dipanggil dari callback toggle. Hanya memperingatkan saat fitur DINYALAKAN.
function Risk.Warn(MugiwaraUI, key, state)
    local feature = Risk.Features[key]
    if not state or not feature or not MugiwaraUI then return end

    pcall(function()
        MugiwaraUI:Notify({
            Title = "High risk: " .. feature.Name,
            Content = feature.Reason,
            Duration = 6,
        })
    end)
end

return Risk
