local RoundState = {}

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- Fase ronde dibaca dari HUD, karena belum ada atribut/value yang terbukti memuat statusnya.
-- Label timer di atas layar bertuliskan "INTERMISSION" selama jeda antar ronde.
--   label terlihat           -> "Intermission"
--   label hilang setelahnya  -> "Round"
-- Ini deteksi "best effort": kalau Evade mengganti teks atau struktur HUD-nya, cukup ubah
-- INTERMISSION_KEYWORD di bawah, atau ganti Detect() dengan sinyal yang lebih andal.
local INTERMISSION_KEYWORD = "INTERMISSION"
local POLL_INTERVAL = 0.5      -- detik antar pengecekan
local SEARCH_INTERVAL = 2      -- detik minimal antar pencarian label baru (GetDescendants itu mahal)

RoundState.Phase = nil -- "Intermission", "Round", atau nil (belum diketahui)

local listeners = {}
local alive = true
local cachedLabel = nil
local lastSearch = 0

local function GetPlayerGui()
    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

-- Label benar-benar tampil di layar: dirinya dan semua induknya visible, ScreenGui enabled.
local function IsVisible(gui)
    local current = gui
    while current do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") then return current.Enabled end
        current = current.Parent
    end
    return false
end

local function HasKeyword(label)
    return string.find(string.upper(label.Text), INTERMISSION_KEYWORD, 1, true) ~= nil
end

local function IsCachedLabelValid(playerGui)
    return cachedLabel ~= nil
        and cachedLabel:IsDescendantOf(playerGui)
        and HasKeyword(cachedLabel)
end

local function FindLabel(playerGui)
    for _, inst in ipairs(playerGui:GetDescendants()) do
        if inst:IsA("TextLabel") and HasKeyword(inst) then return inst end
    end
    return nil
end

local function Detect()
    local playerGui = GetPlayerGui()
    if not playerGui then return RoundState.Phase end

    if not IsCachedLabelValid(playerGui) then
        cachedLabel = nil
        if os.clock() - lastSearch >= SEARCH_INTERVAL then
            lastSearch = os.clock()
            cachedLabel = FindLabel(playerGui)
        end
    end

    if cachedLabel and IsVisible(cachedLabel) then return "Intermission" end

    -- Label hilang/tersembunyi setelah sempat terlihat = intermission selesai.
    if RoundState.Phase == "Intermission" then return "Round" end
    return RoundState.Phase
end

-- Daftarkan fungsi yang dipanggil tiap fase berganti: fn(phase). Mengembalikan fungsi untuk berhenti.
function RoundState.OnChanged(fn)
    table.insert(listeners, fn)
    return function()
        local index = table.find(listeners, fn)
        if index then table.remove(listeners, index) end
    end
end

task.spawn(function()
    while alive do
        task.wait(POLL_INTERVAL)
        local ok, phase = pcall(Detect)
        if ok and phase ~= nil and phase ~= RoundState.Phase then
            RoundState.Phase = phase
            for _, fn in ipairs(table.clone(listeners)) do pcall(fn, phase) end
        end
    end
end)

-- Full teardown on re-execute / unload.
getgenv().MugiwaraRegisterCleanup(function()
    alive = false
    table.clear(listeners)
    cachedLabel = nil
end)

return RoundState
