# SAS Trustworthy AI Examples

## Overview

This repository contains Python notebooks and SAS programs that demonstrate key principles of Trustworthy AI, including fairness, robustness, and explainability. The examples use publicly available datasets across multiple sectors such as financial services, education, healthcare, and the public sector.

## Prerequisites

The examples require access to the SAS® Viya® Workbench.

## Installation

Clone the examples repository into the root of your workspace:

```bash
git clone https://github.com/sassoftware/sas-trustworthy-ai-examples.git
```

## Examples

The repository is organized into the following folders:

- `data/` — Contains datasets for all 4 sectors

- `python/` — Contains Python-based Trustworthy AI example notebooks

- `sas/` — Contains equivalent SAS code examples

## Trustworthy AI Features Covered

### Fairness Accessment

- Assess bias using tools like Fairlearn and SAS Fair AI Toolset

- Calculate equal accuracy, equal opportunity, equalized odds, demographic parity, predictive parity

### Bias Mitigation

- Explore bias mitigation (pre-, in-, and post-processing techniques)

### Explainability & Interpretability

- Use SHAP, LIME, ICE, and SAS Explain Model action set

- Generate global and local explanations for predictions

### Robustness & Adversarial Testing

- Evaluate models under corrupted data (e.g., Gaussian noise, blur)

- Apply OOD and anomaly detection techniques

- Compare model resilience across clean vs corrupted inputs

## Datasets

Example datasets include:

- Adult Dataset

- Student Performance Dataset

- German Credit Data

- CDC Diabetes Health Indicators

[View Datasets Here](data/README.md)

## Contributing

Contributions are not currently accepted.

## License

This project is licensed under the Apache 2.0 License.


## Additional Resources

- [Fairlearn](https://fairlearn.org/)

- [SAS® Viya® Workbench GitHub](https://github.com/sassoftware/sas-viya-workbench-examples)

- [Trustworthy AI Blog Series](https://blogs.sas.com/content/tag/trustworthy-ai-toolkit/)
