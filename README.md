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

## Installation

Copy the `AesirsQualityOfLife` folder containing `AesirsQualityOfLife.toc`, `Core.lua`, and `Main.lua` into:

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
