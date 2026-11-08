local _, A = ...
local events = CreateFrame("Frame")
local hub, primary, tracking, aspects, mover, feedButton
local actions, trackButtons, aspectButtons = {}, {}, {}
local dirty, editing, elapsed = true, false, 0
local SIZE, HUB_SIZE, FAN_RADIUS = 32, 44, 68
local ART = "Interface\\AddOns\\AesirsQualityOfLife\\Media\\"
local ASPECT_IDS = { 13165, 13163, 5118, 13159, 13161, 20043, 34074, 61846 }
local PET_SPELLS = {
    { key = "mend", id = 136, icon = "Interface\\Icons\\Ability_Hunter_MendPet" },
    { key = "feed", id = 6991, icon = "Interface\\Icons\\Ability_Hunter_BeastTraining" },
    { key = "call", id = 883, icon = "Interface\\Icons\\Ability_Hunter_BeastCall" },
    { key = "revive", id = 982, icon = "Interface\\Icons\\Ability_Hunter_BeastSoothe" },
    { key = "tame", id = 1515, icon = "Interface\\Icons\\Ability_Hunter_BeastTaming" },
}

local function DB()
    AesirsQualityOfLifeDB = AesirsQualityOfLifeDB or {}
    AesirsQualityOfLifeDB.hunterPositions = AesirsQualityOfLifeDB.hunterPositions or {}
    return AesirsQualityOfLifeDB.hunterPositions
end

local function LayoutKey()
    local info = C_EditMode.GetLayouts()
    if not info then return "default" end
    -- The API excludes the two built-in presets from layouts but includes them
    -- in activeLayout. The UI manager prepends those presets in its own copy.
    if info.activeLayout <= 2 then return "preset:" .. info.activeLayout end
    local active = info.layouts and info.layouts[info.activeLayout - 2]
    return active and (tostring(active.layoutType) .. ":" .. active.layoutName) or ("layout:" .. info.activeLayout)
end

local function RestorePosition()
    if not hub or InCombatLockdown() then dirty = true; return end
    local position = DB()[LayoutKey()]
    hub:ClearAllPoints()
    if position then hub:SetPoint("CENTER", UIParent, "BOTTOMLEFT", position.x, position.y)
    else hub:SetPoint("CENTER", UIParent, "CENTER", 260, -100) end
end

local function Tooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.spellID then GameTooltip:SetSpellByID(self.spellID)
    else GameTooltip:SetText(self.title or "Aesir QoL Hunter") end
    if self.note then GameTooltip:AddLine(self.note, 1, 0.82, 0.3, true) end
    GameTooltip:Show()
end

