local Cursor = {}

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Shift lock (bawaan Roblox maupun buatan game seperti Evade) mengunci mouse di tengah layar
-- lewat UserInputService.MouseBehavior, sehingga UI hub tidak bisa diklik. Selama jendela hub
-- terbuka modul ini membebaskan kursor; saat jendela ditutup, kondisi aslinya dikembalikan
-- (kalau shift lock sedang nyala, kursor kembali terkunci).

local BIND_NAME = "MugiwaraFreeCursor"

Cursor.Enabled = true -- bisa dimatikan user dari tab Misc

local windowOpen = false
local active = false
local saved = nil -- { Behavior, Icon } sebelum kursor dibebaskan

local function Apply()
    local shouldFree = Cursor.Enabled and windowOpen
    if shouldFree == active then return end
    active = shouldFree

    if active then
        saved = {
            Behavior = UserInputService.MouseBehavior,
            Icon = UserInputService.MouseIconEnabled,
        }

        -- Prioritas paling akhir: dijalankan setelah skrip kamera/shift lock milik game yang
        -- menyetel ulang MouseBehavior tiap frame, jadi nilai kita yang berlaku.
        pcall(function() RunService:UnbindFromRenderStep(BIND_NAME) end)
        RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Last.Value + 5, function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
    else
        pcall(function() RunService:UnbindFromRenderStep(BIND_NAME) end)

        if saved then
            UserInputService.MouseBehavior = saved.Behavior
            UserInputService.MouseIconEnabled = saved.Icon
            saved = nil
        end
    end
end

-- Dipanggil Main.lua tiap jendela hub dibuka/ditutup.
function Cursor.SetWindowOpen(open)
    windowOpen = open == true
    Apply()
end

function Cursor.SetEnabled(state)
    Cursor.Enabled = state == true
    Apply()
end

-- Full teardown on re-execute / unload: lepas kunci dan kembalikan kondisi mouse.
getgenv().MugiwaraRegisterCleanup(function()
    windowOpen = false
    Apply()
end)

return Cursor
