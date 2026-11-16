if _G.__isaac_history_modules and _G.__isaac_history_modules.debug_commands then
    return _G.__isaac_history_modules.debug_commands
end

local Storage = include("scripts.storage")
local HistoryMenu = include("scripts.history_menu")

local DebugCommands = {}

-- Ordered oldest -> newest because Storage.AddRun prepends to index 1
local SAMPLE_RUNS = {
    {
        isWin = false,
        playerType = 21, -- T. Isaac
        playerName = "T. Isaac",
        timeFrames = 26700, -- 14:50
        targetEntity = { type = 0, variant = 0, name = "Spikes / Hazard", deathAnimName = "Spikes" },
        items = { 68, 149, 261, 317, 379, 55, 2, 182 }
    },
    {
        isWin = true,
        playerType = 16, -- The Forgotten
        playerName = "The Forgotten",
        timeFrames = 56160, -- 31:12
        targetEntity = { type = 273, variant = 0, name = "The Lamb", deathAnimName = "TheLamb" },
        items = { 229, 440, 374, 300, 168, 80, 82, 215, 259, 51, 399 }
    },
    {
        isWin = false,
        playerType = 6, -- Samson
        playerName = "Samson",
        timeFrames = 19800, -- 11:00
        targetEntity = { type = 11, variant = 0, name = "Gusher", deathAnimName = "Gusher" },
        items = { 157, 14, 70, 116, 104, 228, 358, 496, 531 }
    },
    {
        isWin = false,
        playerType = 10, -- The Lost
        playerName = "The Lost",
        timeFrames = 32130, -- 17:51
        targetEntity = { type = 68, variant = 1, name = "The Bloat", deathAnimName = "Bloat" },
        items = { 313, 1, 245, 7, 15, 214, 25, 193 }
    },
    {
        isWin = true,
        playerType = 7, -- Azazel
        playerName = "Azazel",
        timeFrames = 84300, -- 46:50
        targetEntity = { type = 951, variant = 0, name = "The Beast", deathAnimName = "Beast" },
        items = { 118, 222, 159, 329, 13, 345, 360, 237, 275, 187, 276, 57, 128, 279, 318, 519 }
    },
    {
        isWin = true,
        playerType = 18, -- Bethany
        playerName = "Bethany",
        timeFrames = 75900, -- 42:10
        targetEntity = { type = 912, variant = 0, name = "Mother", deathAnimName = "Mother" },
        items = { 584, 182, 331, 108, 172, 246, 54, 21, 307, 138, 92, 73, 156, 207 }
    },
    {
        isWin = false,
        playerType = 3, -- Judas
        playerName = "Judas",
        timeFrames = 14850, -- 08:15
        targetEntity = { type = 85, variant = 0, name = "Spider", deathAnimName = "Spider" },
        items = { 34, 12, 51, 79 }
    },
    {
        isWin = true,
        playerType = 2, -- Cain
        playerName = "Cain",
        timeFrames = 64800, -- 36:00
        targetEntity = { type = 274, variant = 0, name = "Mega Satan", deathAnimName = "MegaSatan" },
        items = { 46, 17, 238, 239, 114, 153, 245, 311, 20, 62, 134, 89, 27, 32 }
    },
    {
        isWin = true,
        playerType = 0, -- Isaac
        playerName = "Isaac",
        timeFrames = 93150, -- 51:45
        targetEntity = { type = 412, variant = 0, name = "Delirium", deathAnimName = "Delirium" },
        items = {
            105, 182, 114, 331, 4, 12, 7, 169, 245, 360,
            153, 68, 395, 118, 224, 313, 108, 230, 51, 80,
            259, 399, 246, 54, 21, 92, 15, 20
        }
    },
    {
        isWin = false,
        playerType = 1, -- Magdalene
        playerName = "Magdalene",
        timeFrames = 990, -- 00:33
        targetEntity = { type = 14, variant = 0, name = "Pooter", deathAnimName = "Pooter" },
        items = { 45 }
    }
}

--- Initializes console commands (`history_mock`, `history_clear`, `history_list`, `history_toggle`, `history_key`)
---@param mod table
function DebugCommands.Init(mod)
    mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, function(_, cmd, params)
        local command = string.lower(tostring(cmd or ""))

        if command == "history_mock" then
            Storage.Clear(mod)
            for _, sample in ipairs(SAMPLE_RUNS) do
                Storage.AddRun(mod, sample)
            end
            local keyName = Storage.GetToggleKeyName(mod)
            Isaac.ConsoleOutput(string.format(
                "[Run History] Populated 10 mock runs! Open Main Menu -> [%s] History (or press %s / F3 in-game) to inspect.\n",
                keyName,
                keyName
            ))
            return true

        elseif command == "history_clear" then
            Storage.Clear(mod)
            Isaac.ConsoleOutput("[Run History] Cleared all recorded runs.\n")
            return true

        elseif command == "history_list" then
            local runs = Storage.GetRuns(mod)
            Isaac.ConsoleOutput(string.format("[Run History] Stored runs: %d / %d\n", #runs, Storage.MAX_RUNS))
            for idx, r in ipairs(runs) do
                local status = r.isWin and "WON" or "LOST"
                local targetName = r.targetEntity and r.targetEntity.name or "Unknown"
                local itemCount = r.items and #r.items or 0
                Isaac.ConsoleOutput(string.format(
                    "  #%d: [%s] %s | %s | %s | %d items\n",
                    idx,
                    status,
                    tostring(r.playerName),
                    tostring(r.timeFormatted),
                    tostring(targetName),
                    itemCount
                ))
            end
            return true

        elseif command == "history_toggle" then
            local isOpen = HistoryMenu.ToggleOverlay(mod)
            Isaac.ConsoleOutput(string.format("[Run History] In-game preview overlay: %s\n", isOpen and "OPEN" or "CLOSED"))
            return true

        elseif command == "history_key" then
            local trimmed = tostring(params or ""):match("^%s*(.-)%s*$")
            if trimmed == "" then
                Isaac.ConsoleOutput(string.format(
                    "[Run History] Current toggle hotkey: %s (Usage: history_key <KEY_NAME>, e.g. H, J, K, F3, TAB, SPACE)\n",
                    Storage.GetToggleKeyName(mod)
                ))
                return true
            end

            local keyCode = Storage.FindKeyByName(trimmed)
            if not keyCode then
                Isaac.ConsoleOutput(string.format(
                    "[Run History] Unknown or reserved key '%s'. Try letters A-Z, digits 0-9, F1, F3-F12, TAB, SPACE, or press [F2] inside the History panel.\n",
                    trimmed
                ))
                return true
            end

            local ok, err = Storage.SetToggleKey(mod, keyCode)
            if ok then
                Isaac.ConsoleOutput(string.format(
                    "[Run History] Toggle hotkey updated to: %s\n",
                    Storage.GetToggleKeyName(mod)
                ))
            else
                Isaac.ConsoleOutput(string.format("[Run History] Could not set key: %s\n", tostring(err)))
            end
            return true
        end
    end)
end

if _G.__isaac_history_modules then
    _G.__isaac_history_modules.debug_commands = DebugCommands
end

return DebugCommands
