import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
ROUTING_FILE = REPO_ROOT / "policy" / "task-routing-matrix.json"


class TaskRoutingMatrixTests(unittest.TestCase):
    def test_routing_matrix_has_expected_profiles_and_language_rule(self):
        data = json.loads(ROUTING_FILE.read_text(encoding="utf-8"))
        self.assertEqual("user_language", data["response_language"])
        self.assertEqual(
            ["repo_change", "repo_read", "content_task", "general"],
            data["profile_order"],
        )

        profiles = data["profiles"]
        self.assertEqual(
            {"repo_change", "repo_read", "content_task", "general"},
            set(profiles.keys()),
        )

    def test_commit_output_is_restricted_to_repo_change(self):
        data = json.loads(ROUTING_FILE.read_text(encoding="utf-8"))
        profiles = data["profiles"]

        self.assertTrue(profiles["repo_change"]["allow_commit_output"])
        self.assertFalse(profiles["repo_read"]["allow_commit_output"])
        self.assertFalse(profiles["content_task"]["allow_commit_output"])
        self.assertFalse(profiles["general"]["allow_commit_output"])

        required = data["commit_output_gate"]["required"]
        self.assertIn("tracked_repo_diff_exists", required)
        self.assertIn("verification_passed", required)
        self.assertIn("change_is_ready_to_commit", required)
