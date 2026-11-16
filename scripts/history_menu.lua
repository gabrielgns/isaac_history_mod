if _G.__isaac_history_modules and _G.__isaac_history_modules.history_menu then
    return _G.__isaac_history_modules.history_menu
end

local Storage = include("scripts.storage")
local IconResolver = include("scripts.icon_resolver")

local HistoryMenu = {}
local IS_REPENTOGON = (REPENTOGON ~= nil)

local KEY_REBIND = (Keyboard and Keyboard.KEY_F2) or 291
local KEY_FALLBACK_F3 = (Keyboard and Keyboard.KEY_F3) or 292
local KEY_ESCAPE_CODE = (Keyboard and Keyboard.KEY_ESCAPE) or 256

-- Fonts
local titleFont = Font()
local bodyFont = Font()
local smallFont = Font()
local fontsLoaded = false

-- UI Sprite Atlas (resources/gfx/ui/history_ui.anm2)
local uiSprite = Sprite()
local uiSpriteLoaded = false

local function ensureAssetsLoaded()
    if not fontsLoaded then
        pcall(function()
            titleFont:Load("font/teammeatfont12.fnt")
            bodyFont:Load("font/teammeatfont10.fnt")
            smallFont:Load("font/pftempestasevencondensed.fnt")
        end)
        fontsLoaded = true
    end

    if not uiSpriteLoaded then
        local ok = pcall(function()
            uiSprite:Load("gfx/ui/history_ui.anm2", true)
            uiSprite:SetFrame("Board", 0)
        end)
        if ok and #(uiSprite:GetDefaultAnimation()) > 0 then
            uiSpriteLoaded = true
        end
    end
end

-- Menu state
local state = {
    isHistoryPageOpen = false,   -- True when viewing the History screen on the Main Menu
    isInGameOverlayOpen = false, -- Toggleable overlay inside an active run
    waitingForKey = false,       -- True while capturing a new toggle hotkey via [F2]
    selectedRunIdx = 1,          -- 1..#runs (Up/Down navigation)
    scrollStartRunIdx = 1,       -- Top visible run card index in the viewport
    itemScrollOffset = 0,        -- Horizontal column scroll offset for the selected run's items
    inputCooldown = 0,           -- Cooldown frames after opening/closing modal
    pendingRestoreInput = false  -- Delays restoring native menu input mask until Esc key clears
}

local VISIBLE_CARDS = 3
local ITEMS_PER_ROW = 6
local ITEM_ROWS_PER_CARD = 2

-- Gameplay actions suppressed while the in-game History overlay is active
local BLOCKED_OVERLAY_ACTIONS = ButtonAction and {
    [ButtonAction.ACTION_LEFT] = true,
    [ButtonAction.ACTION_RIGHT] = true,
    [ButtonAction.ACTION_UP] = true,
    [ButtonAction.ACTION_DOWN] = true,
    [ButtonAction.ACTION_SHOOTLEFT] = true,
    [ButtonAction.ACTION_SHOOTRIGHT] = true,
    [ButtonAction.ACTION_SHOOTUP] = true,
    [ButtonAction.ACTION_SHOOTDOWN] = true,
    [ButtonAction.ACTION_BOMB] = true,
    [ButtonAction.ACTION_ITEM] = true,
    [ButtonAction.ACTION_PILLCARD] = true,
    [ButtonAction.ACTION_DROP] = true,
    [ButtonAction.ACTION_PAUSE] = true,
    [ButtonAction.ACTION_MAP] = true,
    [ButtonAction.ACTION_RESTART] = true
} or {}

-- Colors
local COLOR_HISTORY_GREEN = KColor(0.22, 0.85, 0.34, 1.0)
local COLOR_MENU_INK      = KColor(0.21, 0.18, 0.17, 0.95)
local COLOR_PAPER_TEXT    = KColor(0.92, 0.90, 0.86, 1.0)
local COLOR_MUTED_TEXT    = KColor(0.68, 0.66, 0.62, 0.95)
local COLOR_WON           = KColor(0.28, 0.92, 0.40, 1.0)
local COLOR_LOST          = KColor(0.96, 0.34, 0.34, 1.0)
local COLOR_SELECTED_GLOW = KColor(0.28, 0.88, 0.40, 1.0)
local COLOR_ITEM_BOX_HL   = KColor(0.58, 0.64, 0.96, 1.0)
local COLOR_KEYBIND_HINT  = KColor(0.96, 0.86, 0.36, 1.0)

