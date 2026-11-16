if _G.__isaac_history_modules and _G.__isaac_history_modules.icon_resolver then
    return _G.__isaac_history_modules.icon_resolver
end

local IconResolver = {}

local IS_REPENTOGON = (REPENTOGON ~= nil)

local collectibleSprites = {}
local playerSprites = {}
local playerCostumeSprites = {}
local targetEntitySprites = {}

-- Complete static lookup table for all 41 vanilla PlayerType IDs (0..40) so Vanilla mode renders
-- accurate names, base skins, and hair/accessory costumes without REPENTOGON's EntityConfig.
local VANILLA_PLAYERS = {
    [0]  = { name = "Isaac",         skin = "gfx/characters/costumes/character_001_isaac.png",         costumes = {} },
    [1]  = { name = "Magdalene",     skin = "gfx/characters/costumes/character_002_magdalene.png",     costumes = { "gfx/characters/character_002_magdalenehead.anm2" } },
    [2]  = { name = "Cain",          skin = "gfx/characters/costumes/character_003_cain.png",          costumes = { "gfx/characters/character_003_cainseyepatch.anm2" } },
    [3]  = { name = "Judas",         skin = "gfx/characters/costumes/character_004_judas.png",         costumes = { "gfx/characters/character_004_judasfez.anm2" } },
    [4]  = { name = "???",           skin = "gfx/characters/costumes/character_006_bluebaby.png",      costumes = {} },
    [5]  = { name = "Eve",           skin = "gfx/characters/costumes/character_005_eve.png",           costumes = { "gfx/characters/character_005_evehead.anm2" } },
    [6]  = { name = "Samson",        skin = "gfx/characters/costumes/character_007_samson.png",        costumes = { "gfx/characters/character_007_samsonhead.anm2" } },
    [7]  = { name = "Azazel",        skin = "gfx/characters/costumes/character_008_azazel.png",        costumes = { "gfx/characters/t118_batwing.anm2", "gfx/characters/character_008_azazelhead.anm2" } },
    [8]  = { name = "Lazarus",       skin = "gfx/characters/costumes/character_009_lazarus.png",       costumes = { "gfx/characters/character_lazarushair1.anm2" } },
    [9]  = { name = "Eden",          skin = "gfx/characters/costumes/character_009_eden.png",          costumes = { "gfx/characters/character_009_edenhair1.anm2" } },
    [10] = { name = "The Lost",      skin = "gfx/characters/costumes/character_012_thelost.png",       costumes = { "gfx/characters/n_lost_body.anm2" } },
    [11] = { name = "Lazarus Risen", skin = "gfx/characters/costumes/character_010_lazarus2.png",      costumes = { "gfx/characters/character_lazarushair2.anm2" } },
    [12] = { name = "Dark Judas",    skin = "gfx/characters/costumes/character_013_blackjudas.png",    costumes = { "gfx/characters/character_004_judasfez.anm2" } },
    [13] = { name = "Lilith",        skin = "gfx/characters/costumes/character_014_lilith.png",        costumes = { "gfx/characters/character_lilithhair.anm2", "gfx/characters/n014_blindfold.anm2" } },
    [14] = { name = "Keeper",        skin = "gfx/characters/costumes/character_015_keeper.png",        costumes = { "gfx/characters/character_014_keepernoose.anm2" } },
    [15] = { name = "Apollyon",      skin = "gfx/characters/costumes/character_016_apollyon.png",      costumes = { "gfx/characters/character_015_apollyonbody.anm2" } },
    [16] = { name = "The Forgotten", skin = "gfx/characters/costumes/character_017_theforgotten.png",  costumes = { "gfx/characters/character_016_theforgottenbody.anm2" } },
    [17] = { name = "The Soul",      skin = "gfx/characters/costumes/character_018_thesoul.png",       costumes = { "gfx/characters/n_lost_body.anm2" } },
    [18] = { name = "Bethany",       skin = "gfx/characters/costumes/character_001x_bethany.png",      costumes = { "gfx/characters/character_001x_bethanyhead.anm2" } },
    [19] = { name = "Jacob & Esau",  skin = "gfx/characters/costumes/character_002x_jacob.png",        costumes = { "gfx/characters/character_002x_jacobhead.anm2" } },
    [20] = { name = "Esau",          skin = "gfx/characters/costumes/character_003x_esau.png",         costumes = { "gfx/characters/character_003x_esauhead.anm2" } },
    [21] = { name = "T. Isaac",      skin = "gfx/characters/costumes/character_001b_isaac.png",        costumes = { "gfx/characters/character_b01_isaac.anm2" } },
    [22] = { name = "T. Magdalene",  skin = "gfx/characters/costumes/character_002b_magdalene.png",    costumes = { "gfx/characters/character_b02_magdalene.anm2" } },
    [23] = { name = "T. Cain",       skin = "gfx/characters/costumes/character_003b_cain.png",         costumes = { "gfx/characters/character_b03_cain.anm2" } },
    [24] = { name = "T. Judas",      skin = "gfx/characters/costumes/character_004b_judas.png",        costumes = { "gfx/characters/character_b04_judas.anm2" } },
    [25] = { name = "T. ???",        skin = "gfx/characters/costumes/character_005b_bluebaby.png",     costumes = { "gfx/characters/character_b05_bluebaby.anm2" } },
    [26] = { name = "T. Eve",        skin = "gfx/characters/costumes/character_006b_eve.png",          costumes = { "gfx/characters/character_b06_eve.anm2" } },
    [27] = { name = "T. Samson",     skin = "gfx/characters/costumes/character_007b_samson.png",       costumes = { "gfx/characters/character_b07_samson.anm2" } },
    [28] = { name = "T. Azazel",     skin = "gfx/characters/costumes/character_008b_azazel.png",       costumes = { "gfx/characters/character_b08_azazel.anm2" } },
    [29] = { name = "T. Lazarus",    skin = "gfx/characters/costumes/character_009b_lazarus.png",      costumes = { "gfx/characters/character_b09_lazarus.anm2" } },
    [30] = { name = "T. Eden",       skin = "gfx/characters/costumes/character_009b_eden.png",         costumes = { "gfx/characters/character_b10_eden.anm2" } },
    [31] = { name = "T. Lost",       skin = "gfx/characters/costumes/character_012b_thelost.png",      costumes = { "gfx/characters/n_lost_body.anm2", "gfx/characters/character_b11_thelost.anm2" } },
    [32] = { name = "T. Lilith",     skin = "gfx/characters/costumes/character_014b_lilith.png",       costumes = { "gfx/characters/character_b12_lilith.anm2" } },
    [33] = { name = "T. Keeper",     skin = "gfx/characters/costumes/character_015b_keeper.png",       costumes = { "gfx/characters/character_b13_keeper.anm2" } },
    [34] = { name = "T. Apollyon",   skin = "gfx/characters/costumes/character_016b_apollyon.png",     costumes = { "gfx/characters/character_b14_apollyon.anm2" } },
    [35] = { name = "T. Forgotten",  skin = "gfx/characters/costumes/character_016b_theforgotten.png", costumes = { "gfx/characters/character_b15_theforgotten.anm2" } },
    [36] = { name = "T. Bethany",    skin = "gfx/characters/costumes/character_018b_bethany.png",      costumes = { "gfx/characters/character_b16_bethany.anm2" } },
    [37] = { name = "T. Jacob",      skin = "gfx/characters/costumes/character_019b_jacob.png",        costumes = { "gfx/characters/character_b17_jacob.anm2" } },
    [38] = { name = "T. Lazarus",    skin = "gfx/characters/costumes/character_009b_lazarus2.png",     costumes = { "gfx/characters/character_b09_lazarus2.anm2" } },
    [39] = { name = "T. Jacob",      skin = "gfx/characters/costumes/character_019b_jacob2.png",       costumes = { "gfx/characters/character_b17_jacob2.anm2" } },
    [40] = { name = "T. Soul",       skin = "gfx/characters/costumes/character_018b_thesoul.png",      costumes = { "gfx/characters/character_b15_theforgotten.anm2" } },
}

