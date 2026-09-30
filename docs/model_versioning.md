# Model Versioning in FieldSure

Reproducibility and auditability are foundational to the FieldSure architecture. Every classification event logs precise version identifiers linking the result back to the algorithms and configurations used.

## Tracked Attributes

Every `Classification` record stores the following versions:
1. `algorithmVersion`: The code logic used for extraction and classification (e.g., `logistic-regression-v1.0`).
2. `modelVersion`: The specific weights, thresholds, or trained artifacts used (e.g., `demo-weights-v1`).
3. `configurationVersion`: The structural definition of the test kit, including ROI coordinates and expected reference card colours (e.g., `marq-v2.1`).

## Rationale

If a presumptive positive result is questioned months after the fact, the system guarantees the ability to reconstruct exactly how the features were extracted and classified. Any update to the feature logic requires an `algorithmVersion` bump, while any retrained weights require a `modelVersion` bump.

Mobile clients do not perform inference locally. The NestJS API acts as the central orchestrator, persisting these metadata fields directly from the ML Service output into the Prisma database alongside the `Test` record.
