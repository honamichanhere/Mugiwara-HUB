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
local openChecker = nil -- fungsi yang membaca status jendela sebenarnya (jaga-jaga event OnClose tidak sampai)

local Apply

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
    -- Event OnClose bisa terlewat (jendela ditutup lewat jalur lain): cek status sebenarnya.
    if openChecker and not openChecker() then
        windowOpen = false
        Apply()
        return
    end

    -- Nilai non-default di sini berarti game baru saja menulisnya (kita sendiri selalu menulis
    -- Default/true), jadi itu kondisi yang harus dikembalikan saat hub ditutup.
    if saved then
        local behavior = UserInputService.MouseBehavior
        if behavior ~= Enum.MouseBehavior.Default then saved.Behavior = behavior end
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
            Behavior = UserInputService.MouseBehavior,
            Icon = UserInputService.MouseIconEnabled,
            MouseIcon = UserInputService.MouseIcon,
        }

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

-- Main.lua memberi fungsi yang mengembalikan true selama jendela hub benar-benar terbuka.
function Cursor.SetOpenChecker(fn)
    openChecker = type(fn) == "function" and fn or nil
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
    windowOpen = false
    suspended = false
    openChecker = nil
    Apply()
    Release()
end)

return Cursor
