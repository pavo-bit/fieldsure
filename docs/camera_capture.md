# Phase 3: Camera Capture & Evidence Foundation

## Overview
Phase 3 implements the foundational camera capture workflow for the FieldSure mobile application. This phase enables the operator to use the device's rear camera to securely capture an image of the presumptive field-test kit and its reference colour card. 

**IMPORTANT**: This phase provides the evidence-capture and image-quality foundation. It does not yet provide validated drug-result classification.

## Architecture
The camera workflow utilizes:
- `camera` package for hardware access and preview rendering.
- `permission_handler` to explicitly request and handle camera permissions.
- Riverpod for state management (linking camera screens to test workflow).
- GoRouter for declarative navigation.

## State Transitions
The test state machine expands in this phase:
1. `DRAFT`: The initial test record is created locally.
2. `CAPTURING` (implicit UI state): The operator is using the camera screen.
3. `CAPTURED`: The operator confirmed a captured image that passed quality checks.
4. `READY_FOR_PROCESSING` / `PENDING_SYNC`: The local evidence is saved and queued for backend synchronization.

## Image Lifecycle
1. **Initialization**: App requests permissions. If granted, initializes the rear camera.
2. **Preview**: The live camera feed is displayed with a custom capture overlay to guide alignment.
3. **Capture**: The raw image is saved to a temporary cache directory.
4. **Validation**: The image undergoes objective quality checks (resolution, decodability, brightness).
5. **Confirmation**: If acceptable, the user can review and confirm.
6. **Hashing**: The image bytes are hashed using deterministic SHA-256.
7. **Persistence**: The metadata, hash, and local file reference are written to the local SQLite database (Drift) in the `LocalEvidence` table.

## Limitations
- The current implementation validates capture mechanics and local storage. It does not synchronize the image payload to the backend via a multipart upload yet.
- The `ImageQualityResult` logic relies on placeholders for brightness, sharpness, and glare detection until the full CV pipeline is integrated.
- The `ImageHash` is currently generated client-side, but the backend will serve as the authoritative verifier of this hash in Phase 4.

## Future Work
- Implementing `POST /api/v1/tests/:id/images` for multipart evidence upload.
- Full Reference Card Detection and CV classification on the backend.
