# FieldSure API — Developer Documentation

> Generated from actual NestJS controller, DTO, guard, and service inspection.
> Source of truth: `apps/api/src/` implementation code.

---

## 1. Overview

FieldSure is a digital companion for colorimetric field drug testing. The API provides:

- **Authentication** — JWT-based login with token rotation and session revocation.
- **User Management** — RBAC-protected CRUD for operators, supervisors, and admins.
- **Test Kit Catalogue** — Configuration-driven kit definitions.
- **Field Test Lifecycle** — Create, capture, process, complete, with full state machine enforcement.
- **CV/ML Processing** — Backend-to-internal-ML-service pipeline (classification via `DEMO-CONFIG-v1`).
- **Cryptographic Evidence** — SHA-256 hashes, RSA-SHA256 signatures, and tamper verification.
- **Offline Synchronization** — Idempotent endpoints for retry-safe mobile sync.
- **Audit Logging** — Server-side audit trail for every security and evidence event.

> **Scientific Limitation:** No scientifically validated model is currently available. The CV/ML infrastructure is implemented and ready for validated, kit-specific labeled data.

---

## 2. Architecture & API Boundary

```
┌──────────────┐       ┌───────────────┐       ┌──────────────┐
│ Flutter App  │──────▶│  NestJS API   │──────▶│ Python ML    │
│ (Mobile)     │ HTTPS │  (Port 3000)  │ HTTP  │ Service      │
│              │◀──────│               │◀──────│ (Port 8000)  │
└──────────────┘       │  PostgreSQL   │       │ OpenCV/NumPy │
                       │  (Prisma ORM) │       └──────────────┘
                       └───────────────┘
```

**The NestJS API is the only externally accessible service.** The Python ML service is an internal backend-to-backend dependency and should NOT be exposed to mobile clients or the public internet.

---

## 3. Base URL

No global prefix is set in `main.ts`. Each controller defines its own route prefix.

| Environment | Base URL |
|---|---|
| Local development | `http://localhost:3000` |

The Flutter mobile client configures `AppConstants.apiBaseUrl` = `http://localhost:3000/api/v1` and makes relative requests (e.g., `/auth/login` resolves to `http://localhost:3000/api/v1/auth/login`).

---

## 4. Authentication

### JWT Bearer Authentication

All protected endpoints require `Authorization: Bearer <accessToken>`.

| Property | Value |
|---|---|
| Access token expiry | 15 minutes (configurable via `JWT_ACCESS_EXPIRES_IN`) |
| Refresh token expiry | 7 days (configurable via `JWT_REFRESH_EXPIRES_IN`) |
| Refresh mechanism | Token rotation — old session revoked, new session created |
| Logout | Revokes ALL active sessions for the user |
| Password hashing | bcrypt (12 rounds) |

### JWT Payload

```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "role": "OPERATOR",
  "sessionId": "session-uuid",
  "iat": 1234567890,
  "exp": 1234568790
}
```

---

## 5. Roles / RBAC

| Role | Capabilities |
|---|---|
| `ADMIN` | Full access: user management, all tests, all evidence |
| `SUPERVISOR` | Read users, view all tests, verify evidence |
| `OPERATOR` | Own tests only, create/capture/process tests |

### Per-Endpoint Role Requirements

| Endpoint | Roles | Rate Limit |
|---|---|---|
| `POST /api/v1/users` | ADMIN | Default |
| `GET /api/v1/users` | ADMIN, SUPERVISOR | Default |
| `GET /api/v1/users/:id` | ADMIN, SUPERVISOR | Default |
| `PATCH /api/v1/users/:id` | ADMIN | Default |
| `DELETE /api/v1/users/:id` | ADMIN | Default |
| `POST /api/v1/auth/login` | Public | Auth (5/15min) |
| `POST /api/v1/auth/refresh` | Public | Auth (5/15min) |
| `POST /api/v1/tests/:id/process` | Any authenticated | Default |
| All other protected endpoints | Any authenticated | Default |

---

## 6. Endpoint Index

