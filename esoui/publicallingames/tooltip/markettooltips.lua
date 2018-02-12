function ZO_Tooltip:AddInstantUnlockEligibilityFailures(...)
    local count = select("#", ...)
    if count > 0 then
        local ineligibilitySection = self:AcquireSection(self:GetStyle("instantUnlockIneligibilitySection"))
        for i = 1, count do
            local errorStringId = select(i, ...)
            if errorStringId ~= 0 then
                ineligibilitySection:AddLine(GetErrorString(errorStringId), self:GetStyle("instantUnlockIneligibilityLine"))
            end
        end
        self:AddSection(ineligibilitySection)
    end
end

do
    local BUNDLE_HEADER = GetString(SI_MARKET_PRODUCT_TOOLTIP_BUNDLE)
    local DLC_HEADER = GetString(SI_MARKET_PRODUCT_TOOLTIP_DLC)
    local UPGRADE_HEADER = GetString(SI_MARKET_PRODUCT_TOOLTIP_UPGRADE)
    local UNLOCK_LABEL = GetString(SI_MARKET_PRODUCT_TOOLTIP_UNLOCK)
    local SERVICE_HEADER = GetString(SI_SERVICE_TOOLTIP_TYPE)

    local NO_CATEGORY_NAME = nil
    local NO_NICKNAME = nil
    local HIDE_VISUAL_LAYER_INFO = false
    local NO_COOLDOWN = nil
    local HIDE_BLOCK_REASON = false

    function ZO_Tooltip:LayoutMarketProduct(productId)
        local productType = GetMarketProductType(productId)
        -- For some market product types we can just use other tooltip layouts
        if productType == MARKET_PRODUCT_TYPE_COLLECTIBLE then
            local collectibleId, _, name, type, description, owned, isPlaceholder, isPurchasable, hint = GetMarketProductCollectibleInfo(productId)
            self:LayoutCollectible(collectibleId, NO_CATEGORY_NAME, name, NO_NICKNAME, isPurchasable, description, hint, isPlaceholder, type, HIDE_VISUAL_LAYER_INFO, NO_COOLDOWN, HIDE_BLOCK_REASON)
            return
        elseif productType == MARKET_PRODUCT_TYPE_ITEM then
            local itemLink = GetMarketProductItemLink(productId)
            local stackCount = GetMarketProductStackCount(productId)
            self:LayoutItemWithStackCountSimple(itemLink, stackCount)
            return
        elseif productType == MARKET_PRODUCT_TYPE_CROWN_CRATE then
            local crateId = GetMarketProductCrownCrateId(productId)
            local stackCount = GetMarketProductStackCount(productId)
            self:LayoutCrownCrate(crateId, stackCount)
            return
        elseif productType == MARKET_PRODUCT_TYPE_CURRENCY then
            local currencyType = GetMarketProductCurrencyType(productId)
            local amount = GetMarketProductStackCount(productId)
            self:LayoutCurrency(currencyType, amount)
            return
        elseif productType == MARKET_PRODUCT_TYPE_INSTANT_UNLOCK then
            local instantUnlockId = GetMarketProductInstantUnlockId(productId)
            self:LayoutInstantUnlock(instantUnlockId)
            --Instant Unlock Restrictions
            if GetMarketProductInstantUnlockType(productId) ~= INSTANT_UNLOCK_NONE then
                local GET_CACHED_STATE = true
                local purchaseState = GetMarketProductPurchaseState(productId, GET_CACHED_STATE)
                if purchaseState == MARKET_PRODUCT_PURCHASE_STATE_INSTANT_UNLOCK_INELIGIBLE then
                    self:AddInstantUnlockEligibilityFailures(GetMarketProductEligibilityErrorStringIds(productId))
                end
            end
            return
        end

        -- things added to the topSection stack upwards
        local topSection = self:AcquireSection(self:GetStyle("topSection"))

        if productType == MARKET_PRODUCT_TYPE_BUNDLE then
            if DoesMarketProductContainDLC(productId) and GetMarketProductNumBundledProducts(productId) == 1 then
                topSection:AddLine(DLC_HEADER)
            else
                topSection:AddLine(BUNDLE_HEADER)
            end
        end

        self:AddSection(topSection)

        -- Name
        local displayName = GetMarketProductDisplayName(productId)
        local stackCount = GetMarketProductStackCount(productId)
        if stackCount > 1 then
            displayName = zo_strformat(SI_TOOLTIP_ITEM_NAME_WITH_QUANTITY, displayName, stackCount)
        else
            displayName = zo_strformat(SI_TOOLTIP_ITEM_NAME, displayName)
        end
        self:AddLine(displayName, self:GetStyle("title"))

        -- Description
        local bodySection = self:AcquireSection(self:GetStyle("collectionsInfoSection"))
        bodySection:AddLine(GetMarketProductDescription(productId), self:GetStyle("bodyDescription"))
        self:AddSection(bodySection)
    end