IconResolver.VANILLA_PLAYERS = VANILLA_PLAYERS

-- Mapping of (EntityType, Variant) to readable display names
local ENTITY_NAME_MAP = {
    -- Major Bosses
    ["45.0"]   = "Mom",
    ["78.0"]   = "Mom's Heart",
    ["78.1"]   = "It Lives!",
    ["84.0"]   = "Satan",
    ["102.0"]  = "Isaac",
    ["102.1"]  = "???",
    ["273.0"]  = "The Lamb",
    ["274.0"]  = "Mega Satan",
    ["275.0"]  = "Mega Satan 2",
    ["406.0"]  = "Ultra Greed",
    ["406.1"]  = "Ultra Greedier",
    ["407.0"]  = "Hush",
    ["412.0"]  = "Delirium",
    ["912.0"]  = "Mother",
    ["950.0"]  = "Dogma",
    ["951.0"]  = "The Beast",
    ["951.10"] = "Ultra Famine",
    ["951.20"] = "Ultra Pestilence",
    ["951.30"] = "Ultra War",
    ["951.40"] = "Ultra Death",
    -- Floor Bosses
    ["19.0"]   = "Larry Jr.",
    ["19.1"]   = "The Hollow",
    ["20.0"]   = "Monstro",
    ["28.0"]   = "Chub",
    ["36.0"]   = "Gurdy",
    ["43.0"]   = "Monstro II",
    ["62.0"]   = "Pin",
    ["63.0"]   = "Famine",
    ["64.0"]   = "Pestilence",
    ["65.0"]   = "War",
    ["66.0"]   = "Death",
    ["67.0"]   = "The Duke of Flies",
    ["68.0"]   = "Peep",
    ["68.1"]   = "The Bloat",
    ["69.0"]   = "Loki",
    ["71.0"]   = "Fistula",
    ["74.0"]   = "Blastocyst",
    ["79.0"]   = "Gemini",
    ["81.0"]   = "The Fallen",
    ["82.0"]   = "Headless Horseman",
    ["97.0"]   = "Mask of Infamy",
    ["99.0"]   = "Gurdy Jr.",
    ["100.0"]  = "Widow",
    ["101.0"]  = "Daddy Long Legs",
    ["237.0"]  = "Gurgling",
    ["260.0"]  = "The Haunt",
    ["261.0"]  = "Dingle",
    ["262.0"]  = "Mega Maw",
    ["263.0"]  = "The Gate",
    ["264.0"]  = "Mega Fatty",
    ["265.0"]  = "The Cage",
    ["266.0"]  = "Mama Gurdy",
    ["267.0"]  = "Dark One",
    ["268.0"]  = "The Adversary",
    ["269.0"]  = "Polycephalus",
    ["401.0"]  = "The Stain",
    ["402.0"]  = "Brownie",
    ["403.0"]  = "The Forsaken",
    ["404.0"]  = "Little Horn",
    ["405.0"]  = "Rag Man",
    ["900.0"]  = "Reap Creep",
    ["901.0"]  = "Lil Blub",
    ["902.0"]  = "The Rainmaker",
    ["903.0"]  = "The Visage",
    ["904.0"]  = "The Siren",
    ["905.0"]  = "The Heretic",
    ["908.0"]  = "Baby Plum",
    -- Common Enemies & Hazards
    ["10.0"]   = "Frowning Gaper",
    ["10.1"]   = "Gaper",
    ["10.2"]   = "Flaming Gaper",
    ["11.0"]   = "Gusher",
    ["11.1"]   = "Pacer",
    ["12.0"]   = "Horf",
    ["13.0"]   = "Fly",
    ["14.0"]   = "Pooter",
    ["15.0"]   = "Clotty",
    ["16.0"]   = "Mulligan",
    ["18.0"]   = "Attack Fly",
    ["21.0"]   = "Maggot",
    ["22.0"]   = "Hive",
    ["23.0"]   = "Charger",
    ["24.0"]   = "Globin",
    ["25.0"]   = "Boom Fly",
    ["26.0"]   = "Maw",
    ["27.0"]   = "Host",
    ["29.0"]   = "Hopper",
    ["29.1"]   = "Trite",
    ["30.0"]   = "Boil",
    ["31.0"]   = "Spitty",
    ["32.0"]   = "Brain",
    ["33.0"]   = "Fireplace",
    ["34.0"]   = "Leaper",
    ["38.0"]   = "Baby",
    ["39.0"]   = "Vis",
    ["40.0"]   = "Guts",
    ["41.0"]   = "Knight",
    ["42.0"]   = "Stone Grimace",
    ["85.0"]   = "Spider",
    ["86.0"]   = "Keeper Head",
    ["88.0"]   = "Walking Boil",
    ["94.0"]   = "Big Spider",
    ["208.0"]  = "Fatty",
    ["215.0"]  = "Dip",
    ["217.0"]  = "Corn Dip",
    ["227.0"]  = "Bony",
    ["0.0"]    = "Spikes / Hazard",
}

