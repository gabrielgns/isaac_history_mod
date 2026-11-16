if _G.__isaac_history_modules and _G.__isaac_history_modules.storage then
    return _G.__isaac_history_modules.storage
end

local json = require("json")

local Storage = {}

Storage.MAX_RUNS = 10
Storage.SCHEMA_VERSION = 2

local DEFAULT_TOGGLE_KEY = (Keyboard and Keyboard.KEY_H) or 72

-- Human-readable names for bindable Keyboard key codes
local KEY_NAMES = {
    [32]  = "SPACE",
    [39]  = "'",
    [44]  = ",",
    [45]  = "-",
    [46]  = ".",
    [47]  = "/",
    [48]  = "0", [49] = "1", [50] = "2", [51] = "3", [52] = "4",
    [53]  = "5", [54] = "6", [55] = "7", [56] = "8", [57] = "9",
    [59]  = ";",
    [61]  = "=",
    [65]  = "A", [66] = "B", [67] = "C", [68] = "D", [69] = "E",
    [70]  = "F", [71] = "G", [72] = "H", [73] = "I", [74] = "J",
    [75]  = "K", [76] = "L", [77] = "M", [78] = "N", [79] = "O",
    [80]  = "P", [81] = "Q", [82] = "R", [83] = "S", [84] = "T",
    [85]  = "U", [86] = "V", [87] = "W", [88] = "X", [89] = "Y",
    [90]  = "Z",
    [91]  = "[",
    [92]  = "\\",
    [93]  = "]",
    [96]  = "`",
    [256] = "ESC",
    [257] = "ENTER",
    [258] = "TAB",
    [259] = "BACKSPACE",
    [260] = "INSERT",
    [261] = "DELETE",
    [262] = "RIGHT",
    [263] = "LEFT",
    [264] = "DOWN",
    [265] = "UP",
    [266] = "PGUP",
    [267] = "PGDN",
    [268] = "HOME",
    [269] = "END",
    [290] = "F1",  [291] = "F2",  [292] = "F3",  [293] = "F4",
    [294] = "F5",  [295] = "F6",  [296] = "F7",  [297] = "F8",
    [298] = "F9",  [299] = "F10", [300] = "F11", [301] = "F12",
}

-- Keys reserved for menu navigation, closing dialogs, or initiating key rebind
local RESERVED_KEYS = {
    [256] = true, -- KEY_ESCAPE
    [257] = true, -- KEY_ENTER
    [262] = true, -- KEY_RIGHT
    [263] = true, -- KEY_LEFT
    [264] = true, -- KEY_DOWN
    [265] = true, -- KEY_UP
    [291] = true, -- KEY_F2 (Rebind trigger)
}

-- Bidirectional name-to-keycode table (supports both canonical names and common aliases)
local NAME_TO_KEY = {}
for code, name in pairs(KEY_NAMES) do
    NAME_TO_KEY[name] = code
end

local KEY_ALIASES = {
    SPACEBAR      = 32,
    APOSTROPHE    = 39,
    QUOTE         = 39,
    COMMA         = 44,
    MINUS         = 45,
    DASH          = 45,
    PERIOD        = 46,
    DOT           = 46,
    SLASH         = 47,
    SEMICOLON     = 59,
    EQUAL         = 61,
    EQUALS        = 61,
    LEFT_BRACKET  = 91,
    LBRACKET      = 91,
    BACKSLASH     = 92,
    RIGHT_BRACKET = 93,
    RBRACKET      = 93,
    GRAVE         = 96,
    GRAVE_ACCENT  = 96,
    TILDE         = 96,
    ESCAPE        = 256,
    RETURN        = 257,
    BKSP          = 259,
    INS           = 260,
    DEL           = 261,
    PAGE_UP       = 266,
    PAGEUP        = 266,
    PAGE_DOWN     = 267,
    PAGEDOWN      = 267,
}
for alias, code in pairs(KEY_ALIASES) do
    NAME_TO_KEY[alias] = code
end

-- Deterministically ordered list of bindable keys for interactive listening and MCM cycling
local BINDABLE_KEYS = {}
do
    local orderedCodes = {}
    for code, _ in pairs(KEY_NAMES) do
        if not RESERVED_KEYS[code] then
            table.insert(orderedCodes, code)
        end
    end
    table.sort(orderedCodes)
    for _, code in ipairs(orderedCodes) do
        table.insert(BINDABLE_KEYS, { code = code, name = KEY_NAMES[code] })
    end
end

Storage.KEY_NAMES = KEY_NAMES
Storage.NAME_TO_KEY = NAME_TO_KEY
Storage.DEFAULT_TOGGLE_KEY = DEFAULT_TOGGLE_KEY

