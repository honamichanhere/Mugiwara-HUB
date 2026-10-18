local Keybinds = {}

local HttpService = game:GetService("HttpService")

local ROOT = getgenv().MugiwaraFolder or "MugiwaraHub"
local PATH = ROOT .. "/Keybinds.json"

local data = {}

if readfile and isfile and isfile(PATH) then
    local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(PATH)) end)
    if ok and type(decoded) == "table" then data = decoded end
end

-- Nama tombol dianggap valid hanya kalau ada di Enum.KeyCode (mouse tidak didukung).
function Keybinds.IsValidKey(name)
    if type(name) ~= "string" then return false end
    return (pcall(function() return Enum.KeyCode[name] end))
end

function Keybinds.GetKeyCode(name)
    if not Keybinds.IsValidKey(name) then return nil end
    return Enum.KeyCode[name]
end

-- Saved key for an action, or the default when nothing valid is saved.
function Keybinds.Get(id, default)
    local saved = data[id]
    if Keybinds.IsValidKey(saved) then return saved end
    return default
end

local function Save()
    if writefile then
        pcall(function() writefile(PATH, HttpService:JSONEncode(data)) end)
    end
end

function Keybinds.Set(id, name)
    data[id] = name
    Save()
end

-- Master switch for all shortcuts. Disimpan di key khusus "_enabled"; default OFF.
function Keybinds.GetEnabled()
    return data._enabled == true
end

function Keybinds.SetEnabled(state)
    data._enabled = state == true
    Save()
end

return Keybinds
