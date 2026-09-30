# FieldSure — Demo Guide

## Intended Audience
This guide is intended for operators and judges during the SIH26231 demonstration.

## Preparation
1. Ensure the backend services are running.
2. Run the database seed script to populate demo user accounts and synthetic history:
   ```bash
   pwsh scripts/seed-demo.ps1
   ```

## Demo Accounts
The following simulated identities have been provisioned in the local database:

**Operator (Demo User)**
- Email: `operator@fieldsure.local`
- Password: `Operator@123456`
- Role: OPERATOR

**Supervisor**
- Email: `supervisor@fieldsure.local`
- Password: `Super@123456`
- Role: SUPERVISOR

*Note: These credentials only function against the local demo database environment. They must not be reused in production.*

---

## Canonical Demo Scenario

To properly demonstrate the FieldSure workflow, perform the following steps sequentially.

### 1. Authentication
- Launch the FieldSure Android app.
- Login using the **Operator** credentials.
- Note the Dashboard displays the Operator's Badge ID, Name, and current Sync status.

### 2. Standard Workflow (Online)
- Tap **New Field Test**.
- Enter a demo **Case ID** (e.g., `DEMO-2026`) and **Sample ID** (e.g., `SMP-01`).
- Proceed to **Kit Selection**.
- Select the `Marquis Reagent (DEMO)` configuration.
- Follow the **Test Preparation** instructions and tap **Start Test**.
- Use the physical camera to capture a test image. Frame the hypothetical reference card and test region using the UI guide.
- **Confirm** the capture to transition to the processing state.
- Note the processing diagnostics loading from the API.
- Observe the generated **Classification Result** (e.g., POSITIVE, NEGATIVE, INCONCLUSIVE) which depends on the backend ML processing pipeline simulation.
- Tap **View Evidence Record** on the completed test.
- Tap **Verify Evidence** to trigger cryptographic signature checks confirming that the record has not been altered in transit or resting state.

### 3. History & Search
- Navigate to the **History** tab from the main Dashboard.
- Search for the Case ID or Sample ID you created.
- Review historical dummy data seeded earlier by the script.
- Notice status and sync indicators accurately reflect server truth.

### 4. Evidence Verification Failure (Tamper Demonstration)
To prove the cryptographic integrity of the system, you can deliberately tamper with a server record and observe the application detecting it.
- Ensure the app is currently displaying the Evidence Record for a seeded test (e.g., `FS-2026-000001`).
- Note that tapping **Verify Evidence** succeeds (`VERIFIED`).
- On the host machine, run the corruption script:
  ```bash
  pwsh scripts/corrupt-demo-evidence.ps1
  ```
- Tap **Verify Evidence** on the mobile application again.
- The application will now securely report **INTEGRITY_FAILED** with visual indicators showing exactly which hashes mismatch.

### 5. Offline Capture & Synchronization
- Disconnect the mobile device from Wi-Fi and Cellular networks (Airplane Mode).
- Start a **New Field Test** and complete the capture workflow.
- Notice that the test succeeds but displays **SYNC PENDING** or **Pending Sync**.
- Return to the Dashboard and verify the offline task sits in the pending queue.
- Re-enable Wi-Fi/Cellular data.
- The `SyncService` will automatically begin synchronizing the pending test.
- The test status will transition to **SYNCED** and gracefully appear on the server without creating duplicates.
