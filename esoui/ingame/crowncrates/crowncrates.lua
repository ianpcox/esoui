do
    local function BuyCratesCallback()
        ShowMarketAndSearch(GetString(SI_CROWN_STORE_SEARCH_CROWN_CRATES), MARKET_OPEN_OPERATION_CROWN_CRATES)
    end

    ZO_CROWN_CRATES_BUY_CRATES_KEYBIND_KEYBOARD =
    {
        keybind = "UI_SHORTCUT_TERTIARY",
        name = GetString(SI_CROWN_CRATE_BUY_CRATES_KEYBIND),
        callback = BuyCratesCallback,
    }

    ZO_CROWN_CRATES_BUY_CRATES_KEYBIND_GAMEPAD =
    {
        keybind = "UI_SHORTCUT_RIGHT_STICK",
        name = GetString(SI_CROWN_CRATE_BUY_CRATES_KEYBIND),
        callback = BuyCratesCallback,
    }
end

function ZO_GetNextOwnedCrownCrateIdIter(state, lastCrateId)
    return GetNextOwnedCrownCrateId(lastCrateId)
end

--Crown Crates
-------------------

local IDLE_CHATTER_ANIMATION_NOTE = "UI_Chatter"
local REFRESH_DECK_FX_ANIM_NOTE = "UI_RefreshDeckFx"

ZO_CrownCrates = ZO_Object:Subclass()

function ZO_CrownCrates:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function ZO_CrownCrates:Initialize(control)
    self.control = control

    CROWN_CRATES_PACK_OPENING = ZO_CrownCratesPackOpening:New(self)
    CROWN_CRATES_PACK_CHOOSING = ZO_CrownCratesPackChoosing:New(self)

    self:InitializeCrownGemsQuantity()

    CROWN_CRATE_KEYBOARD_SCENE = ZO_RemoteScene:New("crownCrateKeyboard", SCENE_MANAGER)
    SYSTEMS:RegisterKeyboardRootScene("crownCrate", CROWN_CRATE_KEYBOARD_SCENE)

    CROWN_CRATE_GAMEPAD_SCENE = ZO_RemoteScene:New("crownCrateGamepad", SCENE_MANAGER)
    SYSTEMS:RegisterGamepadRootScene("crownCrate", CROWN_CRATE_GAMEPAD_SCENE)

    self.mainMenuDirty = false

    local function UpdateMainMenu()
        self.mainMenuDirty = false

        if MAIN_MENU_KEYBOARD then
            local DONT_FORCE_RESELECTION = false
            MAIN_MENU_KEYBOARD:RefreshCategoryBar(DONT_FORCE_RESELECTION)
        end

        if MAIN_MENU_GAMEPAD then
            MAIN_MENU_GAMEPAD:RefreshLists()
        end
    end

    local function OnStateChangeCallback() 
        self:RefreshApplicableInputTypeKeybinds() 
    end

    local function SharedStateChangeCallback(oldState, newState)
        if newState == SCENE_SHOWING then
            self:PerformDeferredInitializationShared()
            self.control:SetHidden(false)
            self:UpdateCrownGemsQuantity()
            ZO_CROWN_CRATE_STATE_MACHINE:FireCallbacks(ZO_CROWN_CRATE_TRIGGER_COMMANDS.SCENE_SHOWN)
            ZO_CROWN_CRATE_STATE_MACHINE:RegisterCallback("OnStateChange", OnStateChangeCallback)
            TriggerTutorial(TUTORIAL_TRIGGER_CROWN_CRATE_UI_OPENED)
            PlaySound(SOUNDS.CROWN_CRATES_SCENE_OPEN)
        elseif newState == SCENE_HIDING then
            PlaySound(SOUNDS.CROWN_CRATES_SCENE_CLOSED)
        elseif newState == SCENE_HIDDEN then
            self.control:SetHidden(true)
            self.selectedCard = nil
            ZO_CROWN_CRATE_STATE_MACHINE:UnregisterCallback("OnStateChange", OnStateChangeCallback)
            self:RemoveInputTypeKeybinds()
            ZO_CrownCrateStateMachine_Reset()
            --Actually delete the particle effects from memory so they don't consume part of the particle effect budget when the scene is hidden.
            self:DeleteAllParticles()
            if self.mainMenuDirty then
                UpdateMainMenu()
            end
        end
    end

    CROWN_CRATE_KEYBOARD_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        self.sceneName = "crownCrateKeyboard"
        SharedStateChangeCallback(oldState, newState)
        
        if newState == SCENE_SHOWING then
            self:PerformDeferredInitializationKeyboard()
            self:AddApplicableInputTypeKeybinds()
        end
    end)

    CROWN_CRATE_GAMEPAD_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        self.sceneName = "crownCrateGamepad"
        SharedStateChangeCallback(oldState, newState)

        if newState == SCENE_SHOWING then
            self:PerformDeferredInitializationGamepad()
            self:AddApplicableInputTypeKeybinds()
        end
    end)

    --Initialize state--
    ZO_CrownCrateStateMachine_Reset()

    local function UpdateMainMenuWhenClosed()
        if SYSTEMS:IsShowing("crownCrate") then
            self.mainMenuDirty = true
        else
            UpdateMainMenu()
        end
    end

    local function OnAnimationNote(eventCode, eventNote)
        if SYSTEMS:IsShowing("crownCrate") then
            if eventNote == IDLE_CHATTER_ANIMATION_NOTE then
                TriggerCrownCrateNPCAnimation(CROWN_CRATE_NPC_ANIMATION_TYPE_IDLE_CHATTER)
            elseif eventNote == REFRESH_DECK_FX_ANIM_NOTE then
                RefreshCardsInCrownCrateNPCsHand()
            end
        end
    end

    local function OnPlayerCombatState(eventCode, isInCombat)
        if isInCombat and SYSTEMS:IsShowing("crownCrate") then
            TriggerCrownCrateNPCAnimation(CROWN_CRATE_NPC_ANIMATION_TYPE_UNDER_ATTACK)
        end
    end

    control:RegisterForEvent(EVENT_CROWN_CRATE_INVENTORY_UPDATED, UpdateMainMenuWhenClosed)
    control:RegisterForEvent(EVENT_CROWN_CRATE_QUANTITY_UPDATE, UpdateMainMenuWhenClosed)
    control:RegisterForEvent(EVENT_CROWN_CRATES_SYSTEM_STATE_CHANGED, UpdateMainMenuWhenClosed)
    control:RegisterForEvent(EVENT_ANIMATION_NOTE, OnAnimationNote)
    control:RegisterForEvent(EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)