end

function ZO_Tooltip:LayoutEsoPlusTrialNotification(marketProductId, keybindIcon)
    local legendaryColor = GetItemQualityColor(ITEM_QUALITY_LEGENDARY)
    local coloredHeader = legendaryColor:Colorize(GetString(SI_MARKET_FREE_TRIAL_TOOLTIP_HEADER))
    self:AddLine(coloredHeader, self:GetStyle("title"))

    local bodySection = self:AcquireSection(self:GetStyle("bodySection"))
    local endTimeString = GetMarketProductEndTimeString(marketProductId)
    bodySection:AddLine(zo_strformat(SI_MARKET_FREE_TRIAL_TOOLTIP_DESCRIPTION, endTimeString), self:GetStyle("bodyDescription"))
    self:AddSection(bodySection)

    -- using a second body section here to separate out the start instruction from the description
    local bodySection2 = self:AcquireSection(self:GetStyle("bodySection"))
    local startInstructionString = zo_strformat(SI_MARKET_FREE_TRIAL_TOOLTIP_START_INSTRUCTIONS, keybindIcon)
    bodySection2:AddLine(startInstructionString, self:GetStyle("bodyDescription"))
    self:AddSection(bodySection2)
end

function ZO_Tooltip:LayoutCrownCrate(crateId, stackCount)
    -- things added to the topSection stack upwards
    local topSection = self:AcquireSection(self:GetStyle("topSection"))
    local crateCount = GetCrownCrateCount(crateId)
    if crateCount > 0 then
        local topSubsection = topSection:AcquireSection(self:GetStyle("topSubsectionItemDetails"))
        topSubsection:AddLine(zo_iconTextFormat("EsoUI/Art/Tooltips/icon_crown_crate.dds", 24, 24, crateCount))
        topSection:AddSection(topSubsection)
    end

    self:AddSection(topSection)

    -- Name
    local displayName = GetCrownCrateName(crateId)
    if stackCount > 1 then
        displayName = zo_strformat(SI_TOOLTIP_ITEM_NAME_WITH_QUANTITY, displayName, stackCount)
    else
        displayName = zo_strformat(SI_TOOLTIP_ITEM_NAME, displayName)
    end
    self:AddLine(displayName, self:GetStyle("title"))

    -- Description
    local bodySection = self:AcquireSection(self:GetStyle("collectionsInfoSection"))
    local description = GetCrownCrateDescription(crateId)
    bodySection:AddLine(description, self:GetStyle("bodyDescription"))
    self:AddSection(bodySection)
end