-- Vanilla entity .anm2 fallback paths when REPENTOGON's EntityConfig.GetEntity is unavailable
local VANILLA_ENTITY_ANM2 = {
    ["10.0"]  = { path = "gfx/010.000_frowninggaper.anm2", anim = "HeadDown", isBoss = false },
    ["11.0"]  = { path = "gfx/011.000_gusher.anm2",        anim = "WalkDown", isBoss = false },
    ["12.0"]  = { path = "gfx/012.000_horf.anm2",          anim = "Shake",    isBoss = false },
    ["13.0"]  = { path = "gfx/013.000_fly.anm2",           anim = "Fly",      isBoss = false },
    ["14.0"]  = { path = "gfx/014.000_pooter.anm2",        anim = "Fly",      isBoss = false },
    ["15.0"]  = { path = "gfx/015.000_clotty.anm2",        anim = "WalkDown", isBoss = false },
    ["20.0"]  = { path = "gfx/020.000_monstro.anm2",       anim = "Idle",     isBoss = true  },
    ["45.0"]  = { path = "gfx/045.000_mom.anm2",           anim = "Idle",     isBoss = true  },
    ["68.1"]  = { path = "gfx/068.001_the bloat.anm2",     anim = "Idle",     isBoss = true  },
    ["84.0"]  = { path = "gfx/084.000_satan.anm2",         anim = "Idle",     isBoss = true  },
    ["85.0"]  = { path = "gfx/085.000_spider.anm2",        anim = "Idle",     isBoss = false },
    ["102.0"] = { path = "gfx/102.000_isaac.anm2",         anim = "Idle",     isBoss = true  },
    ["273.0"] = { path = "gfx/273.000_thelamb.anm2",       anim = "Idle",     isBoss = true  },
    ["274.0"] = { path = "gfx/274.000_megasatan.anm2",     anim = "Idle",     isBoss = true  },
    ["406.0"] = { path = "gfx/406.000_ultragreed.anm2",    anim = "Idle",     isBoss = true  },
    ["407.0"] = { path = "gfx/407.000_hush.anm2",          anim = "Idle",     isBoss = true  },
    ["412.0"] = { path = "gfx/412.000_delirium.anm2",      anim = "Idle",     isBoss = true  },
    ["912.0"] = { path = "gfx/912.000_mother.anm2",        anim = "Idle",     isBoss = true  },
    ["950.0"] = { path = "gfx/950.000_dogma.anm2",         anim = "Idle",     isBoss = true  },
    ["951.0"] = { path = "gfx/951.000_beast.anm2",         anim = "Idle",     isBoss = true  },
}

