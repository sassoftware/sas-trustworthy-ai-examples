# SAS Trustworthy AI Examples

## Overview

This repository contains Python notebooks and SAS programs that demonstrate key principles of Trustworthy AI, including fairness, robustness, and explainability. The examples use publicly available datasets across multiple sectors such as financial services, education, healthcare, and the public sector.

## Prerequisites

The examples require access to the SAS® Viya® Workbench.

## Installation

Clone the examples repository into the root of your workspace:

```bash
git clone https://github.com/sassoftware/sas-trustworthy-ai-examples.git
cd sas-trustworthy-ai-examples
```

### Python Environment Setup

1. **Create a Virtual Environment**

```bash
python -m venv venv
```

2. **Activate the Virtual Environment**

On macOS/Linux:

```bash
source venv/bin/activate
```

On Windows:

```bash
venv\Scripts\activate
```

3. **Install Required Python Packages**

```bash
pip install -r requirements.txt
```

4. **Run Examples**

Navigate to the `python/` directory and open a notebook or script.

## Examples

The repository is organized into the following folders:

- `data/` — Contains datasets for all 4 
- `python/` — Contains Python-based Trustworthy AI example 
- `sas/` — Contains equivalent SAS code examples

## Trustworthy AI Examples Covered

### Healthcare

- Enhancing Diabetes Risk Predictions with Adaptive Imputation and Monte Carlo Dropout

- Explaining Diabetes Risk Predictions with SHAP and XGBoost

- Improving Heart Disease Risk Predictions with Domain-Adversarial Neural Networks and Ensemble Optimization

- Interpreting Heart Disease Diagnosis with LIME and SVM

- Mitigating Income Bias in Access to Diabetes Screening

- Mitigating Sex Bias in Heart Disease Diagnosis

### Finance

- Mitigating Age Bias in Credit Scoring

- Strengthening Loan Amount Estimation with Adversarial Training and Conformal Prediction

- Visualizing Loan Amount Predictions via PDP and ICE

### Education

- Adapting Student Performance Predictions with Drift Detection and Adaptive BatchNorm

- Distilling Student Dropout Rules with Surrogate Tree

- Mitigating International Status Bias in Scholarship Allocation

### Public/Government

- Mitigating Racial Bias in Employment Service Allocation

- Safeguarding Income Classification with Noise Correction

- Uncovering Income Prediction Logic with RuleFit

## Datasets

Example datasets include:

- Adult Dataset
- CDC Diabetes Health Indicators
- German Credit Data
- Heart Disease Dataset
- Student Performance Dataset

[View all datasets](data/README.md)

## Contributing

Maintainers are not currently accepting contributions to this project.

## License

This project is licensed under the Apache 2.0 License. See [LICENSE](LICENSE) for details.

## Additional Resources

- [Fairlearn](https://fairlearn.org/) - [SAS® Trustworthy AI Life
  Cycle](https://github.com/sassoftware/sas-trustworthy-ai-life-cycle) - [Trustworthy AI Blog
  Series](https://blogs.sas.com/content/tag/trustworthy-ai-toolkit/) - [SAS® Viya® Workbench
  Examples](https://github.com/sassoftware/sas-viya-workbench-examples)
