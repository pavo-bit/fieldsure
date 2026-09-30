# Phase 3: Image Quality Validation

## Overview
As part of the evidence-capture foundation, FieldSure implements client-side image quality checks immediately after an image is captured. The goal is to prevent the submission of corrupted, completely unreadable, or excessively low-resolution images *before* attempting network synchronization or cloud ML processing.

**IMPORTANT**: Phase 3 provides the evidence-capture and image-quality foundation. It does not yet provide validated drug-result classification.

## Quality Checks Implemented
The current `ImageQualityService` validates objective engineering thresholds rather than arbitrary scientific/drug classification metrics.

1. **Existence**: Verifies the captured file exists on the local filesystem.
2. **Decodability**: Attempts to decode the image bytes to ensure the file is a valid, uncorrupted image format (JPEG).
3. **Resolution**: Verifies the image meets the minimum required dimensions (configurable, currently set to 1080x1080) for reliable downstream ML processing.
4. **Brightness & Exposure**: (Foundation laid, implementation pending) Will check average luminance to reject completely black or completely blown-out images.
5. **Sharpness**: (Foundation laid, implementation pending) Will use Laplacian variance to reject excessively blurred images where the reference card cannot be reliably read.

## Result Structure
The service returns an `ImageQualityResult` object containing:
- `isAcceptable` (bool): The aggregate pass/fail status.
- `resolutionOk` (bool)
- `brightnessOk` (bool)
- `sharpnessOk` (bool)
- `glareOk` (bool)
- `decodable` (bool)
- `warnings` (List<String>)
- `errors` (List<String>)

## Handling Failures
If `isAcceptable` is false, the `CameraPreviewScreen` displays the specific failure reasons (e.g., "Resolution too low") and disables the "Confirm Evidence" button. The operator must tap "Retake" and capture a new image.

## Limitations
- Brightness, sharpness, and glare detection are currently mocked as `true` pending the integration of OpenCV or native image processing pipelines.
- These thresholds do NOT classify the drug. They only determine if the image is technically suitable to be analyzed.
- Real-world forensic accuracy requires laboratory confirmation. FieldSure's output remains presumptive.
