# FieldSure — API Design

## Base URL

```
Development: http://localhost:3000/api/v1
Production:  https://api.fieldsure.example/api/v1
```

## Authentication

All endpoints except `/auth/login` require a valid JWT in the `Authorization` header:

```
Authorization: Bearer <access_token>
```

### Auth Endpoints

| Method | Path | Description | Access |
|---|---|---|---|
| POST | `/auth/login` | Authenticate, returns JWT + refresh token | Public |
| POST | `/auth/refresh` | Refresh access token | Authenticated |
| POST | `/auth/logout` | Invalidate refresh token | Authenticated |
| GET | `/auth/me` | Get current user profile | Authenticated |

### User Management

| Method | Path | Description | Access |
|---|---|---|---|
| GET | `/users` | List users (paginated) | ADMIN |
| POST | `/users` | Create user | ADMIN |
| GET | `/users/:id` | Get user details | ADMIN, SUPERVISOR |
| PATCH | `/users/:id` | Update user | ADMIN |
| DELETE | `/users/:id` | Deactivate user | ADMIN |

### Devices

| Method | Path | Description | Access |
|---|---|---|---|
| POST | `/devices` | Register device | Authenticated |
| GET | `/devices` | List user's devices | Authenticated |
| PATCH | `/devices/:id` | Update device info | Authenticated |

### Test Kits

| Method | Path | Description | Access |
|---|---|---|---|
| GET | `/kits` | List active kits | Authenticated |
| GET | `/kits/:id` | Get kit details | Authenticated |
| POST | `/kits` | Create kit | ADMIN |
| PATCH | `/kits/:id` | Update kit | ADMIN |
| POST | `/kits/:id/configs` | Add classification config | ADMIN |
| GET | `/kits/:id/configs` | List kit configs | ADMIN |

### Tests

| Method | Path | Description | Access |
|---|---|---|---|
| POST | `/tests` | Create new test | OPERATOR, SUPERVISOR |
| GET | `/tests` | List tests (paginated, filtered) | Authenticated |
| GET | `/tests/:id` | Get test details | Authenticated |
| PATCH | `/tests/:id` | Update test (DRAFT only) | Owner |
| POST | `/tests/:id/images` | Upload test image | Owner |
| GET | `/tests/:id/images` | List test images | Authenticated |
| POST | `/tests/:id/submit` | Submit for processing | Owner |
| GET | `/tests/:id/result` | Get classification result | Authenticated |
| GET | `/tests/:id/evidence` | Get evidence record | Authenticated |

### Sync

| Method | Path | Description | Access |
|---|---|---|---|
| POST | `/sync/tests` | Batch sync offline tests | Authenticated |
| GET | `/sync/status` | Get sync status | Authenticated |

### Evidence

| Method | Path | Description | Access |
|---|---|---|---|
| GET | `/evidence/:id` | Get evidence record | Authenticated |
| POST | `/evidence/:id/verify` | Verify evidence integrity | Authenticated |
| GET | `/evidence/:id/export` | Export evidence (PDF/JSON) | Authenticated |

### Audit

| Method | Path | Description | Access |
|---|---|---|---|
| GET | `/audit` | Query audit logs (paginated) | ADMIN, SUPERVISOR |
| GET | `/audit/test/:testId` | Get audit trail for a test | ADMIN, SUPERVISOR |

### Health

| Method | Path | Description | Access |
|---|---|---|---|
| GET | `/health` | Service health check | Public |
| GET | `/health/ready` | Readiness probe | Public |

## ML Service Internal API

> Internal service — not exposed to mobile clients.

| Method | Path | Description |
|---|---|---|
| POST | `/process` | Process an image through the CV pipeline |
| GET | `/health` | Service health check |
| GET | `/models` | List available model versions |
| GET | `/configs` | List available kit configurations |

### Process Request

```json
{
  "image_url": "s3://fieldsure-images/tests/abc123/reaction.jpg",
  "kit_code": "MARQUIS_001",
  "config_version": "1.0.0",
  "model_version": "1.0.0",
  "test_id": "uuid",
  "processing_run_id": "uuid"
}
```

### Process Response

```json
{
  "status": "completed",
  "quality": {
    "overall": "PASS",
    "checks": {
      "resolution": { "status": "PASS", "value": 3024 },
      "blur": { "status": "PASS", "score": 0.92 },
      "brightness": { "status": "PASS", "value": 128 },
      "exposure": { "status": "PASS" },
      "glare": { "status": "PASS" },
      "card_visible": { "status": "PASS" },
      "region_visible": { "status": "PASS" }
    }
  },
  "classification": {
    "result": "POSITIVE",
    "confidence": 0.89,
    "detected_substance": "Methamphetamine",
    "features": { /* extracted colour features */ }
  },
  "diagnostics": {
    "processing_time_ms": 1234,
    "pipeline_steps": [ /* step-by-step log */ ],
    "annotated_image_url": "s3://fieldsure-images/tests/abc123/annotated.jpg"
  }
}
```

## Common Response Formats

### Success

```json
{
  "data": { /* response payload */ },
  "meta": {
    "timestamp": "2026-09-28T12:00:00Z"
  }
}
```

### Paginated

```json
{
  "data": [ /* items */ ],
  "meta": {
    "total": 150,
    "page": 1,
    "limit": 20,
    "totalPages": 8,
    "timestamp": "2026-09-28T12:00:00Z"
  }
}
```

### Error

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": [
      { "field": "case_number", "message": "must not be empty" }
    ]
  },
  "meta": {
    "timestamp": "2026-09-28T12:00:00Z"
  }
}
```

## HTTP Status Codes

| Code | Usage |
|---|---|
| 200 | Successful GET/PATCH |
| 201 | Successful POST (created) |
| 204 | Successful DELETE |
| 400 | Validation error |
| 401 | Unauthenticated |
| 403 | Forbidden (insufficient role) |
| 404 | Resource not found |
| 409 | Conflict (duplicate) |
| 413 | File too large |
| 422 | Unprocessable entity |
| 429 | Rate limited |
| 500 | Server error |