end

function ZO_CrownCrates:InitializeCrownGemsQuantity()
    self.crownGemsAvailableQuantity = ZO_CrownCratesGemsCounter
    CROWN_CRATE_GEMS_AVAILABLE_QUANTITY_FRAGMENT = ZO_FadeSceneFragment:New(self.crownGemsAvailableQuantity)

    self.gemsUpdateCountAnimationTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ZO_CrownCrateGainGemsUpdateCount")
    self.gemsUpdateCountAnimationTimeline:SetHandler("OnStop", function(timeline, completedPlaying)
        if completedPlaying then
            self.crownGemsAvailableQuantity.gemsIcon:SetScale(1)
        end
    end)

    ZO_PlatformStyle:New(function() self:RefreshCrownGemsQuantityTemplate() end)

    self.currentGemAnimationValue = 0
end

function ZO_CrownCrates:RefreshCrownGemsQuantityTemplate()
    ApplyTemplateToControl(self.crownGemsAvailableQuantity, ZO_GetPlatformTemplate("ZO_CrownCrates_GemsCounter"))
    self.formattedGemIcon = ZO_Currency_GetPlatformFormattedCurrencyIcon(ZO_Currency_MarketCurrencyToUICurrency(MKCT_CROWN_GEMS), "100%")
end

function ZO_CrownCrates:GetFormattedGemIcon()
    return self.formattedGemIcon
end

function ZO_CrownCrates:PerformDeferredInitializationShared()
    if not self.initialized then
        self.initialized = true

        self.control:Create3DRenderSpace()
        self:InitializeAnimationPools()
        self:InitializeCardParticlePools()
    end
end

function ZO_CrownCrates:PerformDeferredInitializationKeyboard()
    if not self.initializedKeyboard then
        self.initializedKeyboard = true
        self:InitializeKeyboardKeybindStripDescriptors()
    end
end

function ZO_CrownCrates:PerformDeferredInitializationGamepad()
    if not self.initializedGamepad then
        self.initializedGamepad = true
        self.directionalMovementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL)
        self:InitializeGamepadKeybindStripDescriptors()
    end
