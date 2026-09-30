# Scientific and Technical Limitations

FieldSure is designed strictly as a presumptive digital companion. The following limitations apply universally to the CV/ML pipeline:

## 1. Dataset Limitations
The accuracy of any configuration-driven classification is bound entirely by the variance and scale of the training dataset.

## 2. Kit-Specific Nature
Models and threshold geometries are highly kit-specific. FieldSure cannot generalize visual reactions from a Marquis reagent test to a Cobalt Thiocyanate test.

## 3. Camera and Lighting Variability
Despite reference card calibration, extreme lighting (e.g., direct bright sunlight causing glare, pitch darkness, heavily tinted lighting) may produce out-of-distribution artifacts. The `INCONCLUSIVE` state exists to trap these occurrences safely.

## 4. Model Uncertainty & False Positives/Negatives
Colorimetric tests are fundamentally presumptive.
- **False Positives:** Non-illicit substances may share reactive properties.
- **False Negatives:** Adulterants or low concentrations may fail to trigger a noticeable reaction.
The model inherits the physical limitations of the underlying chemical test.

## 5. Requirement for Laboratory Confirmation
**FieldSure does not replace laboratory confirmatory testing (such as GC/MS).** All positive classifications require standard chain-of-custody transfer to a certified laboratory for legally admissible confirmation.
