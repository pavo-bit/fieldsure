# FieldSure — Implementation Plan

> Phased implementation roadmap for FieldSure — Digital Companion for Field Drug Testing.

---

## Phase Overview

| Phase | Name | Scope | Est. Duration |
|---|---|---|---|
| 0 | Project Foundation | Monorepo, scaffolding, CI structure, tooling | 1 week |
| 1 | Authentication & Core Backend | Users, auth, RBAC, database schema | 1–2 weeks |
| 2 | Mobile Shell & Auth | Flutter project, navigation, login/logout | 1–2 weeks |
| 3 | Test Management | Create/read tests, kit selection, state machine | 1–2 weeks |
| 4 | Camera & Image Capture | Guided capture, quality checks, upload | 2 weeks |
| 5 | CV Pipeline (Basic) | Image processing, reference card detection, classification stub | 2–3 weeks |
| 6 | Evidence & Signing | Evidence records, hashing, digital signatures | 1–2 weeks |
| 7 | History & Search | Test history, filtering, detail view | 1 week |
| 8 | Offline Support | Local storage, sync queue, idempotent sync | 2 weeks |
| 9 | CV Pipeline (Full) | Colour calibration, feature extraction, kit-specific classification | 3–4 weeks |
| 10 | Verification & Audit | Evidence verification, audit log viewer, export | 1–2 weeks |
| 11 | Admin & Supervisor | User management, kit config, oversight dashboard | 2 weeks |
| 12 | Hardening & Polish | Security audit, performance, accessibility, edge cases | 2 weeks |

---

## Phase 0 — Project Foundation

### Objective
Establish the monorepo structure, scaffold all three services, configure Docker Compose, and set up development tooling.

### Deliverables

#### 0.1 Monorepo Structure
- [x] Create the directory layout
- [x] Create root `.gitignore`
- [x] Initialize git repository

#### 0.2 Flutter Project Scaffold
- [x] `flutter create` under `apps/mobile/`
- [x] Add core dependencies to `pubspec.yaml` (Drift, Riverpod, GoRouter, Dio, SecureStorage)
- [x] Set up feature-based directory structure under `lib/`
- [x] Configure `analysis_options.yaml` with strict linting
- [x] Verify `flutter analyze` passes
- [x] Verify `flutter test` passes

#### 0.3 NestJS Project Scaffold
- [x] NestJS 12 under `apps/api/`
- [x] Add core dependencies (Prisma, JWT, Passport, Bcrypt, Throttler, Helmet)
- [x] Configure Prisma with PostgreSQL
- [x] Configure Oxlint + Vitest
- [x] Verify `npm run lint` passes
- [x] Verify `npm run test` passes
- [x] Verify `npm run build` succeeds

#### 0.4 Python ML Service Scaffold
- [x] Create FastAPI project under `apps/ml-service/`
- [x] Configure ruff, pytest, pydantic
- [x] Create health and process stub endpoints
- [x] Verify `ruff check` passes
- [x] Verify `pytest` passes

#### 0.5 Docker Compose
- [x] Create `Dockerfile.api` for API service
- [x] Create `Dockerfile.ml` for ML service
- [x] Create `docker-compose.yml` with PostgreSQL 16, Redis 7, MinIO
- [x] Create `.env.example` with all required variables

#### 0.6 Development Scripts
- [x] `scripts/setup.ps1` — initial dev environment setup
- [x] `scripts/dev.ps1` — start all services for development
- [x] `scripts/lint-all.ps1` — run linting across all services
- [x] `scripts/test-all.ps1` — run tests across all services

---

## Phase 1 — Authentication & Core Backend

### Objective
Implement user authentication, RBAC, database schema, Flutter mobile authentication flow, and secure storage foundation.

### Deliverables

#### 1.1 Database Schema
- [x] Define Prisma schema with entities: `User`, `AuthSession`, `AuditLog`, enums (`UserRole`, `AuditEventType`)
- [x] Define proper relations, cascading rules, and indexes
- [x] Validate Prisma schema (`npx prisma validate`)
- [x] Generate Prisma client (`npx prisma generate`)

#### 1.2 Authentication Module
- [x] POST `/api/v1/auth/login` — returns JWT + hashed refresh token session + safe user profile
- [x] POST `/api/v1/auth/refresh` — refresh access token with single-use session rotation
- [x] POST `/api/v1/auth/logout` — invalidate active user refresh sessions
- [x] GET `/api/v1/auth/me` — retrieve authenticated user profile
- [x] Passport JWT strategy with active session validation
- [x] Bcrypt password hashing (cost factor 12)
- [x] Rate limiting with ThrottlerGuard on auth endpoints

