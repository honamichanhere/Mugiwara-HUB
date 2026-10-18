local Cursor = {}

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Shift lock (bawaan Roblox maupun buatan game seperti Evade) mengunci mouse di tengah layar
-- lewat UserInputService.MouseBehavior, sehingga UI hub tidak bisa diklik. Selama jendela hub
-- terbuka modul ini membebaskan kursor; saat jendela ditutup, kondisi aslinya dikembalikan
-- (kalau shift lock sedang nyala, kursor kembali terkunci).
--
-- Kondisi asli dicatat saat kursor dibebaskan (MouseBehavior, MouseIconEnabled, MouseIcon) dan
-- diperbarui tiap frame kalau game menulis nilai baru selama hub terbuka (mis. shift lock
-- dinyalakan/dimatikan), jadi yang dikembalikan adalah niat terakhir game, bukan data basi.

local BIND_NAME = "MugiwaraFreeCursor"

Cursor.Enabled = true -- bisa dimatikan user dari tab Misc

local windowOpen = false
local suspended = false -- true setelah Cursor.Lock(): kursor bebas ditahan sampai hub dibuka lagi
local active = false
local saved = nil -- { Behavior, Icon, MouseIcon } sebelum kursor dibebaskan

local env = getgenv()
local HANDOFF_MAX_AGE = 90 -- detik; warisan state dari sesi sebelumnya hanya berlaku sebentar

local Apply

-- Hanya dua kondisi yang dianggap "asli": dikunci di tengah (shift lock) atau bebas. Mode lain
-- (mis. LockCurrentPosition saat klik kanan ditahan untuk memutar kamera) sifatnya sementara dan
-- tidak boleh dipulihkan setelah hub ditutup.
local function NormalizeBehavior(behavior)
    if behavior == Enum.MouseBehavior.LockCenter then return behavior end
    return Enum.MouseBehavior.Default
end

local function Release()
    pcall(function() RunService:UnbindFromRenderStep(BIND_NAME) end)

    if saved then
        local snapshot = saved
        saved = nil
        pcall(function()
            UserInputService.MouseBehavior = snapshot.Behavior
            UserInputService.MouseIconEnabled = snapshot.Icon
            UserInputService.MouseIcon = snapshot.MouseIcon
        end)
    end
end

local function Step()
    -- Nilai non-default di sini berarti game baru saja menulisnya (kita sendiri selalu menulis
    -- Default/true), jadi itu kondisi yang harus dikembalikan saat hub ditutup.
    if saved then
        local behavior = UserInputService.MouseBehavior
        if behavior == Enum.MouseBehavior.LockCenter then saved.Behavior = behavior end
        local iconEnabled = UserInputService.MouseIconEnabled
        if iconEnabled ~= true then saved.Icon = iconEnabled end
    end

    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
end

Apply = function()
    local shouldFree = Cursor.Enabled and windowOpen and not suspended
    if shouldFree == active then return end
    active = shouldFree

    if active then
        saved = {
            Behavior = NormalizeBehavior(UserInputService.MouseBehavior),
            Icon = UserInputService.MouseIconEnabled,
            MouseIcon = UserInputService.MouseIcon,
        }

        -- Re-execute saat hub terbuka: sesi lama sudah mengembalikan kursor, tapi nilai yang terbaca
        -- sekarang bisa masih berupa kondisi bebas (bukan kondisi asli game). Kalau sesi lama
        -- mewariskan catatan kondisi asli, itu yang dipakai; hanya dipakai sekali.
        local handoff = env.MugiwaraCursorHandoff
        env.MugiwaraCursorHandoff = nil
        if type(handoff) == "table" and os.clock() - (handoff.At or 0) < HANDOFF_MAX_AGE then
            if saved.Behavior == Enum.MouseBehavior.Default and handoff.Behavior == Enum.MouseBehavior.LockCenter then
                saved.Behavior = handoff.Behavior
            end
            if saved.Icon == true and handoff.Icon == false then
                saved.Icon = false
            end
            if saved.MouseIcon == "" and type(handoff.MouseIcon) == "string" then
                saved.MouseIcon = handoff.MouseIcon
            end
        end

        -- Prioritas paling akhir: dijalankan setelah skrip kamera/shift lock milik game yang
        -- menyetel ulang MouseBehavior tiap frame, jadi nilai kita yang berlaku.
        pcall(function() RunService:UnbindFromRenderStep(BIND_NAME) end)
        RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Last.Value + 5, Step)
    else
        Release()
    end
end

-- Dipanggil Main.lua tiap jendela hub dibuka/ditutup.
function Cursor.SetWindowOpen(open)
    local wasOpen = windowOpen
    windowOpen = open == true
    if windowOpen and not wasOpen then suspended = false end
    Apply()
end

function Cursor.SetEnabled(state)
    Cursor.Enabled = state == true
    Apply()
end

-- Tombol "Lock Cursor": lepas mode kursor bebas lalu langsung kunci kursor ke tengah layar.
-- Kursor bebas lagi saat hub ditutup lalu dibuka kembali.
function Cursor.Lock()
    suspended = true
    Apply()
    pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end)
end

-- Full teardown on re-execute / unload: lepas kunci dan kembalikan kondisi mouse.
getgenv().MugiwaraRegisterCleanup(function()
    -- Kalau kursor sedang dibebaskan, catat kondisi aslinya untuk sesi berikutnya (re-execute).
    if saved then
        env.MugiwaraCursorHandoff = {
            Behavior = saved.Behavior,
            Icon = saved.Icon,
            MouseIcon = saved.MouseIcon,
            At = os.clock(),
        }
    end

    windowOpen = false
    suspended = false
    Apply()
    Release()
end)

return Cursor