### Authentication (4 endpoints)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/v1/auth/login` | No | Authenticate with email/password |
| `POST` | `/api/v1/auth/refresh` | No | Exchange refresh token for new tokens |
| `POST` | `/api/v1/auth/logout` | JWT | Revoke all sessions |
| `GET` | `/api/v1/auth/me` | JWT | Get current user profile |

### Users (5 endpoints)

| Method | Path | Auth | Roles | Description |
|---|---|---|---|---|
| `POST` | `/api/v1/users` | JWT | ADMIN | Create user |
| `GET` | `/api/v1/users` | JWT | ADMIN, SUPERVISOR | List all users |
| `GET` | `/api/v1/users/:id` | JWT | ADMIN, SUPERVISOR | Get user by ID |
| `PATCH` | `/api/v1/users/:id` | JWT | ADMIN | Update user |
| `DELETE` | `/api/v1/users/:id` | JWT | ADMIN | Deactivate user |

### Test Kits (2 endpoints)

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/api/v1/test-kits` | JWT | List active test kits |
| `GET` | `/api/v1/test-kits/:id` | JWT | Get test kit by ID |

### Tests (5 endpoints)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/v1/tests` | JWT | Create test (idempotent by `id`) |
| `GET` | `/api/v1/tests` | JWT | Search/list tests (paginated) |
| `GET` | `/api/v1/tests/:id` | JWT | Get test by ID |
| `PATCH` | `/api/v1/tests/:id/status` | JWT | Update test status |
| `POST` | `/api/v1/tests/:id/process` | JWT | Submit for CV/ML processing |
| `GET` | `/api/v1/tests/:id/result` | JWT | Get classification result |

### Evidence (3 endpoints)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/v1/tests/:id/evidence` | JWT | Create evidence record (idempotent) |
| `GET` | `/api/v1/tests/:id/evidence` | JWT | Get evidence record |
| `POST` | `/api/v1/tests/:id/verify` | JWT | Verify evidence integrity |