#### 1.3 User Management & RBAC
- [x] User CRUD operations in `UsersService`
- [x] `@Roles()` decorator and `RolesGuard`
- [x] Role hierarchy enforcement (ADMIN, SUPERVISOR, OPERATOR)
- [x] Prevent duplicate email/operatorId conflict handling
- [x] User deactivation with automatic session revocation

#### 1.4 Audit Logging
- [x] `AuditService` with structured audit log persistence
- [x] Audit events: LOGIN, LOGIN_FAILED, LOGOUT, TOKEN_REFRESH, USER_CREATED, USER_UPDATED, USER_DEACTIVATED

#### 1.5 Security Foundation & Middleware
- [x] Helmet security headers
- [x] CORS configuration from environment variables
- [x] Global ValidationPipe with strict whitelist and transformation
- [x] Exclusion of sensitive data (passwordHash, refreshTokenHash) from all DTO responses

#### 1.6 Flutter Mobile Authentication Flow
- [x] `UserModel`, `AuthTokens`, and `AuthState` immutable data models
- [x] `SecureStorageService` with platform-encrypted storage (Android EncryptedSharedPreferences, iOS Keychain)
- [x] `ApiClient` (Dio) with Bearer token injection, automatic 401 token refresh retry, and error normalization
- [x] `AuthRepository` for login, refresh, logout, profile
- [x] `AuthController` (Riverpod) managing authentication state lifecycle
- [x] `SplashScreen` with branding, fast session verification, and statutory notice
- [x] `LoginScreen` with operator authentication form, validation, loading state, error alert, and disclaimer
- [x] `DashboardScreen` displaying officer name, badge ID, role pill, and operational actions
- [x] `GoRouter` with reactive auth guard redirecting unauthenticated users to `/login` and authenticated users to `/dashboard`
- [ ] Global exception filter with sanitized errors

### Verification
```powershell
cd apps/api && npm run lint && npm run test && npm run test:e2e
```

---

## Phase 2 — Mobile Shell & Authentication

### Objective
Build the Flutter app shell with navigation, theming, and authentication flow.

### Deliverables

#### 2.1 Theme & Design System
- [ ] Implement FieldSure theme with brand colours
- [ ] Typography scale
- [ ] Reusable widget library (buttons, cards, inputs, status badges)
- [ ] Responsive layout utilities

#### 2.2 Navigation
- [ ] GoRouter configuration for all planned screens
- [ ] Auth-guard redirect (unauthenticated → login)
- [ ] Bottom navigation for main sections

#### 2.3 Authentication Screens & Logic
- [ ] Splash screen
- [ ] Login screen
- [ ] Auth state management (Riverpod)
- [ ] JWT storage (secure storage)
- [ ] Token refresh logic in Dio interceptor
- [ ] Logout flow

#### 2.4 Dashboard Shell
- [ ] Dashboard screen (placeholder content)
- [ ] Profile screen (placeholder)
- [ ] Settings screen (placeholder)

### Verification
```powershell
cd apps/mobile && flutter analyze && flutter test && flutter build apk --debug
```

---

## Phase 3 — Test Management

### Objective
Implement the core test creation and management flow across backend and mobile.

### Deliverables
- [ ] Backend: Test CRUD endpoints, test state machine, kit selection endpoint
- [ ] Mobile: New Test flow screens (Test Info → Kit Selection → state display)
- [ ] Backend: Test state transitions with validation
- [ ] Mobile: Riverpod providers for test state

---

## Phase 4 — Camera & Image Capture

### Objective
Implement guided camera capture with quality assessment.

### Deliverables
- [ ] Mobile: Camera screen with overlay guides
- [ ] Mobile: Image preview with retake option
- [ ] Mobile: Client-side quality checks (blur, brightness, framing)
- [ ] Mobile: Image upload via Dio (multipart)
- [ ] Backend: Image upload endpoint, S3 storage, SHA-256 hashing
- [ ] Backend: Image metadata recording

---

## Phase 5 — CV Pipeline (Basic)

### Objective
Implement the initial computer vision pipeline with stub classification.

### Deliverables
- [ ] ML Service: Image quality validation
- [ ] ML Service: Reference card detection (ArUco/contour-based)
- [ ] ML Service: Perspective correction
- [ ] ML Service: Test region detection
- [ ] ML Service: Stub classification (returns INCONCLUSIVE)
- [ ] Backend: BullMQ job to call ML service
- [ ] Backend: Processing run recording
- [ ] Mobile: Processing status screen