local function Button(name, parent, template, icon)
    local button = CreateFrame("Button", name, parent, template)
    button:SetSize(SIZE, SIZE)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetNormalTexture(ART .. "RoundBorder")
    button:SetHighlightTexture(ART .. "RoundHighlight", "ADD")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    button.icon:SetTexture(icon)
    button.mask = button:CreateMaskTexture()
    button.mask:SetAllPoints(button.icon)
    button.mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    button.icon:AddMaskTexture(button.mask)
    button:SetScript("OnEnter", Tooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

local function KnownPetSpells()
    local found, names, aspectNames, learnedAspects = {}, {}, {}, {}
    for _, id in ipairs(ASPECT_IDS) do
        local name = C_Spell.GetSpellName(id)
        if name then aspectNames[name] = true end
        if name and C_SpellBook.IsSpellKnown(id, Enum.SpellBookSpellBank.Player) then learnedAspects[name] = id end
    end
    for _, action in ipairs(PET_SPELLS) do
        local name = C_Spell.GetSpellName(action.id)
        if name then names[name] = action.key end
        if C_SpellBook.IsSpellKnown(action.id, Enum.SpellBookSpellBank.Player) then found[action.key] = action.id end
    end
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local spell = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
                if spell and spell.spellID and not spell.isPassive
                    and not spell.isOffSpec and not C_SpellBook.IsSpellBookItemLowRank(slot, Enum.SpellBookSpellBank.Player) then
                    if names[spell.name] then found[names[spell.name]] = spell.spellID end
                    if aspectNames[spell.name] then learnedAspects[spell.name] = spell.spellID end
                end
            end
        end
    end
    return found, learnedAspects
end

local function FoodBenefit(id)
    local _, spellID = C_Item.GetItemSpell(id)
    if not spellID then return 0 end -- Raw ingredients provide no player use benefit.
    local description = C_Spell.GetSpellDescription(spellID)
    if not description or description == "" then return 2 end -- Preserve unknown effects.
    description = description:lower()
    local wellFed = C_Spell.GetSpellName(19705)
    if wellFed and description:find(wellFed:lower(), 1, true) then return 2 end
    for _, stat in ipairs({ "AGILITY", "STRENGTH", "STAMINA", "INTELLECT", "SPIRIT" }) do
        local text = _G["ITEM_MOD_" .. stat .. "_SHORT"]
        if text and description:find(text:lower(), 1, true) then return 2 end
    end
    return 1 -- Plain recovery food; lower level breaks ties.
end

local function SelectFood()
    if not UnitExists("pet") or UnitIsDeadOrGhost("pet") then return end
    local best
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = C_Container.GetContainerItemInfo(bag, slot)
            if item and not item.isLocked and C_PetInfo.CanPetEatItem(item.itemID) then
                local name, link, quality, level, required, _, _, _, _, _, price = C_Item.GetItemInfo(item.itemID)
                -- Very old food cannot feed a higher-level pet even if its diet matches.
                if name and level and level > UnitLevel("pet") - 30 then
                    local candidate = { id = item.itemID, bag = bag, slot = slot, name = name, link = link,
                        benefit = FoodBenefit(item.itemID), level = level, requiredLevel = required or 0,
                        quality = quality or 0, price = price or 0 }
                    if A.BetterPetFood(candidate, best) then best = candidate end
                end
            end
        end
    end
    return best
end

local function Refresh()
    if not hub or InCombatLockdown() then dirty = true; return end
    dirty = false
    local spells, learnedAspects = KnownPetSpells()
    for _, action in ipairs(PET_SPELLS) do
        local button = actions[action.key]
        local id = spells[action.key]
        button.spellID = id
        button:SetAttribute("type", id and "spell" or nil)
        button:SetAttribute("spell", id)
        local info = id and C_Spell.GetSpellInfo(id)
        button.icon:SetTexture(info and info.iconID or action.icon)
        button.icon:SetDesaturated(not id)
        button.note = not id and "Not learned yet." or nil
    end
    local food = spells.feed and SelectFood()
    feedButton:SetAttribute("type", nil)
    feedButton:SetAttribute("macrotext", nil)
    if food then
        local name = C_Spell.GetSpellName(spells.feed)
        feedButton:SetAttribute("type", "macro")
        feedButton:SetAttribute("macrotext", "/stopmacro [combat][@pet,noexists][@pet,dead]\n/cast "
            .. name .. "\n/use " .. food.bag .. " " .. food.slot)
        feedButton.note = "Feed: " .. food.name .. ". Prefers raw/plain food over player-buff food."
    elseif spells.feed then
        feedButton.note = "No suitable food, or no living pet. Feeding requires being out of combat."
    end
    feedButton.icon:SetDesaturated(not food)

    local known, seen = {}, {}
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(i)
        if info and info.spellID and not seen[info.spellID]
            and C_SpellBook.IsSpellKnown(info.spellID, Enum.SpellBookSpellBank.Player) then
            seen[info.spellID] = true
            known[#known + 1] = info
        end
    end
    table.sort(known, function(a, b) return a.spellID < b.spellID end)
    for i, info in ipairs(known) do
        local button = trackButtons[i]
        if not button then
            button = Button("AesirsQoLTracking" .. i, tracking, "SecureActionButtonTemplate", info.texture)
            trackButtons[i] = button
        end
        button.spellID, button.title = info.spellID, info.name
        button.icon:SetTexture(info.texture)
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", info.spellID)
        local x, y = A.FanOffset(i, #known, math.max(58, #known * 13), 25, 130)
        button:ClearAllPoints()
        button:SetPoint("CENTER", actions.tracking, "CENTER", x, y)
        button:Show()
    end
    for i = #known + 1, #trackButtons do
        trackButtons[i]:SetAttribute("type", nil)
        trackButtons[i]:Hide()
    end
    actions.tracking.note = #known == 0 and "No learned tracking spells found." or "Opens a second fan; the pet-action fan stays open."
    local aspectIDs = {}
    for _, id in pairs(learnedAspects) do aspectIDs[#aspectIDs + 1] = id end
    table.sort(aspectIDs)
    for i, id in ipairs(aspectIDs) do
        local info = C_Spell.GetSpellInfo(id)
        local button = aspectButtons[i]
        if not button then
            button = Button("AesirsQoLAspect" .. i, aspects, "SecureActionButtonTemplate", info and info.iconID)
            aspectButtons[i] = button
        end
        button.spellID = id
        button.icon:SetTexture(info and info.iconID)
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", id)
        local x, y = A.FanOffset(i, #aspectIDs, math.max(62, #aspectIDs * 19), -50, 100)
        button:ClearAllPoints()
        button:SetPoint("CENTER", actions.aspects, "CENTER", x, y)
        button:Show()
    end
    for i = #aspectIDs + 1, #aspectButtons do aspectButtons[i]:SetAttribute("type", nil); aspectButtons[i]:Hide() end
    actions.aspects.note = #aspectIDs == 0 and "No learned aspect spells found." or "Opens Aspects and closes Tracking."
end

local function EditMode(active)
    editing = active
    if not hub or InCombatLockdown() then dirty = true; return end
    primary:Hide()
    tracking:Hide()
    aspects:Hide()
    mover:SetShown(active)
end

local function Create()
    if hub or InCombatLockdown() then return end
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return end
    hub = Button("AesirsQoLHunterBar", UIParent, "SecureHandlerClickTemplate", "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    hub:SetSize(HUB_SIZE, HUB_SIZE)
    local coords = CLASS_ICON_TCOORDS.HUNTER
    hub.icon:SetTexCoord(unpack(coords))
    hub:SetMovable(true)
    hub:SetClampedToScreen(true)
    hub.title = "Aesir QoL Hunter"
    hub.note = "Click for tracking and pet actions. Move using Edit Interface."
    primary = CreateFrame("Frame", nil, hub, "SecureHandlerBaseTemplate")
    primary:SetAllPoints(hub)
    tracking = CreateFrame("Frame", nil, primary, "SecureHandlerBaseTemplate")
    tracking:SetAllPoints(hub)
    aspects = CreateFrame("Frame", nil, primary, "SecureHandlerBaseTemplate")
    aspects:SetAllPoints(hub)
    primary:Hide()
    tracking:Hide()
    aspects:Hide()
    hub:SetFrameRef("primary", primary)
    hub:SetFrameRef("tracking", tracking)
    hub:SetFrameRef("aspects", aspects)
    hub:SetAttribute("_onclick", [[
        if down then return end
        local fan = self:GetFrameRef("primary")
        if fan:IsShown() then
            fan:Hide(); self:GetFrameRef("tracking"):Hide(); self:GetFrameRef("aspects"):Hide()
        else fan:Show() end
    ]])
    actions.tracking = Button("AesirsQoLTrackingMenu", primary, "SecureHandlerClickTemplate", "Interface\\Icons\\Ability_Tracking")
    actions.tracking.title = "Tracking"
    actions.tracking:SetPoint("CENTER", hub, "CENTER", 0, FAN_RADIUS)
    actions.tracking:SetFrameRef("tracking", tracking)
    actions.tracking:SetFrameRef("aspects", aspects)
    actions.tracking:SetAttribute("_onclick", [[
        if down then return end
        self:GetFrameRef("aspects"):Hide()
        local fan = self:GetFrameRef("tracking")
        if fan:IsShown() then fan:Hide() else fan:Show() end
    ]])
    actions.aspects = Button("AesirsQoLAspectMenu", primary, "SecureHandlerClickTemplate", "Interface\\Icons\\Spell_Nature_RavenForm")
    actions.aspects.title = "Aspects"
    actions.aspects:SetPoint("CENTER", hub, "CENTER", A.FanOffset(1, 1, FAN_RADIUS, 30, 0))
    actions.aspects:SetFrameRef("tracking", tracking)
    actions.aspects:SetFrameRef("aspects", aspects)
    actions.aspects:SetAttribute("_onclick", [[
        if down then return end
        self:GetFrameRef("tracking"):Hide()
        local fan = self:GetFrameRef("aspects")
        if fan:IsShown() then fan:Hide() else fan:Show() end
    ]])
    for i, action in ipairs(PET_SPELLS) do
        local button = Button("AesirsQoLPet" .. action.key, primary, "SecureActionButtonTemplate", action.icon)
        button.title = C_Spell.GetSpellName(action.id) or action.key
        local x, y = A.FanOffset(i, 5, FAN_RADIUS, -20, -200)
        button:SetPoint("CENTER", hub, "CENTER", x, y)
        actions[action.key] = button
    end
    feedButton = actions.feed
    feedButton:SetScript("PreClick", function()
        if not InCombatLockdown() then Refresh() end
    end)
    mover = CreateFrame("Frame", nil, hub, "BackdropTemplate")
    mover:SetPoint("TOPLEFT", -5, 5)
    mover:SetPoint("BOTTOMRIGHT", 5, -5)
    mover:SetFrameLevel(hub:GetFrameLevel() + 20)
    mover:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    mover:SetBackdropColor(0.1, 0.4, 0.1, 0.4)
    mover:SetBackdropBorderColor(0.67, 0.83, 0.45, 1)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    local label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", mover, "TOP", 0, 5)
    label:SetText("Aesir Hunter Bar\nDrag to move (saved on drop)")
    mover:SetScript("OnDragStart", function() if editing and not InCombatLockdown() then hub:StartMoving() end end)
    mover:SetScript("OnDragStop", function()
        if InCombatLockdown() then return end
        hub:StopMovingOrSizing()
        local x, y = hub:GetCenter()
        if x and y then DB()[LayoutKey()] = { x = x, y = y } end
        RestorePosition()
    end)
    mover:Hide()
    EventRegistry:RegisterCallback("EditMode.Enter", function() EditMode(true) end, hub)
    EventRegistry:RegisterCallback("EditMode.Exit", function() EditMode(false); RestorePosition() end, hub)
    RestorePosition()
    Refresh()
end

for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
    "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "SPELL_TEXT_UPDATE", "UNIT_PET",
    "MINIMAP_UPDATE_TRACKING", "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED" }) do
    -- Event availability differs from Retail. An optional unsupported event must
    -- not abort loading before the login/update handlers are installed.
    if C_EventUtils.IsEventValid(event) then events:RegisterEvent(event) end
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then Create() end
    if not hub then return end
    dirty = true
    if event == "EDIT_MODE_LAYOUTS_UPDATED" and not editing then RestorePosition() end
    if event == "PLAYER_REGEN_ENABLED" then EditMode(editing); RestorePosition() end
end)
events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.25 then return end
    elapsed = 0
    if dirty and hub and not InCombatLockdown() then Refresh() end
end)