### Health (1 endpoint)

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/` | No | Root health check |

**Total: 21 implemented NestJS endpoints**

---

## 7. Response Envelope

All success responses follow:

```json
{
  "data": { ... },
  "meta": {
    "timestamp": "2026-09-29T12:00:00.000Z"
  }
}
```

---

## 8. Error Handling

All errors follow (from `GlobalExceptionFilter`):

```json
{
  "error": {
    "code": 400,
    "message": "Validation failed",
    "details": ["email must be an email"]
  },
  "meta": {
    "timestamp": "2026-09-29T12:00:00.000Z"
  }
}
```

### HTTP Status Codes

| Status | When |
|---|---|
| 400 | DTO validation failure, invalid state transition, test not completed |
| 401 | Missing/invalid/expired JWT, invalid credentials |
| 403 | Insufficient role, deactivated account |
| 404 | Resource not found |
| 409 | Duplicate email/operatorId, test number collision |
| 413 | Image too large (>20MB) |
| 429 | Rate limited (60 req/min general, 5 auth/15 min) |
| 500 | Unhandled server error (details are NOT leaked to client) |
| 503 | Service unavailable (ML service down, circuit breaker open) |

### Application Error Codes

Backend uses structured error codes (from `ErrorCode` enum):

**Authentication & Authorization:**
- `INVALID_CREDENTIALS` — Login failed
- `UNAUTHORIZED` — Missing/invalid JWT
- `SESSION_NOT_FOUND` — Session expired or revoked
- `FORBIDDEN` — Insufficient role
- `ACCOUNT_DEACTIVATED` — User account disabled

**Resource Errors:**
- `TEST_NOT_FOUND` — Test ID not found
- `KIT_NOT_FOUND` — Test kit not found
- `USER_NOT_FOUND` — User not found
- `EVIDENCE_NOT_FOUND` — Evidence record not found

**Validation & State:**
- `INVALID_STATE_TRANSITION` — Test state machine violation
- `INVALID_TEST_STATUS` — Invalid status update
- `TEST_NOT_COMPLETED` — Cannot get result for incomplete test
- `DUPLICATE_EMAIL` — Email already exists
- `DUPLICATE_OPERATOR_ID` — OperatorID already exists
- `TEST_NUMBER_COLLISION` — Test number generation failed after retries

**ML Service:**
- `ML_UNAVAILABLE` — ML service down, timeout, or circuit open (retriable)
- `ML_TIMEOUT` — ML request exceeded 30s timeout
- `PROCESSING_ERROR` — Non-retriable ML processing failure
- `RATE_LIMITED` — Rate limit hit (429)

**Evidence & Integrity:**
- `EVIDENCE_ALREADY_EXISTS` — Evidence record already created
- `VERIFICATION_FAILED` — Integrity verification failed
- `HASH_MISMATCH` — SHA-256 hash mismatch
- `SIGNATURE_INVALID` — RSA signature verification failed

**Sync & Conflict:**
- `CONFLICT` — Generic conflict (HTTP 409)
- `SYNC_CONFLICT` — Client-server data conflict during sync

The `GlobalExceptionFilter` sanitizes all exceptions — stack traces and internal database errors are never exposed.

---

## 9. Idempotency

### Test Creation (`POST /api/v1/tests`)

The `id` field in `CreateTestRequest` serves as an idempotency key. If a test with the supplied UUID already exists, the existing record is returned (HTTP 201) without creating a duplicate.

### Image Processing (`POST /api/v1/tests/:id/process`)

If the test is already `COMPLETED` with an existing `Classification` record, the server returns the existing classification result without re-processing, preventing P2002 unique constraint violations.

### Evidence Creation (`POST /api/v1/tests/:id/evidence`)

If an `EvidenceRecord` already exists for the given `testId`, it is returned without creating a duplicate.

---

## 10. Offline Synchronization

```
Mobile (SQLite/Drift)          NestJS API (PostgreSQL)
        │                              │
  1. Create draft locally              │
  2. Enqueue CREATE_TEST op            │
  3. Network restored                  │
  4. ──── POST /api/v1/tests ────────▶ │ (idempotent by id)
  5. ◀──── 201 { data: test } ──────── │
  6. Mark queue item SYNCED            │
  7. Enqueue PROCESS_TEST              │
  8. ──── POST /tests/:id/process ───▶ │ (idempotent if COMPLETED)
  9. ◀──── 200 { classification } ──── │
 10. Update local status               │
```

Supported queue operation types: `CREATE_TEST`, `UPLOAD_IMAGE`, `UPDATE_STATUS`, `PROCESS_TEST`.

Retry statuses: `PENDING` → `SYNCING` → `SYNCED` | `REQUIRES_RETRY` | `CONFLICT`.

HTTP 409 from the backend marks the queue item as `CONFLICT` for manual resolution.

---

## 11. Evidence & Cryptographic Verification

### Evidence Creation Flow

1. **Image Hash**: SHA-256 of the raw image file → `imageHash`.
2. **Canonical Record**: JSON object with sorted keys containing `testId`, `testNumber`, `caseId`, `sampleId`, `operatorId`, `kitId`, `classificationResult`, `classificationConfidence`, `algorithmVersion`, `modelVersion`, `imageHash`, `hashingAlgorithm`, `schemaVersion`, `canonicalizationVersion`.
3. **Record Hash**: SHA-256 of the canonical JSON string → `recordHash`.
4. **Digital Signature**: RSA-SHA256 sign the canonical string with the server's private key → Base64-encoded `signature`.

### Verification

| Check | What is compared |
|---|---|
| `imageIntegrity` | Current SHA-256 of image vs stored `imageHash` |
| `recordIntegrity` | Recomputed canonical hash vs stored `recordHash` |
| `signatureIntegrity` | RSA-SHA256 verify canonical string against stored `signature` |

Overall: `VERIFIED` if all three pass; `INTEGRITY_FAILED` if any fail.

### Algorithms

| Algorithm | Usage |
|---|---|
| SHA-256 | Image hashing, record hashing |
| RSA-SHA256 | Digital signature (2048-bit key) |
| Base64 | Signature encoding |

---

## 12. CV/ML API Boundary (Internal)

The Python FastAPI ML service runs on `http://localhost:8000` (dev) or internal network (production) and is consumed exclusively by the NestJS backend. **This service MUST NOT be exposed to public internet or mobile clients.**