---

## Phase 6 — Evidence & Digital Signatures

### Objective
Implement tamper-evident evidence records with digital signatures.

### Deliverables
- [ ] Backend: Evidence record generation
- [ ] Backend: Canonical record hashing (SHA-256)
- [ ] Backend: Asymmetric digital signature (RSA/ECDSA)
- [ ] Backend: Signing abstraction (pluggable for KMS/HSM)
- [ ] Backend: Signature verification endpoint
- [ ] Mobile: Evidence record display screen

---

## Phase 7 — History & Search

### Objective
Searchable test history with filtering and detail views.

### Deliverables
- [ ] Backend: Paginated test listing with filters
- [ ] Mobile: Test History screen with search/filter
- [ ] Mobile: Test Detail screen
- [ ] Mobile: Verify Record screen

---

## Phase 8 — Offline Support

### Objective
Enable temporary offline operation with idempotent synchronization.

### Deliverables
- [ ] Mobile: Isar local database for offline storage
- [ ] Mobile: Offline test creation (PENDING_SYNC state)
- [ ] Mobile: Sync queue management screen
- [ ] Mobile: Connectivity monitoring
- [ ] Mobile: Background sync on reconnection
- [ ] Backend: Idempotent sync endpoint (client-generated UUIDs)
- [ ] Backend: Duplicate detection

---

## Phase 9 — CV Pipeline (Full)

### Objective
Complete the computer vision pipeline with colour calibration and kit-specific classification.

### Deliverables
- [ ] ML Service: Colour calibration using reference card
- [ ] ML Service: Feature extraction
- [ ] ML Service: Kit-specific classification (configuration-driven)
- [ ] ML Service: Confidence scoring
- [ ] ML Service: Diagnostic output (annotated images, metrics)
- [ ] Backend: Classification config management
- [ ] Backend: Model version tracking

> **Note:** This phase requires actual validated colour data for at least one test kit. Demo configurations must be clearly labelled.

---

## Phase 10 — Verification & Audit

### Deliverables
- [ ] Mobile: Evidence verification flow
- [ ] Backend: Full audit log query API
- [ ] Mobile: Audit event viewer (SUPERVISOR/ADMIN)
- [ ] Backend: Evidence export (PDF/JSON)

---

## Phase 11 — Admin & Supervisor Features

### Deliverables
- [ ] Mobile: User management (ADMIN)
- [ ] Mobile: Kit configuration management
- [ ] Mobile: Supervisor dashboard (oversight, statistics)
- [ ] Backend: Reporting endpoints

---

## Phase 12 — Hardening & Polish

### Deliverables
- [ ] Security audit and penetration testing
- [ ] Performance optimization
- [ ] Accessibility review
- [ ] Edge case handling
- [ ] Error recovery flows
- [ ] Final documentation review
- [ ] Production deployment configuration

---

## Architectural Risks

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| 1 | **Colour consistency across devices** — Different phone cameras produce different colour profiles | Classification accuracy | Reference colour card calibration; document device variance |
| 2 | **Lighting conditions in the field** — Uncontrolled ambient lighting affects colour accuracy | Misclassification | Quality checks for exposure/brightness; guidance overlays; INCONCLUSIVE for ambiguous cases |
| 3 | **Offline data conflicts** — Tests created offline may conflict on sync | Data integrity | Client-generated UUIDs; idempotent sync; PENDING_SYNC state; conflict resolution |
| 4 | **No validated training data** — No real drug test image datasets available initially | Cannot train real models | Configuration-driven classification; demo data clearly labelled; framework ready for real data |
| 5 | **Evidence legal validity** — Digital signatures and chain of custody may not meet jurisdictional requirements | Legal admissibility | Signing abstraction for KMS/HSM upgrade; audit trail; consultation with legal/forensic experts |
| 6 | **S3-compatible storage availability** — Field deployments may lack cloud access | Image storage | Offline queue; local image retention until sync; configurable storage backends |
| 7 | **iOS build not testable on Windows** — No macOS available for initial development | iOS compatibility gaps | Cross-platform architecture from day one; iOS testing deferred to macOS phase |
| 8 | **Camera API fragmentation** — Different Android devices have varying camera capabilities | Capture quality | camera plugin abstraction; minimum device requirements; quality validation |
| 9 | **GPS accuracy in indoor/urban environments** — GPS may be inaccurate inside buildings | Location data quality | Record GPS accuracy value; allow manual location entry; don't make GPS blocking |
| 10 | **Key management for signing** — Hardcoded keys are insecure; KMS/HSM adds complexity | Security | Signing abstraction from Phase 6; env-variable keys for dev; KMS integration path |

