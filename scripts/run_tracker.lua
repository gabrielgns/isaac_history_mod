if _G.__isaac_history_modules and _G.__isaac_history_modules.run_tracker then
    return _G.__isaac_history_modules.run_tracker
end

local Storage = include("scripts.storage")
local IconResolver = include("scripts.icon_resolver")

local RunTracker = {}
local IS_REPENTOGON = (REPENTOGON ~= nil)

local ITEM_TYPE_ACTIVE = (ItemType and ItemType.ITEM_ACTIVE) or 3

-- Explicit numeric fallbacks prevent bitwise nil crashes if an enum field is unavailable
local SAFE_DAMAGE_FLAGS = {
    FIRE = (DamageFlag and DamageFlag.DAMAGE_FIRE) or (1 << 1),
    EXPLOSION = (DamageFlag and DamageFlag.DAMAGE_EXPLOSION) or (1 << 2),
    LASER = (DamageFlag and DamageFlag.DAMAGE_LASER) or (1 << 3),
    ACID = (DamageFlag and DamageFlag.DAMAGE_ACID) or (1 << 4),
    RED_HEARTS = (DamageFlag and DamageFlag.DAMAGE_RED_HEARTS) or (1 << 5),
    COUNTDOWN = (DamageFlag and DamageFlag.DAMAGE_COUNTDOWN) or (1 << 6),
    SPIKES = (DamageFlag and DamageFlag.DAMAGE_SPIKES) or (1 << 7),
    POOP = (DamageFlag and DamageFlag.DAMAGE_POOP) or (1 << 9),
    DEVIL = (DamageFlag and DamageFlag.DAMAGE_DEVIL) or (1 << 10),
    TNT = (DamageFlag and DamageFlag.DAMAGE_TNT) or (1 << 12),
    POISON_BURN = (DamageFlag and DamageFlag.DAMAGE_POISON_BURN) or (1 << 15),
    CURSED_DOOR = (DamageFlag and DamageFlag.DAMAGE_CURSED_DOOR) or (1 << 16),
    IV_BAG = (DamageFlag and DamageFlag.DAMAGE_IV_BAG) or (1 << 18),
    PITFALL = (DamageFlag and DamageFlag.DAMAGE_PITFALL) or (1 << 19),
    CHEST = (DamageFlag and DamageFlag.DAMAGE_CHEST) or (1 << 20),
    CRUSH = (DamageFlag and DamageFlag.DAMAGE_CRUSH) or (1 << 24)
}

--- Nil-safe bitwise DamageFlag check
---@param damageFlags integer|nil
---@param flag integer|nil
---@return boolean
local function hasDamageFlag(damageFlags, flag)
    if type(damageFlags) ~= "number" or type(flag) ~= "number" then
        return false
    end
    return (damageFlags & flag) ~= 0
end

-- Priority weights for major bosses so minor spawns or sub-bosses don't overwrite the main final boss
local MAJOR_BOSS_PRIORITY = {
    ["412.0"] = 100, -- Delirium
    ["951.0"] = 100, -- The Beast
    ["912.0"] = 95,  -- Mother
    ["275.0"] = 95,  -- Mega Satan 2
    ["274.0"] = 90,  -- Mega Satan
    ["406.1"] = 90,  -- Ultra Greedier
    ["406.0"] = 85,  -- Ultra Greed
    ["407.0"] = 80,  -- Hush
    ["273.0"] = 75,  -- The Lamb
    ["102.1"] = 75,  -- ??? (Blue Baby)
    ["950.0"] = 70,  -- Dogma
    ["84.0"]  = 65,  -- Satan
    ["102.0"] = 65,  -- Isaac
    ["78.1"]  = 55,  -- It Lives!
    ["78.0"]  = 50,  -- Mom's Heart
    ["45.0"]  = 45,  -- Mom
}

local currentRunState = {
    lastDamageSource = nil,
    lastBossKilled = nil,
    bestMajorBossKilled = nil,
    bestMajorBossPriority = -1,
    hasRecordedEnd = false,
    collectedItems = {},
    itemCounts = {},
    lastQueuedItem = {},
    lastInventorySyncFrame = -100
}

