"""Tests for home/dot_local/bin/executable_claude-usage. Run: python3 -m unittest discover tests"""
import csv
import importlib.machinery
import importlib.util
import json
import os
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

SCRIPT = Path(__file__).resolve().parent.parent / "home/dot_local/bin/executable_claude-usage"
loader = importlib.machinery.SourceFileLoader("claude_usage", str(SCRIPT))
spec = importlib.util.spec_from_loader("claude_usage", loader)
cu = importlib.util.module_from_spec(spec)
loader.exec_module(cu)

TZ = ZoneInfo("America/New_York")


def assistant(ts, *, session="s1", cwd="/home/u/code/acme/shop", model="claude-opus-5-5",
              msg_id="m1", req="r1", inp=10, out=100, cw5=0, cw1=0, read=0, block=0):
    return {
        "type": "assistant", "timestamp": ts, "sessionId": session, "cwd": cwd,
        "requestId": req, "apiBlockIndex": block, "uuid": f"{req}-{block}",
        "message": {"id": msg_id, "model": model, "content": [{"type": "text", "text": "secret"}],
                    "usage": {"input_tokens": inp, "output_tokens": out,
                              "cache_creation_input_tokens": cw5 + cw1, "cache_read_input_tokens": read,
                              "cache_creation": {"ephemeral_5m_input_tokens": cw5,
                                                 "ephemeral_1h_input_tokens": cw1},
                              "service_tier": "standard", "inference_geo": "global"}},
    }


def limit_hit(ts, *, session="s1", cwd="/home/u/code/acme/shop", req="rl", kind="five_hour",
              resets=1793228400):
    return {
        "type": "assistant", "timestamp": ts, "sessionId": session, "cwd": cwd, "requestId": req,
        "error": "rate_limit", "isApiErrorMessage": True, "apiError": "usage_limit_reached",
        "quotaLimits": {"status": "rejected", "rateLimitType": kind, "resetsAt": resets},
        "message": {"id": "x" + req, "model": "<synthetic>",
                    "content": [{"type": "text", "text": "You've hit your session limit"}],
                    "usage": {"input_tokens": 0, "output_tokens": 0}},
    }


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.home = root / "home/u"
        self.code = self.home / "code"
        (self.code / "acme/shop/.git").mkdir(parents=True)
        (self.code / "notes/.git").mkdir(parents=True)
        self.projects = root / "projects"
        self.out = root / "out"
        self.out.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def log(self, name, entries):
        path = self.projects / name
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "a") as f:
            for e in entries:
                # Entries name /home/u; the fixture's home is a temporary folder.
                e = {**e, "cwd": e["cwd"].replace("/home/u", str(self.home), 1)}
                f.write(json.dumps(e) + "\n")

    def run_update(self, now):
        return cu.update(self.projects, self.out, code_root=self.code, home=self.home,
                         now=datetime.fromisoformat(now).replace(tzinfo=TZ), tz=TZ)

    def rows(self, name):
        with open(self.out / "usage" / name) as f:
            return list(csv.DictReader(f))


class DailyRows(Fixture):
    def test_one_row_per_day_project_and_model_counting_each_request_once(self):
        # One request logged as three content blocks, plus a second request in another session.
        self.log("p/s1.jsonl", [assistant("2026-11-03T15:00:00Z", block=b) for b in range(3)])
        self.log("p/s2.jsonl", [assistant("2026-11-03T16:00:00Z", session="s2", msg_id="m2",
                                          req="r2", inp=5, out=50, read=1000)])
        self.run_update("2026-11-05T03:00:00")
        rows = self.rows("2026-11.csv")
        self.assertEqual(len(rows), 1)
        r = rows[0]
        self.assertEqual((r["date"], r["project"], r["model"]), ("2026-11-03", "acme/shop", "claude-opus-5-5"))
        self.assertEqual((r["sessions"], r["requests"]), ("2", "2"))
        self.assertEqual((r["input"], r["output"], r["cache_read"]), ("15", "150", "1000"))


