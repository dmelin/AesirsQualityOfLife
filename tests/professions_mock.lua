recipes, schematics, requirements, cooldowns, crafts = {}, {}, {}, {}, {}
professionID, professionShown, autoComplete = 165, true, true
function UnitCastingInfo() return casting end
function UnitChannelInfo() return nil end
local widget = {}
function widget:RegisterEvent() end
function widget:SetScript(name, fn) self[name] = fn end
function widget:HookScript(name, fn) self[name] = fn end
function widget:SetSize() end
function widget:SetPoint() end
function widget:SetWidth() end
function widget:SetJustifyH() end
function widget:SetText(text) self.text = text end
function widget:CreateFontString() return setmetatable({}, {__index=widget}) end
function widget:IsShown() return professionShown end
function widget:SelectRecipe(info) selected = info.recipeID end
function CreateFrame(kind, name)
    local obj = setmetatable({}, {__index=widget})
    if kind == "Button" then skillButton = obj else professionFrame = obj end
    return obj
end
ProfessionsFrame = {CraftingPage=setmetatable({}, {__index=widget})}
C_TradeSkillUI = {}
local T = C_TradeSkillUI
function T.GetBaseProfessionInfo() return {professionID=professionID} end
function T.IsTradeSkillReady() return true end
function T.IsDataSourceChanging() return false end
function T.IsTradeSkillLinked() return linked end
function T.IsTradeSkillGuild() return false end
function T.IsNPCCrafting() return false end
function T.GetAllRecipeIDs()
    local ids = {}; for id in pairs(recipes) do ids[#ids+1] = id end
    return ids
end
function T.GetRecipeInfo(id) return recipes[id] end
function T.GetRecipeSchematic(id) return schematics[id] end
function T.GetRecipeRequirements(id) return requirements[id] or {} end
function T.GetRecipeCooldown(id) return cooldowns[id] or 0 end
function recipe(id, difficulty, reagent, quantity, points)
    recipes[id] = {recipeID=id, name="Recipe "..id, learned=true, craftable=true,
        canSkillUp=true, relativeDifficulty=difficulty, numSkillUps=points or 1}
    schematics[id] = {recipeType=1, outputItemID=10000+id, reagentSlotSchematics={{reagentType=1,
        quantityRequired=quantity, dataSlotType=1, reagents={{itemID=reagent}}}}}
end
function pevent(name, ...)
    professionFrame.OnEvent(professionFrame, name, ...)
end
function ptick(n)
    for i=1,n do now=now+0.3; professionFrame.OnUpdate(professionFrame, 0.3) end
end
function complete(id)
    for _, slot in ipairs(schematics[id].reagentSlotSchematics) do
        local need = slot.quantityRequired
        local reagent = slot.reagents[1].itemID
        for bag=0,4 do for index, v in pairs(bags[bag]) do
            if v.itemID == reagent then
                local take=math.min(need, v.stackCount)
                need=need-take; v.stackCount=v.stackCount-take
                if v.stackCount == 0 then bags[bag][index]=nil end
            end
        end end
        assert(need==0)
    end
    if receiveOutput then
        local slot = 10 + id
        local old = bags[0][slot]
        bags[0][slot] = item(10000+id, (old and old.stackCount or 0)+1)
    end
    if sendResult then pevent("TRADE_SKILL_ITEM_CRAFTED_RESULT", {itemID=10000+id, quantity=1}) end
    if not suppressSuccess then pevent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", castSpellID or id) end
end
function T.CraftRecipe(id, quantity)
    assert(quantity==1)
    crafts[#crafts+1]=id
    if autoComplete then complete(id) end
end