### Service-to-Service Authentication

**Production Requirement:** The ML service requires authentication via shared secret (Bearer token) or mTLS.

```http
POST /process
Authorization: Bearer <ML_SHARED_SECRET>
Content-Type: application/json
```

Configuration:
- `ML_SHARED_SECRET` — Shared secret for API ↔ ML authentication (REQUIRED in production)
- `ML_MTLS_ENABLED` — Optional mTLS for transport security
- `ML_BIND_HOST` — Network binding (use `127.0.0.1` or internal IP in production, NOT `0.0.0.0`)

### Client Resilience Patterns

The NestJS `MLClientService` implements production-grade resilience:

| Pattern | Configuration | Behavior |
|---|---|---|
| **Timeout** | 30 seconds | Request aborted after 30s |
| **Retry** | Max 3 attempts | Exponential backoff: 2s, 4s, 8s (+ jitter) |
| **Circuit Breaker** | 5 failures / 60s | Opens after 5 consecutive failures, transitions HALF_OPEN after 60s |
| **Non-retriable Errors** | 4xx (except 429) | Immediate failure, no retry |
| **Rate Limit Handling** | 429 + Retry-After | Respects server's Retry-After header |

**Error Codes:**
- `ML_SERVICE_UNAVAILABLE` — Service down, timeout, or circuit open (retriable)
- `ML_TIMEOUT` — Request exceeded 30s timeout
- `PROCESSING_ERROR` — Non-retriable processing failure
- `RATE_LIMITED` — 429 rate limit hit

Tests marked `FAILED` with `ML_SERVICE_UNAVAILABLE` can be re-queued for processing.

### Security Controls

**Validation & Limits:**
- **URL Allowlist:** Image URLs validated against `ML_ALLOWED_IMAGE_HOSTS` (production enforced)
- **Image Size:** Max 20MB (configurable via `ML_MAX_IMAGE_SIZE_MB`)
- **Resolution:** Min 1920px, Max 8192px
- **Decode Bomb Protection:** PIL `MAX_IMAGE_PIXELS` = 178,956,970 (~8192×8192)
- **Request Timeout:** 30 seconds
- **Content Validation:** SHA-256 hash computed for integrity tracking

**Structured Error Responses:**
```json
{
  "code": "IMAGE_TOO_LARGE",
  "message": "Image size 25.3MB exceeds limit of 20MB",
  "details": null
}
```

Error codes: `IMAGE_TOO_LARGE`, `IMAGE_DECOMPRESSION_BOMB`, `IMAGE_RESOLUTION_TOO_LOW`, `IMAGE_RESOLUTION_TOO_HIGH`, `URL_HOST_NOT_ALLOWED`, `IMAGE_INVALID`.

### Internal Endpoints

| Method | Path | Auth | Description |
|---|---|---|
| `GET` | `/health` | No | Health check |
| `GET` | `/health/ready` | No | Readiness probe |
| `POST` | `/process` | Bearer token | Process image through CV pipeline |

### Processing Pipeline

```
Image URL → Validate URL/Size → Fetch → Validate Content/Decode Bomb
→ Quality Validation → Reference Card Detection → Perspective Correction
→ Color Calibration → ROI Extraction → Feature Extraction
→ Classification → Response
```

### Extended Response Contract

The ML service returns enriched classification data:

```json
{
  "status": "completed",
  "processing_run_id": "uuid",
  "test_id": "uuid",
  "quality": {
    "acceptable": true,
    "issues": [],
    "diagnostics": {
      "width": 3024,
      "height": 4032,
      "brightness": 128.5,
      "blur_score": 145.2,
      "reference_card_detected": true,
      "test_region_detected": true
    },
    "assessment": {
      "overall_status": "ACCEPTABLE",
      "image_integrity": { "status": "ACCEPTABLE", "issues": [], "metrics": {} },
      "focus_and_resolution": { "status": "ACCEPTABLE", "issues": [], "metrics": {} },
      "exposure_and_illumination": { "status": "ACCEPTABLE", "issues": [], "metrics": {} },
      "reference_card_quality": { "status": "ACCEPTABLE", "issues": [], "metrics": {} },
      "calibration_quality": { "status": "ACCEPTABLE", "issues": [], "metrics": {} },
      "can_proceed_to_measurement": true,
      "can_interpret": true,
      "recapture_guidance": null,
      "config_version": "v1-provisional"
    }
  },
  "classification": {
    "observedColor": {
      "L": 65.3,
      "a": -5.2,
      "b": 12.8
    },
    "colorDistance": 15.2,
    "nearestReferenceLabel": "Blue-Purple range",
    "qualityStatus": "ACCEPTABLE",
    "qualityIssues": [],
    "algorithmVersion": "colorimetric-demo-v1",
    "modelVersion": "DEMO-UNVALIDATED-v1",
    "configurationVersion": "DEMO-CONFIG-v1",
    "kitCode": "DEMO-KIT-01",
    "validationStatus": "UNVALIDATED",
    "features": {
      "lab_mean_l": 65.3,
      "lab_mean_a": -5.2,
      "lab_mean_b": 12.8,
      "delta_e_76": 16.4,
      "delta_e_2000": 15.2,
      "chroma": 13.8,
      "color_distance": 15.2
    },
    "uncertainty": {
      "pixel_sampling_std_l": 1.2,
      "pixel_sampling_std_a": 0.8,
      "pixel_sampling_std_b": 1.1,
      "roi_variability": 1.03,
      "calibration_residual_delta_e": null,
      "is_available": true
    },
    "diagnostics": {
      "classifier_type": "demo_colorimetric",
      "reference_colors_count": 4,
      "nearest_reference_distance": 15.2
    },
    "classifiedAt": "2026-09-29T12:00:00.000Z"
  },
  "diagnostics": {
    "processing_time_ms": 1250,
    "image_sha256": "a3f5c8d...",
    "gate_status": "VALIDATED_INTERPRETATION"
  }
}
```

**Extended Fields:**
- `deltaE` / `delta_e_2000` — Correct Color difference metric (Lab space CIEDE2000)
- `QualityAssessment` — Dedicated structure providing component-wise quality checks (Integrity, Focus, Exposure, Reference, Calibration)
- `MeasurementUncertainty` — Spatial variation mapping across pixel ROI and calibration residuals.
- `gate_status` — Authoritative backend Safe Abstention gate (e.g. `VALIDATED_INTERPRETATION` or `REJECTED_QUALITY`).
- `validationStatus` — `VALIDATED` | `UNVALIDATED` (gates on validation report)

### Classification Outputs

The upgraded ML service no longer returns deterministic substance identification (`result` / `confidence`). Instead, it returns scientifically objective colorimetric measurements gated by the Decision Gate:

| Property | Description |
|---|---|
| `observedColor` | True Lab color space measurement `{L, a, b}` (D65). |
| `colorDistance` | CIEDE2000 distance ($\Delta E_{00}$) to the nearest configured reference profile. |
| `nearestReferenceLabel` | Descriptive label of the closest match (e.g., "Blue-Purple range"). **Explicitly NOT a drug name.** |
| `qualityStatus` | Determined by the authoritative Decision Gate considering blur, exposure, uncertainty, and domain checks. |
| `uncertainty` | Metric array describing pixel sampling std dev across L/a/b channels and `roi_variability`. |

> **DEMO-UNVALIDATED-v1** is a demonstration configuration, NOT a scientifically trained model. No drug detection accuracy, precision, recall, or F1 metrics are claimed.

### Validation Status

The ML service tracks pipeline validation status:

- **UNVALIDATED** — Default state, no qualifying validation report exists
- **VALIDATED** — Service has validation report meeting minimum requirements:
  - Minimum sample size (100+ total, 30+ per class)
  - Performance thresholds met (accuracy ≥85%, per-class metrics ≥80%)
  - Stratified group-aware evaluation (session/device splits)
  - Wilson confidence intervals computed

**Production Requirement:** Service MUST NOT report `VALIDATED` status without a signed-off validation report file (JSON) that meets configurable minimum sample size and metric thresholds.

All results carry presumptive disclaimer: *"Laboratory confirmation using GC-MS or equivalent analytical methods is required for legal proceedings."*

---

## 13. Test Lifecycle States

```
DRAFT → CAPTURED → UPLOADING → PROCESSING → COMPLETED
                                           → INCONCLUSIVE
                                           → FAILED
PENDING_SYNC (client-side concept)
```

State transitions are enforced by `TestStateMachineService`.

---

## 14. Rate Limiting

| Window | Limit | Scope | Header |
|---|---|---|---|
| 1 minute | 60 requests | General (all endpoints) | `default` |
| 15 minutes | 5 requests | Authentication attempts | `auth` |
| 1 minute | 100 requests | Sync endpoints | `sync` |

Implemented via `@nestjs/throttler` as a global guard with per-user tracking.

**Rate Limit Headers:**
```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1609459260
Retry-After: 15
```

When rate limited (HTTP 429), the `Retry-After` header indicates seconds to wait before retrying.

---

## 15. Security Summary

| Feature | Implementation |
|---|---|
| Transport | HTTPS recommended (Helmet security headers enabled) |
| Authentication | JWT access tokens (15 min), UUID refresh tokens (7 days) |
| Password storage | bcrypt (12 rounds) |
| RBAC | ADMIN, SUPERVISOR, OPERATOR |
| Input validation | class-validator with whitelist + forbidNonWhitelisted |
| Error sanitization | GlobalExceptionFilter strips stack traces |
| CORS | Configurable origins via `CORS_ORIGINS` |
| Digital signatures | RSA-SHA256 (2048-bit, server-side only) |
| Private keys | Server-side only — NEVER in Flutter or client storage |
| Audit logging | Every auth, test, evidence, and verification event |
| Rate limiting | Throttler guards on all endpoints (60/min, auth 5/15min) |
| **ML Service Auth** | Shared secret (Bearer token) or mTLS (production required) |
| **Image Validation** | Size limits (20MB), decode bomb protection, SHA-256 integrity |
| **URL Allowlist** | Host allowlist enforced in production |
| **Request Timeout** | 30s timeout on ML service calls |
| **Circuit Breaker** | Opens after 5 ML failures, auto-resets after 60s |

### Threat Model (ML Service)

Documented in `apps/ml-service/app/core/auth.py`:

**Threats:**
- External attackers attempting to call ML endpoints directly
- Compromised API service attempting unauthorized access
- Man-in-the-middle attacks on internal network
- Replay attacks using captured tokens
- Timing attacks on secret comparison

**Mitigations:**
- Shared secret with constant-time comparison
- Optional mTLS for transport security
- Request signing with timestamps (optional enhancement)
- Rate limiting at reverse proxy level
- Internal network binding (not exposed to public internet)

---

## 16. API Versioning

The current version prefix is `api/v1`. All controllers use this prefix explicitly in their `@Controller()` decorator.

---

## 17. Production Deployment

### Environment Variables

**API Service:**
```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/fieldsure
POSTGRES_USER=fieldsure
POSTGRES_PASSWORD=<strong_password>

# JWT
JWT_ACCESS_SECRET=<64_char_random_string>
JWT_REFRESH_SECRET=<64_char_random_string>
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# ML Service Authentication
ML_SERVICE_URL=http://ml-service:8000
ML_SHARED_SECRET=<strong_shared_secret>

# Storage
S3_ENDPOINT=https://s3.amazonaws.com
S3_ACCESS_KEY=<access_key>
S3_SECRET_KEY=<secret_key>
S3_BUCKET=fieldsure-production

# Redis
REDIS_URL=redis://redis:6379

# CORS (empty for production API)
CORS_ORIGINS=
```