---

## Required Development Tools

### Already Available (Verified)

| Tool | Version | Status |
|---|---|---|
| Flutter | 3.47.1 (stable) | ✅ |
| Dart | 3.13.1 | ✅ |
| Node.js | v24.21.0 | ✅ |
| npm | 11.19.0 | ✅ |
| Python | 3.14.7 | ✅ |
| pip | 26.2.1 | ✅ |
| Docker | 29.8.0 | ✅ |
| Docker Compose | v5.5.1 | ✅ |
| Git | 2.55.0 | ✅ |
| ADB | 1.0.41 | ✅ |
| Android SDK | 37.0.0 | ✅ |
| Java (JDK) | 21.0.12.1 | ✅ |
| Chrome | 153.x | ✅ |

### To Be Installed / Configured

| Tool | Purpose | When Needed |
|---|---|---|
| NestJS CLI | `npm i -g @nestjs/cli` | Phase 0 |
| Prisma CLI | Via `npx prisma` (no global install needed) | Phase 0 |
| MinIO (Docker) | S3-compatible dev storage | Phase 0 |
| ruff | Python linter (`pip install ruff`) | Phase 0 |
| mypy | Python type checker (`pip install mypy`) | Phase 0 |
| pytest | Python testing (`pip install pytest`) | Phase 0 |

---

## Verification Commands Reference

```powershell
# ==========================================
# Flutter (Mobile)
# ==========================================
cd apps/mobile
flutter pub get
flutter analyze                    # Static analysis
flutter test                       # Unit/widget tests
flutter build apk --debug         # Debug APK build
flutter run                        # Run on connected device

# ==========================================
# NestJS (API)
# ==========================================
cd apps/api
npm install
npm run lint                       # ESLint
npm run test                       # Unit tests
npm run test:e2e                   # E2E tests
npm run build                      # Production build
npm run start:dev                  # Dev server

# ==========================================
# Python (ML Service)
# ==========================================
cd apps/ml-service
pip install -r requirements.txt
ruff check .                       # Linting
mypy .                             # Type checking
pytest                             # Tests
uvicorn app.main:app --reload     # Dev server

# ==========================================
# Docker Infrastructure
# ==========================================
docker compose up -d               # Start all services
docker compose ps                  # Check status
docker compose logs -f api         # Follow API logs
docker compose logs -f ml-service  # Follow ML logs
docker compose down                # Stop all services

# ==========================================
# Full Suite
# ==========================================
scripts/lint-all.ps1               # Lint everything
scripts/test-all.ps1               # Test everything
```

---

## Dependencies Summary

### Flutter (`pubspec.yaml`)

| Package | Purpose |
|---|---|
| flutter_riverpod | State management |
| go_router | Declarative routing |
| dio | HTTP client |
| camera | Camera access |
| geolocator | GPS coordinates |
| permission_handler | Runtime permissions |
| image | Image manipulation |
| connectivity_plus | Network state monitoring |
| isar / isar_flutter_libs | Local database (offline) |
| flutter_secure_storage | Secure token storage |
| uuid | Client-side UUID generation |
| intl | Internationalization/formatting |
| freezed_annotation | Immutable models |
| json_annotation | JSON serialization |
| crypto | SHA-256 hashing |
| path_provider | File system paths |

### NestJS (`package.json`)

| Package | Purpose |
|---|---|
| @nestjs/jwt | JWT authentication |
| @nestjs/passport | Auth strategy framework |
| passport-jwt | JWT passport strategy |
| @nestjs/bullmq | Job queue integration |
| bullmq | Background job processing |
| @prisma/client | Database ORM |
| class-validator | DTO validation |
| class-transformer | DTO transformation |
| bcrypt | Password hashing |
| helmet | Security headers |
| @nestjs/throttler | Rate limiting |
| ioredis | Redis client |
| uuid | UUID generation |
| @aws-sdk/client-s3 | S3-compatible storage |

### Python (`requirements.txt`)

| Package | Purpose |
|---|---|
| fastapi | Web framework |
| uvicorn | ASGI server |
| opencv-python-headless | Image processing |
| numpy | Numerical computation |
| pillow | Image I/O |
| scikit-learn | Classification algorithms |
| pydantic | Data validation |
| python-multipart | File uploads |
| httpx | HTTP client (testing) |
| ruff | Linter |
| mypy | Type checker |
| pytest | Testing framework |
