local HideGui = {}

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

-- Menyembunyikan semua ScreenGui (game, CoreGui, dan GUI script lain) kecuali UI hub ini.
-- Sebelum dimatikan, tiap ScreenGui dicatat kondisi Enabled-nya, jadi yang memang sudah mati
-- sebelumnya tetap mati saat dikembalikan. Bagian bawaan Roblox (chat, daftar pemain, tas, dan
-- sebagainya) dikembalikan lewat SetCoreGuiEnabled dengan cara yang sama.
--
-- Tabel di sini sengaja tabel biasa (bukan weak table): kuncinya Instance, dan entri yang hilang
-- karena GC berarti ScreenGui tidak pernah dikembalikan.

HideGui.Enabled = false
HideGui.WindUI = nil -- diisi dari tab Misc; dipakai untuk mengenali GUI milik hub

local saved = {}        -- [ScreenGui] = nilai Enabled sebelum disembunyikan
local watchers = {}     -- [ScreenGui] = koneksi pantau Enabled
local containerConns = {}
local coreSaved = {}    -- [Enum.CoreGuiType] = kondisi sebelum disembunyikan
local coreConn = nil

local coreTypes = {}
for _, coreType in ipairs(Enum.CoreGuiType:GetEnumItems()) do
    if coreType ~= Enum.CoreGuiType.All then table.insert(coreTypes, coreType) end
end

-- GUI milik hub: keempat ScreenGui WindUI, loading screen, dan apa pun yang diawali "Mugiwara".
local function IsHubGui(gui)
    local ui = HideGui.WindUI
    if ui and (gui == ui.ScreenGui or gui == ui.NotificationGui or gui == ui.DropdownGui or gui == ui.TooltipGui) then
        return true
    end
    local name = gui.Name
    return name:sub(1, 6) == "WindUI" or name:sub(1, 8) == "Mugiwara"
end

local function Hide(gui)
    if not gui:IsA("ScreenGui") or IsHubGui(gui) or saved[gui] ~= nil then return end

    saved[gui] = gui.Enabled
    pcall(function() gui.Enabled = false end)

    -- Game yang menyalakan GUI-nya lagi (mis. saat ronde baru) langsung dimatikan lagi, dan
    -- nilai barunya dicatat sebagai kondisi yang harus dikembalikan.
    watchers[gui] = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if HideGui.Enabled and gui.Enabled then
            saved[gui] = true
            pcall(function() gui.Enabled = false end)
        end
    end)
end

local function Containers()
    local list = {}
    if LocalPlayer then
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui then table.insert(list, playerGui) end
    end
    table.insert(list, CoreGui)

    -- Executor menyimpan GUI script lain di gethui(); itu ikut disembunyikan kalau tempatnya beda.
    if gethui then
        local ok, hidden = pcall(gethui)
        if ok and typeof(hidden) == "Instance" and hidden ~= CoreGui then table.insert(list, hidden) end
    end
    return list
end

local function HideCore()
    for _, coreType in ipairs(coreTypes) do
        local ok, state = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, coreType)
        if ok then coreSaved[coreType] = state end
    end
    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)

    -- Kalau game menyalakan bagian bawaan lagi, matikan dan catat nilai barunya.
    local ok, signal = pcall(function() return StarterGui.CoreGuiChangedSignal end)
    if ok and signal then
        coreConn = signal:Connect(function(coreType, enabled)
            if not HideGui.Enabled or not enabled then return end
            if coreType == Enum.CoreGuiType.All then
                for _, each in ipairs(coreTypes) do coreSaved[each] = true end
            else
                coreSaved[coreType] = true
            end
            pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, false)
        end)
    end
end

function HideGui.SetHidden(state)
    state = state and true or false
    if state == HideGui.Enabled then return end

    if state then
        HideGui.Enabled = true

        for _, container in ipairs(Containers()) do
            local ok, children = pcall(container.GetChildren, container)
            if ok then
                for _, child in ipairs(children) do Hide(child) end
            end
            -- GUI yang muncul belakangan (respawn, ronde baru, script lain) ikut disembunyikan.
            table.insert(containerConns, container.ChildAdded:Connect(function(child)
                if HideGui.Enabled then Hide(child) end
            end))
        end

        HideCore()
        return
    end

    -- Matikan dulu pemantauannya, baru kembalikan satu per satu.
    HideGui.Enabled = false

    for _, conn in ipairs(containerConns) do conn:Disconnect() end
    containerConns = {}
    for _, conn in pairs(watchers) do conn:Disconnect() end
    watchers = {}
    if coreConn then coreConn:Disconnect() coreConn = nil end

    for gui, wasEnabled in pairs(saved) do
        -- GUI yang sudah dihapus game tidak perlu (dan tidak bisa) dikembalikan.
        if gui.Parent then pcall(function() gui.Enabled = wasEnabled end) end
    end
    saved = {}

    for coreType, wasEnabled in pairs(coreSaved) do
        pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, wasEnabled)
    end
    coreSaved = {}
end

-- Unload / re-execute: kembalikan semua GUI supaya tidak ada yang tertinggal tersembunyi.
getgenv().MugiwaraRegisterCleanup(function()
    HideGui.SetHidden(false)
end)

return HideGui