**ML Service:**
```bash
# Production Mode
ML_DEBUG=false

# Network Binding (internal IP, NOT 0.0.0.0)
ML_BIND_HOST=10.0.1.10
ML_BIND_PORT=8000

# Authentication (REQUIRED in production)
ML_SHARED_SECRET=<strong_shared_secret>

# S3
ML_S3_ENDPOINT=https://s3.amazonaws.com
ML_S3_ACCESS_KEY=<access_key>
ML_S3_SECRET_KEY=<secret_key>
ML_S3_BUCKET=fieldsure-production

# CORS (empty for internal service)
ML_CORS_ORIGINS=[]

# Validation
ML_MAX_IMAGE_SIZE_MB=20
ML_MIN_IMAGE_RESOLUTION=1920
ML_MAX_IMAGE_RESOLUTION=8192
ML_REQUEST_TIMEOUT_SECONDS=30
ML_ALLOWED_IMAGE_HOSTS=["s3.amazonaws.com"]
```

### Docker Deployment

Production-ready Dockerfiles provided:
- `infrastructure/docker/Dockerfile.api` — Multi-stage, non-root user, healthcheck
- `infrastructure/docker/Dockerfile.ml` — Multi-stage, non-root user, healthcheck

```bash
# Build
docker build -f infrastructure/docker/Dockerfile.api -t fieldsure-api:latest .
docker build -f infrastructure/docker/Dockerfile.ml -t fieldsure-ml:latest .

# Run with compose
docker compose --profile full up -d
```

### Database Backup & Restore

```bash
# Backup (scheduled via cron)
./scripts/backup-db.sh
# Creates: backups/fieldsure_YYYYMMDD_HHMMSS.sql.gz + SHA-256 hash

# Restore with verification
export POSTGRES_PASSWORD=<password>
./scripts/restore-db.sh backups/fieldsure_20260929_120000.sql.gz
# Automatically runs verify-evidence-chain.sh

# Manual verification
./scripts/verify-evidence-chain.sh
```

### Health Checks

**API:**
```bash
curl http://localhost:3000/health
# Returns: { "status": "ok", "database": "healthy", "mlService": "healthy" }
```

**ML Service:**
```bash
curl -H "Authorization: Bearer <secret>" http://localhost:8000/health
# Returns: { "status": "healthy", "version": "0.1.0" }
```

### CI/CD

GitHub Actions workflow configured (`.github/workflows/ci.yml`):
- Lint, type-check, unit tests (API + ML)
- Prisma migration checks
- Security: npm audit, pip-audit, Gitleaks, CodeQL SAST
- Container builds
- E2E tests with docker-compose

### Monitoring & Observability

**Required (Not Yet Implemented):**
- Structured JSON logging with requestId correlation
- Prometheus metrics: request latency, error rates, ML circuit breaker status
- Grafana dashboards
- Alerting on circuit breaker opens, high error rates

### Performance Tuning

**Circuit Breaker:**
- Failure threshold: 5 consecutive failures
- Reset timeout: 60 seconds
- Adjust based on load testing results

**Rate Limits:**
- General: 60 req/min per user
- Auth: 5 attempts/15min per IP
- Sync: 100 req/min per user
- Tune based on p95 latency measurements

**Database:**
- Connection pool size: 10 (default)
- Max connections: 100
- Adjust based on concurrent user load

The current FieldSure deployment uses `DEMO-CONFIG-v1` as the classification pipeline identifier. This is:

- A **demonstration configuration** with placeholder thresholds.
- **NOT** a scientifically trained or validated model.
- **NOT** forensically valid or admissible as evidence without laboratory confirmation.

Scientifically valid classification requires:
- Kit-specific labeled ground-truth datasets.
- Controlled validation with GC/MS laboratory confirmation.
- Documented sensitivity, specificity, and error rates.

All classification results are **presumptive** and require laboratory confirmation.
