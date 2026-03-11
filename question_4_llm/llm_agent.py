"""GenAI Clinical Data Assistant (LLM & LangChain-style agent).

Translates free-text safety-reviewer questions into structured Pandas
queries on the SDTM AE (Adverse Events) dataset.  Uses a local Ollama
Llama 3.2-1B model — no API key required.

Pipeline:  User Question  →  LLM Prompt  →  Structured JSON  →  Pandas Filter

Usage:
    python question_4_llm/test_script.py        # runs 3 demo queries
    # or import and use interactively:
    from llm_agent import ClinicalTrialDataAgent, load_ae
    ae = load_ae()
    agent = ClinicalTrialDataAgent(ae)
    result = agent.ask("subjects with moderate severity")

Input:  pharmaversesdtm AE CSV (local file preferred, downloaded on first use).
Output: For each query — count of unique subjects + list of USUBJIDs.
"""

import pandas as pd
import json
import requests
import re
from pathlib import Path
from typing import Dict

# ============================================================================
# 1. LOAD DATA
# ============================================================================
AE_SOURCE_URL = "https://raw.githubusercontent.com/pharmaverse/pharmaversesdtm/refs/heads/main/inst/extdata/ae.csv"
AE_LOCAL_PATH = Path(__file__).resolve().parent / "ae.csv"


def load_ae(
    path: Path = AE_LOCAL_PATH, url: str = AE_SOURCE_URL
) -> pd.DataFrame:
    """Load the AE dataset, preferring an existing local CSV.

    If the local file does not exist, download it from the given URL,
    save it to *path*, and then load it.
    """
    if path.is_file():
        return pd.read_csv(path)

    resp = requests.get(url, timeout=60)
    resp.raise_for_status()

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(resp.content)

    return pd.read_csv(path)

# ============================================================================
# 2. SCHEMA DEFINITION
# ============================================================================
# Maps each relevant AE column to a plain-English description.
# This dictionary is injected into every LLM prompt so the model can
# correctly route a free-text question to the right column.
AE_SCHEMA = {
    "USUBJID": "Unique subject identifier for each patient in the trial.",
    "AETERM": "Reported term for the adverse event (e.g., HEADACHE, DIARRHOEA, ERYTHEMA).",
    "AEDECOD": "Dictionary-derived (standardised/preferred) term for the adverse event.",
    "AEBODSYS": "Body system or organ class associated with the event (e.g., CARDIAC DISORDERS, GASTROINTESTINAL DISORDERS, SKIN AND SUBCUTANEOUS TISSUE DISORDERS).",
    "AESOC": "System Organ Class for the adverse event. Generally identical to AEBODSYS.",
    "AESEV": "Severity or intensity of the adverse event: MILD, MODERATE, or SEVERE.",
    "AESER": "Serious adverse event flag: Y (yes) or N (no).",
    "AEREL": "Causality / relationship of the event to the study drug: NONE, REMOTE, POSSIBLE, PROBABLE.",
    "AEACN": "Action taken with study treatment due to the adverse event.",
    "AEOUT": "Outcome of the adverse event (e.g., RECOVERED/RESOLVED, NOT RECOVERED/NOT RESOLVED).",
    "AESTDTC": "Start date/time of the adverse event (ISO 8601).",
    "AEENDTC": "End date/time of the adverse event (ISO 8601).",
    "AESTDY": "Study day of the adverse event start (numeric).",
    "AEENDY": "Study day of the adverse event end (numeric).",
}

SCHEMA_PROMPT = "\n".join(
    f"  - {col}: {desc}" for col, desc in AE_SCHEMA.items()
)

# ============================================================================
# 3. LOCAL LLM VIA OLLAMA (llama3.2:1b – no API key needed)
# ============================================================================
OLLAMA_URL = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "llama3.2:1b"


def call_ollama(prompt: str, temperature: float = 0.0) -> str:
    """Send a prompt to the local Ollama model and return the generated text.

    Args:
        prompt:      The full prompt string to send.
        temperature: Sampling temperature (0 = deterministic).

    Returns:
        The model's text response.

    Raises:
        RuntimeError: If the Ollama server is not reachable.
    """
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": temperature},
    }
    try:
        resp = requests.post(OLLAMA_URL, json=payload, timeout=120)
        resp.raise_for_status()
        return resp.json().get("response", "")
    except requests.exceptions.ConnectionError:
        raise RuntimeError(
            "Ollama is not running. Start it with: ollama serve"
        )
    except requests.exceptions.RequestException as exc:
        raise RuntimeError(
            f"Ollama request failed: {exc}"
        ) from exc
    except (ValueError, KeyError) as exc:
        raise RuntimeError(
            f"Unexpected Ollama response: {exc}"
        ) from exc