end

do
    local function IsCrownCrateStateAllRevealed()
        return ZO_CROWN_CRATE_STATE_MACHINE:GetCurrentState() == ZO_CROWN_CRATE_STATES.ALL_REVEALED
    end

    function ZO_CrownCrates:InitializeGamepadKeybindStripDescriptors()
        local function BackCallback()
            if IsCrownCrateStateAllRevealed() then
                ZO_CROWN_CRATE_STATE_MACHINE:FireCallbacks(ZO_CROWN_CRATE_TRIGGER_COMMANDS.BACK_TO_MANIFEST)
            else
                self:AttemptExit()
            end
        end

        self.gamepadSharedKeybindStripDescriptor =
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            {
                name = GetString(SI_GAMEPAD_BACK_OPTION),
                keybind = "UI_SHORTCUT_NEGATIVE",
                enabled = ZO_CrownCrateStateMachine_CanUseBackKeybind_Gamepad,
                callback = BackCallback,
            }
        }
    end

    function ZO_CrownCrates:InitializeKeyboardKeybindStripDescriptors()
        local function BackCallback()
            ZO_CROWN_CRATE_STATE_MACHINE:FireCallbacks(ZO_CROWN_CRATE_TRIGGER_COMMANDS.BACK_TO_MANIFEST)
        end

        self.keyboardSharedKeybindStripDescriptor =
        {
            alignment = KEYBIND_STRIP_ALIGN_CENTER,
            {
                name = GetString(SI_CROWN_CRATE_CHANGE_CRATE_KEYBIND),
                keybind = "UI_SHORTCUT_NEGATIVE",
                visible = IsCrownCrateStateAllRevealed,
                callback = BackCallback,
            }
        }
    end
end

function ZO_CrownCrates:RefreshApplicableInputTypeKeybinds()
    if self.initializedGamepad and SCENE_MANAGER:IsCurrentSceneGamepad() then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.gamepadSharedKeybindStripDescriptor)
    elseif self.initializedKeyboard then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keyboardSharedKeybindStripDescriptor)
    end
end

function ZO_CrownCrates:AddApplicableInputTypeKeybinds()
    self:RemoveInputTypeKeybinds()
    if self.initializedGamepad and SCENE_MANAGER:IsCurrentSceneGamepad() then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.gamepadSharedKeybindStripDescriptor)
        DIRECTIONAL_INPUT:Activate(self, self:GetControl())
    elseif self.initializedKeyboard then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.keyboardSharedKeybindStripDescriptor)
    end
end

function ZO_CrownCrates:RemoveInputTypeKeybinds()
    if self.initializedGamepad and SCENE_MANAGER:IsCurrentSceneGamepad() then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.gamepadSharedKeybindStripDescriptor)
        DIRECTIONAL_INPUT:Deactivate(self)
    elseif self.initializedKeyboard then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keyboardSharedKeybindStripDescriptor)
    end
end

function ZO_CrownCrates:UpdateDirectionalInput()
    local result = self.directionalMovementController:CheckMovement()
    local selectedDirection
    if result == MOVEMENT_CONTROLLER_MOVE_NEXT then
        selectedDirection = 1
    elseif result == MOVEMENT_CONTROLLER_MOVE_PREVIOUS then
        selectedDirection = -1
    end

    CROWN_CRATES_PACK_OPENING:HandleDirectionalInput(selectedDirection)
    CROWN_CRATES_PACK_CHOOSING:HandleDirectionalInput(selectedDirection)
end

function ZO_CrownCrates:AttemptExit()
    SCENE_MANAGER:Hide(self.sceneName)
end

