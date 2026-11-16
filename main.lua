local mod = RegisterMod("Run History", 1)
mod.IS_REPENTOGON = (REPENTOGON ~= nil)

-- Mod-scoped singleton module cache so `include("scripts.xyz")` shares state across
-- submodules without touching global `package.loaded` or colliding with other Workshop mods
_G.__isaac_history_modules = {}

local Storage = include("scripts.storage")
local IconResolver = include("scripts.icon_resolver")
local RunTracker = include("scripts.run_tracker")
local HistoryMenu = include("scripts.history_menu")
local DebugCommands = include("scripts.debug_commands")

-- Preload persisted runs and user settings before registering UI/tracker callbacks
Storage.Load(mod)

-- Initialize all subsystems
RunTracker.Init(mod)
HistoryMenu.Init(mod)
DebugCommands.Init(mod)

local activeHotkey = Storage.GetToggleKeyName(mod)
if mod.IS_REPENTOGON then
    Isaac.ConsoleOutput(string.format(
        "[Run History] Loaded with REPENTOGON Main Menu integration enabled (Hotkey: %s).\n",
        activeHotkey
    ))
else
    Isaac.ConsoleOutput(string.format(
        "[Run History] Loaded in Vanilla compatibility mode (press %s or F3 in-game, or run 'history_toggle').\n",
        activeHotkey
    ))
end
