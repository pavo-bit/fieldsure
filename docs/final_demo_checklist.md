# FieldSure — Final Demo Checklist

Use this checklist to ensure the demonstration environment is perfectly staged before presenting to judges.

### Before Demonstration

- [ ] **Docker Containers Running**: Ensure PostgreSQL and Redis (if used) are up and healthy.
- [ ] **NestJS Backend Running**: `npm run start` is actively listening.
- [ ] **Python ML Service Running**: FastAPI server is listening (or mock is properly intercepting).
- [ ] **Database Seeded**: Run `pwsh scripts/seed-demo.ps1` to populate demo data, clearing out unpredictable old artifacts.
- [ ] **Flutter App Installed**: App is cleanly installed on the Android device without corrupted local storage from previous builds.
- [ ] **Network Connected**: Mobile device and host server are on the same accessible network, and `AppConstants.apiBaseUrl` accurately reflects the host IP (not `localhost`).
- [ ] **Demo Guide Printed/Open**: Ensure you have `docs/demo_guide.md` open for following the canonical script exactly.
- [ ] **Credentials Ready**: Operator (`operator@fieldsure.local` / `Operator@123456`) memorized or accessible.

### During Demonstration

- [ ] Read the introductory problem statement and solution from `docs/sih_demo.md`.
- [ ] Emphasize that **"FieldSure does not replace laboratory confirmatory testing."**
- [ ] Log in clearly, highlighting the offline-session resilience.
- [ ] Create a New Field Test, emphasizing the Kit Configurations being pulled securely from the backend.
- [ ] Explain the camera masking and reference-card alignment during the Capture step.
- [ ] Point out the cryptographic hashing happening securely under the hood when viewing the Evidence Record.
- [ ] Show the "Verify Evidence" success state, confirming server signature.
- [ ] Transition the phone into airplane mode to demonstrate the "Pending Sync" offline state on a secondary test.
- [ ] Enable networking to demonstrate the robust duplicate-free Sync resolution.
- [ ] Use History to find the specific Case ID created during the demo.
