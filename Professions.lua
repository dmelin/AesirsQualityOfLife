local _, A = ...
local T = C_TradeSkillUI
local frame = CreateFrame("Frame")
local button, label, page, run, pending
local elapsed, nextCraft = 0, 0

local function Status(text)
    if label then label:SetText(text) end
end

local function Stop(reason)
    run, pending = nil, nil
    if button then button:SetText("Smart Skill Up") end
    if reason then Status(reason) end
end

local function Inventory()
    local counts = {}
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = C_Container.GetContainerItemInfo(bag, slot)
            if item and not item.isLocked then
                counts[item.itemID] = (counts[item.itemID] or 0) + item.stackCount
            end
        end
    end
    return counts
end

local function ProfessionID()
    local info = T.GetBaseProfessionInfo()
    return info and info.professionID
end

local function LocalProfession()
    return page and page:IsShown() and T.IsTradeSkillReady()
        and not T.IsDataSourceChanging() and not T.IsTradeSkillLinked()
        and not T.IsTradeSkillGuild() and not T.IsNPCCrafting()
end

local function Requirements(id)
    local schematic = T.GetRecipeSchematic(id, false)
    -- Target-item enchants, salvage, qualities, currencies, and variable reagent
    -- choices need explicit allocation. Do not silently choose or consume them.
    if not schematic or schematic.recipeType ~= 1 or schematic.isRecraft then return end
    local requirements = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        if slot.reagentType == 1 or slot.required then
            if slot.dataSlotType ~= 1 or #slot.reagents ~= 1 then return end
            local reagent = slot.reagents[1]
            if not reagent.itemID or not slot.quantityRequired or slot.quantityRequired <= 0 then return end
            requirements[reagent.itemID] = (requirements[reagent.itemID] or 0) + slot.quantityRequired
        end
    end
    return requirements
end

local function Choose(inventory)
    local best
    for _, id in ipairs(T.GetAllRecipeIDs()) do
        local info = T.GetRecipeInfo(id)
        if info and info.learned and not info.disabled and info.craftable ~= false
            and info.canSkillUp and info.relativeDifficulty and info.relativeDifficulty < 3
            and not info.supportsQualities and not info.isRecraft and not info.isDummyRecipe
            and not info.isEnchantingRecipe and not info.isSalvageRecipe and not info.isGatheringRecipe then
            local requirements = Requirements(id)
            local count = requirements and A.BagCraftCount(requirements, inventory) or 0
            if count > 0 then
                local cooldown, _, charges = T.GetRecipeCooldown(id)
                local available = not cooldown or cooldown <= 0 or (charges and charges > 0)
                for _, requirement in ipairs(T.GetRecipeRequirements(id) or {}) do
                    if not requirement.met then available = false end
                end
                if available then
                    local candidate = { id = id, info = info, requirements = requirements,
                        count = count, difficulty = info.relativeDifficulty, skillUps = info.numSkillUps or 1 }
                    if A.BetterSkillRecipe(candidate, best) then best = candidate end
                end
            end
        end
    end
    return best
end

local function CraftNext()
    if not LocalProfession() or ProfessionID() ~= run.profession then
        Stop("Stopped: profession changed or closed."); return
    end
    if InCombatLockdown() or GetCursorInfo() then
        Stop("Stopped: combat or an item on the cursor."); return
    end
    if UnitCastingInfo("player") or UnitChannelInfo("player") then return end
    local inventory = Inventory()
    local best = Choose(inventory)
    if not best then Stop("No skill-up recipe can be crafted from your bags."); return end
    page:SelectRecipe(best.info)
    Status(best.info.name .. " (" .. best.count .. " craftable from bags)")
    -- Set before invoking CraftRecipe: instant crafts can deliver events immediately.
    pending = { id = best.id, before = inventory, requirements = best.requirements,
        started = GetTime() }
    local ok = pcall(T.CraftRecipe, best.id, 1)
    if not ok then Stop("Crafting requires another click. Click Smart Skill Up to retry.") end
end

local function Attach()
    if button or not ProfessionsFrame or not ProfessionsFrame.CraftingPage then return end
    page = ProfessionsFrame.CraftingPage
    button = CreateFrame("Button", "AesirsQoLSkillUpButton", page, "UIPanelButtonTemplate")
    button:SetSize(142, 24)
    button:SetPoint("TOPLEFT", page, "BOTTOMLEFT", 10, -4)
    button:SetText("Smart Skill Up")
    label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", button, "RIGHT", 8, 0)
    label:SetWidth(550)
    label:SetJustifyH("LEFT")
    Status("Uses materials in your bags. Click to start.")
    button:SetScript("OnClick", function()
        if run then Stop("Stopped. Any current item will finish."); return end
        if not LocalProfession() then Status("Open your own crafting profession first."); return end
        if UnitCastingInfo("player") or UnitChannelInfo("player") then
            Status("Wait for the current cast to finish."); return
        end
        run = { profession = ProfessionID() }
        button:SetText("Stop Skill Up")
        CraftNext()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Aesirs Smart Skill Up")
        GameTooltip:AddLine("Prefers orange, then yellow, then green recipes. Within a difficulty, prefers more skill points, then the most crafts from your bags.", 1, 1, 1, true)
        GameTooltip:AddLine("Rechecks after each item. Click again to stop further crafts. Materials are consumed.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    page:HookScript("OnHide", function() Stop("Stopped: crafting window closed.") end)
end

for _, event in ipairs({ "ADDON_LOADED", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE",
    "TRADE_SKILL_DATA_SOURCE_CHANGING", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UI_ERROR_MESSAGE", "PLAYER_REGEN_DISABLED",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do frame:RegisterEvent(event) end

frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "ADDON_LOADED" or event == "TRADE_SKILL_SHOW" then Attach() end
    if not run then return end
    if event == "TRADE_SKILL_CLOSE" or event == "TRADE_SKILL_DATA_SOURCE_CHANGING"
        or event == "PLAYER_REGEN_DISABLED" then Stop("Stopped: profession closed, changed, or combat started.")
    elseif (event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN") and unit == "AesirsQualityOfLife" then
        Stop("Crafting requires another click. Click Smart Skill Up to continue.")
    elseif pending then
        if event == "UI_ERROR_MESSAGE" then Stop("Stopped after a crafting error.")
        elseif unit == "player" and spellID == pending.id then
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                pending.succeeded = GetTime()
            elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
                Stop("Stopped: crafting failed or was interrupted.")
            end
        end
    end
end)

frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.25 then return end
    elapsed = 0
    if not run then return end
    if not LocalProfession() or ProfessionID() ~= run.profession then Stop("Stopped: profession changed or closed."); return end
    if pending then
        if pending.succeeded and GetTime() - pending.succeeded >= 0.6 then
            local inventory, consumed = Inventory(), true
            for id, quantity in pairs(pending.requirements) do
                if (inventory[id] or 0) > (pending.before[id] or 0) - quantity then consumed = false end
            end
            if consumed then pending = nil; nextCraft = GetTime() + 0.25 end
        end
        if pending and GetTime() - pending.started > 60 then
            Stop("Stopped: craft completion was not confirmed. Click to retry.")
        end
    elseif GetTime() >= nextCraft then CraftNext() end
end)

Attach()