--- Ensures an asset path starts with "gfx/" when loaded by Sprite:Load
---@param path string|nil
---@return string|nil
local function normalizeGfxPath(path)
    if type(path) ~= "string" or #path == 0 then
        return nil
    end
    if not path:lower():find("^gfx/") then
        return "gfx/" .. path
    end
    return path
end

--- Checks whether an animation exists on a loaded Sprite without generating warning noise when REPENTOGON is active
---@param spr Sprite
---@param animName string|nil
---@return boolean
local function hasAnimation(spr, animName)
    if type(animName) ~= "string" or #animName == 0 then
        return false
    end
    if IS_REPENTOGON and spr.GetAnimationData then
        local ok, data = pcall(spr.GetAnimationData, spr, animName)
        return ok and data ~= nil
    end
    local prevAnim = spr:GetAnimation()
    spr:SetFrame(animName, 0)
    if spr:GetAnimation() == animName then
        return true
    end
    if prevAnim and #prevAnim > 0 then
        spr:SetFrame(prevAnim, 0)
    end
    return false
end

--- Picks the best available idle/display animation and configures sprite scale/offset
---@param spr Sprite
---@param preferredAnim string|nil
---@param isBoss boolean
---@return number yOffset
local function finalizeEntitySprite(spr, preferredAnim, isBoss)
    local defAnim = spr:GetDefaultAnimation() or ""
    local candidates = { preferredAnim, "Idle", "WalkDown", "Fly", "HeadDown", "Appear", defAnim }
    local chosenAnim = defAnim
    for _, cand in ipairs(candidates) do
        if hasAnimation(spr, cand) then
            chosenAnim = cand
            break
        end
    end
    spr:SetFrame(chosenAnim, 0)
    local scale = isBoss and 0.24 or 0.36
    spr.Scale = Vector(scale, scale)
    return isBoss and 4 or 3
