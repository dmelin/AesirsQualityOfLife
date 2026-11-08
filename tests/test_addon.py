"""Run with Python and lupa: python -m pip install lupa; python tests/test_addon.py."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.test-libs'))
from lupa.lua51 import LuaRuntime


class AddonTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((ROOT / 'tests' / 'mock.lua').read_text())
        self.lua.execute('A = {}')
        for name in ('Core.lua', 'Main.lua'):
            self.lua.execute((ROOT / name).read_text(), 'AesirsQualityOfLife', self.lua.globals().A)
        self.lua.execute('event("ADDON_LOADED", "AesirsQualityOfLife")')

    def check(self, code):
        self.lua.execute(code)

    def test_weapon_and_purchase_rules(self):
        self.check('''
            assert(A.AmmoType(2, 2) == 2)
            assert(A.AmmoType(2, 18) == 2)
            assert(A.AmmoType(2, 3) == 3)
            assert(A.AmmoType(2, 19) == nil)
            assert(A.PurchaseQuantity(450, 200, 200, 10, 100, -1) == 200)
            assert(A.PurchaseQuantity(199, 200, 200, 10, 100, -1) == 0)
            assert(A.PurchaseQuantity(450, 200, 1, 10, 35, -1) == 3)
            assert(A.PurchaseQuantity(450, 200, 1, 10, 1000, 15) == 15)
        ''')

    def test_sale_and_ammo_logs_have_separate_actual_totals(self):
        self.check('''
            saleProfit=12345; sizes[1]=3; families[1]=1
            event("MERCHANT_SHOW"); tick(50)
            assert(#logs==2)
            assert(logs[1]:find("Aesir ") and logs[1]:find("QoL:"))
            assert(logs[1]:find("Sold trash") and logs[1]:find("1g")
                and logs[1]:find("23s") and logs[1]:find("45c"))
            assert(logs[2]:find("600 ammo") and logs[2]:find("30c"))
            event("MERCHANT_CLOSED"); tick(10); assert(#logs==2)
        ''')

    def test_no_success_logs_for_no_sale_or_failed_purchase(self):
        self.check('''
            sizes[1]=2; families[1]=1; confirmPurchase=false
            event("MERCHANT_SHOW"); tick(40)
            for _, message in ipairs(logs) do
                assert(not message:find("Sold trash") and not message:find("Total cost"))
            end
        ''')

    def test_partial_restock_is_reported_on_close(self):
        self.check('''
            sizes[1]=3; families[1]=1
            event("MERCHANT_SHOW")
            for i=1,40 do tick(1); if calls==1 then break end end
            event("MERCHANT_CLOSED"); tick(10)
            assert(calls==1 and #logs==1)
            assert(logs[1]:find("200 ammo") and logs[1]:find("10c"))
        ''')

    def test_delayed_sale_finishes_after_vendor_closes(self):
        self.check('''
            event("MERCHANT_SHOW"); tick(1)
            event("MERCHANT_CLOSED"); money=money+57; tick(10)
            assert(#logs==1 and logs[1]:find("Sold trash") and logs[1]:find("57c"))
            assert(calls==0)
        ''')

    def test_sells_only_at_accepting_vendor(self):
        self.check('''
            event("MERCHANT_SHOW"); tick(1)
            assert(sales == 1)
            tick(4); assert(sales == 1)
            event("MERCHANT_CLOSED"); tick(4); assert(sales == 1)
            sellEnabled = false
            event("MERCHANT_SHOW"); tick(1); assert(sales == 1)
        ''')

    def test_fills_quiver_without_backpack_capacity(self):
        self.check('''
            sizes[1] = 3; families[1] = 1
            bags[1][1] = item(100, 150)
            event("MERCHANT_SHOW"); tick(30)
            assert(bought == 400) -- 450 space, sold in bundles of 200
            assert(count(100) == 550)
            for _, v in pairs(bags[0]) do assert(v.itemID ~= 100) end
        ''')

    def test_wrong_bag_and_non_hunter(self):
        self.check('''
            sizes[1] = 3; families[1] = 2
            event("MERCHANT_SHOW"); tick(20); assert(bought == 0)
            event("MERCHANT_CLOSED"); families[1] = 1; class = "MAGE"
            event("MERCHANT_SHOW"); tick(20); assert(bought == 0)
        ''')

    def test_gun_selects_bullets(self):
        self.check('''
            weaponSub = 3; families[1] = 2; sizes[1] = 1
            event("MERCHANT_SHOW"); tick(20)
            assert(bought == 200 and bags[1][1].itemID == 200)
        ''')

    def test_existing_backpack_ammo_moves_first(self):
        self.check('''
            sizes[1] = 2; families[1] = 1
            bags[0][1] = item(100, 200)
            event("MERCHANT_SHOW"); tick(30)
            assert(bought == 200 and count(100) == 400)
            assert(bags[0][1] == nil)
        ''')

    def test_highest_usable_tier_and_no_extended_cost(self):
        self.check('''
            sizes[1] = 1; families[1] = 1
            addAmmo(300, 2, 10, 20)
            addAmmo(400, 2, 20, 30)
            addAmmo(500, 2, 15, 40).info.hasExtendedCost = true
            event("MERCHANT_SHOW"); tick(20)
            assert(bought == 200 and bags[1][1].itemID == 300)
        ''')

    def test_no_purchases_with_no_bag_no_money_or_full_bag(self):
        self.check('''
            event("MERCHANT_SHOW"); tick(20); assert(bought == 0)
            event("MERCHANT_CLOSED"); sizes[1] = 1; families[1] = 1
            money = 0; event("MERCHANT_SHOW"); tick(20); assert(bought == 0)
            event("MERCHANT_CLOSED"); money = 10000; bags[1][1] = item(999, 1)
            event("MERCHANT_SHOW"); tick(20); assert(bought == 0)
        ''')

    def test_closed_vendor_and_pending_purchase(self):
        self.check('''
            sizes[1] = 4; families[1] = 1; confirmPurchase = false
            event("MERCHANT_SHOW"); tick(20)
            assert(calls == 1) -- no repeated spending on unconfirmed requests
            event("MERCHANT_CLOSED"); tick(20); assert(calls == 1)
        ''')

    def test_cursor_combat_settings_and_vendor_errors(self):
        self.check('''
            sizes[1] = 4; families[1] = 1; combat = true
            event("MERCHANT_SHOW"); tick(5); assert(calls == 0 and sales == 0)
            combat = false; cursor = item(999, 1); tick(5); assert(calls == 0)
            cursor = nil; confirmPurchase = false; tick(2)
            event("UI_ERROR_MESSAGE", 1); tick(20); assert(calls == 1)
            event("MERCHANT_CLOSED"); SlashCmdList.AESIRSQOL("ammo")
            event("MERCHANT_SHOW"); tick(20); assert(calls == 1)
        ''')


class ProfessionTests(unittest.TestCase):
    def setUp(self):
        AddonTests.setUp(self)
        self.lua.execute((ROOT / 'tests' / 'professions_mock.lua').read_text())
        self.lua.execute((ROOT / 'Professions.lua').read_text(), 'AesirsQualityOfLife', self.lua.globals().A)

    def check(self, code):
        self.lua.execute(code)

    def test_crafts_using_materials_in_additional_reagent_bag(self):
        self.check('''
            bags[5]={[1]=item(2318, 11)}
            recipe(1, 0, 2318, 1); recipes[1].name="Light Armor Kit"
            skillButton.OnClick(); ptick(20)
            assert(#crafts==1 and crafts[1]==1 and batchQuantity==11)
            assert(skillButton.text=="Smart Skill Up")
        ''')

    def test_counts_materials_split_between_regular_and_reagent_bags(self):
        self.check('''
            bags[0][1]=item(2318, 3); bags[5]={[1]=item(2318, 8)}
            recipe(1, 0, 2318, 2)
            skillButton.OnClick(); assert(batchQuantity==5)
        ''')

    def test_bank_slots_do_not_increase_crafting_count(self):
        self.check('''
            bags[6]={[1]=item(2318, 99)}
            recipe(1, 0, 2318, 1)
            skillButton.OnClick(); assert(#crafts==0)
        ''')

    def test_seven_beats_five_at_equal_skill_gain(self):
        self.check('''
            bags[0][1]=item(10, 7); bags[0][2]=item(20, 5)
            recipe(1, 0, 10, 1); recipe(2, 0, 20, 1)
            autoComplete=false; skillButton.OnClick()
            assert(crafts[1]==1)
        ''')

    def test_difficulty_then_points_then_count(self):
        self.check('''
            bags[0][1]=item(10, 7); bags[0][2]=item(20, 2)
            recipe(1, 1, 10, 1); recipe(2, 0, 20, 1)
            autoComplete=false; skillButton.OnClick(); assert(crafts[1]==2)
            skillButton.OnClick(); recipes[1].relativeDifficulty=0
            recipes[2].numSkillUps=2
            skillButton.OnClick(); assert(crafts[2]==2)
        ''')

    def test_next_recipe_requires_new_click(self):
        self.check('''
            bags[0][1]=item(10, 2); bags[0][2]=item(20, 1)
            recipe(1, 0, 10, 1); recipe(2, 0, 20, 1)
            skillButton.OnClick(); recipes[1].relativeDifficulty=1
            ptick(40)
            assert(#crafts==1 and batchQuantity==2 and crafts[1]==1)
            assert(skillButton.text=="Smart Skill Up")
            skillButton.OnClick(); ptick(20)
            assert(#crafts==2 and crafts[2]==2 and batchQuantity==1)
        ''')

    def test_bags_only_and_no_gray_or_unlearned_recipes(self):
        self.check('''
            bags[0][1]=item(10, 3)
            recipe(1, 3, 10, 1); recipe(2, 0, 99, 1)
            recipe(3, 0, 10, 1); recipes[3].learned=false
            skillButton.OnClick(); ptick(10); assert(#crafts==0)
        ''')

    def test_requirements_cooldowns_and_special_recipes_excluded(self):
        self.check('''
            bags[0][1]=item(10, 8)
            for id=1,5 do recipe(id, 0, 10, 1) end
            requirements[1]={{met=false}}; cooldowns[2]=20
            schematics[3].recipeType=3; recipes[4].supportsQualities=true
            schematics[4].reagentSlotSchematics[1].reagents[2]={itemID=11}
            autoComplete=false; skillButton.OnClick(); assert(crafts[1]==5)
        ''')

    def test_stop_close_change_combat_and_interruption(self):
        for action in ('skillButton.OnClick()', 'professionShown=false',
                       'professionID=164', 'pevent("PLAYER_REGEN_DISABLED")',
                       'pevent("UNIT_SPELLCAST_INTERRUPTED", "player", "cast", 1)'):
            with self.subTest(action=action):
                self.setUp()
                self.check('''
                    bags[0][1]=item(10, 8); recipe(1, 0, 10, 1)
                    autoComplete=false; skillButton.OnClick()
                ''' + action + '''
                    complete(1); ptick(30); assert(#crafts==1)
                ''')

    def test_never_repeats_an_unconfirmed_craft(self):
        self.check('''
            bags[0][1]=item(10, 8); recipe(1, 0, 10, 1)
            autoComplete=false; skillButton.OnClick(); ptick(250)
            assert(#crafts==1 and skillButton.text=="Smart Skill Up")
        ''')

    def test_linked_profession_cannot_start(self):
        self.check('''
            bags[0][1]=item(10, 8); recipe(1, 0, 10, 1)
            linked=true; skillButton.OnClick(); ptick(10); assert(#crafts==0)
        ''')

    def test_continues_with_different_cast_spell_id(self):
        self.check('''
            bags[0][1]=item(10, 3); recipe(1, 0, 10, 1)
            receiveOutput=true; castSpellID=99999
            skillButton.OnClick(); ptick(50)
            assert(#crafts==1 and batchQuantity==3 and skillButton.text=="Smart Skill Up")
        ''')

    def test_continues_from_native_profession_result(self):
        self.check('''
            bags[0][1]=item(10, 3); recipe(1, 0, 10, 1)
            sendResult=true; suppressSuccess=true
            skillButton.OnClick(); ptick(50)
            assert(#crafts==1 and batchQuantity==3)
        ''')

    def test_result_waits_for_material_consumption_and_cast_end(self):
        self.check('''
            bags[0][1]=item(10, 3); recipe(1, 0, 10, 1)
            autoComplete=false; skillButton.OnClick()
            pevent("TRADE_SKILL_ITEM_CRAFTED_RESULT", {itemID=10001, quantity=1})
            ptick(10); assert(#crafts==1)
            casting="Recipe 1"; complete(1); ptick(10); assert(#crafts==1)
            casting=nil; complete(1); complete(1); ptick(10)
            assert(#crafts==1 and skillButton.text=="Smart Skill Up")
        ''')

    def test_unrelated_result_or_consumption_does_not_repeat(self):
        self.check('''
            bags[0][1]=item(10, 3); recipe(1, 0, 10, 1)
            autoComplete=false; suppressSuccess=true; skillButton.OnClick()
            pevent("TRADE_SKILL_ITEM_CRAFTED_RESULT", {itemID=9999, quantity=1})
            complete(1); ptick(20); assert(#crafts==1)
        ''')

    def test_duplicate_reagents_counted_together_and_zero_cost_excluded(self):
        self.check('''
            assert(A.BagCraftCount({[10]=3}, {[10]=7})==2)
            assert(A.BagCraftCount({}, {[10]=7})==0)
            bags[0][1]=item(10, 3); recipe(1, 0, 10, 2)
            local slots=schematics[1].reagentSlotSchematics
            slots[2]={reagentType=1, quantityRequired=2, dataSlotType=1, reagents={{itemID=10}}}
            skillButton.OnClick(); assert(#crafts==0)
        ''')

    def test_quality_capability_does_not_exclude_fixed_item_recipe(self):
        self.check('''
            bags[0][1]=item(10, 2); recipe(1, 0, 10, 1)
            recipes[1].name="Light Armor Kit"
            recipes[1].supportsQualities=true
            skillButton.OnClick()
            assert(#crafts==1 and crafts[1]==1 and batchQuantity==2)
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