class Windows(Fixture):
    def test_a_window_opens_on_the_hour_of_its_first_request_and_lasts_five_hours(self):
        # Local (EST, UTC-5): 10:20 and 14:50 share the 10:00 window; 15:10 opens a 15:00 one.
        self.log("p/s1.jsonl", [
            assistant("2026-11-03T15:20:00Z", req="a", msg_id="a", out=100),
            assistant("2026-11-03T19:50:00Z", req="b", msg_id="b", out=200, model="claude-sonnet-5-5"),
            assistant("2026-11-03T20:10:00Z", req="c", msg_id="c", out=300),
        ])
        self.run_update("2026-11-05T03:00:00")
        got = [(r["window_start"], r["model"], r["output"]) for r in self.rows("2026-11-windows.csv")]
        self.assertEqual(got, [
            ("2026-11-03T10:00-05:00", "claude-opus-5-5", "100"),
            ("2026-11-03T10:00-05:00", "claude-sonnet-5-5", "200"),
            ("2026-11-03T15:00-05:00", "claude-opus-5-5", "300"),
        ])

    def test_limit_hits_one_row_per_limit_with_the_model_in_use(self):
        self.log("p/s1.jsonl", [
            assistant("2026-11-03T15:20:00Z", model="claude-fable-5-1"),
            limit_hit("2026-11-03T16:00:00Z", req="x1"),
            limit_hit("2026-11-03T16:00:05Z", req="x2"),
        ])
        self.run_update("2026-11-05T03:00:00")
        limits = self.rows("2026-11-limits.csv")
        self.assertEqual(len(limits), 1)
        l = limits[0]
        self.assertEqual((l["time"], l["limit"], l["resets_at"], l["model"], l["project"], l["rejected_requests"]),
                         ("2026-11-03T11:00-05:00", "five_hour", "2026-10-28T19:00-04:00",
                          "claude-fable-5-1", "acme/shop", "2"))
        windows = self.rows("2026-11-windows.csv")
        self.assertEqual(windows[0]["limit_hit"], "five_hour")

    def test_api_throttling_is_not_a_plan_limit(self):
        throttled = limit_hit("2026-11-03T16:00:00Z")
        del throttled["apiError"], throttled["quotaLimits"]
        self.log("p/s1.jsonl", [assistant("2026-11-03T15:20:00Z"), throttled])
        self.run_update("2026-11-05T03:00:00")
        self.assertFalse((self.out / "usage/2026-11-limits.csv").exists())


class Merging(Fixture):
    def seed(self, name, header, *rows):
        path = self.out / "usage" / name
        path.parent.mkdir(exist_ok=True)
        path.write_text(header + "\n" + "".join(r + "\n" for r in rows))

    HEADER = "date,project,model,sessions,requests,input,output,cache_write_5m,cache_write_1h,cache_read,web_searches,cost_usd"

    def test_recorded_days_outlive_their_logs_and_older_days_are_not_rewritten(self):
        self.seed("2026-10.csv", self.HEADER,
                  "2026-10-01,acme/shop,claude-opus-5-5,1,99,0,0,0,0,0,0,1.0000",   # logs since deleted
                  "2026-10-20,acme/shop,claude-opus-5-5,1,5,0,0,0,0,0,0,1.0000",    # logs partly deleted
                  "2026-10-31,acme/shop,claude-opus-5-5,1,5,0,0,0,0,0,0,1.0000")    # recent: recount
        self.log("p/s1.jsonl", [
            assistant("2026-10-20T15:00:00Z", req="a", msg_id="a"),
            assistant("2026-10-31T15:00:00Z", req="b", msg_id="b"),
        ])
        self.run_update("2026-11-05T03:00:00")
        got = [(r["date"], r["requests"]) for r in self.rows("2026-10.csv")]
        self.assertEqual(got, [("2026-10-01", "99"), ("2026-10-20", "5"), ("2026-10-31", "1")])

    def test_today_and_open_windows_wait_for_the_next_run(self):
        self.log("p/s1.jsonl", [
            assistant("2026-11-04T15:00:00Z", req="a", msg_id="a"),
            assistant("2026-11-05T07:30:00Z", req="b", msg_id="b"),  # 02:30 local on the run's day
        ])
        self.run_update("2026-11-05T03:00:00")
        self.assertEqual([r["date"] for r in self.rows("2026-11.csv")], ["2026-11-04"])
        self.assertEqual([r["window_start"] for r in self.rows("2026-11-windows.csv")],
                         ["2026-11-04T10:00-05:00"])


