now, sales, bought, calls, money = 0, 0, 0, 0, 10000
class, weaponSub, sellEnabled, confirmPurchase = "HUNTER", 2, true, true
sizes, families, bags, stock, data = {}, {}, {}, {}, {}
for bag = 0, 4 do sizes[bag], families[bag], bags[bag] = 0, 0, {} end
sizes[0] = 16
SlashCmdList = {}
function item(id, n) return {itemID=id, stackCount=n, isLocked=false} end
function addAmmo(id, sub, required, level)
    data[id] = {sub=sub, required=required, level=level, stack=200}
    local entry = {id=id, info={price=10, stackCount=200, numAvailable=-1,
        isPurchasable=true, isUsable=true, hasExtendedCost=false}}
    stock[#stock+1] = entry
    return entry
end
addAmmo(100, 2, 1, 1); addAmmo(200, 3, 1, 1)
function CreateFrame()
    frame = {RegisterEvent=function() end, SetScript=function(self, name, fn) self[name]=fn end}
    return frame
end
MerchantFrame = {IsShown=function() return shown end}
function event(name, ...)
    if name == "MERCHANT_SHOW" then shown = true end
    if name == "MERCHANT_CLOSED" then shown = false end
    frame.OnEvent(frame, name, ...)
end
function tick(n)
    for i = 1, n do now = now + 0.4; frame.OnUpdate(frame, 0.4) end
end
function GetTime() return now end
function GetMoney() return money end
function UnitLevel() return 15 end
function UnitClass() return class, class end
function InCombatLockdown() return combat end
function GetCursorInfo() if cursor then return "item" end end
function ClearCursor()
    if cursor then bags[sourceBag][sourceSlot] = cursor; cursor = nil end
end
function GetInventoryItemLink() return "weapon" end
function GetMerchantNumItems() return #stock end
function GetMerchantItemLink(i) return stock[i].id end
function GetMerchantItemMaxStack() return 200 end
function count(id)
    local n = 0
    for bag = 0, 4 do for _, v in pairs(bags[bag]) do
        if v.itemID == id then n = n + v.stackCount end
    end end
    return n
end
C_Item = {}
function C_Item.GetItemInfoInstant(id)
    if id == "weapon" then return 1, nil, nil, nil, nil, 2, weaponSub end
    return id, nil, nil, nil, nil, 6, data[id].sub
end
function C_Item.GetItemInfo(id)
    local d = data[id]
    return "Ammo", id, 1, d.level, d.required, nil, nil, d.stack
end
C_MerchantFrame = {}
function C_MerchantFrame.GetItemInfo(i) return stock[i].info end
function C_MerchantFrame.IsSellAllJunkEnabled() return sellEnabled end
function C_MerchantFrame.SellAllJunkItems() sales = sales + 1 end
C_Container = {}
function C_Container.GetContainerNumSlots(bag) return sizes[bag] end
function C_Container.GetContainerNumFreeSlots(bag)
    local n = 0
    for slot = 1, sizes[bag] do if not bags[bag][slot] then n = n + 1 end end
    return n, families[bag]
end
function C_Container.GetContainerItemInfo(bag, slot) return bags[bag][slot] end
function C_Container.PickupContainerItem(bag, slot)
    local dest = bags[bag][slot]
    if not cursor then
        cursor = dest; bags[bag][slot] = nil; sourceBag, sourceSlot = bag, slot
    elseif not dest then bags[bag][slot] = cursor; cursor = nil
    elseif dest.itemID == cursor.itemID then
        local n = math.min(200 - dest.stackCount, cursor.stackCount)
        dest.stackCount = dest.stackCount + n; cursor.stackCount = cursor.stackCount - n
        if cursor.stackCount == 0 then cursor = nil end
    else error("unexpected item swap") end
    event("BAG_UPDATE_DELAYED")
end
function BuyMerchantItem(index, amount)
    calls = calls + 1
    if not confirmPurchase then return end
    local entry = stock[index]
    local family = entry.id == 200 and 2 or 1
    local left = amount
    for bag = 1, 4 do
        if families[bag] == family then
            for slot = 1, sizes[bag] do
                local dest = bags[bag][slot]
                if not dest or dest.itemID == entry.id then
                    local n = math.min(left, 200 - (dest and dest.stackCount or 0))
                    if n > 0 then
                        bags[bag][slot] = item(entry.id, (dest and dest.stackCount or 0) + n)
                        left = left - n
                    end
                end
            end
        end
    end
    assert(left == 0, "purchase exceeded dedicated bag capacity")
    bought = bought + amount
    money = money - entry.info.price * amount / entry.info.stackCount
    event("BAG_UPDATE_DELAYED")
end
function print() end