local function resetRunState()
    currentRunState = {
        lastDamageSource = nil,
        lastBossKilled = nil,
        bestMajorBossKilled = nil,
        bestMajorBossPriority = -1,
        hasRecordedEnd = false,
        collectedItems = {},
        itemCounts = {},
        lastQueuedItem = {},
        lastInventorySyncFrame = -100
    }
end

local function isVisibleCollectible(id, itemConfig)
    if type(id) ~= "number" or id <= 0 then
        return false
    end
    if not itemConfig then
        return true
    end
    local cfg = itemConfig:GetCollectible(id)
    if not cfg then
        return false
    end
    return not cfg.Hidden
end

local function getMainAndTwinPlayers(mainPlayer)
    local list = {}
    if not mainPlayer then
        return list
    end
    table.insert(list, mainPlayer)

    if mainPlayer.GetOtherTwin then
        local ok, twin = pcall(function()
            return mainPlayer:GetOtherTwin()
        end)
        if ok and twin and GetPtrHash(twin) ~= GetPtrHash(mainPlayer) then
            table.insert(list, twin)
        end
    end
    return list
end

local function isTrackedMainPlayer(player)
    if not player then
        return false
    end
    local mainPlayer = Isaac.GetPlayer(0)
    if not mainPlayer then
        return false
    end
    local targetHash = GetPtrHash(player)
    for _, p in ipairs(getMainAndTwinPlayers(mainPlayer)) do
        if GetPtrHash(p) == targetHash then
            return true
        end
    end
    return false
end

--- Reconciles recorded Vanilla item counts with current inventory (for starting items, D4, spindown, etc.)
---@param mainPlayer EntityPlayer
---@param itemConfig ItemConfig
local function syncVanillaInventoryCounts(mainPlayer, itemConfig)
    if not mainPlayer or not itemConfig or not itemConfig:GetCollectibles() then
        return
    end

    local players = getMainAndTwinPlayers(mainPlayer)
    local maxId = itemConfig:GetCollectibles().Size - 1
    for id = 1, maxId do
        local cfg = itemConfig:GetCollectible(id)
        if cfg and not cfg.Hidden then
            local totalCount = 0
            for _, p in ipairs(players) do
                totalCount = totalCount + (p:GetCollectibleNum(id, true) or 0)
            end
            local recordedCount = currentRunState.itemCounts[id] or 0
            if totalCount > recordedCount then
                for _ = 1, (totalCount - recordedCount) do
                    table.insert(currentRunState.collectedItems, id)
                end
                currentRunState.itemCounts[id] = totalCount
            end
        end
    end

    local game = Game()
    if game then
        currentRunState.lastInventorySyncFrame = game:GetFrameCount()
    end
end

--- Real-time chronological item tracking for Vanilla Repentance/Repentance+ (when GetHistory is absent)
---@param player EntityPlayer
local function trackVanillaPlayerItems(player)
    if (IS_REPENTOGON and player.GetHistory) or not isTrackedMainPlayer(player) then
        return
    end

    local itemConfig = Isaac.GetItemConfig()
    local pKey = GetPtrHash(player)
    local isQueueEmpty = player:IsItemQueueEmpty()

    if not isQueueEmpty and player.QueuedItem and player.QueuedItem.Item then
        local qItem = player.QueuedItem.Item
        if qItem.IsCollectible and qItem:IsCollectible() and isVisibleCollectible(qItem.ID, itemConfig) then
            if currentRunState.lastQueuedItem[pKey] ~= qItem.ID then
                currentRunState.lastQueuedItem[pKey] = qItem.ID
                -- Avoid duplicating active item swaps (e.g. juggling two active items repeatedly)
                local isActive = (qItem.Type == ITEM_TYPE_ACTIVE)
                local alreadyRecorded = (currentRunState.itemCounts[qItem.ID] or 0) > 0
                if not (isActive and alreadyRecorded) then
                    table.insert(currentRunState.collectedItems, qItem.ID)
                    currentRunState.itemCounts[qItem.ID] = (currentRunState.itemCounts[qItem.ID] or 0) + 1
                end
            end
        end
    elseif isQueueEmpty then
        currentRunState.lastQueuedItem[pKey] = nil
    end

    local mainPlayer = Isaac.GetPlayer(0)
    if mainPlayer and GetPtrHash(player) == GetPtrHash(mainPlayer) then
        local game = Game()
        local frameCount = game and game:GetFrameCount() or 0
        if currentRunState.lastInventorySyncFrame < 0 or (frameCount - currentRunState.lastInventorySyncFrame) >= 15 then
            syncVanillaInventoryCounts(mainPlayer, itemConfig)
        end
    end