-- In-memory cache of the loaded history state (schema v2)
local cachedData = {
    version = Storage.SCHEMA_VERSION,
    settings = {
        toggleKey = DEFAULT_TOGGLE_KEY
    },
    runs = {}
}
local isLoaded = false
local activeModRef = nil

--- Normalizes optional mod + single-argument calls so Storage methods work with or without explicit `mod`
---@param modOrArg any
---@param maybeArg any
---@return table|nil, any
local function resolveModAndArg(modOrArg, maybeArg)
    if type(modOrArg) == "table" and (modOrArg.HasData ~= nil or modOrArg.SaveData ~= nil or modOrArg.Name ~= nil) then
        activeModRef = modOrArg
        return modOrArg, maybeArg
    end
    return activeModRef, modOrArg
end

--- Checks whether a key code is valid and not reserved for UI navigation
---@param keyCode any
---@return boolean
local function isValidBindableKey(keyCode)
    local num = tonumber(keyCode)
    return num ~= nil and KEY_NAMES[num] ~= nil and not RESERVED_KEYS[num]
end

--- Ensures decoded JSON data conforms to schema v2 and migrates v1 or raw run arrays losslessly
---@param decoded any
---@return table data, boolean didMigrate
local function normalizeAndMigrateData(decoded)
    if type(decoded) ~= "table" then
        return {
            version = Storage.SCHEMA_VERSION,
            settings = { toggleKey = DEFAULT_TOGGLE_KEY },
            runs = {}
        }, false
    end

    local didMigrate = false
    local runsList = {}

    if type(decoded.runs) == "table" then
        runsList = decoded.runs
        if tonumber(decoded.version) ~= Storage.SCHEMA_VERSION or type(decoded.settings) ~= "table" then
            didMigrate = true
        end
    elseif #decoded > 0 and type(decoded[1]) == "table" and (decoded[1].isWin ~= nil or decoded[1].playerType ~= nil) then
        -- Legacy raw runs array format
        runsList = decoded
        didMigrate = true
    else
        didMigrate = true
    end

    while #runsList > Storage.MAX_RUNS do
        table.remove(runsList)
    end

    local rawKey = decoded.settings and tonumber(decoded.settings.toggleKey)
    local toggleKey = isValidBindableKey(rawKey) and rawKey or DEFAULT_TOGGLE_KEY
    if not isValidBindableKey(rawKey) and decoded.settings ~= nil then
        didMigrate = true
    end

    return {
        version = Storage.SCHEMA_VERSION,
        settings = {
            toggleKey = toggleKey
        },
        runs = runsList
    }, didMigrate
end

--- Formats a game TimeCounter (30 frames per second) into MM:SS or HH:MM:SS
---@param frames integer
---@return string
function Storage.FormatDuration(frames)
    frames = math.max(0, math.floor(tonumber(frames) or 0))
    local totalSeconds = math.floor(frames / 30)
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = totalSeconds % 60

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, seconds)
    else
        return string.format("%02d:%02d", minutes, seconds)
    end
end

--- Saves the current history state to the mod's persistent storage
---@param mod? table
function Storage.Save(mod)
    mod = mod or activeModRef
    if not mod or not mod.SaveData then
        return
    end
    local ok, encoded = pcall(json.encode, cachedData)
    if ok and type(encoded) == "string" then
        pcall(function()
            mod:SaveData(encoded)
        end)
    end
end

--- Loads saved history data from the mod's persistent storage (auto-migrating v1 -> v2)
---@param mod? table
---@param forceReload? boolean
---@return table
function Storage.Load(mod, forceReload)
    if type(mod) == "boolean" then
        forceReload = mod
        mod = activeModRef
    elseif type(mod) == "table" then
        activeModRef = mod
    else
        mod = activeModRef
    end

    if isLoaded and not forceReload then
        return cachedData
    end

    if mod and mod.HasData and mod:HasData() then
        local ok, raw = pcall(function()
            return mod:LoadData()
        end)
        if ok and type(raw) == "string" and #raw > 0 then
            local decodeOk, decoded = pcall(json.decode, raw)
            if decodeOk and type(decoded) == "table" then
                local migratedData, didMigrate = normalizeAndMigrateData(decoded)
                cachedData = migratedData
                isLoaded = true
                if didMigrate then
                    Storage.Save(mod)
                end
                return cachedData
            end
        end
    end

    cachedData = {
        version = Storage.SCHEMA_VERSION,
        settings = {
            toggleKey = DEFAULT_TOGGLE_KEY
        },
        runs = {}
    }
    isLoaded = true
    return cachedData
end

--- Converts a Keyboard.KEY_* code into a readable label
---@param keyCode integer
---@return string
function Storage.GetKeyName(keyCode)
    local num = tonumber(keyCode)
    if num and KEY_NAMES[num] then
        return KEY_NAMES[num]
    end
    return "KEY_" .. tostring(keyCode)
