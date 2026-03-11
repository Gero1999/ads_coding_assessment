# ADS Coding Assessment

> A collection of completed clinical programming exercises mainly using pharmaverse tools.

## Questions

| # | Topic | Directory | Language |
|---|-------|-----------|----------|
| 1 | SDTM DS Domain Derivation | [`question_1_sdtm/`](question_1_sdtm/) | R |
| 2 | ADaM ADSL Dataset Creation | [`question_2_adam/`](question_2_adam/) | R |
| 3 | TLG Adverse Events Summary | [`question_3_tlg/`](question_3_tlg/) | R |
| 4 | GenAI Clinical Data Assistant | [`question_4_llm/`](question_4_llm/) | Python |

## Folder Structure

```text
ads_coding_assessment/
├── README.md                        # Repository overview and navigation
├── AGENT.md                         # Assessment/evaluation guidance
├── question_1_sdtm/
│   ├── README.md                    # Task and implementation summary
│   ├── 01_create_ds_domain.R        # SDTM DS derivation script
│   ├── log_generator.R              # Logging utility for script execution
│   ├── ds.csv / ds.rds              # DS output datasets
│   ├── 01_create_ds_domain.log      # Error-free run evidence
│   └── sdtm_ct.csv                  # Controlled terminology input
├── question_2_adam/
│   ├── README.md                    # Task and implementation summary
│   ├── create_adsl.R                # ADaM ADSL derivation script
│   ├── log_generator.R              # Logging utility for script execution
│   ├── adsl.csv / adsl.rds          # ADSL output datasets
│   └── create_adsl.log              # Error-free run evidence
├── question_3_tlg/
│   ├── README.md                    # Task and implementation summary
│   ├── 01_create_ae_summary_table.R # TEAE summary table script
│   ├── 02_create_visualizations.R   # AE visualization script
│   ├── log_generator.R              # Logging utility for script execution
│   ├── teaes.html                   # AE summary table output
│   ├── plot1.png / plot2.png        # Visualization outputs
│   └── *.log                        # Error-free run evidence
└── question_4_llm/
    ├── README.md                    # Task and implementation summary
    ├── llm_agent.py                 # ClinicalTrialDataAgent implementation
    ├── test_script.py               # Example query execution script
    └── ae.csv                       # AE input data
```