function ZO_CrownCrates:InitializeAnimationPools()
    self.animationPools =
    {
        [ZO_CROWN_CRATES_ANIMATION_PRIMARY_DEAL] = ZO_AnimationPool:New("ZO_CrownCrateCardPrimaryDealAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_BONUS_DEAL] = ZO_AnimationPool:New("ZO_CrownCrateCardBonusDealAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_BONUS_DEAL_GLOW] = ZO_AnimationPool:New("ZO_CrownCrateCardBonusDealGlowAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_BONUS_SLIDE] = ZO_AnimationPool:New("ZO_CrownCrateCardBonusSlideAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_MYSTERY_SELECTED_GLOW] = ZO_AnimationPool:New("ZO_CrownCrateCardMysterySelectedGlowAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_REVEAL] = ZO_AnimationPool:New("ZO_CrownCrateCardRevealAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_MYSTERY_SELECT] = ZO_AnimationPool:New("ZO_CrownCrateCardMysterySelectAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_MYSTERY_DESELECT] = ZO_AnimationPool:New("ZO_CrownCrateCardMysteryDeselectAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_LEAVE] = ZO_AnimationPool:New("ZO_CrownCrateCardLeaveAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_REVEALED_SELECTED_GLOW] = ZO_AnimationPool:New("ZO_CrownCrateCardRevealedSelectedGlowAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_GEMIFY_CARD] = ZO_AnimationPool:New("ZO_CrownCrateCardGemifyCardAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_GEMIFY_OVERLAY] = ZO_AnimationPool:New("ZO_CrownCrateCardGemifyOverlayAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_CARD_SHOW_INFO] = ZO_AnimationPool:New("ZO_CrownCrateCardShowInfo"),
        [ZO_CROWN_CRATES_ANIMATION_CARD_HIDE_INFO] = ZO_AnimationPool:New("ZO_CrownCrateCardHideInfo"),
        [ZO_CROWN_CRATES_ANIMATION_PACK_SHOW_INFO] = ZO_AnimationPool:New("ZO_CrownCratePackShowInfo"),
        [ZO_CROWN_CRATES_ANIMATION_PACK_HIDE_INFO] = ZO_AnimationPool:New("ZO_CrownCratePackHideInfo"),
        [ZO_CROWN_CRATES_ANIMATION_PACK_SHOW] = ZO_AnimationPool:New("ZO_CrownCratePackShow"),
        [ZO_CROWN_CRATES_ANIMATION_PACK_SELECT] = ZO_AnimationPool:New("ZO_CrownCratePackSelect"),
        [ZO_CROWN_CRATES_ANIMATION_PACK_DESELECT] = ZO_AnimationPool:New("ZO_CrownCratePackDeselect"),
        [ZO_CROWN_CRATES_ANIMATION_PACK_GLOW] = ZO_AnimationPool:New("ZO_CrownCratePackGlow"),
        [ZO_CROWN_CRATES_ANIMATION_PACK_HIDE] = ZO_AnimationPool:New("ZO_CrownCratePackHide"),
        [ZO_CROWN_CRATES_ANIMATION_PACK_CHOOSE] = ZO_AnimationPool:New("ZO_CrownCratePackChoose"),
        [ZO_CROWN_CRATES_ANIMATION_PACK_OPEN] = ZO_AnimationPool:New("ZO_CrownCratePackOpen"),
        [ZO_CROWN_CRATES_ANIMATION_GEMIFY_SINGLE_GEM_GAIN] = ZO_AnimationPool:New("ZO_CrownCrateCardGemifySingleGemAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_GEMIFY_COLOR_TINT] = ZO_AnimationPool:New("ZO_CrownCrateCardGemifyColorTintAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_GEMIFY_FINAL_GEM] = ZO_AnimationPool:New("ZO_CrownCrateCardGemifyFinalGemAnimation"),
        [ZO_CROWN_CRATES_ANIMATION_GEMIFY_CROWN_GEM_TEXT] = ZO_AnimationPool:New("ZO_CrownCrateCardGemifyCrownGemsTextAnimation"),
    }
    
    do
        local function FloatWobbleReset(animation, pool)
            animation:Stop()
        end
        
        local CardFloatEase = ZO_GenerateCubicBezierEase(.25, -0.1, .75, 1.1)

        local function InsertRotateAnimations(animationTimeline, startFunctionName, endFunctionName, startRadians, direction, offsetMS)
            local halfWobbleDuration = ZO_CROWN_CRATES_MYSTERY_SELECTED_WOBBLE_DURATION_MS * 0.5
            local rotateAnimation = animationTimeline:InsertAnimation(ANIMATION_ROTATE3D, nil, offsetMS)
            rotateAnimation:SetDuration(halfWobbleDuration)
            rotateAnimation:SetEasingFunction(CardFloatEase)
            local unrotateAnimation = animationTimeline:InsertAnimation(ANIMATION_ROTATE3D, nil, offsetMS + halfWobbleDuration)
            unrotateAnimation:SetDuration(halfWobbleDuration)
            unrotateAnimation:SetEasingFunction(CardFloatEase)
            local endRadians = startRadians + ZO_CROWN_CRATES_MYSTERY_SELECTED_WOBBLE_MAGNITUDE_RADIANS * direction
            rotateAnimation[startFunctionName](rotateAnimation, startRadians)
            rotateAnimation[endFunctionName](rotateAnimation, endRadians)
            unrotateAnimation[startFunctionName](unrotateAnimation, endRadians)
            unrotateAnimation[endFunctionName](unrotateAnimation, startRadians)
        end
    
        local function FloatWobbleFactory(pool)
            local animationTimeline = ANIMATION_MANAGER:CreateTimeline()
            animationTimeline:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
            local currentOffsetMS = 0
            for setIndex = 1, ZO_CROWN_CRATES_MYSTERY_SELECTED_WOBBLE_NUM_SETS do
                for wobbleIndex = 1, ZO_CROWN_CRATES_MYSTERY_SELECTED_WOBBLE_NUM_PER_SET do
                    local axisIndex = wobbleIndex
                    local direction
                    if (wobbleIndex + setIndex) % 2 == 0 then
                        direction = -1
                    else
                        direction = 1
                    end

                    if axisIndex == 1 then
                        InsertRotateAnimations(animationTimeline, "SetStartPitch", "SetEndPitch", ZO_CROWN_CRATES_PRIMARY_DEAL_END_PITCH_RADIANS, direction, currentOffsetMS)
                    elseif axisIndex == 2 then
                        InsertRotateAnimations(animationTimeline, "SetStartYaw", "SetEndYaw", ZO_CROWN_CRATES_PRIMARY_DEAL_END_YAW_RADIANS, direction, currentOffsetMS)
                    else
                        InsertRotateAnimations(animationTimeline, "SetStartRoll", "SetEndRoll", ZO_CROWN_CRATES_PRIMARY_DEAL_END_ROLL_RADIANS, direction, currentOffsetMS)
                    end
                    currentOffsetMS = currentOffsetMS + ZO_CROWN_CRATES_MYSTERY_SELECTED_WOBBLE_SPACING_MS
                end
            end
            return animationTimeline
        end

        self.animationPools[ZO_CROWN_CRATES_ANIMATION_MYSTERY_SELECTED] = ZO_ObjectPool:New(FloatWobbleFactory, FloatWobbleReset)
    end
