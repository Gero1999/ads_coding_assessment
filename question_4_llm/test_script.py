"""Test script — runs 3 example queries against the ClinicalTrialDataAgent.

Usage:
    python question_4_llm/test_script.py
"""

from llm_agent import ClinicalTrialDataAgent, load_ae

# Load the AE dataset (uses local CSV if available, else downloads)
ae = load_ae()

# Instantiate the agent
agent = ClinicalTrialDataAgent(ae)

# ── Query 1: Severity ─────────────────────────────────────────────────────
q1 = "Give me the subjects who had adverse events of Moderate severity"
r1 = agent.ask(q1)

# ── Query 2: Specific condition ───────────────────────────────────────────
q2 = "Which patients experienced Headache?"
r2 = agent.ask(q2)

# ── Query 3: Body system ─────────────────────────────────────────────────
q3 = "Show me subjects with adverse events in the Cardiac body system"
r3 = agent.ask(q3)

# ── Summary ───────────────────────────────────────────────────────────────
print("\n" + "=" * 70)
print("  SUMMARY")
print("=" * 70)
for label, res in [("Moderate severity", r1),
                   ("Headache", r2),
                   ("Cardiac disorders", r3)]:
    print(f"  {label:25s} → {res['subject_count']} subjects")
print("=" * 70)