end

--- Converts a raw localization key like "#GUSHER_NAME" into "Gusher"
---@param rawKey string
---@param category string
---@return string
local function cleanLocalizedName(rawKey, category)
    if type(rawKey) ~= "string" or #rawKey == 0 then
        return ""
    end
    if not rawKey:find("^#") then
        return rawKey
    end

    if IS_REPENTOGON and Isaac and Isaac.GetString then
        local ok, translated = pcall(Isaac.GetString, category, rawKey)
        if ok and type(translated) == "string" and #translated > 0
            and translated ~= "StringTable::InvalidKey"
            and not translated:find("^#") then
            return translated
        end
    end

    local stripped = rawKey:gsub("^#", ""):gsub("_NAME$", ""):gsub("_", " "):lower()
    stripped = stripped:gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest
    end)
    return stripped
end

--- Resolves display name for a PlayerType (works in both REPENTOGON and Vanilla)
---@param playerType integer
---@return string
function IconResolver.GetPlayerName(playerType)
    playerType = tonumber(playerType) or 0
    local fallback = VANILLA_PLAYERS[playerType]
    if fallback then
        return fallback.name
    end
    if IS_REPENTOGON and EntityConfig and EntityConfig.GetPlayer then
        local ok, cfg = pcall(EntityConfig.GetPlayer, playerType)
        if ok and cfg and cfg.GetName then
            local cleaned = cleanLocalizedName(cfg:GetName(), "Players")
            if #cleaned > 0 then
                return cleaned
            end
        end
    end
    return "Player " .. tostring(playerType)
end

