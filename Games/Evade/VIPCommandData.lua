-- Salinan data command Evade, dipakai kalau executor tidak bisa me-require modul game
-- (ReplicatedStorage.Shared.Admin.Commands.Commands). Bentuknya sama dengan entri aslinya:
--   CommandNames, CommandLayout, VIPMenuAccessible, VIPCommandDisablesRewards,
--   commandStringParents (folder tempat nama aset dicari).
-- Sumber: modul "Other" hasil decompile. Command dari modul lain (Admin, Fun, Camera, Data,
-- Developer, Announcements) belum ada di sini; tambahkan di bawah kalau sudah di-decompile.

local PLAYERS = "playersString"
local NUMBER = "numberString"
local STRING = "commandString"
local BOOLEAN = "booleanString"

-- vip: bisa dipakai lewat menu VIP; rewards: true kalau command mematikan reward
local function Command(names, layout, vip, rewards, parents)
    return {
        CommandNames = names,
        CommandLayout = layout,
        VIPMenuAccessible = vip == true,
        VIPCommandDisablesRewards = rewards == true,
        commandStringParents = parents,
    }
end

return {
    -- Suara
    Command({ "playerglobalvoicechat" }, { PLAYERS, BOOLEAN }, true, true),
    Command({ "globalvoicechat" }, { BOOLEAN }, true, false),

    -- Pemain
    Command({ "respawn" }, { PLAYERS }, true, true),
    Command({ "revive" }, { PLAYERS }, true, true),
    Command({ "kill" }, { PLAYERS }, true, false),
    Command({ "instakill" }, { PLAYERS }, false, false),
    Command({ "teleport", "tp" }, { PLAYERS, PLAYERS }, true, true),
    Command({ "god", "forcefield" }, { PLAYERS }, true, true),
    Command({ "ungod", "unforcefield" }, { PLAYERS }, true, false),
    Command({ "stretchvertical" }, { PLAYERS, NUMBER }, true, false),
    Command({ "stretchhorizontal" }, { PLAYERS, NUMBER }, true, false),
    Command({ "scale", "size" }, { PLAYERS, STRING }, false, false),
    Command({ "team", "setteam" }, { PLAYERS, STRING }, false, false),
    Command({ "tool", "givetool" }, { PLAYERS, STRING }, true, true, { { "ReplicatedStorage", "Tools" } }),

    -- Gerakan
    Command({ "speed", "movespeed" }, { PLAYERS, NUMBER }, true, true),
    Command({ "runaccel" }, { PLAYERS, NUMBER }, true, true),
    Command({ "friction" }, { PLAYERS, NUMBER }, true, true),
    Command({ "rundeaccel" }, { PLAYERS, NUMBER }, true, true),
    Command({ "airstrafeacceleration", "airstrafe" }, { PLAYERS, NUMBER }, true, true),
    Command({ "airacceleration" }, { PLAYERS, NUMBER }, true, true),
    Command({ "jumpspeedmultiplier", "jumpspeedmult", "jumpspeed" }, { PLAYERS, NUMBER }, true, true),
    Command({ "jumpheight", "jumppower" }, { PLAYERS, NUMBER }, true, true),
    Command({ "jumpcap" }, { PLAYERS, NUMBER }, true, true),

    -- Ronde, map, dan mode
    Command({ "timer", "settimer", "time", "intermissiontime", "setintermissiontime" }, { STRING }, true, false),
    Command({ "map", "forcemap" }, { STRING }, true, false, { { "ReplicatedStorage", "Info", "Maps" } }),
    Command({ "gamemode", "setgamemode", "setmode", "mode" }, { STRING }, true, false, { { "ReplicatedStorage", "Info", "Gamemodes" } }),
    Command({ "specialround", "setspecialround" }, { STRING }, true, false, { { "ReplicatedStorage", "Info", "SpecialRounds" } }),
    Command({ "gravity" }, { STRING }, true, true),

    -- AI, kendaraan, dan objek
    Command({ "clearai", "clearnpcs", "clearnextbots", "removeai", "removenpcs", "removenextbots", "destroyai", "destroynpcs", "destroynextbots" }, {}, true, true),
    Command({ "killai", "killnpcs", "killnextbots" }, {}, true, true),
    Command({ "enableai" }, {}, true, false),
    Command({ "disableai" }, {}, true, true),
    Command({ "insertai", "insertnpc", "insertnextbot", "ai", "nextbot", "npc" }, { STRING }, true, true, { { "ReplicatedStorage", "NPCs" } }),
    Command({ "insertvehicle", "vehicle" }, { STRING }, true, true, { { "ReplicatedStorage", "Assets", "Vehicles" } }),
    Command({ "clearvehicles", "destroyvehicles", "removevehicles" }, {}, true, false),
    Command({ "cleardeployables", "destroydeployables", "removedeployables" }, {}, true, false),
    Command({ "clearignore", "destroyignore", "removeignore" }, {}, false, false),
    Command({ "clearinviswalls", "destroyinviswalls", "removeinviswalls" }, {}, true, true),
    Command({ "showinviswalls", "viewinviswalls" }, {}, false, false),

    -- Server khusus
    Command({ "prioritize", "prioritizeserver", "prioritizecustomserver" }, { NUMBER }, false, false),
    Command({ "servercap", "playercap" }, { NUMBER }, false, false),
}
