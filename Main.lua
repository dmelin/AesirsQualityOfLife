local _, A = ...
local frame = CreateFrame("Frame")
local session, elapsed = nil, 0
local function Say(message)
    print("|cff66ccffAesirs Quality of Life:|r " .. message)
end

local function Ready()
    return session and MerchantFrame and MerchantFrame:IsShown()
        and not InCombatLockdown() and not GetCursorInfo()
end

local function AmmoCount(id)
    local count = 0
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = C_Container.GetContainerItemInfo(bag, slot)
            if item and item.itemID == id then count = count + item.stackCount end
        end
    end
    return count
end

local function Capacity(id, stack, family)
    local room = 0
    for bag = 1, 4 do
        local _, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        -- Ordinary bags never contribute capacity. Wrong ammo types stay untouched.
        if bagFamily == family then
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local item = C_Container.GetContainerItemInfo(bag, slot)
                if not item then room = room + stack
                elseif item.itemID == id and not item.isLocked then
                    room = room + math.max(0, stack - item.stackCount)
                end
            end
        end
    end
    return room
end

-- Move existing stacks first, including purchases the client placed in an ordinary
-- bag. A move is followed by a wait for bag updates before another transaction.
local function MoveAmmo(id, stack, family)
    for destBag = 1, 4 do
        local _, destFamily = C_Container.GetContainerNumFreeSlots(destBag)
        if destFamily == family then
            for destSlot = 1, C_Container.GetContainerNumSlots(destBag) do
                local dest = C_Container.GetContainerItemInfo(destBag, destSlot)
                if not dest or (dest.itemID == id and not dest.isLocked and dest.stackCount < stack) then
                    for bag = 0, 4 do
                        local _, sourceFamily = C_Container.GetContainerNumFreeSlots(bag)
                        if sourceFamily ~= family then
                            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                                local item = C_Container.GetContainerItemInfo(bag, slot)
                                if item and item.itemID == id and not item.isLocked then
                                    C_Container.PickupContainerItem(bag, slot)
                                    C_Container.PickupContainerItem(destBag, destSlot)
                                    -- A partial merge leaves the remainder on the cursor.
                                    if GetCursorInfo() then ClearCursor() end
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function FindAmmo(subclass)
    local best, missing = nil, false
    for index = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(index)
        local info = C_MerchantFrame.GetItemInfo(index)
        if link and info then
            local id, _, _, _, _, class, sub = C_Item.GetItemInfoInstant(link)
            if class == 6 and sub == subclass then
                local name, _, _, level, required, _, _, stack = C_Item.GetItemInfo(link)
                if not name then missing = true
                elseif info.isPurchasable and info.isUsable and not info.hasExtendedCost
                    and not info.currencyID and info.numAvailable ~= 0 and required <= UnitLevel("player") then
                    if not best or required > best.required or (required == best.required and level > best.level) then
                        best = { index = index, id = id, stack = stack, required = required, level = level }
                    end
                end
            end
        end
    end
    -- Wait for all matching ammo data before choosing a lower tier.
    if missing then return nil end
    return best
end

local function Tick()
    if not Ready() then return end
    local s = session
    if not s.sold then
        s.sold = true
        if AesirsQualityOfLifeDB.sellJunk and C_MerchantFrame.IsSellAllJunkEnabled() then
            C_MerchantFrame.SellAllJunkItems()
        end
        return
    end
    if not AesirsQualityOfLifeDB.buyAmmo or s.done then return end
    if s.pending then
        if AmmoCount(s.pending.id) >= s.pending.before + s.pending.amount then
            s.bought = s.bought + s.pending.amount
            s.pending = nil
        elseif GetTime() - s.pending.time > 5 then
            s.done = true
            Say("Ammo restock stopped: purchase was not confirmed.")
        end
        return
    end
    if s.moveTime then
        if not s.bagsChanged and GetTime() - s.moveTime < 2 then return end
        s.moveTime, s.bagsChanged = nil, nil
    end
    if GetTime() - s.started > 60 or s.moves >= 100 then s.done = true; return end
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then s.done = true; return end
    local weapon = GetInventoryItemLink("player", 18)
    if not weapon then s.done = true; return end
    local _, _, _, _, _, weaponClass, weaponSubclass = C_Item.GetItemInfoInstant(weapon)
    local subclass, family = A.AmmoType(weaponClass, weaponSubclass)
    if not subclass then s.done = true; return end
    local ammo = FindAmmo(subclass)
    if not ammo then return end
    local room = Capacity(ammo.id, ammo.stack, family)
    if room <= 0 then
        s.done = true
        if s.bought > 0 then Say("Restocked " .. s.bought .. " ammo.") end
        return
    end
    if MoveAmmo(ammo.id, ammo.stack, family) then
        s.moveTime, s.bagsChanged = GetTime(), false
        s.moves = s.moves + 1
        return
    end
    -- A fixed per-visit budget prevents repeat buying if inventory placement fails.
    s.budget = s.budget or room
    local info = C_MerchantFrame.GetItemInfo(ammo.index)
    if not info then return end
    local amount = A.PurchaseQuantity(math.min(room, s.budget - s.bought),
        math.min(ammo.stack, GetMerchantItemMaxStack(ammo.index)),
        info.stackCount, info.price, GetMoney(), info.numAvailable)
    if amount == 0 then s.done = true; return end
    s.pending = { id = ammo.id, before = AmmoCount(ammo.id), amount = amount, time = GetTime() }
    BuyMerchantItem(ammo.index, amount)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == "AesirsQualityOfLife" then
        AesirsQualityOfLifeDB = AesirsQualityOfLifeDB or {}
        if AesirsQualityOfLifeDB.sellJunk == nil then AesirsQualityOfLifeDB.sellJunk = true end
        if AesirsQualityOfLifeDB.buyAmmo == nil then AesirsQualityOfLifeDB.buyAmmo = true end
    elseif event == "MERCHANT_SHOW" then
        session = { started = GetTime(), bought = 0, moves = 0 }
    elseif event == "MERCHANT_CLOSED" then session = nil
    elseif event == "BAG_UPDATE_DELAYED" and session then session.bagsChanged = true
    elseif event == "UI_ERROR_MESSAGE" and session and session.pending then
        session.done, session.pending = true, nil
        Say("Ammo restock stopped after a vendor error.")
    end
end)
frame:SetScript("OnUpdate", function(_, delta)
    if not session then return end
    elapsed = elapsed + delta
    if elapsed < 0.35 then return end
    elapsed = 0
    Tick()
end)

SLASH_AESIRSQOL1 = "/aqol"
SlashCmdList.AESIRSQOL = function(message)
    local command = message:lower():match("^%s*(.-)%s*$")
    if command == "trash" then AesirsQualityOfLifeDB.sellJunk = not AesirsQualityOfLifeDB.sellJunk
    elseif command == "ammo" then AesirsQualityOfLifeDB.buyAmmo = not AesirsQualityOfLifeDB.buyAmmo end
    Say("Sell trash: " .. (AesirsQualityOfLifeDB.sellJunk and "on" or "off")
        .. "; buy ammo: " .. (AesirsQualityOfLifeDB.buyAmmo and "on" or "off")
        .. ". /aqol trash or /aqol ammo to toggle.")
end