--- Resolves display name and an animation hint for an entity
---@param entityType integer
---@param variant integer
---@param fallbackName? string
---@return string name, string animName
function IconResolver.ResolveEntityInfo(entityType, variant, fallbackName)
    entityType = tonumber(entityType) or 0
    variant = tonumber(variant) or 0

    local exactKey = string.format("%d.%d", entityType, variant)
    local genericKey = string.format("%d.0", entityType)
    local mappedName = ENTITY_NAME_MAP[exactKey] or ENTITY_NAME_MAP[genericKey]

    local resolvedName = fallbackName
    if resolvedName and (resolvedName == "Unknown" or resolvedName:find("^Entity %d+$") or resolvedName:find("^Monster #%d+$") or resolvedName:find("^#")) then
        if resolvedName:find("^#") then
            resolvedName = cleanLocalizedName(resolvedName, "Entities")
        else
            resolvedName = nil
        end
    end

    if mappedName and (not resolvedName or resolvedName == "") then
        resolvedName = mappedName
    end

    if (not resolvedName or resolvedName == "") and IS_REPENTOGON and EntityConfig and EntityConfig.GetEntity and entityType > 0 then
        local ok, cfg = pcall(EntityConfig.GetEntity, entityType, variant, 0)
        if ok and cfg and cfg.GetName then
            local cleaned = cleanLocalizedName(cfg:GetName(), "Entities")
            if #cleaned > 0 then
                resolvedName = cleaned
            end
        end
    end

    if not resolvedName or resolvedName == "" then
        resolvedName = (entityType > 0) and ("Monster #" .. tostring(entityType)) or "Spikes / Hazard"
    end

    return resolvedName, "Idle"
end

--- Retrieves or creates a cached base Sprite for a character standing figure
---@param playerType integer
---@return Sprite|nil
function IconResolver.GetPlayerSprite(playerType)
    playerType = tonumber(playerType) or 0
    if playerSprites[playerType] ~= nil then
        return playerSprites[playerType] or nil
    end

    local skinPath = nil
    if IS_REPENTOGON and EntityConfig and EntityConfig.GetPlayer then
        local ok, cfg = pcall(EntityConfig.GetPlayer, playerType)
        if ok and cfg and cfg.GetSkinPath then
            local path = normalizeGfxPath(cfg:GetSkinPath())
            if path then
                skinPath = path
            end
        end
    end

    if not skinPath then
        local fallback = VANILLA_PLAYERS[playerType]
        skinPath = fallback and fallback.skin or VANILLA_PLAYERS[0].skin
    end

    local sprite = Sprite()
    local ok = pcall(function()
        sprite:Load("gfx/001.000_player.anm2", true)
        for layer = 0, 14 do
            sprite:ReplaceSpritesheet(layer, skinPath)
        end
        sprite:LoadGraphics()
        sprite:SetFrame("WalkDown", 0)
        sprite.Scale = Vector(0.80, 0.80)
    end)

    if ok and #(sprite:GetDefaultAnimation()) > 0 then
        playerSprites[playerType] = sprite
        return sprite
    else
        playerSprites[playerType] = false
        return nil
    end
end

--- Retrieves or creates cached costume Sprites (hair, hats, eyepatches, wings, etc.) for a PlayerType
---@param playerType integer
---@return table[]
local function getPlayerCostumeSprites(playerType)
    playerType = tonumber(playerType) or 0
    if playerCostumeSprites[playerType] ~= nil then
        return playerCostumeSprites[playerType]
    end

    local paths = {}
    local seen = {}

    local function addPath(p)
        local norm = normalizeGfxPath(p)
        if norm and not seen[norm] then
            seen[norm] = true
            table.insert(paths, norm)
        end
    end

    -- 1. Check REPENTOGON EntityConfig costume ID first for modded characters or automatic resolution
    if IS_REPENTOGON and EntityConfig and EntityConfig.GetPlayer then
        local ok, cfg = pcall(EntityConfig.GetPlayer, playerType)
        if ok and cfg and cfg.GetCostumeID then
            local cidOk, costumeId = pcall(cfg.GetCostumeID, cfg)
            if cidOk and type(costumeId) == "number" and costumeId > 0 then
                local itemCfg = Isaac.GetItemConfig()
                local costumeCfg = itemCfg and itemCfg:GetNullItem(costumeId)
                if costumeCfg and costumeCfg.Costume and costumeCfg.Costume.Anm2Path then
                    addPath(costumeCfg.Costume.Anm2Path)
                end
            end
        end
    end

    -- 2. Include verified vanilla character costume .anm2 files (required in Vanilla mode & complementary in REPENTOGON)
    local fallback = VANILLA_PLAYERS[playerType]
    if fallback and fallback.costumes then
        for _, costumePath in ipairs(fallback.costumes) do
            addPath(costumePath)
        end
    end

    local loadedCostumes = {}
    for _, path in ipairs(paths) do
        local cSpr = Sprite()
        local loaded = pcall(function()
            cSpr:Load(path, true)
            cSpr.Scale = Vector(0.80, 0.80)
        end)
        local defAnim = loaded and cSpr:GetDefaultAnimation() or ""
        if loaded and #defAnim > 0 then
            table.insert(loadedCostumes, {
                sprite = cSpr,
                hasWalk = hasAnimation(cSpr, "WalkDown"),
                hasHead = hasAnimation(cSpr, "HeadDown"),
                defaultAnim = defAnim
            })
        end
    end

    playerCostumeSprites[playerType] = loadedCostumes
    return loadedCostumes