function ZO_Tooltip:LayoutInstantUnlock(instantUnlockId)
    -- things added to the topSection stack upwards
    local topSection = self:AcquireSection(self:GetStyle("topSection"))

    local isServiceToken = IsInstantUnlockRewardServiceToken(instantUnlockId)
    local isUpgrade = IsInstantUnlockRewardUpgrade(instantUnlockId)
    if isServiceToken then
        topSection:AddLine(SERVICE_HEADER)
    elseif isUpgrade then
        topSection:AddLine(UPGRADE_HEADER)
    end

    self:AddSection(topSection)

    -- Name
    local displayName = GetInstantUnlockRewardDisplayName(instantUnlockId)
    displayName = zo_strformat(SI_TOOLTIP_ITEM_NAME, displayName)
    self:AddLine(displayName, self:GetStyle("title"))

    local tooltipLines = {}
    local instantUnlockType = GetInstantUnlockRewardType(instantUnlockId)
    if isUpgrade then
        local statsSection = self:AcquireSection(self:GetStyle("baseStatsSection"))
        local statValuePair = statsSection:AcquireStatValuePair(self:GetStyle("statValuePair"))
        statValuePair:SetStat(UNLOCK_LABEL, self:GetStyle("statValuePairStat"))

        local currentUnlock
        local maxUnlock
        local unlockDescription

        if instantUnlockType == INSTANT_UNLOCK_PLAYER_BACKPACK then
            currentUnlock = GetCurrentBackpackUpgrade()
            maxUnlock = GetMaxBackpackUpgrade()
            unlockDescription = zo_strformat(SI_MARKET_PRODUCT_TOOLTIP_BACKPACK_UPGRADE_DESCRIPTION, GetNumBackpackSlotsPerUpgrade())
        elseif instantUnlockType == INSTANT_UNLOCK_PLAYER_BANK then
            currentUnlock = GetCurrentBankUpgrade()
            maxUnlock = GetMaxBankUpgrade()
            unlockDescription = zo_strformat(SI_MARKET_PRODUCT_TOOLTIP_BANK_UPGRADE_DESCRIPTION, GetNumBankSlotsPerUpgrade())
        elseif instantUnlockType == INSTANT_UNLOCK_CHARACTER_SLOT then
            currentUnlock = GetCurrentCharacterSlotsUpgrade()
            maxUnlock = GetMaxCharacterSlotsUpgrade()
            unlockDescription = zo_strformat(SI_MARKET_PRODUCT_TOOLTIP_CHARACTER_SLOT_UPGRADE_DESCRIPTION, GetNumCharacterSlotsPerUpgrade())
        elseif instantUnlockType == INSTANT_UNLOCK_OUTFIT then
            currentUnlock = GetNumUnlockedOutfits()
            maxUnlock = MAX_OUTFIT_UNLOCKS
            unlockDescription = zo_strformat(SI_MARKET_PRODUCT_TOOLTIP_OUTFIT_UPGRADE_DESCRIPTION, NUM_OUTFITS_PER_UPGRADE)
        end

        table.insert(tooltipLines, unlockDescription)

        statValuePair:SetValue(zo_strformat(SI_MARKET_PRODUCT_TOOLTIP_UNLOCK_LEVEL, currentUnlock, maxUnlock), self:GetStyle("statValuePairValue"))
        statsSection:AddStatValuePair(statValuePair)
        self:AddSection(statsSection)
    elseif isServiceToken then
        local tokenDescription
        local tokenUsageRequirement = GetString(SI_SERVICE_TOKEN_USAGE_REQUIREMENT_CHARACTER_SELECT) -- All tokens only usable from character select
        local tokenCountString

        if instantUnlockType == INSTANT_UNLOCK_RENAME_TOKEN then
            tokenDescription = GetString(SI_SERVICE_TOOLTIP_NAME_CHANGE_TOKEN_DESCRIPTION)
            tokenCountString = zo_strformat(SI_SERVICE_TOOLTIP_SERVICE_TOKENS_AVAILABLE, GetNumServiceTokens(SERVICE_TOKEN_NAME_CHANGE), GetString("SI_SERVICETOKENTYPE", SERVICE_TOKEN_NAME_CHANGE))
        elseif instantUnlockType == INSTANT_UNLOCK_RACE_CHANGE_TOKEN then
            tokenDescription = GetString(SI_SERVICE_TOOLTIP_RACE_CHANGE_TOKEN_DESCRIPTION)
            tokenCountString = zo_strformat(SI_SERVICE_TOOLTIP_SERVICE_TOKENS_AVAILABLE, GetNumServiceTokens(SERVICE_TOKEN_RACE_CHANGE), GetString("SI_SERVICETOKENTYPE", SERVICE_TOKEN_RACE_CHANGE))
        elseif instantUnlockType == INSTANT_UNLOCK_APPEARANCE_CHANGE_TOKEN then
            tokenDescription = GetString(SI_SERVICE_TOOLTIP_APPEARANCE_CHANGE_TOKEN_DESCRIPTION)
            tokenCountString = zo_strformat(SI_SERVICE_TOOLTIP_SERVICE_TOKENS_AVAILABLE, GetNumServiceTokens(SERVICE_TOKEN_APPEARANCE_CHANGE), GetString("SI_SERVICETOKENTYPE", SERVICE_TOKEN_APPEARANCE_CHANGE))
        end

        table.insert(tooltipLines, tokenDescription)
        table.insert(tooltipLines, tokenUsageRequirement)
        table.insert(tooltipLines, tokenCountString)
    else
        table.insert(tooltipLines, GetInstantUnlockRewardDescription(instantUnlockId))
    end

    -- Description
    local bodySection = self:AcquireSection(self:GetStyle("collectionsInfoSection"))
    for i = 1, #tooltipLines do
        bodySection:AddLine(tooltipLines[i], self:GetStyle("bodyDescription"))
    end
    self:AddSection(bodySection)
end
