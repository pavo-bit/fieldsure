# Dataset Architecture & Management

FieldSure strictly separates image classification from ground truth definitions to prevent data leakage and ensure scientifically rigorous evaluations.

## Structure

The dataset structure represents physical records mapped to metadata and ground truth labels:
- `image_id`: Reference to the S3 stored capture.
- `kit_id`: The ID of the test kit being used.
- `ground_truth`: The scientifically confirmed label (e.g., from GC/MS laboratory verification), which is `POSITIVE` or `NEGATIVE`.
- `metadata`: Surrounding context including capture device type, lighting condition string, setup notes, and timestamps.
- `test_batch`: Grouping variable to ensure that multiple photographs of the same physical sample do not leak across Train/Validation splits.

## Principles

1. **No Predicted Labels**: The system never uses predictions as ground truth for training or evaluation.
2. **Explicit Splits**: Training sets must be grouped by physical `test_batch` to ensure a model does not overfit to a specific physical cartridge photographed multiple times.
3. **Demo Limitations**: A small stub `DEMO_KIT` configuration exists for software validation, but no training process will occur until a physically validated dataset is supplied.
