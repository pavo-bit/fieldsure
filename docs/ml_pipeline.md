# FieldSure ML Pipeline Architecture

The Computer Vision (CV) and Machine Learning (ML) pipeline for FieldSure is designed as a deterministic, modular sequence of stages. It is strictly configured to act as a companion to physical field-test kits, interpreting observed colour reactions without introducing unsupported AI capabilities.

## Architecture

The pipeline processes incoming images via the following logical steps:

1. **Image Validation**: Assesses the image for blur (Laplacian variance), brightness, and resolution constraints. Images failing quality thresholds are rejected as `INCONCLUSIVE` early in the process.
2. **Reference Card Detection**: Uses structural computer vision (e.g., ArUco markers or fixed contour ratios) to isolate the standard colour reference card in the image.
3. **Perspective Correction**: Computes a homography matrix from the reference card corners and warps the test kit region into a standardized flat perspective.
4. **Colour Calibration**: Extracts observed values from the reference card's known colour patches, creating a mapping to standardize lighting anomalies before reading the chemical test area.
5. **Test Region Extraction**: Slices the calibrated test window based on exact coordinate configurations tied to the specific test kit.
6. **Feature Extraction**: Extracts continuous numerical features from the calibrated pixels (e.g., L*a*b* means, HSV statistics, and perceptual colour distance).
7. **Classification**: Evaluates the features against a specific set of rules or a simple weighted model (e.g., Logistic Regression) to return `POSITIVE`, `NEGATIVE`, or `INCONCLUSIVE`.

## Configuration-Driven Execution

The entire pipeline is dynamically configured based on the `TestKit` definition. There are no hard-coded boundaries; the `TestRegion` x, y, width, and height—along with reference patch L*a*b* expectations—are injected from the configuration schema.

## Demo Status

Currently, the `DemoLogisticClassifier` is installed as a mock to simulate execution without generating fabricated accuracy metrics. A scientifically validated classification configuration is required for production usage.