end

function ZO_CrownCrates:GetAnimationPool(animationType)
    return self.animationPools[animationType]
end

function ZO_CrownCrates:InitializeCardParticlePools()
    self.crateSpecificCardParticlePools = {}
    self.tierSpecificCardParticlePools = {}
end

function ZO_CrownCrates:GetCrateSpecificCardParticlePool(crownCrateId, crownCrateParticleEffects)
    if not self.crateSpecificCardParticlePools[crownCrateId] then
        self.crateSpecificCardParticlePools[crownCrateId] = {}
    end
    local crateTable = self.crateSpecificCardParticlePools[crownCrateId]
    if not crateTable[crownCrateParticleEffects] then
        local function Factory(pool)
            local positionX, positionY, positionZ = 0, 0, 0
            local particleId = CreateCrownCrateSpecificParticleEffect(crownCrateId, crownCrateParticleEffects, positionX, positionY, positionZ)
            return ZO_Particle:New(particleId)
        end

        local function Reset(particle, pool)
            particle:Reset()
        end

        crateTable[crownCrateParticleEffects] = ZO_ObjectPool:New(Factory, Reset)
    end
    
    return crateTable[crownCrateParticleEffects]
end

function ZO_CrownCrates:GetTierSpecificCardParticlePool(crownCrateTierId, crownCrateTierParticleEffects)
    if not self.tierSpecificCardParticlePools[crownCrateTierId] then
        self.tierSpecificCardParticlePools[crownCrateTierId] = {}
    end
    local crateTierTable = self.tierSpecificCardParticlePools[crownCrateTierId]
    if not crateTierTable[crownCrateTierParticleEffects] then
        local function Factory(pool)
            local positionX, positionY, positionZ = 0, 0, 0
            local particleId = CreateCrownCrateTierSpecificParticleEffect(crownCrateTierId, crownCrateTierParticleEffects, positionX, positionY, positionZ)
            return ZO_Particle:New(particleId)
        end

        local function Reset(particle, pool)
            particle:Reset()
        end

        crateTierTable[crownCrateTierParticleEffects] = ZO_ObjectPool:New(Factory, Reset)
    end
    
    return crateTierTable[crownCrateTierParticleEffects]