end

--- Appends visible (non-hidden, non-trinket) collectibles from a single player entity
---@param targetPlayer EntityPlayer
---@param items integer[]
---@param itemConfig ItemConfig
local function appendPlayerItems(targetPlayer, items, itemConfig)
    if not targetPlayer then
        return
    end

    -- 1. REPENTOGON History API (preserves chronological pickup order)
    if IS_REPENTOGON and targetPlayer.GetHistory then
        local ok, history = pcall(function()
            return targetPlayer:GetHistory()
        end)
        if ok and history and history.GetCollectiblesHistory then
            local histOk, collectibles = pcall(function()
                return history:GetCollectiblesHistory()
            end)
            if histOk and type(collectibles) == "table" then
                for _, histItem in ipairs(collectibles) do
                    local isTrinket = false
                    if histItem.IsTrinket then
                        pcall(function()
                            isTrinket = histItem:IsTrinket()
                        end)
                    end
                    if not isTrinket and histItem.GetItemID then
                        local itemId = histItem:GetItemID()
                        if isVisibleCollectible(itemId, itemConfig) then
                            table.insert(items, itemId)
                        end
                    end
                end
                return
            end
        end
    end

    -- 2. Vanilla Inventory Fallback: Iterate through ItemConfig collectibles and check HasCollectible
    if itemConfig and itemConfig:GetCollectibles() then
        local maxId = itemConfig:GetCollectibles().Size - 1
        for id = 1, maxId do
            local cfg = itemConfig:GetCollectible(id)
            if cfg and not cfg.Hidden and targetPlayer:HasCollectible(id, true) then
                local count = targetPlayer:GetCollectibleNum(id, true)
                for _ = 1, math.max(1, count) do
                    table.insert(items, id)
                end
            end
        end
    end
end

--- Extracts all visible collected item IDs from the player (and twin for Jacob & Esau)
---@param player EntityPlayer
---@return integer[]
function RunTracker.CollectPlayerItems(player)
    local items = {}
    if not player then
        return items
    end

    local itemConfig = Isaac.GetItemConfig()

    -- 1. REPENTOGON: Use GetHistory() for exact chronological pickup order
    if IS_REPENTOGON and player.GetHistory then
        for _, p in ipairs(getMainAndTwinPlayers(player)) do
            appendPlayerItems(p, items, itemConfig)
        end
        if #items > 0 then
            return items
        end
    end

    -- 2. Vanilla: Flush inventory diff and return chronologically tracked collectedItems
    if isTrackedMainPlayer(player) then
        local mainPlayer = Isaac.GetPlayer(0) or player
        syncVanillaInventoryCounts(mainPlayer, itemConfig)
        if #currentRunState.collectedItems > 0 then
            local copy = {}
            for _, itemId in ipairs(currentRunState.collectedItems) do
                table.insert(copy, itemId)
            end
            return copy
        end
    end

    -- 3. Final fallback: Direct ItemConfig inventory scan
    for _, p in ipairs(getMainAndTwinPlayers(player)) do
        appendPlayerItems(p, items, itemConfig)
    end
    return items
end