# ============================================================================
# 4. ClinicalTrialDataAgent
# ============================================================================
class ClinicalTrialDataAgent:
    """
    GenAI Clinical Data Assistant that translates natural-language questions
    into structured Pandas queries on the AE (Adverse Events) dataset.

    Pipeline:  User Question  →  LLM Prompt  →  Structured JSON  →  Pandas Filter
    """

    def __init__(self, df: pd.DataFrame):
        """Initialise the agent with an AE dataframe.

        Args:
            df: A pandas DataFrame containing SDTM AE-domain columns.
        """
        self.df = df
        # Build a quick reference of unique values per column (truncated)
        self._value_hints = self._build_value_hints()

    # --------------------------------------------------------------------- #
    # Internal helpers
    # --------------------------------------------------------------------- #
    def _build_value_hints(self) -> str:
        """Return a compact summary of unique values for key columns.

        Categorical columns (AESEV, AESER, …) show all values;
        high-cardinality columns (AETERM, AEBODSYS, …) show up to 15.
        """
        hints = []
        for col in ["AESEV", "AESER", "AEREL", "AEOUT"]:
            if col in self.df.columns:
                vals = self.df[col].dropna().unique().tolist()
                hints.append(f"  {col}: {vals}")
        for col in ["AETERM", "AEDECOD", "AEBODSYS", "AESOC"]:
            if col in self.df.columns:
                vals = sorted(self.df[col].dropna().unique().tolist())[:15]
                hints.append(f"  {col} (sample): {vals}")
        return "\n".join(hints)

    def _build_prompt(self, question: str) -> str:
        """Build a few-shot prompt that instructs the LLM to return JSON.

        The prompt includes:
          - Column descriptions (AE_SCHEMA)
          - Sample data values (_value_hints)
          - Six worked Q→A examples
          - Explicit mapping rules
        """
        return f"""You are a clinical-data JSON mapper. Convert the question into JSON.

Columns:
{SCHEMA_PROMPT}

Sample values:
{self._value_hints}

EXAMPLES:
Q: "subjects with moderate severity"
A: {{"target_column": "AESEV", "filter_value": "MODERATE"}}

Q: "patients who had headache"
A: {{"target_column": "AETERM", "filter_value": "HEADACHE"}}

Q: "adverse events in the cardiac body system"
A: {{"target_column": "AESOC", "filter_value": "CARDIAC DISORDERS"}}

Q: "serious adverse events"
A: {{"target_column": "AESER", "filter_value": "Y"}}

Q: "events probably related to drug"
A: {{"target_column": "AEREL", "filter_value": "PROBABLE"}}

Q: "events that resolved"
A: {{"target_column": "AEOUT", "filter_value": "RECOVERED/RESOLVED"}}

RULES:
- Return ONLY the JSON object. No extra text.
- target_column must be one of: {list(AE_SCHEMA.keys())}
- filter_value must be UPPER CASE.
- severity/intensity → AESEV (values: MILD, MODERATE, SEVERE)
- specific condition → AETERM
- body system/organ class → AESOC
- seriousness → AESER (Y or N)
- relationship/causality → AEREL
- outcome → AEOUT

Q: "{question}"
A:"""

    @staticmethod
    def _parse_llm_json(raw: str) -> Dict[str, str]:
        """Extract {target_column, filter_value} from raw LLM text.

        Handles markdown fences, single quotes, trailing commas,
        and falls back to regex extraction when JSON parsing fails.
        """
        raw = raw.strip()
        # Remove possible markdown fences
        raw = re.sub(r"```json\s*", "", raw)
        raw = re.sub(r"```", "", raw)
        # Find first { ... } – greedy to catch nested quotes
        match = re.search(r"\{[^}]+\}", raw, re.DOTALL)
        if match:
            candidate = match.group()
            # Fix common LLM issues: single quotes → double quotes
            candidate = candidate.replace("'", '"')
            # Remove trailing commas before }
            candidate = re.sub(r",\s*}", "}", candidate)
            try:
                return json.loads(candidate)
            except json.JSONDecodeError:
                pass

        # Fallback: extract key-value pairs with regex
        col_match = re.search(
            r"target_column[\"']?\s*[:=]\s*[\"']([A-Z]+)[\"']", raw
        )
        val_match = re.search(
            r"filter_value[\"']?\s*[:=]\s*[\"']([^\"']+)[\"']", raw
        )
        if col_match and val_match:
            return {
                "target_column": col_match.group(1),
                "filter_value": val_match.group(1),
            }

        raise ValueError(f"Could not parse JSON from LLM response:\n{raw}")

    # --------------------------------------------------------------------- #
    # Public API
    # --------------------------------------------------------------------- #
    def parse_question(self, question: str) -> Dict[str, str]:
        """Convert a natural-language question to structured filter params.

        Sends the question to the LLM and parses the JSON response.
        Retries up to 3 times (with increasing temperature) on failure.

        Args:
            question: Free-text question from the clinical reviewer.

        Returns:
            Dict with keys ``target_column`` and ``filter_value``.

        Raises:
            ValueError: If all attempts fail to produce valid JSON.
        """
        prompt = self._build_prompt(question)
        last_error = None
        for attempt in range(3):
            raw_response = call_ollama(prompt, temperature=0.0 + attempt * 0.1)
            try:
                parsed = self._parse_llm_json(raw_response)
                # Validate keys
                if "target_column" not in parsed or "filter_value" not in parsed:
                    raise ValueError(
                        f"LLM response missing required keys: {parsed}"
                    )
                # Validate column exists in schema
                if parsed["target_column"] not in AE_SCHEMA:
                    raise ValueError(
                        f"Unknown column: {parsed['target_column']}"
                    )
                return parsed
            except (ValueError, json.JSONDecodeError) as e:
                last_error = e
                continue
        raise ValueError(
            f"Failed to parse LLM response after 3 attempts. Last error: {last_error}"
        )

    def execute_query(self, parsed: Dict[str, str]) -> Dict:
        """Apply the parsed filter to the AE dataframe.

        Uses case-insensitive partial matching so that, e.g.,
        filter_value="CARDIAC" matches "CARDIAC DISORDERS".

        Args:
            parsed: Dict with ``target_column`` and ``filter_value``.

        Returns:
            Dict with keys: target_column, filter_value,
            subject_count, subject_ids (sorted list of USUBJIDs).
        """
        col = parsed["target_column"]
        val = str(parsed["filter_value"]).upper()

        if col not in self.df.columns:
            return {
                "error": f"Column '{col}' not found in dataset.",
                "subject_count": 0,
                "subject_ids": [],
            }

        # Case-insensitive partial match for text columns; use nullable string
        # dtype to avoid NaN → "nan" false positives
        mask = (
            self.df[col]
            .astype("string")
            .str.upper()
            .str.contains(val, na=False)
        )
        filtered = self.df.loc[mask]

        unique_subjects = sorted(filtered["USUBJID"].unique().tolist())
        return {
            "target_column": col,
            "filter_value": val,
            "subject_count": len(unique_subjects),
            "subject_ids": unique_subjects,
        }

    def ask(self, question: str) -> Dict:
        """End-to-end: parse a question with the LLM and execute the query.

        Prints a formatted summary to stdout and returns the result dict.
        """
        print(f"\n{'='*70}")
        print(f"  QUESTION: {question}")
        print(f"{'='*70}")

        # Step 1 – LLM parses question into structured JSON
        parsed = self.parse_question(question)
        print(f"  LLM Output  → target_column: {parsed['target_column']}, "
              f"filter_value: {parsed['filter_value']}")

        # Step 2 – Execute Pandas filter
        result = self.execute_query(parsed)
        print(f"  Result      → {result['subject_count']} unique subject(s)")
        if result["subject_count"] > 0:
            print(f"  Subject IDs → {result['subject_ids']}")
        print(f"{'='*70}\n")
        return result


# ============================================================================
# 5. DEMO (run via test_script.py for the full test suite)
# ============================================================================
if __name__ == "__main__":
    ae = load_ae()
    agent = ClinicalTrialDataAgent(ae)
    result = agent.ask("Give me the subjects who had adverse events of Moderate severity")
    print(result)