--- Plays a menu sound effect safely
---@param sfxId integer
local function playMenuSound(sfxId)
    if SFXManager then
        pcall(function()
            SFXManager():Play(sfxId, 1.0, 0, false, 1.0)
        end)
    end
end

--- Checks if an action was triggered across keyboard or controller
---@param action integer
---@return boolean
local function isMenuActionTriggered(action)
    for controllerIdx = 0, 4 do
        if Input.IsActionTriggered(action, controllerIdx) then
            return true
        end
    end
    return false
end

--- Restores full input mask to the native Main Menu
local function restoreNativeMenuInput()
    if MenuManager and MenuManager.SetInputMask then
        pcall(function()
            MenuManager.SetInputMask(0xFFFFFFFF)
        end)
    end
end

--- Blocks native Main Menu inputs while our custom History modal is open
---@param mask integer
local function setNativeMenuInputMask(mask)
    if MenuManager and MenuManager.SetInputMask then
        pcall(function()
            MenuManager.SetInputMask(mask)
        end)
    end
end

--- Opens the History modal page from the Main Menu
---@param mod table
local function openHistoryPage(mod)
    Storage.Load(mod, true)
    state.isHistoryPageOpen = true
    state.waitingForKey = false
    state.pendingRestoreInput = false
    state.selectedRunIdx = 1
    state.scrollStartRunIdx = 1
    state.itemScrollOffset = 0
    state.inputCooldown = 6

    setNativeMenuInputMask(0)
    playMenuSound(SoundEffect.SOUND_PAPER_IN)
end

--- Closes the History modal page and schedules native menu input restoration
local function closeHistoryPage()
    state.isHistoryPageOpen = false
    state.waitingForKey = false
    state.pendingRestoreInput = true
    state.inputCooldown = 5

    setNativeMenuInputMask(0)
    playMenuSound(SoundEffect.SOUND_PAPER_OUT)
end

--- Closes the in-game History overlay
local function closeInGameOverlay()
    state.isInGameOverlayOpen = false
    state.waitingForKey = false
    state.inputCooldown = 5
    playMenuSound(SoundEffect.SOUND_PAPER_OUT)
end

