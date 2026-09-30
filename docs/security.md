# FieldSure — Security Architecture

## Threat Model

FieldSure handles evidence-grade data in uncontrolled field environments. The security model must address:

| Threat | Description | Mitigation |
|---|---|---|
| Credential theft | Stolen device or shoulder-surfing | JWT with short expiry, secure storage, session management |
| Data tampering | Modification of test results or evidence | SHA-256 hashing, digital signatures, audit trail |
| Unauthorized access | Accessing another operator's data | RBAC, resource ownership checks |
| Man-in-the-middle | Network interception | HTTPS/TLS, certificate pinning (future) |
| Replay attacks | Replaying captured requests | Nonce/timestamp validation, idempotency keys |
| Image forgery | Submitting manipulated images | Server-side hashing, metadata validation |
| Privilege escalation | Operator acting as admin | Server-side RBAC enforcement, DTO validation |
| Offline data exposure | Data on lost device | Encrypted local storage, minimal offline data |

## Authentication

### JWT Strategy

- **Access token:** Short-lived (15 minutes)
- **Refresh token:** Longer-lived (7 days), stored securely, single-use rotation
- **Algorithm:** RS256 (asymmetric) preferred, HS256 acceptable for development
- **Claims:** user ID, role, device ID, issued-at, expiry

### Token Storage (Mobile)

- Use `flutter_secure_storage` (Keychain on iOS, EncryptedSharedPreferences on Android)
- Never store tokens in plain SharedPreferences
- Clear tokens on logout

### Token Refresh Flow

```mermaid
sequenceDiagram
    participant App as Mobile App
    participant API as API Server

    App->>API: Request with expired access token
    API-->>App: 401 Unauthorized
    App->>API: POST /auth/refresh (refresh token)
    API->>API: Validate refresh token
    API->>API: Rotate refresh token
    API-->>App: New access token + new refresh token
    App->>API: Retry original request
```

## Authorization (RBAC)

### Role Hierarchy

| Permission | OPERATOR | SUPERVISOR | ADMIN |
|---|---|---|---|
| Create tests | ✅ | ✅ | ✅ |
| View own tests | ✅ | ✅ | ✅ |
| View all tests | ❌ | ✅ | ✅ |
| Verify evidence | ❌ | ✅ | ✅ |
| View audit logs | ❌ | ✅ | ✅ |
| Manage users | ❌ | ❌ | ✅ |
| Manage kits | ❌ | ❌ | ✅ |
| Manage configs | ❌ | ❌ | ✅ |
| System settings | ❌ | ❌ | ✅ |

### Implementation

```typescript
// Guard decorator usage
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@Post('users')
createUser(@Body() dto: CreateUserDto) { ... }
```

## Password Security

- **Hashing:** bcrypt with cost factor ≥ 12
- **Policy:** Minimum 8 characters, complexity requirements
- **No plaintext:** Passwords never logged or returned in responses
- **Rate limiting:** Max 5 login attempts per 15 minutes per IP

## Data Integrity

### Image Integrity

1. Client captures image
2. Client computes SHA-256 hash (for local verification)
3. Image uploaded to server
4. **Server independently computes SHA-256 hash** (authoritative)
5. Hash stored in `test_images.sha256_hash`
6. Original image stored in S3

### Evidence Integrity

1. Evidence record fields assembled
2. Fields serialized to canonical JSON (sorted keys, no whitespace)
3. SHA-256 hash computed → `record_hash`
4. Signing service signs the hash → `signature`
5. Signature + key ID stored in evidence record

### Verification

1. Re-serialize evidence fields to canonical JSON
2. Re-compute SHA-256
3. Compare with stored `record_hash`
4. Verify signature using public key

## Digital Signatures

### Abstraction Layer

```typescript
interface SigningService {
  sign(data: Buffer): Promise<SigningResult>;
  verify(data: Buffer, signature: string, keyId: string): Promise<boolean>;
  getPublicKey(keyId: string): Promise<string>;
}

interface SigningResult {
  signature: string;  // Base64-encoded
  keyId: string;      // Key identifier for verification
  algorithm: string;  // e.g., "RSA-SHA256", "ECDSA-SHA256"
}
```

### Implementation Roadmap

| Phase | Implementation | Key Storage |
|---|---|---|
| Development | `LocalSigningService` | File-based RSA keys via env vars |
| Staging | `KmsSigningService` | AWS KMS / Azure Key Vault |
| Production | `HsmSigningService` | Hardware Security Module |

### Key Requirements

- **Private keys** never in mobile app, never in source code
- **Key rotation** supported via key ID tracking
- **Algorithm:** RSA-2048 + SHA-256 minimum; ECDSA P-256 preferred
- **Key IDs** stored with every signature for multi-key support

## Input Validation

### API Layer

- All DTOs validated with `class-validator`
- Global `ValidationPipe` with `whitelist: true, forbidNonWhitelisted: true`
- File uploads validated: type (JPEG/PNG), size (< 20MB), magic bytes

### File Upload Security

```typescript
// Validation checks for uploaded images
- MIME type: image/jpeg, image/png only
- File size: max 20MB
- Magic bytes: verify file header matches declared type
- Filename: sanitize, generate server-side name
- Storage: S3 with private ACL, pre-signed URLs for retrieval
```

## Network Security

### Backend Headers (Helmet)

- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Strict-Transport-Security` (production)
- `Content-Security-Policy`

### CORS

- Whitelist specific origins (no `*` in production)
- Restrict methods and headers

### Rate Limiting

| Endpoint Group | Limit |
|---|---|
| Auth endpoints | 5 req/15 min per IP |
| API endpoints | 100 req/min per user |
| File uploads | 10 req/min per user |

## Audit Logging

### What Gets Logged

Every security-relevant action is recorded in `audit_logs`:

- Authentication events (login, logout, failed login)
- Data access (record viewed, evidence verified)
- Data modification (test created, image uploaded)
- Administrative actions (user created, kit modified)
- System events (processing started, sync completed)
- Errors (with sanitized details)

### What Gets Captured

- Event type
- Actor (user ID)
- Resource (type + ID)
- IP address
- User agent
- Timestamp (server)
- Details (event-specific metadata)

### Retention

- Audit logs are immutable — no UPDATE or DELETE operations
- Retention period: configurable (minimum 1 year recommended)

## Environment Variables

All secrets and configuration via environment variables:

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/fieldsure

# JWT
JWT_SECRET=<random-256-bit-key>
JWT_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d

# Signing
SIGNING_PRIVATE_KEY_PATH=/keys/private.pem
SIGNING_PUBLIC_KEY_PATH=/keys/public.pem
SIGNING_ALGORITHM=RSA-SHA256

# S3
S3_ENDPOINT=http://minio:9000
S3_ACCESS_KEY=<key>
S3_SECRET_KEY=<secret>
S3_BUCKET=fieldsure-images

# Redis
REDIS_URL=redis://redis:6379

# ML Service
ML_SERVICE_URL=http://ml-service:8000
```

Never commit `.env` files. Use `.env.example` as a template.
