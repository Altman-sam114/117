import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location(
    "ci_simulator", pathlib.Path(__file__).resolve().parents[1] / "ci_simulator.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-18-5"


def device(number=1, name="iPhone 16", state="Shutdown", available=True):
    return {"udid": f"00000000-0000-0000-0000-{number:012d}", "name": name,
            "state": state, "isAvailable": available}


class SimulatorSelectionTests(unittest.TestCase):
    def select(self, devices, **others):
        return module.select_device({"devices": {RUNTIME: devices, **others}}, RUNTIME)

    def test_selects_pinned_runtime_instead_of_newest(self):
        result = self.select([device()], **{"iOS-26-2": [device(2, state="Booted")]})
        self.assertEqual(result["udid"], device()["udid"])
        self.assertEqual(result["runtime"], RUNTIME)

    def test_reuses_booted_iphone_in_same_runtime(self):
        self.assertEqual(self.select([device(), device(2, "iPhone 16 Pro", "Booted")])["udid"],
                         device(2)["udid"])

    def test_prefers_exact_iphone_16_for_cold_boot(self):
        self.assertEqual(self.select([device(2, "iPhone 16 Pro"), device()])["udid"], device()["udid"])

    def test_excludes_unavailable_and_non_iphone(self):
        self.assertEqual(self.select([device(2, available=False), device(3, "iPad Pro"), device()])["udid"],
                         device()["udid"])

    def test_rejects_missing_runtime_and_does_not_fallback(self):
        with self.assertRaisesRegex(ValueError, "no runtime fallback"):
            self.select([], **{"iOS-26-2": [device()]})

    def test_rejects_malformed_udid(self):
        invalid = device()
        invalid["udid"] = "not-a-device"
        with self.assertRaises(ValueError):
            self.select([invalid])

    def test_selection_is_stable_across_inventory_order(self):
        devices = [device(2, "iPhone 16 Pro"), device(1, "iPhone 16 Pro")]
        self.assertEqual(self.select(devices), self.select(list(reversed(devices))))

    def test_destination_uses_the_reported_udid(self):
        result = self.select([device()])
        self.assertEqual(result["destination"], f"platform=iOS Simulator,id={result['udid']}")


if __name__ == "__main__":
    unittest.main()
