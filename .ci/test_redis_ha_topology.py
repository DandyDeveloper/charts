import copy
from pathlib import Path
import subprocess
import unittest

import yaml


CHART = Path(__file__).resolve().parents[1] / "charts" / "redis-ha"


class TopologySpreadConstraintsTest(unittest.TestCase):
    def render(self, enabled=True, **constraints):
        values = {
            "haproxy": {"enabled": True},
            "topologySpreadConstraints": constraints,
        }
        if enabled is not None:
            values["topologySpreadConstraints"]["enabled"] = enabled
        result = subprocess.run(
            [
                "helm", "template", "test", str(CHART), "--values", "-",
                "--show-only", "templates/redis-ha-statefulset.yaml",
                "--show-only", "templates/redis-haproxy-deployment.yaml",
            ],
            input=yaml.safe_dump(values),
            text=True,
            capture_output=True,
            check=True,
        )
        workloads = list(yaml.safe_load_all(result.stdout))
        self.assertEqual([w["kind"] for w in workloads], ["StatefulSet", "Deployment"])
        return workloads

    def test_constraints_disabled_by_default(self):
        for workload in self.render(enabled=None):
            with self.subTest(kind=workload["kind"]):
                self.assertNotIn("topologySpreadConstraints", workload["spec"]["template"]["spec"])

    def test_policy_omitted_by_default(self):
        for workload in self.render():
            with self.subTest(kind=workload["kind"]):
                constraint = workload["spec"]["template"]["spec"]["topologySpreadConstraints"][0]
                self.assertNotIn("nodeTaintsPolicy", constraint)
                self.assertEqual(constraint["maxSkew"], 1)
                self.assertEqual(constraint["topologyKey"], "topology.kubernetes.io/zone")
                self.assertEqual(constraint["whenUnsatisfiable"], "ScheduleAnyway")

    def test_empty_or_null_policy_preserves_defaults(self):
        baseline = self.render()
        for policy in ("", None):
            with self.subTest(policy=policy):
                self.assertEqual(self.render(nodeTaintsPolicy=policy), baseline)

    def test_explicit_policy_only_adds_requested_field(self):
        for enforcement in ("ScheduleAnyway", "DoNotSchedule"):
            baseline = self.render(whenUnsatisfiable=enforcement)
            for policy in ("Honor", "Ignore"):
                expected = copy.deepcopy(baseline)
                for workload in expected:
                    constraint = workload["spec"]["template"]["spec"]["topologySpreadConstraints"][0]
                    constraint["nodeTaintsPolicy"] = policy
                with self.subTest(enforcement=enforcement, policy=policy):
                    self.assertEqual(
                        self.render(whenUnsatisfiable=enforcement, nodeTaintsPolicy=policy),
                        expected,
                    )

    def test_disabled_constraints_remain_absent(self):
        for workload in self.render(enabled=False, nodeTaintsPolicy="Honor"):
            with self.subTest(kind=workload["kind"]):
                self.assertNotIn("topologySpreadConstraints", workload["spec"]["template"]["spec"])


if __name__ == "__main__":
    unittest.main()