end

--- Renders the character's full figure (body, head, and hair/accessories costumes) at the given screen position
---@param playerType integer
---@param pos Vector
function IconResolver.RenderPlayerFigure(playerType, pos)
    local spr = IconResolver.GetPlayerSprite(playerType)
    if not spr then
        return
    end
    local costumes = getPlayerCostumeSprites(playerType)

    pcall(function()
        -- 1. Render body & legs
        spr:SetFrame("WalkDown", 0)
        spr:Render(pos, Vector.Zero, Vector.Zero)

        -- 2. Render body-level costumes (e.g., Azazel wings, Forgotten bone body)
        for _, c in ipairs(costumes) do
            if c.hasWalk then
                c.sprite:SetFrame("WalkDown", 0)
                c.sprite:Render(pos, Vector.Zero, Vector.Zero)
            end
        end

        -- 3. Render head on top of the body
        spr:SetFrame("HeadDown", 0)
        spr:Render(pos, Vector.Zero, Vector.Zero)

        -- 4. Render head-level costumes (hair, eyepatch, fez, horns, blindfold, etc.)
        for _, c in ipairs(costumes) do
            if c.hasHead then
                c.sprite:SetFrame("HeadDown", 0)
                c.sprite:Render(pos, Vector.Zero, Vector.Zero)
            elseif not c.hasWalk and c.defaultAnim and #c.defaultAnim > 0 then
                c.sprite:SetFrame(c.defaultAnim, 0)
                c.sprite:Render(pos, Vector.Zero, Vector.Zero)
            end
        end
    end)
end

--- Retrieves or creates a cached Sprite for a collectible item ID
---@param itemId integer
---@return Sprite|nil
function IconResolver.GetCollectibleSprite(itemId)
    itemId = tonumber(itemId) or 0
    if itemId <= 0 then
        return nil
    end

    if collectibleSprites[itemId] ~= nil then
        return collectibleSprites[itemId] or nil
    end

    local itemConfig = Isaac.GetItemConfig()
    local cfg = itemConfig and itemConfig:GetCollectible(itemId)
    if not cfg or not cfg.GfxFileName or cfg.GfxFileName == "" then
        collectibleSprites[itemId] = false
        return nil
    end

    local sprite = Sprite()
    local ok = pcall(function()
        sprite:Load("gfx/005.100_collectible.anm2", true)
        sprite:ReplaceSpritesheet(1, cfg.GfxFileName)
        sprite:LoadGraphics()
        sprite:SetFrame("ShopIdle", 0)
        sprite.Scale = Vector(0.62, 0.62)
    end)

    if ok and #(sprite:GetDefaultAnimation()) > 0 then
        collectibleSprites[itemId] = sprite
        return sprite
    else
        collectibleSprites[itemId] = false
        return nil
    end
end

