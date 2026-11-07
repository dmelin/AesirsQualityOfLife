local _, A = ...

-- Numeric item classes/subclasses and bag-family masks are locale independent.
function A.AmmoType(weaponClass, weaponSubclass)
    if weaponClass ~= 2 then return end
    if weaponSubclass == 2 or weaponSubclass == 18 then return 2, 1 end -- bows/crossbows: arrows
    if weaponSubclass == 3 then return 3, 2 end -- guns: bullets
end

function A.PurchaseQuantity(capacity, stack, bundle, price, money, available)
    if not stack or stack < 1 or not bundle or bundle < 1 or price < 0 then return 0 end
    local amount = math.min(capacity, stack)
    if price > 0 then amount = math.min(amount, math.floor(money / price) * bundle) end
    if available >= 0 then amount = math.min(amount, available) end
    return math.max(0, math.floor(amount / bundle) * bundle)
end
