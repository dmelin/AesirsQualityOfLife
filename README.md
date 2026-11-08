# Aesirs Quality of Life

A small World of Warcraft: Forever addon that handles routine vendor chores.

## Features

- Automatically sells poor-quality (grey) junk when a vendor opens, using Forever's native junk-selling API and its junk-selling rules.
- On hunters, restocks arrows for bows/crossbows or bullets for guns.
- Chooses the highest required-level, usable matching ammunition offered by the current vendor; item level breaks ties.
- Counts only free slots and matching partial stacks in equipped quivers or ammo pouches. Ordinary bags never increase the purchase target. Other ammo types are not replaced.
- Moves existing matching ammunition from ordinary bags into the ammo bag before buying.
- Buys in the vendor's bundle sizes, within your available money and stock. Space smaller than one vendor bundle is left empty.
- Waits for each purchase to appear in your bags before another purchase. Stops on vendor errors, unconfirmed purchases, or closing the vendor. Pauses while in combat or holding something on the cursor.

Both features are enabled by default. No libraries or other addons are required.

Vendor actions print colored **Aesir QoL:** chat messages: trash-sale income in green, ammo quantity and cost in gold, and totals formatted in gold/silver/copper. Totals use money changes from the vendor operation, with ammo counted only after receipt is confirmed. Restock summaries include successful partial purchases when a vendor closes or restocking stops; failed/unconfirmed purchases do not produce success messages.

## Smart Skill Up (1.2.0)

Open Leatherworking or another crafting profession and click **Smart Skill Up**, attached below the profession window. The click picks the best recipe and starts a native batch using your bag materials, similar to Create All. When the batch finishes, click again to reassess and start the next best recipe. Click **Stop Skill Up** during a batch to cancel native repeats; an item already being cast can finish.

Recipes are ranked by:

1. Skill-up difficulty: orange, then yellow, then green. Grey recipes are excluded.
2. More skill points awarded per successful skill-up within the same difficulty.
3. More crafts possible from materials currently in your backpack and equipped bags.

For equal skill-up potential, a recipe you can craft **7 times** beats one you can craft **5 times**. There are no Auction House prices, gold valuations, or bank-material counts. Difficulty categories are used rather than claiming exact skill-up probabilities.

Only learned, usable item recipes with ordinary, unambiguous item reagents are included. Unmet tool/station requirements and active cooldowns are excluded. Target-item enchants, salvage, recrafting, and recipes requiring alternative/currency reagent allocations are excluded. A recipe's quality-capability flag alone does not exclude it; the actual required reagent choices determine whether it is supported. Cooking and other ordinary item-crafting professions can use the same button.

Forever's live client blocks attempts to start another craft from a timer or completion event. All craft starts now run directly from the button click using the native `CraftRecipe(recipeID, numCasts)` batch argument. The addon never starts another batch automatically. Recipe ranking is evaluated per click, so difficulty changes during a batch do not switch recipes; stop and click again to reassess. Materials are consumed while the batch runs.

Batch monitoring ends on profession changes, closing the window, combat, interrupted/failed crafts, crafting errors, or unconfirmed completion. Completion is checked using crafted-item/cast events or output changes together with total batch reagent consumption. The addon never retries an unconfirmed batch automatically.

Profession API names were checked against the captured Forever API list. Recipe and reagent fields were checked against [Forever's profession type documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUITypesDocumentation.lua), and the button attaches to the [Forever crafting page](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Professions/Camelot/Blizzard_ProfessionsCrafting.lua). Recipe selection has been confirmed in-game; native batch crafting still needs a smoke test.

## Installation

Copy the `AesirsQualityOfLife` folder containing `AesirsQualityOfLife.toc`, `Core.lua`, `Main.lua`, and `Professions.lua` into:

```text
World of Warcraft/_forever_/Interface/AddOns/AesirsQualityOfLife/
```

Restart WoW if the addon was installed while the client was open. Enable **Aesirs Quality of Life** in the character-selection AddOns list. Future Lua changes can be loaded with `/reload`.

## Commands

| Command | Action |
| --- | --- |
| `/aqol` | Show feature status |
| `/aqol trash` | Toggle automatic junk selling |
| `/aqol ammo` | Toggle automatic hunter ammo restocking |
| `/aqolcraftdebug` | Print recipe eligibility and bag craft counts for the open profession |

Settings are saved account-wide. Ammo restocking requires a matching dedicated ammo bag and a vendor selling usable ammunition. Purchases spend your character's money; extended-cost purchases are excluded. The addon does not change which ammo is equipped.

## Forever compatibility and validation

Targets interface **16001**, matching the installed Forever **1.60.1.70862** client at development time. The TOC allows the `camelot` game type.

API presence was checked against the [captured Forever API list](https://github.com/Thunderz96/forever-addon-kit/blob/main/data/forever_api.json). Signatures were checked against the [client-generated inventory API reference](https://github.com/Atraeau/WoW-Addons/tree/main/docs/api/Items-Inventory), [Forever merchant API documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MerchantFrameDocumentation.lua), and [Forever's merchant UI source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua).

Uses `C_Container`, `C_Item`, and `C_MerchantFrame`; it does not depend on removed legacy bag/item API globals. Captured API presence and simulated tests do not replace live-client validation. A live vendor test is still required.

## Tests

The tests run the actual addon files under Lua 5.1 with a simulated merchant and inventory:

```sh
python -m pip install lupa
python tests/test_addon.py
```

Coverage includes weapon matching, ammo-bag capacity, partial stacks, bundle rounding, affordability, limited stock calculations, moving existing ammo, tier selection, non-hunters, vendor closure, combat/cursor pauses, toggles, and purchase failures.

For a live smoke test, visit a vendor with a grey item, then visit an ammo vendor on a hunter with a partially empty matching ammo bag. Confirm junk is sold and only the available ammo-bag capacity is restocked. Test without a dedicated bag and confirm no ammo is purchased.
