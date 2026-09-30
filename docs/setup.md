# FieldSure — Development Setup Guide

## Prerequisites

Ensure the following tools are installed:

| Tool | Minimum Version | Install |
|---|---|---|
| Flutter | 3.47+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart | 3.13+ | Included with Flutter |
| Node.js | 24+ | [nodejs.org](https://nodejs.org/) |
| Python | 3.14+ | [python.org](https://python.org/) |
| Docker | 29+ | [docker.com](https://www.docker.com/products/docker-desktop/) |
| Docker Compose | 5+ | Included with Docker Desktop |
| Git | 2.50+ | [git-scm.com](https://git-scm.com/) |
| Android SDK | 37+ | Via Android Studio or standalone |
| ADB | 1.0.41+ | Included with Android SDK platform-tools |

### Verify Installation

```powershell
flutter --version
dart --version
node --version
npm --version
python --version
docker --version
docker compose version
git --version
adb version
```

## Clone and Setup

```powershell
# Clone the repository
git clone <repository-url> FieldSure
cd FieldSure

# Run the setup script (when available)
.\scripts\setup.ps1
```

## Manual Setup (Per Service)

### 1. Flutter Mobile App

```powershell
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run          # Requires connected device or emulator
```

### 2. NestJS API

```powershell
cd apps/api
npm install
cp .env.example .env    # Edit with local values
npm run lint
npm run test
npm run start:dev       # Starts on http://localhost:3000
```

### 3. Python ML Service

```powershell
cd apps/ml-service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
ruff check .
pytest
uvicorn app.main:app --reload --port 8000
```

### 4. Infrastructure (Docker)

```powershell
# From project root
cp .env.example .env    # Edit with local values
docker compose up -d

# Verify services
docker compose ps
```

This starts:
- PostgreSQL on port 5432
- Redis on port 6379
- MinIO on port 9000 (console: 9001)

### 5. Database Migrations

```powershell
cd apps/api
npx prisma migrate dev
npx prisma db seed       # Seeds admin user
```

## Connecting a Physical Android Device

1. Enable **Developer Options** on your Android phone
2. Enable **USB Debugging**
3. Connect phone via USB
4. Accept the debugging prompt on the phone
5. Verify connection:
   ```powershell
   adb devices
   ```
6. Run the app:
   ```powershell
   cd apps/mobile
   flutter run
   ```

## Environment Variables

Copy `.env.example` to `.env` in the project root and in `apps/api/`:

```bash
# See .env.example for all required variables
# NEVER commit .env files
```

## Common Issues

### Flutter doctor shows issues
```powershell
flutter doctor -v    # Detailed diagnostics
```

### Android device not detected
```powershell
adb kill-server
adb start-server
adb devices
```

### Port conflicts
Ensure ports 3000, 5432, 6379, 8000, 9000, 9001 are available.

### Docker memory
Ensure Docker Desktop has at least 4GB RAM allocated.

## IDE Recommendations

- **VS Code** with extensions:
  - Flutter
  - Dart
  - ESLint
  - Prettier
  - Python
  - Prisma
  - Docker
- **Android Studio** (alternative for Flutter development)
