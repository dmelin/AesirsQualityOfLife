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


if __name__ == '__main__':
    unittest.main(verbosity=2)
