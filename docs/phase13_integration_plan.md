# Phase 13 Integration Plan

## Current Architecture
The FieldSure architecture comprises:
1. **Flutter Mobile Application:** Handles local camera capture, offline SQLite storage (`drift`), and UI state management (`riverpod`).
2. **NestJS API:** The authoritative backend (`PostgreSQL`, `Prisma`), enforcing JWT authentication, Evidence canonicalization, and cryptographic signing.
3. **Python ML Service:** A FastAPI microservice executing CV/ML tasks (Image Quality, OpenCV geometric warping, Feature Extraction, and Demo Classification via `DEMO-CONFIG-v1`).

## Current Working Features
- End-to-End Demo Capture Flow (Draft -> Uploading -> Processing -> Completed)
- Offline Resilience (SQLite queue and idempotent SyncService)
- Cryptographic Evidence Verification (Server-side hash chain and signing)
- Image Quality gating (Blur and Brightness checks)
- Paginated History and Search
- SIH Demonstration Data (`seed-demo.ps1` and tamper scripts)

## Known Risks & Integration Checkpoints
- **Scientific Validation Limit:** The current system uses a simulated configuration pipeline (`DEMO-CONFIG-v1`). Judges must explicitly be made aware this is not a scientifically trained model yet.
- **Offline Network Transitions:** The demonstration requires a smooth transition out of Airplane mode. Network flakiness on the presentation floor should be mitigated by prioritizing the local-first architecture.
- **Physical Camera Variables:** Glare on the reference card during the live demo. The app must trap this via the `INCONCLUSIVE` image quality loop.

## Demo-Critical Paths
1. `New Field Test` creation.
2. `Camera Capture` bounding box alignment.
3. `Evidence Record` cryptographic verification.
4. `Offline Sync` queueing and recovery.

## Files That Should NOT Be Modified Unnecessarily
- `apps/mobile/lib/core/network/*` (Core API boundaries)
- `apps/api/src/tests/tests.service.ts` (Authoritative evidence signing logic)
- `apps/ml-service/app/services/pipeline.py` (Core ML pipeline flow)
- `apps/api/prisma/schema.prisma` (Database structures)