end

--- Looks up a Keyboard.KEY_* code by human-readable key name (case-insensitive)
---@param name string
---@return integer|nil
function Storage.FindKeyByName(name)
    if type(name) ~= "string" then
        return nil
    end
    local normalized = name:match("^%s*(.-)%s*$"):upper()
    if #normalized == 0 then
        return nil
    end
    normalized = normalized:gsub("^KEY_", "")
    return NAME_TO_KEY[normalized]
end

--- Returns the ordered list of bindable { code, name } key entries
---@return table[]
function Storage.GetBindableKeys()
    return BINDABLE_KEYS
end

--- Returns the configured toggle hotkey code (defaults to Keyboard.KEY_H / 72)
---@param mod? table
---@return integer
function Storage.GetToggleKey(mod)
    local targetMod = resolveModAndArg(mod, nil)
    local data = Storage.Load(targetMod)
    local keyCode = data.settings and tonumber(data.settings.toggleKey)
    if isValidBindableKey(keyCode) then
        return keyCode
    end
    return DEFAULT_TOGGLE_KEY
end

--- Returns the human-readable name of the currently configured toggle hotkey
---@param mod? table
---@return string
function Storage.GetToggleKeyName(mod)
    return Storage.GetKeyName(Storage.GetToggleKey(mod))
end

--- Validates and saves a new toggle hotkey code
---@param modOrKey table|integer
---@param maybeKey? integer
---@return boolean success, string|nil errReason
function Storage.SetToggleKey(modOrKey, maybeKey)
    local targetMod, keyCode = resolveModAndArg(modOrKey, maybeKey)
    local num = tonumber(keyCode)
    if not num or not KEY_NAMES[num] then
        return false, "unrecognized keyboard key"
    end
    if RESERVED_KEYS[num] then
        return false, "key is reserved for menu navigation"
    end

    local data = Storage.Load(targetMod)
    data.version = Storage.SCHEMA_VERSION
    data.settings = data.settings or {}
    data.settings.toggleKey = num
    Storage.Save(targetMod)
    return true, nil
end

--- Returns the list of stored runs (newest first, up to MAX_RUNS)
---@param mod? table
---@return table[]
function Storage.GetRuns(mod)
    local targetMod = resolveModAndArg(mod, nil)
    local data = Storage.Load(targetMod)
    return data.runs or {}
end

--- Prepends a completed run record and trims the history to MAX_RUNS (10)
---@param mod table
---@param runRecord table
function Storage.AddRun(mod, runRecord)
    local targetMod, record = resolveModAndArg(mod, runRecord)
    local data = Storage.Load(targetMod, true)
    data.runs = data.runs or {}
    data.settings = data.settings or { toggleKey = DEFAULT_TOGGLE_KEY }

    local normalized = {
        isWin = record.isWin == true,
        playerType = tonumber(record.playerType) or 0,
        playerName = tostring(record.playerName or "Isaac"),
        timeFrames = tonumber(record.timeFrames) or 0,
        timeFormatted = record.timeFormatted or Storage.FormatDuration(record.timeFrames or 0),
        targetEntity = {
            type = tonumber(record.targetEntity and record.targetEntity.type) or 0,
            variant = tonumber(record.targetEntity and record.targetEntity.variant) or 0,
            subtype = tonumber(record.targetEntity and record.targetEntity.subtype) or 0,
            name = tostring((record.targetEntity and record.targetEntity.name) or (record.isWin and "Unknown Boss" or "Unknown")),
            deathAnimName = tostring((record.targetEntity and record.targetEntity.deathAnimName) or "Unknown")
        },
        items = {},
        seed = tostring(record.seed or ""),
        runIndex = (#data.runs + 1)
    }

    if type(record.items) == "table" then
        for _, itemId in ipairs(record.items) do
            local idNum = tonumber(itemId)
            if idNum and idNum > 0 then
                table.insert(normalized.items, idNum)
            end
        end
    end

    table.insert(data.runs, 1, normalized)

    while #data.runs > Storage.MAX_RUNS do
        table.remove(data.runs)
    end

    Storage.Save(targetMod)
end

--- Clears all recorded runs while preserving user hotkey settings
---@param mod? table
function Storage.Clear(mod)
    local targetMod = resolveModAndArg(mod, nil)
    local existing = Storage.Load(targetMod)
    local preservedKey = (existing.settings and existing.settings.toggleKey) or DEFAULT_TOGGLE_KEY

    cachedData = {
        version = Storage.SCHEMA_VERSION,
        settings = {
            toggleKey = preservedKey
        },
        runs = {}
    }
    isLoaded = true
    Storage.Save(targetMod)
end

if _G.__isaac_history_modules then
    _G.__isaac_history_modules.storage = Storage
end

return Storage
