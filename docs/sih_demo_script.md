# FieldSure SIH Live Demonstration Script

*Target Duration: 2-3 Minutes*

### 0:00–0:20 — Problem
"Good morning, Judges. Currently, presumptive field-test kits like Marquis Reagent depend purely on the visual, subjective interpretation of the officer on the scene. Furthermore, they lack a digital chain of custody—there is no cryptographic proof connecting the test result to the operator, time, and location. To solve this, we built **FieldSure**."

### 0:20–0:45 — Capture
"FieldSure is a digital companion app. Watch as our Operator logs in. They enter the Case ID and select the specific test kit configuration. 
Using the smartphone camera, we frame the physical test result against our standard reference card. This on-screen guide ensures proper capture. I will now take the photo."

### 0:45–1:10 — Processing
"The image is immediately validated for lighting and blur. It is then securely transmitted to our backend.
*Note: For this demonstration, we are using a configured demo pipeline (`DEMO-CONFIG-v1`), not a scientifically validated production model, which requires lab-certified ground truth data.*
The system detects the reference card, calibrates the lighting, and returns a presumptive classification: Positive, Negative, or Inconclusive."

### 1:10–1:35 — Digital Evidence
"The most critical feature is the Evidence Record. 
FieldSure securely binds the operator's ID, the GPS coordinates, and the exact timestamp. It creates a SHA-256 hash of the image and canonicalizes the data before the authoritative server signs it cryptographically."

### 1:35–1:55 — Verification
"Because of this architecture, anyone can verify the integrity of the record. Let's tap 'Verify Evidence'.
As you can see, the record returns `VERIFIED`. If any single pixel of that image or character of that timestamp was tampered with, the cryptographic signature would break, returning `INTEGRITY_FAILED`."

### 1:55–2:20 — Operational Features
"Field operations often occur without internet access. If I switch this phone to Airplane Mode and capture a test, FieldSure safely stores the encrypted draft locally. When connectivity is restored, our idempotent sync engine automatically uploads the result without creating duplicates. You can see this reflected seamlessly in the searchable History view."

### 2:20–2:40 — Scientific Boundary
"To reiterate, FieldSure **does not replace laboratory confirmatory testing**. Our current classification pipeline is for demonstration and UX validation. However, our infrastructure is fully implemented and ready to ingest scientifically validated, kit-specific data. Thank you."