class Summary(Fixture):
    def test_weeks_peak_window_limit_hits_and_model_mix(self):
        M = 1_000_000
        self.log("p/s1.jsonl", [
            # Tue 3 Nov, 10:00 local window: $20 of Opus.
            assistant("2026-11-03T15:00:00Z", req="a", msg_id="a", inp=0, out=M),
            limit_hit("2026-11-03T16:00:00Z", req="x"),
            # Wed 4 Nov, 09:00 local window: $10 of Sonnet.
            assistant("2026-11-04T14:00:00Z", req="b", msg_id="b", inp=0, out=M, model="claude-sonnet-5-5"),
            # Mon 9 Nov: the next week.
            assistant("2026-11-09T14:00:00Z", req="c", msg_id="c", inp=0, out=M // 2),
        ])
        self.run_update("2026-11-12T03:00:00")
        text = (self.out / "usage/2026-11-summary.md").read_text()
        lines = text.splitlines()
        week1 = next(l for l in lines if l.startswith("| 2026-11-02 "))
        week2 = next(l for l in lines if l.startswith("| 2026-11-09 "))
        self.assertIn("$30.00", week1)
        self.assertIn("2026-11-03 10:00", week1)
        self.assertIn("$20.00", week1)
        self.assertTrue(week1.rstrip(" |").endswith("1"), week1)  # limit hits
        self.assertIn("$10.00", week2)
        opus = next(l for l in lines if l.startswith("| claude-opus-5-5 "))
        self.assertIn("$30.00", opus)
        self.assertIn("75%", opus)
        self.assertIn("2026-11-03 11:00", text)  # the limit hit's time
        self.assertNotIn("secret", text)


def req(model="claude-opus-5-5", **tokens):
    fields = {k: 0 for k in ["input", "output", "cache_write_5m", "cache_write_1h", "cache_read"]}
    fields.update(tokens)
    extra = {k: fields.pop(k) for k in ["web_searches", "speed", "geo"] if k in fields}
    return cu.Request(time=datetime(2026, 11, 3, tzinfo=TZ), session="s", cwd="p", model=model,
                      **fields, **extra)


class Cost(unittest.TestCase):
    M = 1_000_000

    def test_opus_5_5_published_rates(self):
        # $4 in, $5 5m write, $8 1h write, $0.20 cache hit, $20 out, per million tokens.
        cost = cu.request_cost(req(input=self.M, cache_write_5m=self.M, cache_write_1h=self.M,
                                   cache_read=self.M, output=self.M))
        self.assertAlmostEqual(cost, 4 + 5 + 8 + 0.20 + 20)

    def test_haiku_5_5_long_prompt_rate(self):
        # Prompts over 100,000 tokens (cache included) pay $0.50 in rather than $0.10.
        self.assertAlmostEqual(cu.request_cost(req("claude-haiku-5-5", input=90_000)), 0.009)
        self.assertAlmostEqual(cu.request_cost(req("claude-haiku-5-5", input=50_000, cache_read=60_000)),
                               50_000 * 0.50 / self.M + 60_000 * 0.05 / self.M)

    def test_us_inference_and_web_search(self):
        self.assertAlmostEqual(cu.request_cost(req("claude-sonnet-5-5", output=self.M, geo="us")), 11.0)
        self.assertAlmostEqual(cu.request_cost(req(web_searches=3)), 0.03)

    def test_fast_mode(self):
        self.assertAlmostEqual(cu.request_cost(req(input=self.M, output=self.M, speed="fast")), 48)

    def test_unknown_model_has_no_price(self):
        self.assertIsNone(cu.request_cost(req("claude-new-9", input=5)))
        # A newer version of a priced family is not priced as the older one.
        self.assertIsNone(cu.request_cost(req("claude-sonnet-5-6", input=5)))

    def test_dated_model_ids_take_their_family_price(self):
        self.assertAlmostEqual(cu.request_cost(req("claude-haiku-4-5-20251001", output=self.M)), 5)


class ProjectNames(Fixture):
    def name(self, cwd):
        return cu.project_name(cwd, self.code, self.home)

    def test_repo_under_an_owner_folder(self):
        self.assertEqual(self.name(f"{self.code}/acme/shop/src/lib"), "acme/shop")

    def test_repo_directly_under_code(self):
        self.assertEqual(self.name(f"{self.code}/notes/specs"), "notes")

    def test_worktrees_fold_into_their_repo(self):
        (self.code / "acme/shop.fix-cart").mkdir()
        self.assertEqual(self.name(f"{self.code}/acme/shop/.claude/worktrees/fix-cart/src"), "acme/shop")
        self.assertEqual(self.name(f"{self.code}/acme/shop.fix-cart"), "acme/shop")

    def test_dotted_repo_name_without_a_sibling_is_kept(self):
        (self.code / "acme/site.example.com/.git").mkdir(parents=True)
        self.assertEqual(self.name(f"{self.code}/acme/site.example.com"), "acme/site.example.com")

    def test_outside_code(self):
        self.assertEqual(self.name(str(self.home)), "~")
        self.assertEqual(self.name(f"{self.code}"), "~/code")
        self.assertEqual(self.name(f"{self.home}/scratch/x"), "~/scratch")
        self.assertEqual(self.name("/tmp/build"), "other")


if __name__ == "__main__":
    unittest.main()
