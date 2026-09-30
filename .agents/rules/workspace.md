# FieldSure — Workspace Rules

## Project Identity

- **Name:** FieldSure — Digital Companion for Field Drug Testing
- **Tagline:** Capture. Verify. Record.
- **SIH Problem:** SIH26231
- **Organization:** Ministry of Home Affairs

## Architecture Rules

### Monorepo Structure

This project uses a monorepo with the following layout:

```
FieldSure/
├── apps/
│   ├── mobile/          # Flutter + Dart (Android & iOS)
│   ├── api/             # NestJS + TypeScript backend
│   └── ml-service/      # Python + FastAPI CV pipeline
├── packages/
│   ├── api-contracts/   # Shared API types/DTOs
│   └── shared-config/   # Shared configuration schemas
├── infrastructure/
│   ├── docker/          # Dockerfiles per service
│   └── scripts/         # Infrastructure automation
├── docs/                # Project documentation
├── scripts/             # Development scripts
├── .agents/rules/       # Agent workspace rules
├── .gitignore
├── README.md
└── docker-compose.yml
```

### Cross-Platform Mobile

- The mobile app is Flutter + Dart targeting both Android and iOS.
- Never create Android-only or iOS-only architecture.
- Use one shared Flutter codebase under `apps/mobile/`.
- Current development environment: Windows + physical Android device via USB/ADB.
- iOS build will be added later via macOS + Xcode.

### Backend Authority

- The backend (NestJS API) is **authoritative** for all security-sensitive operations.
- Never trust the mobile client for: operator identity, authoritative timestamps, classification results, evidence validity, or permissions.
- Private signing keys must never exist inside the Flutter application.
- Use a signing abstraction that can later integrate KMS/HSM.

## Coding Standards

### Flutter / Dart

- Use **Riverpod** for state management.
- Use **GoRouter** for navigation.
- Use **Dio** for HTTP requests.
- Use **Drift** (SQLite-based) for local offline storage.
- Follow the official Dart style guide.
- Run `dart analyze` and `flutter test` before committing.
- Structure code by feature, not by type:
  ```
  lib/
  ├── core/           # Shared utilities, theme, constants
  ├── features/
  │   ├── auth/
  │   ├── test/
  │   ├── camera/
  │   ├── evidence/
  │   ├── history/
  │   └── sync/
  ├── routing/
  └── main.dart
  ```

### NestJS / TypeScript

- Use **Prisma** as the ORM with PostgreSQL.
- Use **BullMQ** with **Redis** for async job processing.
- Follow NestJS module architecture.
- Validate all inputs with DTOs and class-validator.
- Use guards for RBAC enforcement.
- Run `npm run lint` and `npm run test` before committing.

### Python / FastAPI

- Use **OpenCV**, **NumPy**, **Pillow**, **scikit-learn** for the CV pipeline.
- Do not introduce PyTorch unless justified by validated data.
- Use **Pydantic** models for all API contracts.
- Run `ruff check`, `mypy`, and `pytest` before committing.
- Classification must be configuration-driven and kit-specific.

## Scientific Integrity

- **Never invent** drug-specific thresholds, chemical reaction values, laboratory validation, forensic validity, production accuracy, fake ML performance, or fake datasets.
- Classification must be **configuration-driven** and **kit-specific**.
- The system must always support `INCONCLUSIVE`.
- Poor-quality or ambiguous images must **never** be forcibly classified.
- Demo/placeholder classification data must be clearly identified as demonstration/validation configuration.
- All user-facing screens must display: _"Presumptive field-test result. Laboratory confirmation is required."_

## Security Standards

- Use JWT + refresh tokens for authentication.
- Use bcrypt or argon2 for password hashing.
- Implement RBAC for ADMIN, SUPERVISOR, OPERATOR roles.
- Validate all DTOs on the backend.
- Apply rate limiting on all public endpoints.
- Set CORS and security headers.
- Validate file uploads (type, size, magic bytes).
- Use SHA-256 for image integrity hashing.
- Use asymmetric digital signatures for evidence records.
- Log all audit events.
- Store secrets in environment variables, never in code.

## Database Rules

- Use PostgreSQL as the primary database.
- Use proper relationships, indexes, constraints, enums, timestamps, and foreign keys.
- Original image binaries must be stored in S3-compatible object storage, never directly in PostgreSQL.
- Use Prisma migrations for all schema changes.

## Testing Requirements

- Every phase must run tests and static analysis before completion.
- Never silently skip failed tests.
- Never claim a feature works unless it has been verified.

## Development Process

- Implement incrementally — never generate the entire application in one operation.
- Every phase must:
  1. Inspect existing code
  2. Implement only the required scope
  3. Run tests
  4. Run static analysis
  5. Verify builds
  6. Update documentation
  7. Report changed files
  8. Report known limitations

## UI Design Rules

- Primary orange: `#E87524`
- Deep orange: `#C95A12`
- Cream: `#FFF9F0`
- Surface: `#FFFDF9`
- Primary text: `#241A14`
- Secondary text: `#756B63`
- Border: `#E9DED2`
- Success: `#2E8B57`
- Warning: `#D98A00`
- Error: `#C93C37`
- Design must be professional, minimal, field-operation focused.
- High readability, one-hand friendly, generous whitespace, rounded cards, subtle shadows, clear hierarchy.
- No excessive gradients, no unnecessary glassmorphism, minimal animation.
- Primary actions: 56–60dp. Secondary actions: 48–52dp. Utility touch targets: ≥44–48dp.
