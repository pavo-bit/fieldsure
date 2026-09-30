# FieldSure — Digital Companion for Field Drug Testing

> **Capture. Verify. Record.**

FieldSure is a cross-platform digital companion for existing colorimetric field drug-testing kits. It does **not** chemically detect drugs independently — the physical chemical test kit performs the reaction. FieldSure provides guided image capture, AI-powered interpretation, evidence-grade digital records, and searchable test history.

> ⚠️ **Presumptive field-test result. Laboratory confirmation is required.**

## SIH Problem

**SIH26231** — Ministry of Home Affairs

## Repository Structure

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
└── docker-compose.yml
```

## Technology Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter, Dart, Riverpod, GoRouter, Dio, Isar |
| Backend | NestJS, TypeScript, Prisma, PostgreSQL, Redis, BullMQ |
| CV / ML | Python, FastAPI, OpenCV, NumPy, Pillow, scikit-learn |
| Storage | S3-compatible object storage |
| Infrastructure | Docker, Docker Compose |

## Getting Started

See [docs/setup.md](docs/setup.md) for development environment setup.

See [docs/implementation_plan.md](docs/implementation_plan.md) for the phased implementation roadmap.

## User Roles

| Role | Description |
|---|---|
| ADMIN | System administration, user management, kit configuration |
| SUPERVISOR | Oversight, verification, reporting |
| OPERATOR | Field testing, image capture, evidence recording |

## Core Workflow

1. Operator logs in
2. Creates a new field test with case/sample information
3. Selects the test kit
4. Performs the physical chemical test
5. Captures images via guided camera (reference card + reaction)
6. FieldSure validates image quality and processes via CV pipeline
7. Kit-specific classification: **POSITIVE** / **NEGATIVE** / **INCONCLUSIVE**
8. Evidence record created with digital signature
9. Results searchable and verifiable

## Scientific Integrity

- Classification is configuration-driven and kit-specific
- Demo/placeholder data is clearly identified
- Ambiguous or poor-quality images are not forcibly classified
- No invented thresholds, fake datasets, or fabricated ML performance

## License

TBD

## Documentation

- [Architecture](docs/architecture.md)
- [Implementation Plan](docs/implementation_plan.md)
- [API Design](docs/api_design.md)
- [Database Schema](docs/database_schema.md)
- [CV Pipeline](docs/cv_pipeline.md)
- [Security](docs/security.md)
- [Setup Guide](docs/setup.md)
