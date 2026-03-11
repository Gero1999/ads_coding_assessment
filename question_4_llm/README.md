# Question 4 — GenAI Clinical Data Assistant (LLM & LangChain)

## Objective

Develop a Generative AI Assistant that translates natural language questions into structured Pandas queries. The goal is to test your ability to use LLMs (e.g., OpenAI via LangChain) to dynamically map user intent to the correct dataset variable without hard-coding rules.

## Scenario

A clinical safety reviewer wants to ask free-text questions about the AE dataset. They don't know the column names. Your Agent must "understand" the dataset schema and route the question to the correct variable. For example:

- If they ask about "severity" or "intensity" → Map to `AESEV`
- If they ask about a specific condition (e.g., "Headache") → Map to `AETERM`
- If they ask about a body system (e.g., "Cardiac", "Skin") → Map to `AESOC`

## Input

- **File:** `ae.csv` (`pharmaversesdtm::ae`)
- **API Key:** You may use your own OpenAI API key or any other solution. If you do not have one, you may mock the LLM response in your code, but the logic flow (*Prompt → Parse → Execute*) must be complete.

## Requirements

### 1. Schema Definition

Understand the data and define a dictionary or string in your code describing the relevant columns (`AESEV`, `AETERM`, `AESOC`, etc.) to the LLM.

### 2. LLM Implementation

- Create a function or class `ClinicalTrialDataAgent`.
- Use an LLM to parse a user's question into a **Structured JSON Output** containing:
  - `target_column` — The column to filter.
  - `filter_value` — The value to search for (extracted from the question).

### 3. Execution

- Write a function that takes the LLM's output and applies the actual Pandas filter to the `ae` dataframe.
- Return the count of unique subjects (`USUBJID`) and a list of the matching IDs.

## Deliverables

| Deliverable | Path |
|-------------|------|
| Solution code | `question_4_llm/llm_agent.py` |
| Test script (3 example queries) | `question_4_llm/test_script.py` |

> **Example query:** *"Give me the subjects who had Adverse Events of Moderate severity."*