--- Infers the end-game boss on Win if cutscene transitions end the run before MC_POST_NPC_DEATH triggers
---@param game Game
---@return table|nil bossRecord, integer priority
local function inferWinBossFromStage(game)
    if not game then
        return nil, -1
    end

    local level = game:GetLevel()
    local room = game:GetRoom()
    if not level then
        return nil, -1
    end

    if game:IsGreedMode() then
        local isGreedier = (game.Difficulty == Difficulty.DIFFICULTY_GREEDIER)
        return {
            type = 406,
            variant = isGreedier and 1 or 0,
            subtype = 0,
            name = isGreedier and "Ultra Greedier" or "Ultra Greed",
            deathAnimName = "UltraGreed"
        }, isGreedier and 90 or 85
    end

    local stage = level:GetStage()
    local stageType = level:GetStageType()
    local bossId = room and room.GetBossID and room:GetBossID() or 0

    -- Home / The Beast
    if stage == LevelStage.STAGE8 then
        return { type = 951, variant = 0, subtype = 0, name = "The Beast", deathAnimName = "Beast" }, 100
    end

    -- The Void / Delirium
    if stage == LevelStage.STAGE7 then
        return { type = 412, variant = 0, subtype = 0, name = "Delirium", deathAnimName = "Delirium" }, 100
    end

    -- Corpse II / Mother
    if stage == LevelStage.STAGE4_2 and (stageType == StageType.STAGETYPE_REPENTANCE or stageType == StageType.STAGETYPE_REPENTANCE_B) then
        return { type = 912, variant = 0, subtype = 0, name = "Mother", deathAnimName = "Mother" }, 95
    end

    -- Mega Satan (Boss ID 55 in Dark Room / Chest)
    if bossId == 55 then
        return { type = 274, variant = 0, subtype = 0, name = "Mega Satan", deathAnimName = "MegaSatan" }, 90
    end

    -- Dark Room / Chest
    if stage == LevelStage.STAGE6 then
        if stageType == StageType.STAGETYPE_ORIGINAL then
            return { type = 273, variant = 0, subtype = 0, name = "The Lamb", deathAnimName = "TheLamb" }, 75
        else
            return { type = 102, variant = 1, subtype = 0, name = "???", deathAnimName = "BlueBaby" }, 75
        end
    end

    -- Sheol / Cathedral
    if stage == LevelStage.STAGE5 then
        if stageType == StageType.STAGETYPE_ORIGINAL then
            return { type = 84, variant = 0, subtype = 0, name = "Satan", deathAnimName = "Satan" }, 65
        else
            return { type = 102, variant = 0, subtype = 0, name = "Isaac", deathAnimName = "Isaac" }, 65
        end
    end

    -- Womb II
    if stage == LevelStage.STAGE4_2 then
        return { type = 78, variant = 1, subtype = 0, name = "It Lives!", deathAnimName = "ItLives" }, 55
    end

    -- Depths II
    if stage == LevelStage.STAGE3_2 then
        return { type = 45, variant = 0, subtype = 0, name = "Mom", deathAnimName = "Mom" }, 45
    end

    return nil, -1
end

--- Resolves an EntityRef + DamageFlags into a clean targetEntity record
---@param source EntityRef
---@param damageFlags integer
---@return table
local function resolveDamageSource(source, damageFlags)
    local eType = source and source.Type or 0
    local eVar = source and source.Variant or 0
    local eSub = source and source.SubType or 0

    -- If hit by an enemy projectile, laser, or effect with a valid SpawnerType, credit the spawner enemy/boss
    if source and (eType == EntityType.ENTITY_PROJECTILE or eType == EntityType.ENTITY_LASER or eType == EntityType.ENTITY_EFFECT) then
        if source.SpawnerType and source.SpawnerType > 0 then
            eType = source.SpawnerType
            eVar = source.SpawnerVariant or 0
        end
    end

    if eType == 0 then
        local hazardName = "Spikes / Hazard"
        local animName = "Spikes"
        if hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.FIRE) then
            hazardName = "Fire"
            animName = "Fire"
        elseif hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.EXPLOSION) or hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.TNT) then
            hazardName = "Explosion"
            animName = "Bomb"
        elseif hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.CURSED_DOOR) then
            hazardName = "Curse Door"
            animName = "Spikes"
        elseif hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.DEVIL) then
            hazardName = "Devil Deal"
            animName = "Spikes"
        elseif hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.RED_HEARTS) or hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.IV_BAG) then
            hazardName = "Self Sacrifice"
            animName = "Spikes"
        elseif hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.POISON_BURN) or hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.ACID) then
            hazardName = "Poison / Acid"
            animName = "Spikes"
        elseif hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.CHEST) then
            hazardName = "Spiked Chest"
            animName = "Spikes"
        elseif hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.PITFALL) then
            hazardName = "Pitfall"
            animName = "Spikes"
        elseif hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.CRUSH) then
            hazardName = "Crushed"
            animName = "Spikes"
        elseif hasDamageFlag(damageFlags, SAFE_DAMAGE_FLAGS.SPIKES) then
            hazardName = "Spikes"
            animName = "Spikes"
        end
        return {
            type = 0,
            variant = 0,
            subtype = 0,
            name = hazardName,
            deathAnimName = animName
        }
    end

    local resolvedName, resolvedAnim = IconResolver.ResolveEntityInfo(eType, eVar)
    return {
        type = eType,
        variant = eVar,
        subtype = eSub,
        name = resolvedName,
        deathAnimName = resolvedAnim
    }