--- Retrieves or creates a cached Sprite and vertical render offset for a boss or killer icon
---@param targetEntity table
---@param isWin? boolean
---@return Sprite|nil, number yOffset
function IconResolver.GetTargetEntitySprite(targetEntity, isWin)
    if type(targetEntity) ~= "table" then
        targetEntity = {}
    end

    local eType = tonumber(targetEntity.type) or 0
    local eVar = tonumber(targetEntity.variant) or 0
    local eSub = tonumber(targetEntity.subtype) or 0
    local winFlag = (isWin == true)

    local cacheKey = string.format("%d.%d.%d.%s", eType, eVar, eSub, winFlag and "W" or "L")
    if targetEntitySprites[cacheKey] ~= nil then
        local cached = targetEntitySprites[cacheKey]
        if cached == false then
            return nil, 0
        end
        return cached.sprite, cached.yOffset
    end

    -- 1. Try REPENTOGON EntityConfig.GetEntity (covers all vanilla & modded monsters and bosses)
    if IS_REPENTOGON and EntityConfig and EntityConfig.GetEntity and eType > 0 then
        local ok, cfg = pcall(EntityConfig.GetEntity, eType, eVar, eSub)
        if not ok or not cfg then
            ok, cfg = pcall(EntityConfig.GetEntity, eType, eVar, 0)
        end

        if ok and cfg then
            local isBoss = cfg.IsBoss and cfg:IsBoss() or false
            local candidatePaths = {}
            if cfg.GetBestiaryAnm2Path then
                local bPath = normalizeGfxPath(cfg:GetBestiaryAnm2Path())
                if bPath then
                    table.insert(candidatePaths, { path = bPath, isBestiary = true })
                end
            end
            if cfg.GetAnm2Path then
                local aPath = normalizeGfxPath(cfg:GetAnm2Path())
                if aPath then
                    table.insert(candidatePaths, { path = aPath, isBestiary = false })
                end
            end

            for _, entry in ipairs(candidatePaths) do
                local entSprite = Sprite()
                local loaded = pcall(function()
                    entSprite:Load(entry.path, true)
                end)
                local defAnim = loaded and entSprite:GetDefaultAnimation() or ""
                if loaded and #defAnim > 0 then
                    local bestiaryAnim = entry.isBestiary and cfg.GetBestiaryAnimation and cfg:GetBestiaryAnimation() or nil
                    local yOffset = finalizeEntitySprite(entSprite, bestiaryAnim, isBoss)
                    targetEntitySprites[cacheKey] = { sprite = entSprite, yOffset = yOffset }
                    return entSprite, yOffset
                end
            end
        end
    end

    -- 2. Vanilla Static Fallback (.anm2 lookup for bosses and common monsters when EntityConfig is absent)
    if eType > 0 then
        local exactKey = string.format("%d.%d", eType, eVar)
        local genericKey = string.format("%d.0", eType)
        local vanillaEntry = VANILLA_ENTITY_ANM2[exactKey] or VANILLA_ENTITY_ANM2[genericKey]
        if vanillaEntry then
            local entSprite = Sprite()
            local loaded = pcall(function()
                entSprite:Load(vanillaEntry.path, true)
            end)
            local defAnim = loaded and entSprite:GetDefaultAnimation() or ""
            if loaded and #defAnim > 0 then
                local yOffset = finalizeEntitySprite(entSprite, vanillaEntry.anim, vanillaEntry.isBoss)
                targetEntitySprites[cacheKey] = { sprite = entSprite, yOffset = yOffset }
                return entSprite, yOffset
            end
        end
    end

    -- 3. Guaranteed Fallback: CrownIcon (Win) or SkullIcon (Loss) from our bundled history_ui.anm2
    local fallbackSprite = Sprite()
    local fallbackAnim = winFlag and "CrownIcon" or "SkullIcon"
    local fbOk = pcall(function()
        fallbackSprite:Load("gfx/ui/history_ui.anm2", true)
        fallbackSprite:SetFrame(fallbackAnim, 0)
        fallbackSprite.Scale = Vector(0.85, 0.85)
    end)
    if fbOk and #(fallbackSprite:GetDefaultAnimation()) > 0 then
        targetEntitySprites[cacheKey] = { sprite = fallbackSprite, yOffset = -2 }
        return fallbackSprite, -2
    end

    targetEntitySprites[cacheKey] = false
    return nil, 0
end

if _G.__isaac_history_modules then
    _G.__isaac_history_modules.icon_resolver = IconResolver
end

return IconResolver
