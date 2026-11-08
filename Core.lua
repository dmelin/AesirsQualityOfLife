local _, A = ...

-- Numeric item classes/subclasses and bag-family masks are locale independent.
function A.AmmoType(weaponClass, weaponSubclass)
    if weaponClass ~= 2 then return end
    if weaponSubclass == 2 or weaponSubclass == 18 then return 2, 1 end -- bows/crossbows: arrows
    if weaponSubclass == 3 then return 3, 2 end -- guns: bullets
end

-- Difficulty is a category, not an invented exact skill-up probability.
function A.BetterSkillRecipe(candidate, best)
    if not best then return true end
    if candidate.difficulty ~= best.difficulty then return candidate.difficulty < best.difficulty end
    if candidate.skillUps ~= best.skillUps then return candidate.skillUps > best.skillUps end
    if candidate.count ~= best.count then return candidate.count > best.count end
    return candidate.id < best.id -- Stable ties avoid jumping around the recipe list.
end

function A.BagCraftCount(requirements, inventory)
    local count = math.huge
    for id, quantity in pairs(requirements) do
        if quantity <= 0 then return 0 end
        count = math.min(count, math.floor((inventory[id] or 0) / quantity))
    end
    return count == math.huge and 0 or count
end

function A.PurchaseQuantity(capacity, stack, bundle, price, money, available)
    if not stack or stack < 1 or not bundle or bundle < 1 or price < 0 then return 0 end
    local amount = math.min(capacity, stack)
    if price > 0 then amount = math.min(amount, math.floor(money / price) * bundle) end
    if available >= 0 then amount = math.min(amount, available) end
    return math.max(0, math.floor(amount / bundle) * bundle)
end