end

--- Initializes callbacks for tracking run progress and completion
---@param mod table
function RunTracker.Init(mod)
    -- Reset tracker on a brand new run
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
        Storage.Load(mod)
        if not isContinued then
            resetRunState()
        else
            currentRunState.hasRecordedEnd = false
            currentRunState.lastQueuedItem = {}
            currentRunState.lastInventorySyncFrame = -100
        end
    end)

    -- Real-time chronological item tracking for Vanilla Repentance/Repentance+ (zero overhead on REPENTOGON)
    if (not IS_REPENTOGON or not (EntityPlayer and EntityPlayer.GetHistory)) and ModCallbacks.MC_POST_PEFFECT_UPDATE then
        mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, function(_, player)
            trackVanillaPlayerItems(player)
        end)
    end

    -- Track the last damage source applied to the player
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, damageFlags, source, countdownFrames)
        if not entity or entity.Type ~= EntityType.ENTITY_PLAYER then
            return
        end
        currentRunState.lastDamageSource = resolveDamageSource(source, damageFlags)
    end, EntityType.ENTITY_PLAYER)

    -- Track defeated bosses
    mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, function(_, npc)
        if not npc or not npc:IsBoss() then
            return
        end

        local eType = npc.Type
        local eVar = npc.Variant
        local resolvedName, resolvedAnim = IconResolver.ResolveEntityInfo(eType, eVar)

        local bossRecord = {
            type = eType,
            variant = eVar,
            subtype = npc.SubType or 0,
            name = resolvedName,
            deathAnimName = resolvedAnim
        }

        currentRunState.lastBossKilled = bossRecord

        local key = string.format("%d.%d", eType, eVar)
        local genericKey = string.format("%d.0", eType)
        local priority = MAJOR_BOSS_PRIORITY[key] or MAJOR_BOSS_PRIORITY[genericKey] or 10

        if priority >= currentRunState.bestMajorBossPriority then
            currentRunState.bestMajorBossPriority = priority
            currentRunState.bestMajorBossKilled = bossRecord
        end
    end)

    -- Record completed run on Win or Game Over
    mod:AddCallback(ModCallbacks.MC_POST_GAME_END, function(_, isGameOver)
        if currentRunState.hasRecordedEnd then
            return
        end
        currentRunState.hasRecordedEnd = true

        local game = Game()
        local player = Isaac.GetPlayer(0)
        local playerType = player and player:GetPlayerType() or 0
        local playerName = IconResolver.GetPlayerName(playerType)
        local timeFrames = game and game.TimeCounter or 0
        local seeds = game and game:GetSeeds()
        local startSeedStr = seeds and seeds:GetStartSeedString() or ""

        local isWin = not isGameOver
        local targetEntity = nil

        if isWin then
            local stageBoss, stagePriority = inferWinBossFromStage(game)
            if stageBoss and (not currentRunState.bestMajorBossKilled or stagePriority > currentRunState.bestMajorBossPriority) then
                targetEntity = stageBoss
            else
                targetEntity = currentRunState.bestMajorBossKilled or currentRunState.lastBossKilled or {
                    type = 102,
                    variant = 0,
                    subtype = 0,
                    name = "Isaac",
                    deathAnimName = "Isaac"
                }
            end
        else
            targetEntity = currentRunState.lastDamageSource or {
                type = 0,
                variant = 0,
                subtype = 0,
                name = "Spikes / Hazard",
                deathAnimName = "Spikes"
            }
        end

        local collectedItems = RunTracker.CollectPlayerItems(player)

        Storage.AddRun(mod, {
            isWin = isWin,
            playerType = playerType,
            playerName = playerName,
            timeFrames = timeFrames,
            timeFormatted = Storage.FormatDuration(timeFrames),
            targetEntity = targetEntity,
            items = collectedItems,
            seed = startSeedStr
        })
    end)
end

if _G.__isaac_history_modules then
    _G.__isaac_history_modules.run_tracker = RunTracker
end

return RunTracker