end

function ZO_CrownCrates:DeleteAllParticles()
    local function DeleteParticle(particle)
        particle:Delete()
    end

    for _, crateTable in pairs(self.crateSpecificCardParticlePools) do
        for _, particlePool in pairs(crateTable) do
            particlePool:DestroyAllFreeObjects(DeleteParticle)
        end
    end
    self.crateSpecificCardParticlePools = {}

    for _, crateTierTable in pairs(self.tierSpecificCardParticlePools) do
        for _, particlePool in pairs(crateTierTable) do
            particlePool:DestroyAllFreeObjects(DeleteParticle)
        end
    end
    self.tierSpecificCardParticlePools = {}
end

function ZO_CrownCrates:ComputeCameraPlaneMetrics(worldWidth, UIWidth)
    local metrics =
    {
        depthFromCamera = ComputeDepthAtWhichWorldWidthRendersAsUIWidth(worldWidth, UIWidth),
        UIUnitsPerWorldUnit = UIWidth / worldWidth,
        worldUnitsPerUIUnit = worldWidth / UIWidth,
    }
    metrics.frustumWidthWorld, metrics.frustumHeightWorld = GetWorldDimensionsOfViewFrustumAtDepth(metrics.depthFromCamera)
    return metrics
end

function ZO_CrownCrates.ConvertUIUnitsToWorldUnits(planeMetrics, UIUnits)
    return UIUnits * planeMetrics.worldUnitsPerUIUnit
end

function ZO_CrownCrates.GetBottomOffsetUI()
    if IsInGamepadPreferredMode() then
        return ZO_KEYBIND_STRIP_GAMEPAD_VISUAL_HEIGHT
    else
        return ZO_KEYBIND_STRIP_KEYBOARD_VISUAL_HEIGHT
    end
end

do
    local MOVE_DISTANCE = 5

    local function DidMouseMoveFarEnough(oldPointX, oldPointY)
        local mouseX, mouseY = GetUIMousePosition()
        return (zo_abs(oldPointX - mouseX) + zo_abs(oldPointY - mouseY)) > MOVE_DISTANCE
    end

    function ZO_CrownCrates.AddBounceResistantMouseHandlersToControl(control, onMouseEnter, onMouseExit)
        control:SetHandler("OnMouseEnter", function()
            --the mouse must move a little bit from where it was when it exited the control to enter again
            if control.mouseExitX then                
                if DidMouseMoveFarEnough(control.mouseExitX, control.mouseExitY) then
                    onMouseEnter()
                else
                    control:SetHandler("OnUpdate", function()
                        if DidMouseMoveFarEnough(control.mouseExitX, control.mouseExitY) then
                            onMouseEnter()
                        end
                    end)
                end
            else
                onMouseEnter()
            end
        end)
        control:SetHandler("OnMouseExit", function()
            onMouseExit()
            control:SetHandler("OnUpdate", nil)
            control.mouseExitX, control.mouseExitY = GetUIMousePosition()
        end)
    end
end

function ZO_CrownCrates.ComputeSlotBottomUIPosition(slotWidthUI, spacingUI, slotIndex, totalSlots)
    local slotBottomX = ZO_CrownCrates.ComputeSlotCenterUIPositionX(slotWidthUI, spacingUI, slotIndex, totalSlots)
    local slotBottomY = GuiRoot:GetHeight() - ZO_CrownCrates.GetBottomOffsetUI()
    return slotBottomX, slotBottomY
end

function ZO_CrownCrates.ComputeSlotCenterUIPosition(slotWidthUI, slotHeightUI, slotHeightOffset, spacingUI, slotIndex, totalSlots)
    local slotCenterX = ZO_CrownCrates.ComputeSlotCenterUIPositionX(slotWidthUI, spacingUI, slotIndex, totalSlots)
    local slotCenterY = ZO_CrownCrates.ComputeSlotCenterUIPositionY(slotHeightUI, slotHeightOffset)
    return slotCenterX, slotCenterY
end

