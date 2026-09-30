# Evaluation Methodology

The FieldSure pipeline incorporates an `evaluator.py` module designed to systematically benchmark model versions against versioned `ValidationDataset` instances.

## Metrics

When a model is evaluated against a dataset, the system reports:
- **Accuracy**: General correct classification rate.
- **Inconclusive Rate**: The percentage of samples marked `INCONCLUSIVE` (a critical safety metric, as the system must gracefully reject ambiguous evidence).
- **Confusion Matrix**: Maps Ground Truth (Positive/Negative) against Predicted (Positive/Negative/Inconclusive).

## Safety First: The Inconclusive State

Inconclusive states are not failures; they are intentional safety mechanisms. The evaluation pipeline measures the system's ability to default to `INCONCLUSIVE` when:
- The image is too blurry.
- The lighting is outside calibration limits.
- The extracted feature vectors fall between established confidence boundaries.

By evaluating the confusion matrix directly, the development team can balance False Positives (dangerous presumptive charges) against the Inconclusive Rate (need for manual officer review).
