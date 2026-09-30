# OpenAPI Specification Review — Discrepancies & Observations

## Cross-Check: NestJS Controllers ↔ Flutter Client ↔ openapi.yaml

### Path Alignment

| Flutter Client Path | NestJS Controller Route | Match |
|---|---|---|
| `POST /auth/login` | `api/v1/auth` → `@Post('login')` | ✅ (Flutter base URL includes `/api/v1`) |
| `POST /auth/refresh` | `api/v1/auth` → `@Post('refresh')` | ✅ |
| `POST /auth/logout` | `api/v1/auth` → `@Post('logout')` | ✅ |
| `GET /auth/me` | `api/v1/auth` → `@Get('me')` | ✅ |
| `GET /test-kits` | `api/v1/test-kits` → `@Get()` | ✅ |
| `POST /tests` | `api/v1/tests` → `@Post()` | ✅ |
| `GET /tests` | `api/v1/tests` → `@Get()` | ✅ |
| `GET /tests/:id` | `api/v1/tests` → `@Get(':id')` | ✅ |
| `PATCH /tests/:id/status` | `api/v1/tests` → `@Patch(':id/status')` | ✅ |
| `POST /tests/:id/process` | `api/v1/tests` → `@Post(':id/process')` | ✅ |
| `GET /tests/:id/evidence` | `api/v1/tests/:id/evidence` → `@Get()` | ✅ |
| `POST /tests/:id/evidence` | `api/v1/tests/:id/evidence` → `@Post()` | ✅ |
| `POST /tests/:id/verify` | `api/v1/tests/:id/verify` → `@Post()` | ✅ |

**Result: No path discrepancies found.** All Flutter Dio calls resolve to implemented NestJS routes.

### Endpoints Not Consumed by Flutter

| NestJS Endpoint | Reason |
|---|---|
| `GET /` | Root health check — not used by mobile |
| `POST /api/v1/users` | Admin-only user creation — not in mobile UI |
| `GET /api/v1/users` | Admin/Supervisor listing — not in mobile UI |
| `GET /api/v1/users/:id` | Admin/Supervisor detail — not in mobile UI |
| `PATCH /api/v1/users/:id` | Admin-only update — not in mobile UI |
| `DELETE /api/v1/users/:id` | Admin-only deactivation — not in mobile UI |
| `GET /api/v1/test-kits/:id` | Individual kit lookup — mobile uses list only |
| `GET /api/v1/tests/:id/result` | Separate result endpoint — mobile gets result via test detail |

These are all legitimate server-side endpoints used by admin tooling or available for future use. No code changes required.

### Flutter API Client Observations

1. **Base URL configuration**: `AppConstants.apiBaseUrl` defaults to `http://localhost:3000/api/v1` via `String.fromEnvironment('API_BASE_URL')`. For physical device testing, the `--dart-define=API_BASE_URL=http://<host-ip>:3000/api/v1` flag must be used.

2. **Timeout configuration**: Connect and receive timeouts are both 15 seconds — appropriate for mobile.

3. **Token refresh**: The `ApiClient` interceptor uses a separate `Dio` instance for the refresh call to avoid interceptor recursion. This is correct.

### NestJS Observations

1. **No Swagger/OpenAPI module is installed** in the NestJS project. The `openapi.yaml` was generated manually from source inspection, not from `@nestjs/swagger`.

2. **No image upload endpoint exists** yet. The `processImage` method in `tests.service.ts` accepts an `imageUrl` (S3/MinIO URL). The actual multipart upload to object storage is not yet implemented as a direct API endpoint.

3. **Audit logs have no external API**. The `AuditService` is internal-only; there is no `AuditController`. Audit data is only accessible via direct database queries.

---

## Discrepancy Status

| Category | Status |
|---|---|
| Path alignment | ✅ No discrepancies |
| DTO validation alignment | ✅ All DTOs match controller usage |
| Authentication flow | ✅ JWT + refresh rotation confirmed |
| RBAC | ✅ Guards and decorators match documented roles |
| Error format | ✅ GlobalExceptionFilter format documented accurately |
| Idempotency | ✅ Three idempotent endpoints documented |
| Rate limiting | ✅ Throttler configuration documented |

**No changes to application code are required.**