function ZO_CrownCrates.ComputeSlotCenterUIPositionX(slotWidthUI, spacingUI, slotIndex, totalSlots)
    local totalUIWidth = totalSlots * slotWidthUI + (totalSlots - 1) * spacingUI
    --Determine the middle of the screen
    local slotBottomX = GuiRoot:GetWidth() * 0.5
    --Offset by half the width of the pack area (determine the left most pack's left side)
    slotBottomX = slotBottomX - totalUIWidth * 0.5
    --Offset by half a pack, then by this packs visual position (determine the middle of this pack)
    return slotBottomX + slotWidthUI * 0.5 + (slotIndex - 1) * (slotWidthUI + spacingUI)
end

function ZO_CrownCrates.ComputeSlotCenterUIPositionY(slotHeightUI, slotHeightOffset)
    return GuiRoot:GetHeight() - slotHeightOffset - (slotHeightUI * 0.5)
end

function ZO_CrownCrates:UpdateGemsLabel(amount)
    self.crownGemsAvailableQuantity.gemsLabel:SetText(ZO_CommaDelimitNumber(amount))
end

function ZO_CrownCrates:UpdateCrownGemsQuantity()
    local currentCrownGems = GetPlayerCrownGems()
    self:UpdateGemsLabel(currentCrownGems)
    self.currentCrownGems = currentCrownGems
end

do
    local TIME_ADDED_PER_CROWN_GEM_MS = 500
    local TIME_MULTIPLER_FOR_CROWN_GEMS = 2
    local TIME_BASE_VALUE_FOR_CROWN_GEMS_MS= 150
    local function CalculateGemUpdateAnimation(amount)
        return math.sqrt(amount * TIME_ADDED_PER_CROWN_GEM_MS) * TIME_MULTIPLER_FOR_CROWN_GEMS + TIME_BASE_VALUE_FOR_CROWN_GEMS_MS
    end

    function ZO_CrownCrates:AddCrownGems(amount)
        if amount <= 0 then
            return
        end

        local previousGemTotal = self.currentCrownGems 
        self.currentCrownGems = previousGemTotal + amount

        local gemUpdateAnimation = self.gemsUpdateCountAnimationTimeline:GetFirstAnimation()
        if not self.gemsUpdateCountAnimationTimeline:IsPlaying() then
            local calcDuration = CalculateGemUpdateAnimation(amount)
            self.previousGemTotal = previousGemTotal
            self.currentGemAnimationValue = previousGemTotal
            gemUpdateAnimation:SetDuration(calcDuration)
            self.gemsUpdateCountAnimationTimeline:PlayFromStart()
        else
            local currentTimelineProgression = self.gemsUpdateCountAnimationTimeline:GetProgress()
            local newTargetAmount = self.currentCrownGems - self.currentGemAnimationValue
            local newDuration = CalculateGemUpdateAnimation(newTargetAmount) + (gemUpdateAnimation:GetDuration() * currentTimelineProgression)
            gemUpdateAnimation:SetDuration(newDuration)
        end

        TriggerCrownCrateNPCAnimation(CROWN_CRATE_NPC_ANIMATION_TYPE_GEMS_AWARDED)
    end

    local GEMS_UPDATE_REFRESH_RATE = 0.05 -- only update text when a certain percentage to the next step is reached
    function ZO_CrownCrates:UpdateGemsAnimation(animation, progress)
        local difference = self.currentCrownGems - self.previousGemTotal
        local delta = (difference) * progress
        local nextValue = zo_floor(delta + self.previousGemTotal)
        if (nextValue - self.currentGemAnimationValue) / difference > GEMS_UPDATE_REFRESH_RATE then
            self:UpdateGemsLabel(nextValue)
            self.currentGemAnimationValue = nextValue
        end
    end
end

function ZO_CrownCrates:GetControl()
    return self.control
end

function ZO_CrownCrates:GetCameraLocalPositionFromWorldPosition(worldX, worldY, worldZ)
    return self.control:Convert3DWorldPositionToLocalPosition(worldX, worldY, worldZ)
end

--Lifecycle
function ZO_CrownCrates:LockLocalSpaceToCurrentCamera()
    Set3DRenderSpaceToCurrentCamera(self.control:GetName())
    CROWN_CRATES_PACK_OPENING:OnLockLocalSpaceToCurrentCamera()
    CROWN_CRATES_PACK_CHOOSING:OnLockLocalSpaceToCurrentCamera()
end

--Global XML

function ZO_CrownCrates_OnInitialized(self)
    CROWN_CRATES = ZO_CrownCrates:New(self)
end