--- Renders a single Run Card (332x56) inside the History board
---@param run table
---@param index integer
---@param cardX number
---@param cardY number
---@param isSelected boolean
local function renderRunCard(run, index, cardX, cardY, isSelected)
    ensureAssetsLoaded()

    local cardH = 56
    local leftColW = 58

    -- 1. Draw Run Card Background & Rounded Frame from history_ui.anm2
    if uiSpriteLoaded then
        uiSprite:SetFrame(isSelected and "RunCardSelected" or "RunCard", 0)
        uiSprite:Render(Vector(cardX, cardY), Vector.Zero, Vector.Zero)
    end

    -- Selection index badge (#1 .. #10) in top-left corner
    local indexBadgeColor = isSelected and COLOR_SELECTED_GLOW or COLOR_MUTED_TEXT
    smallFont:DrawString(string.format("#%d", index), cardX + 5, cardY + 3, indexBadgeColor, 0, false)

    -- 2. Character Standing Figure (Body + Head + Hair/Costumes) in Left Column (x = 0..58)
    local charCenterX = cardX + 29
    local charCenterY = cardY + 32
    IconResolver.RenderPlayerFigure(run.playerType, Vector(charCenterX, charCenterY))

    -- Character Name centered and auto-scaled so long names (e.g. "Magdalene") stay inside the 58px column
    local charName = tostring(run.playerName or IconResolver.GetPlayerName(run.playerType))
    local charStrW = smallFont:GetStringWidth(charName)
    local charScale = (charStrW > 48) and math.max(0.55, 48 / charStrW) or 0.85
    local charTextX = cardX + math.floor((leftColW - (charStrW * charScale)) / 2)
    smallFont:DrawStringScaled(charName, charTextX, cardY + cardH - 12, charScale, charScale, COLOR_PAPER_TEXT, 0, false)

    -- 3. Outcome, Duration, and Boss / Killer (Middle Column, x = 63..152)
    local infoX = cardX + 63
    local outcomeStr = run.isWin and "Won" or "Lost"
    local outcomeColor = run.isWin and COLOR_WON or COLOR_LOST
    bodyFont:DrawStringScaled(outcomeStr, infoX, cardY + 3, 0.85, 0.85, outcomeColor, 0, false)

    -- Run Duration (MM:SS or HH:MM:SS)
    local timeStr = tostring(run.timeFormatted or Storage.FormatDuration(run.timeFrames or 0))
    bodyFont:DrawStringScaled(timeStr, infoX, cardY + 17, 0.80, 0.80, COLOR_PAPER_TEXT, 0, false)

    -- Boss Killed (if Won) or Killer Entity (if Lost) + Icon
    local target = run.targetEntity or {}
    local resolvedTargetName = IconResolver.ResolveEntityInfo(target.type, target.variant, target.name)
    local targetSpr, iconYOffset = IconResolver.GetTargetEntitySprite(target, run.isWin)

    local targetTextX = infoX
    local maxTargetTextW = 86
    if targetSpr then
        pcall(function()
            targetSpr:Render(Vector(infoX + 9, cardY + 44 + (iconYOffset or 0)), Vector.Zero, Vector.Zero)
        end)
        targetTextX = infoX + 21
        maxTargetTextW = 68
    end

    local targetStrW = smallFont:GetStringWidth(resolvedTargetName)
    local targetScale = (targetStrW > maxTargetTextW) and math.max(0.55, maxTargetTextW / targetStrW) or 0.85
    smallFont:DrawStringScaled(resolvedTargetName, targetTextX, cardY + 36, targetScale, targetScale, COLOR_PAPER_TEXT, 0, false)

    -- 4. "List of items" Bounded Container (Right Column, 168x40 at cardX + 156, cardY + 12)
    local itemsBoxX = cardX + 156
    local itemsBoxY = cardY + 12
    local itemsBoxW = 168
    local itemsBoxH = 40

    if uiSpriteLoaded then
        uiSprite:SetFrame(isSelected and "ItemBoxSelected" or "ItemBox", 0)
        uiSprite:Render(Vector(itemsBoxX, itemsBoxY), Vector.Zero, Vector.Zero)
    end

    local items = run.items or {}
    local totalItems = #items

    -- Item count header cleanly placed above the ItemBox top border (cardY + 1 vs itemsBoxY = cardY + 12)
    local totalCols = math.ceil(totalItems / ITEM_ROWS_PER_CARD)
    local maxColOffset = math.max(0, totalCols - ITEMS_PER_ROW)
    local countLabel = (totalItems == 1) and "1 item" or string.format("%d items", totalItems)
    if isSelected and maxColOffset > 0 then
        countLabel = string.format("%d items [L/R]", totalItems)
    end
    smallFont:DrawStringScaled(
        countLabel,
        itemsBoxX + 4,
        cardY + 1,
        0.85,
        0.85,
        isSelected and COLOR_ITEM_BOX_HL or COLOR_MUTED_TEXT,
        0,
        false
    )

    if totalItems == 0 then
        smallFont:DrawString(
            "No items collected",
            itemsBoxX + 12,
            itemsBoxY + 14,
            COLOR_MUTED_TEXT,
            itemsBoxW - 24,
            true
        )
    else
        local colOffset = isSelected and state.itemScrollOffset or 0
        colOffset = math.max(0, math.min(colOffset, maxColOffset))

        local startIconX = itemsBoxX + 19
        local startIconY = itemsBoxY + 13
        local spacingX = 25
        local spacingY = 17

        for visCol = 0, ITEMS_PER_ROW - 1 do
            local actualCol = colOffset + visCol
            for row = 0, ITEM_ROWS_PER_CARD - 1 do
                local itemIdx = (actualCol * ITEM_ROWS_PER_CARD) + row + 1
                local itemId = items[itemIdx]
                if itemId then
                    local itemSpr = IconResolver.GetCollectibleSprite(itemId)
                    local renderPos = Vector(startIconX + (visCol * spacingX), startIconY + (row * spacingY))
                    if itemSpr then
                        pcall(function()
                            -- RenderLayer(1) draws strictly the collectible icon without the pedestal stone
                            itemSpr:RenderLayer(1, renderPos, Vector.Zero, Vector.Zero)
                        end)
                    else
                        smallFont:DrawString(tostring(itemId), renderPos.X - 6, renderPos.Y - 4, COLOR_PAPER_TEXT, 0, false)
                    end
                end
            end
        end

        -- Left / Right scroll indicators when the run has more items than fit in one view
        if colOffset > 0 then
            smallFont:DrawString("<", itemsBoxX + 3, itemsBoxY + 14, COLOR_SELECTED_GLOW, 0, false)
        end
        if colOffset < maxColOffset then
            smallFont:DrawString(">", itemsBoxX + itemsBoxW - 8, itemsBoxY + 14, COLOR_SELECTED_GLOW, 0, false)
        end
    end
end

--- Renders the full History modal screen (Backdrop + 360x230 centered board) and handles navigation
---@param mod table
---@param isInGameOverlay? boolean
local function renderAndUpdateHistoryScreen(mod, isInGameOverlay)
    ensureAssetsLoaded()

    local runs = Storage.GetRuns(mod)
    local numRuns = #runs

    -- Handle input navigation and interactive [F2] keybind capture
    if state.inputCooldown > 0 then
        state.inputCooldown = state.inputCooldown - 1
    elseif state.waitingForKey then
        if Input.IsButtonTriggered(KEY_ESCAPE_CODE, 0) then
            state.waitingForKey = false
            state.inputCooldown = 6
            playMenuSound(SoundEffect.SOUND_PAPER_OUT)
        else
            for _, entry in ipairs(Storage.GetBindableKeys()) do
                if Input.IsButtonTriggered(entry.code, 0) then
                    local ok = Storage.SetToggleKey(mod, entry.code)
                    if ok then
                        state.waitingForKey = false
                        state.inputCooldown = 8
                        playMenuSound(SoundEffect.SOUND_CHARACTER_SELECT_RIGHT)
                        break
                    end
                end
            end
        end
    else
        local toggleKey = Storage.GetToggleKey(mod)
        local closePressed = Input.IsButtonTriggered(KEY_ESCAPE_CODE, 0)
            or isMenuActionTriggered(ButtonAction.ACTION_MENUBACK)
            or Input.IsButtonTriggered(toggleKey, 0)
            or (isInGameOverlay and Input.IsButtonTriggered(KEY_FALLBACK_F3, 0))

        if closePressed then
            if isInGameOverlay then
                closeInGameOverlay()
            else
                closeHistoryPage()
            end
            return
        elseif Input.IsButtonTriggered(KEY_REBIND, 0) then
            state.waitingForKey = true
            state.inputCooldown = 4
            playMenuSound(SoundEffect.SOUND_CHARACTER_SELECT_RIGHT)
        elseif isMenuActionTriggered(ButtonAction.ACTION_MENUDOWN) and numRuns > 0 then
            state.selectedRunIdx = (state.selectedRunIdx % numRuns) + 1
            state.itemScrollOffset = 0
            if state.selectedRunIdx < state.scrollStartRunIdx then
                state.scrollStartRunIdx = state.selectedRunIdx
            elseif state.selectedRunIdx >= state.scrollStartRunIdx + VISIBLE_CARDS then
                state.scrollStartRunIdx = state.selectedRunIdx - VISIBLE_CARDS + 1
            end
            playMenuSound(SoundEffect.SOUND_CHARACTER_SELECT_RIGHT)
        elseif isMenuActionTriggered(ButtonAction.ACTION_MENUUP) and numRuns > 0 then
            state.selectedRunIdx = ((state.selectedRunIdx - 2 + numRuns) % numRuns) + 1
            state.itemScrollOffset = 0
            if state.selectedRunIdx < state.scrollStartRunIdx then
                state.scrollStartRunIdx = state.selectedRunIdx
            elseif state.selectedRunIdx >= state.scrollStartRunIdx + VISIBLE_CARDS then
                state.scrollStartRunIdx = state.selectedRunIdx - VISIBLE_CARDS + 1
            end
            playMenuSound(SoundEffect.SOUND_CHARACTER_SELECT_LEFT)
        elseif isMenuActionTriggered(ButtonAction.ACTION_MENURIGHT) and numRuns > 0 then
            local selRun = runs[state.selectedRunIdx]
            local totalItems = selRun and selRun.items and #selRun.items or 0
            local maxColOffset = math.max(0, math.ceil(totalItems / ITEM_ROWS_PER_CARD) - ITEMS_PER_ROW)
            if state.itemScrollOffset < maxColOffset then
                state.itemScrollOffset = state.itemScrollOffset + 1
                playMenuSound(SoundEffect.SOUND_CHARACTER_SELECT_RIGHT)
            end
        elseif isMenuActionTriggered(ButtonAction.ACTION_MENULEFT) and numRuns > 0 then
            if state.itemScrollOffset > 0 then
                state.itemScrollOffset = state.itemScrollOffset - 1
                playMenuSound(SoundEffect.SOUND_CHARACTER_SELECT_LEFT)
            end
        end
    end

    -- Center the 360x230 board on screen
    local screenW = Isaac.GetScreenWidth and Isaac.GetScreenWidth() or 480
    local screenH = Isaac.GetScreenHeight and Isaac.GetScreenHeight() or 270
    local panelW = 360
    local panelH = 230
    local panelX = math.floor((screenW - panelW) / 2)
    local panelY = math.floor((screenH - panelH) / 2)

    -- 0. Full-screen dark Backdrop behind the modal so Main Menu papers don't bleed through
    if uiSpriteLoaded then
        uiSprite:SetFrame("Backdrop", 0)
        uiSprite:Render(Vector(screenW / 2, screenH / 2), Vector.Zero, Vector.Zero)
    end

    -- 1. Outer History Board Sprite (360x230)
    if uiSpriteLoaded then
        uiSprite:SetFrame("Board", 0)
        uiSprite:Render(Vector(panelX, panelY), Vector.Zero, Vector.Zero)
    end

    -- 2. Header Bar
    titleFont:DrawStringScaled("RUN HISTORY", panelX + 12, panelY + 4, 0.85, 0.85, COLOR_HISTORY_GREEN, 0, false)
    local subHeader = (numRuns > 0)
        and string.format("Run #%d of %d", state.selectedRunIdx, numRuns)
        or "No Runs Recorded"
    local subHeaderW = smallFont:GetStringWidth(subHeader)
    smallFont:DrawString(subHeader, panelX + panelW - 12 - subHeaderW, panelY + 7, COLOR_MUTED_TEXT, 0, false)

    -- 3. Run Cards List
    if numRuns == 0 then
        bodyFont:DrawStringScaled(
            "No completed runs recorded yet.",
            panelX + 68,
            panelY + 95,
            0.85,
            0.85,
            COLOR_PAPER_TEXT,
            0,
            false
        )
        smallFont:DrawString(
            "Finish a run (Win or Death) or run 'history_mock' in console to test!",
            panelX + 25,
            panelY + 118,
            COLOR_MUTED_TEXT,
            panelW - 50,
            true
        )
    else
        local cardX = panelX + 10
        local startY = panelY + 28
        local gapY = 60

        local endIdx = math.min(numRuns, state.scrollStartRunIdx + VISIBLE_CARDS - 1)
        for idx = state.scrollStartRunIdx, endIdx do
            local slotIdx = idx - state.scrollStartRunIdx
            local cardY = startY + (slotIdx * gapY)
            renderRunCard(runs[idx], idx, cardX, cardY, idx == state.selectedRunIdx)
        end

        -- Vertical Scrollbar Indicator on Right Edge
        if numRuns > VISIBLE_CARDS then
            local trackX = panelX + panelW - 11
            local trackY = startY + 2
            local trackH = (VISIBLE_CARDS * gapY) - 8
            for ty = trackY, trackY + trackH, 6 do
                smallFont:DrawString("|", trackX, ty, COLOR_MUTED_TEXT, 0, false)
            end
            local thumbRatio = (state.selectedRunIdx - 1) / math.max(1, numRuns - 1)
            local thumbY = trackY + math.floor(thumbRatio * (trackH - 8))
            smallFont:DrawString("#", trackX - 1, thumbY, COLOR_SELECTED_GLOW, 0, false)
        end
    end

    -- 4. Footer Controls Legend (centered and auto-scaled inside board width)
    local footerY = panelY + panelH - 15
    local keyName = Storage.GetToggleKeyName(mod)
    local footerText = state.waitingForKey
        and "Press any key to bind History shortcut... ([Esc] Cancel)"
        or string.format("[Up/Down] Run  [Left/Right] Items  [F2] Key: %s  [Esc] Close", keyName)
    local footerColor = state.waitingForKey and COLOR_KEYBIND_HINT or COLOR_MUTED_TEXT
    local maxFooterW = panelW - 24
    local rawFooterW = smallFont:GetStringWidth(footerText)
    local footerScale = (rawFooterW > maxFooterW and rawFooterW > 0) and (maxFooterW / rawFooterW) or 1.0
    local footerX = panelX + math.floor((panelW - rawFooterW * footerScale) / 2)
    smallFont:DrawStringScaled(footerText, footerX, footerY, footerScale, footerScale, footerColor, 0, false)
end

--- Handles the Game Menu ("New Run", "Continue", etc.) prompt injection via REPENTOGON
---@param mod table
local function onMainMenuRender(mod)
    ensureAssetsLoaded()

    if not IS_REPENTOGON or not MenuManager or not MainMenuType then
        return
    end

    local activeMenu = MenuManager.GetActiveMenu()
    if activeMenu ~= MainMenuType.GAME then
        if state.isHistoryPageOpen or state.pendingRestoreInput then
            state.isHistoryPageOpen = false
            state.waitingForKey = false
            state.pendingRestoreInput = false
            restoreNativeMenuInput()
        end
        return
    end

    -- Delay restoring native menu input mask a few frames after closing the modal so Esc doesn't skip back to Saves
    if state.pendingRestoreInput then
        if state.inputCooldown > 0 then
            state.inputCooldown = state.inputCooldown - 1
            setNativeMenuInputMask(0)
        else
            state.pendingRestoreInput = false
            restoreNativeMenuInput()
        end
    end

    -- If our custom History modal is open, render and update it exclusively (with dark backdrop)
    if state.isHistoryPageOpen then
        setNativeMenuInputMask(0)
        renderAndUpdateHistoryScreen(mod, false)
        return
    end

    -- Render the "[<Key>] HISTORY" pinned note inside the right side of the viewport above "[TAB] MODS"
    -- Shifted left from x=354 to x=298 so the entire 108px note clears the 426px HQ4X right screen edge
    local noteWorldPos = Vector(298, 82)
    local notePos = noteWorldPos
    if Isaac.WorldToMenuPosition then
        local ok, converted = pcall(function()
            return Isaac.WorldToMenuPosition(MainMenuType.GAME, noteWorldPos)
        end)
        if ok and converted then
            notePos = converted
        end
    end

    if uiSpriteLoaded then
        uiSprite:SetFrame("MenuNote", 0)
        uiSprite:Render(notePos, Vector.Zero, Vector.Zero)
    end

    local keyName = Storage.GetToggleKeyName(mod)
    local promptText = string.format("[%s] HISTORY", keyName)
    local noteScale = 0.90
    local rawNoteW = bodyFont:GetStringWidth(promptText)
    if rawNoteW * noteScale > 96 and rawNoteW > 0 then
        noteScale = 96 / rawNoteW
    end
    local textW = rawNoteW * noteScale
    local textX = notePos.X + math.floor((108 - textW) / 2)
    local textY = notePos.Y + math.floor((28 - 14 * noteScale) / 2)
    bodyFont:DrawStringScaled(promptText, textX, textY, noteScale, noteScale, COLOR_MENU_INK, 0, false)

    -- Open History modal cleanly without interfering with native Up/Down cursor navigation
    if not state.pendingRestoreInput then
        local toggleKey = Storage.GetToggleKey(mod)
        if Input.IsButtonTriggered(toggleKey, 0) or isMenuActionTriggered(ButtonAction.ACTION_MENULT) then
            openHistoryPage(mod)
        end
    end
end

local mcmRegistered = false

--- Optional Mod Config Menu integration for configuring the History hotkey in-game
---@param mod table
local function registerModConfigMenu(mod)
    if mcmRegistered or not ModConfigMenu or not ModConfigMenu.AddSetting then
        return
    end
    mcmRegistered = pcall(function()
        local bindableKeys = Storage.GetBindableKeys()
        local function findKeyIndex(code)
            for idx, entry in ipairs(bindableKeys) do
                if entry.code == code then
                    return idx
                end
            end
            return 1
        end

        ModConfigMenu.AddSetting(
            "Run History",
            "Controls",
            {
                Type = ModConfigMenu.OptionType and ModConfigMenu.OptionType.NUMBER or 2,
                CurrentSetting = function()
                    return findKeyIndex(Storage.GetToggleKey(mod))
                end,
                Minimum = 1,
                Maximum = #bindableKeys,
                Display = function()
                    return "Toggle Hotkey: " .. Storage.GetToggleKeyName(mod)
                end,
                OnChange = function(newIndex)
                    local entry = bindableKeys[newIndex]
                    if entry then
                        Storage.SetToggleKey(mod, entry.code)
                    end
                end,
                Info = {
                    "Key used to open Run History on the Main Menu and during a run.",
                    "You can also press [F2] inside the History panel to rebind."
                }
            }
        )
    end)
end

--- Initializes Main Menu (REPENTOGON) and universal in-run overlay callbacks
---@param mod table
function HistoryMenu.Init(mod)
    registerModConfigMenu(mod)

    -- Reset overlay state when starting/continuing a run and retry optional ModConfigMenu setup
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
        state.isInGameOverlayOpen = false
        state.waitingForKey = false
        registerModConfigMenu(mod)
    end)

    -- 1. REPENTOGON Main Menu Render Hook
    if IS_REPENTOGON and ModCallbacks.MC_MAIN_MENU_RENDER then
        mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, function()
            onMainMenuRender(mod)
        end)
    end

    -- 2. Universal In-Run Overlay (Configured Hotkey, F3 fallback, or `history_toggle` console command)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
        if not state.isInGameOverlayOpen then
            local mcmVisible = ModConfigMenu and ModConfigMenu.IsVisible
            if not mcmVisible then
                local toggleKey = Storage.GetToggleKey(mod)
                if Input.IsButtonTriggered(toggleKey, 0) or Input.IsButtonTriggered(KEY_FALLBACK_F3, 0) then
                    HistoryMenu.ToggleOverlay(mod)
                    playMenuSound(SoundEffect.SOUND_PAPER_IN)
                end
            end
        end

        if state.isInGameOverlayOpen then
            renderAndUpdateHistoryScreen(mod, true)
        end
    end)

    -- 3. Suppress gameplay actions while the in-game History overlay is open
    if ModCallbacks.MC_INPUT_ACTION and InputHook then
        mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, function(_, entity, inputHook, buttonAction)
            if not state.isInGameOverlayOpen then
                return
            end
            if BLOCKED_OVERLAY_ACTIONS[buttonAction] then
                if inputHook == InputHook.GET_ACTION_VALUE then
                    return 0
                end
                return false
            end
        end)
    end
end

--- Allows console commands or hotkeys to open/close the in-game History overlay
---@param mod table
function HistoryMenu.ToggleOverlay(mod)
    Storage.Load(mod, true)
    state.isInGameOverlayOpen = not state.isInGameOverlayOpen
    state.waitingForKey = false
    state.selectedRunIdx = 1
    state.scrollStartRunIdx = 1
    state.itemScrollOffset = 0
    state.inputCooldown = 6
    return state.isInGameOverlayOpen
end

if _G.__isaac_history_modules then
    _G.__isaac_history_modules.history_menu = HistoryMenu
end

return HistoryMenu
