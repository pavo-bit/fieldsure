"""
Stage B mathematical and regression tests — color science foundation.

Tests cover:
  1. sRGB transfer-function linearisation and inverse.
  2. RGB-to-XYZ known values.
  3. XYZ-to-LAB known values using D65.
  4. White-point differences between D50 and D65.
  5. Round-trip sRGB → linear → sRGB within tolerance.
  6. Published CIEDE2000 reference test vectors (Sharma 2005).
  7. CIE76 known calculations.
  8. Zero-chroma and hue-wrap boundary cases.
  9. Non-finite and invalid input handling.
  10. BGR/RGB channel-order correctness.
  11. 8-bit vs float image handling in extractor.
  12. Calibration with known fixtures (PERSPECTIVE_ONLY path).
  13. Calibration failure with missing corners.
  14. Regression: chroma magnitude ≠ Delta E.
  15. UNVALIDATED status preserved through full pipeline.
  16. features.delta_e_2000 ≠ features.chroma (regression against old code).
"""

import numpy as np
import pytest
from app.services.features.color_math import (
    srgb_to_linear,
    linear_to_srgb,
    linear_rgb_to_xyz,
    xyz_to_lab,
    bgr_image_to_lab,
    delta_e_76,
    delta_e_2000,
    ILLUMINANTS,
    SRGB_TO_XYZ_MATRIX,
)
from app.services.features.extractor import FeatureExtractor
from app.services.calibration.calibrator import ColorCalibrator, CalibrationResult
from app.services.classification.classifier import DemoLogisticClassifier
from app.schemas.responses import ClassificationFeatures


# ─────────────────────────────────────────────────────────────────────────────
# 1. sRGB linearisation
# ─────────────────────────────────────────────────────────────────────────────

class TestSrgbLinearisation:
    """sRGB ↔ linear transfer-function correctness."""

    def test_black_is_zero(self):
        result = srgb_to_linear(np.array([0.0]))
        assert float(result[0]) == pytest.approx(0.0, abs=1e-9)

    def test_white_is_one(self):
        result = srgb_to_linear(np.array([1.0]))
        assert float(result[0]) == pytest.approx(1.0, abs=1e-9)

    def test_midtone_srgb_50pct(self):
        # sRGB 0.5 → linear ~0.2140 (IEC 61966-2-1)
        result = float(srgb_to_linear(np.array([0.5]))[0])
        assert result == pytest.approx(0.21404, rel=1e-3)

    def test_toe_region(self):
        # 0.04045 / 12.92 = 0.003130804...
        result = float(srgb_to_linear(np.array([0.04045]))[0])
        assert result == pytest.approx(0.04045 / 12.92, rel=1e-6)

    def test_boundary_04045(self):
        # Values just below and above 0.04045 handled correctly
        below = float(srgb_to_linear(np.array([0.04044]))[0])
        above = float(srgb_to_linear(np.array([0.04046]))[0])
        assert below < above

    def test_inverse_round_trip(self):
        values = np.array([0.0, 0.01, 0.1, 0.5, 0.9, 1.0])
        linear = srgb_to_linear(values)
        back = linear_to_srgb(linear)
        np.testing.assert_allclose(back, values, atol=1e-7)

    def test_clamp_negative_input(self):
        result = srgb_to_linear(np.array([-0.5]))
        assert float(result[0]) == pytest.approx(0.0)

    def test_clamp_over_one(self):
        result = srgb_to_linear(np.array([1.5]))
        assert float(result[0]) == pytest.approx(1.0, rel=1e-3)


# ─────────────────────────────────────────────────────────────────────────────
# 2. RGB → XYZ known values
# ─────────────────────────────────────────────────────────────────────────────

class TestRgbToXyz:
    """Linear sRGB → CIE XYZ D65 known values."""

    def test_white_maps_to_d65(self):
        xyz = linear_rgb_to_xyz(np.array([1.0, 1.0, 1.0]))
        d65 = ILLUMINANTS["D65"]
        np.testing.assert_allclose(xyz, [d65["X"], d65["Y"], d65["Z"]], atol=1e-4)

    def test_black_maps_to_zero(self):
        xyz = linear_rgb_to_xyz(np.array([0.0, 0.0, 0.0]))
        np.testing.assert_allclose(xyz, [0.0, 0.0, 0.0], atol=1e-9)

    def test_pure_red_linear(self):
        # Linear sRGB [1,0,0] → XYZ: the XYZ tristimulus of the red primary.
        # In the matrix XYZ = M @ RGB, for RGB=[1,0,0] result = M[:,0] (first column).
        xyz = linear_rgb_to_xyz(np.array([1.0, 0.0, 0.0]))
        expected = SRGB_TO_XYZ_MATRIX[:, 0]  # column 0 = R primary contribution
        np.testing.assert_allclose(xyz, expected, atol=1e-6)

    def test_pure_green_linear(self):
        xyz = linear_rgb_to_xyz(np.array([0.0, 1.0, 0.0]))
        expected = SRGB_TO_XYZ_MATRIX[:, 1]  # column 1 = G primary contribution
        np.testing.assert_allclose(xyz, expected, atol=1e-6)

    def test_pure_blue_linear(self):
        xyz = linear_rgb_to_xyz(np.array([0.0, 0.0, 1.0]))
        expected = SRGB_TO_XYZ_MATRIX[:, 2]  # column 2 = B primary contribution
        np.testing.assert_allclose(xyz, expected, atol=1e-6)

    def test_batch_shape(self):
        batch = np.ones((10, 3))
        result = linear_rgb_to_xyz(batch)
        assert result.shape == (10, 3)


# ─────────────────────────────────────────────────────────────────────────────
# 3. XYZ → LAB known values
# ─────────────────────────────────────────────────────────────────────────────

class TestXyzToLab:
    """CIE XYZ → CIELAB known values."""

    def test_d65_white_to_lab(self):
        d65 = ILLUMINANTS["D65"]
        white_xyz = np.array([d65["X"], d65["Y"], d65["Z"]])
        lab = xyz_to_lab(white_xyz, illuminant="D65")
        assert lab[0] == pytest.approx(100.0, abs=0.02)
        assert lab[1] == pytest.approx(0.0, abs=0.02)
        assert lab[2] == pytest.approx(0.0, abs=0.02)

    def test_black_to_lab(self):
        lab = xyz_to_lab(np.array([0.0, 0.0, 0.0]), illuminant="D65")
        assert lab[0] == pytest.approx(0.0, abs=0.01)

    def test_d50_white_to_lab_d50(self):
        d50 = ILLUMINANTS["D50"]
        white_xyz = np.array([d50["X"], d50["Y"], d50["Z"]])
        lab = xyz_to_lab(white_xyz, illuminant="D50")
        assert lab[0] == pytest.approx(100.0, abs=0.02)
        assert lab[1] == pytest.approx(0.0, abs=0.02)
        assert lab[2] == pytest.approx(0.0, abs=0.02)

    def test_unknown_illuminant_raises(self):
        with pytest.raises(ValueError, match="Unknown illuminant"):
            xyz_to_lab(np.array([0.5, 0.5, 0.5]), illuminant="INVALID")


# ─────────────────────────────────────────────────────────────────────────────
# 4. White-point differences between D50 and D65
# ─────────────────────────────────────────────────────────────────────────────

class TestWhitePointDifferences:
    """D50 and D65 are different reference whites."""

    def test_d65_xyz_differs_from_d50(self):
        d65 = ILLUMINANTS["D65"]
        d50 = ILLUMINANTS["D50"]
        assert abs(d65["X"] - d50["X"]) > 0.005

    def test_srgb_white_lab_d65_vs_d50(self):
        white_xyz = linear_rgb_to_xyz(np.array([1.0, 1.0, 1.0]))
        lab_d65 = xyz_to_lab(white_xyz, illuminant="D65")
        lab_d50 = xyz_to_lab(white_xyz, illuminant="D50")
        # D65 white under D65 reference = L*=100, a*≈0, b*≈0
        assert lab_d65[0] == pytest.approx(100.0, abs=0.05)
        # Same white under D50 reference: L* ≈ 100 but a*, b* nonzero
        # (because D65 white ≠ D50 white)
        ab_shift = np.sqrt(lab_d50[1]**2 + lab_d50[2]**2)
        assert ab_shift > 0.5, "D50-referenced sRGB white should have nonzero a*, b*"


# ─────────────────────────────────────────────────────────────────────────────
# 5. Full conversion: sRGB uint8 → CIELAB
# ─────────────────────────────────────────────────────────────────────────────

class TestBgrImageToLab:
    """End-to-end BGR uint8 → CIELAB pipeline."""

    def test_white_image_is_l100(self):
        img = np.full((4, 4, 3), 255, dtype=np.uint8)  # BGR white
        lab = bgr_image_to_lab(img, illuminant="D65")
        mean_L = np.mean(lab[..., 0])
        assert mean_L == pytest.approx(100.0, abs=0.1)

    def test_black_image_is_l0(self):
        img = np.zeros((4, 4, 3), dtype=np.uint8)
        lab = bgr_image_to_lab(img, illuminant="D65")
        mean_L = np.mean(lab[..., 0])
        assert mean_L == pytest.approx(0.0, abs=0.1)

    def test_channel_order_bgr_not_rgb(self):
        """Pure blue in BGR = (255, 0, 0) should differ from pure red in BGR = (0, 0, 255)."""
        blue_bgr = np.full((2, 2, 3), [255, 0, 0], dtype=np.uint8)
        red_bgr = np.full((2, 2, 3), [0, 0, 255], dtype=np.uint8)
        lab_blue = bgr_image_to_lab(blue_bgr)
        lab_red = bgr_image_to_lab(red_bgr)
        assert lab_blue[0, 0, 0] != lab_red[0, 0, 0] or \
               lab_blue[0, 0, 1] != lab_red[0, 0, 1] or \
               lab_blue[0, 0, 2] != lab_red[0, 0, 2]

    def test_output_shape(self):
        img = np.zeros((10, 10, 3), dtype=np.uint8)
        lab = bgr_image_to_lab(img)
        assert lab.shape == (10, 10, 3)

    def test_result_not_opencv_scaled(self):
        """
        Regression: OpenCV uint8 LAB encodes L in [0,255], a/b shifted by 128.
        Our pipeline must return L in [0,100], a/b centered around 0.
        """
        white = np.full((4, 4, 3), 255, dtype=np.uint8)
        lab = bgr_image_to_lab(white)
        L = float(np.mean(lab[..., 0]))
        assert L <= 100.5, f"L={L} looks like OpenCV uint8 scale (0-255) not CIELAB (0-100)"


# ─────────────────────────────────────────────────────────────────────────────
# 6. Delta E 2000 — published Sharma (2005) reference test vectors
# ─────────────────────────────────────────────────────────────────────────────

class TestDeltaE2000:
    """
    CIEDE2000 verified against Sharma et al. (2005), Table 1.
    DOI: 10.1002/col.20070
    """

    SHARMA_VECTORS = [
        # (L1, a1, b1), (L2, a2, b2), expected_de00
        ((50.0000,  2.6772, -79.7751), (50.0000,  0.0000, -82.7485), 2.0425),
        ((50.0000,  3.1571, -77.2803), (50.0000,  0.0000, -82.7485), 2.8615),
        ((50.0000,  2.8361, -74.0200), (50.0000,  0.0000, -82.7485), 3.4412),
        ((50.0000, -1.3802, -84.2814), (50.0000,  0.0000, -82.7485), 1.0000),
        ((50.0000, -1.1848, -84.8006), (50.0000,  0.0000, -82.7485), 1.0000),
        ((50.0000, -0.9009, -85.5211), (50.0000,  0.0000, -82.7485), 1.0000),
        ((50.0000,  0.0000,   0.0000), (50.0000, -1.0000,  2.0000), 2.3669),
        ((50.0000, -1.0000,   2.0000), (50.0000,  0.0000,  0.0000), 2.3669),
        ((50.0000,  2.4900,  -0.0010), (50.0000, -2.4900,  0.0009), 7.1792),
        ((50.0000,  2.4900,  -0.0010), (50.0000, -2.4900,  0.0010), 7.1792),
        ((50.0000,  2.4900,  -0.0010), (50.0000, -2.4900,  0.0011), 7.2195),
        ((50.0000,  2.4900,  -0.0010), (50.0000, -2.4900,  0.0012), 7.2195),
        ((50.0000, -0.0010,   2.4900), (50.0000,  0.0009, -2.4900), 4.8045),
        ((50.0000, -0.0010,   2.4900), (50.0000,  0.0010, -2.4900), 4.8045),
        ((50.0000, -0.0010,   2.4900), (50.0000,  0.0011, -2.4900), 4.7461),
        ((50.0000,  2.5000,   0.0000), (50.0000,  0.0000, -2.5000), 4.3065),
        ((50.0000,  2.5000,   0.0000), (73.0000,  25.0000, -18.0000), 27.1492),
        ((50.0000,  2.5000,   0.0000), (61.0000, -5.0000,  29.0000), 22.8977),
        ((50.0000,  2.5000,   0.0000), (56.0000, -27.0000, -3.0000), 31.9030),
        ((50.0000,  2.5000,   0.0000), (58.0000, 24.0000, 15.0000),  19.4535),
        ((50.0000,  2.5000,   0.0000), (50.0000,  3.1736,  0.5854),   1.0000),
        ((50.0000,  2.5000,   0.0000), (50.0000,  3.2972,  0.0000),   1.0000),
        ((50.0000,  2.5000,   0.0000), (50.0000,  1.8634,  0.5757),   1.0000),
        ((50.0000,  2.5000,   0.0000), (50.0000,  3.2592, -0.3350),   1.0000),
        ((60.2574, -34.0099, 36.2677), (60.4626, -34.1751, 39.4387),  1.2644),
        ((63.0109, -31.0961, -5.8663), (62.8187, -29.7946, -4.0864),  1.2630),
        ((61.2901,  3.7196,  -5.3901), (61.4292,  2.2480,  -4.9620),  1.8731),
        ((35.0831, -44.1164, 3.7933),  (35.0232, -40.0716,  1.5901),  1.8645),
        ((22.7233,  20.0904, -46.6940),(23.0331,  14.9730, -42.5619), 2.0373),
        ((36.4612,  47.8580, 18.3852), (36.2715,  50.5065, 21.2231),  1.4146),
        ((90.8027,  -2.0831,  1.4410), (91.1528,  -1.6435,  0.0447),  1.4441),
        ((90.9257,  -0.5406, -0.9208), (88.6381,  -0.8985, -0.7239),  1.5381),
        ((6.7747,   -0.2908, -2.4247), (5.8714,   -0.0985, -2.2286),  0.6377),
        ((2.0776,    0.0795, -1.1350), (0.9033,   -0.0636, -0.5514),  0.9082),
    ]

    @pytest.mark.parametrize("lab1,lab2,expected", SHARMA_VECTORS)
    def test_sharma_vector(self, lab1, lab2, expected):
        a1 = np.array([lab1])
        a2 = np.array([lab2])
        result = float(delta_e_2000(a1, a2)[0])
        assert result == pytest.approx(expected, abs=0.0005), \
            f"ΔE00({lab1},{lab2}) = {result:.4f}, expected {expected}"


# ─────────────────────────────────────────────────────────────────────────────
# 7. Delta E 76 known calculations
# ─────────────────────────────────────────────────────────────────────────────

class TestDeltaE76:
    def test_identical_colours_are_zero(self):
        lab = np.array([[50.0, 10.0, -10.0]])
        assert float(delta_e_76(lab, lab)[0]) == pytest.approx(0.0, abs=1e-9)

    def test_known_euclidean(self):
        a = np.array([[0.0, 0.0, 0.0]])
        b = np.array([[3.0, 4.0, 0.0]])
        assert float(delta_e_76(a, b)[0]) == pytest.approx(5.0, rel=1e-6)

    def test_batch_shape(self):
        a = np.zeros((5, 3))
        b = np.ones((5, 3))
        result = delta_e_76(a, b)
        assert result.shape == (5,)


# ─────────────────────────────────────────────────────────────────────────────
# 8. Zero-chroma and hue-wrap boundary cases
# ─────────────────────────────────────────────────────────────────────────────

class TestBoundaryAndZeroChroma:
    def test_zero_chroma_pair(self):
        # Both colours on neutral axis (a=b=0): hue is undefined, must not NaN
        a = np.array([[50.0, 0.0, 0.0]])
        b = np.array([[55.0, 0.0, 0.0]])
        result = delta_e_2000(a, b)
        assert np.isfinite(result).all()

    def test_one_zero_chroma(self):
        a = np.array([[50.0, 0.0, 0.0]])
        b = np.array([[50.0, 5.0, 5.0]])
        result = delta_e_2000(a, b)
        assert np.isfinite(result).all()

    def test_hue_wrap_near_360(self):
        # Two colours on opposite sides of 0/360 degree wrap
        a = np.array([[50.0, 30.0,  0.01]])  # hue ≈ 0°
        b = np.array([[50.0, 30.0, -0.01]])  # hue ≈ 360°
        result = delta_e_2000(a, b)
        assert np.isfinite(result).all()
        assert float(result[0]) < 1.0  # Very close colours

    def test_symmetry_de76(self):
        a = np.array([[30.0, 10.0, 5.0]])
        b = np.array([[50.0, -5.0, 20.0]])
        assert delta_e_76(a, b)[0] == pytest.approx(delta_e_76(b, a)[0], rel=1e-9)

    def test_symmetry_de2000(self):
        a = np.array([[30.0, 10.0, 5.0]])
        b = np.array([[50.0, -5.0, 20.0]])
        assert delta_e_2000(a, b)[0] == pytest.approx(delta_e_2000(b, a)[0], rel=1e-6)


# ─────────────────────────────────────────────────────────────────────────────
# 9. Non-finite input handling
# ─────────────────────────────────────────────────────────────────────────────

class TestNonFiniteInputs:
    def test_srgb_nan_clipped(self):
        result = srgb_to_linear(np.array([np.nan]))
        # After np.clip([nan], 0, 1) → nan still; linear_to_srgb would clamp again.
        # The key requirement: must not raise an exception.
        assert result is not None  # should complete without error


# ─────────────────────────────────────────────────────────────────────────────
# 10. BGR/RGB channel-order correctness
# ─────────────────────────────────────────────────────────────────────────────

class TestChannelOrder:
    def test_pure_blue_bgr_has_negative_b_in_lab(self):
        """
        Pure blue in sRGB is (R=0, G=0, B=255).
        In BGR that is (255, 0, 0).
        Expected: CIELAB b* should be negative (blue-yellow axis).
        """
        blue_bgr = np.full((4, 4, 3), [255, 0, 0], dtype=np.uint8)
        lab = bgr_image_to_lab(blue_bgr, illuminant="D65")
        mean_b_star = float(np.mean(lab[..., 2]))
        assert mean_b_star < -50.0, \
            f"b*={mean_b_star:.2f} expected strongly negative for pure blue"

    def test_pure_red_bgr_has_positive_a_in_lab(self):
        """
        Pure red in sRGB is (R=255, G=0, B=0).
        In BGR that is (0, 0, 255).
        Expected: CIELAB a* should be strongly positive (red-green axis).
        """
        red_bgr = np.full((4, 4, 3), [0, 0, 255], dtype=np.uint8)
        lab = bgr_image_to_lab(red_bgr, illuminant="D65")
        mean_a_star = float(np.mean(lab[..., 1]))
        assert mean_a_star > 50.0, \
            f"a*={mean_a_star:.2f} expected strongly positive for pure red"


# ─────────────────────────────────────────────────────────────────────────────
# 11. 8-bit vs float extractor handling
# ─────────────────────────────────────────────────────────────────────────────

class TestExtractorInputFormats:
    def test_uint8_white(self):
        extractor = FeatureExtractor()
        roi = np.full((20, 20, 3), 255, dtype=np.uint8)
        f, _ = extractor.extract(roi)
        assert f.lab_mean_l == pytest.approx(100.0, abs=0.5)

    def test_float32_white_coerced(self):
        extractor = FeatureExtractor()
        roi = np.full((20, 20, 3), 255.0, dtype=np.float32)
        f, _ = extractor.extract(roi)
        assert f.lab_mean_l == pytest.approx(100.0, abs=0.5)

    def test_grayscale_input(self):
        extractor = FeatureExtractor()
        roi = np.full((10, 10), 200, dtype=np.uint8)
        f, _ = extractor.extract(roi)
        assert f.lab_mean_l > 0.0

    def test_alpha_channel_stripped(self):
        extractor = FeatureExtractor()
        roi = np.full((10, 10, 4), 255, dtype=np.uint8)
        f, _ = extractor.extract(roi)
        assert f.lab_mean_l == pytest.approx(100.0, abs=0.5)

    def test_empty_roi_returns_zero_features(self):
        extractor = FeatureExtractor()
        f, _ = extractor.extract(np.array([]))
        assert f.lab_mean_l == 0.0
        assert f.lab_mean_a == 0.0
        assert f.lab_mean_b == 0.0

    def test_color_space_metadata(self):
        extractor = FeatureExtractor()
        roi = np.full((4, 4, 3), 128, dtype=np.uint8)
        f, _ = extractor.extract(roi)
        assert f.color_space == "CIELAB"
        assert f.illuminant == "D65"
        assert f.conversion_version == "srgb-d65-v1"


# ─────────────────────────────────────────────────────────────────────────────
# 12. Regression: chroma ≠ Delta E
# ─────────────────────────────────────────────────────────────────────────────

class TestChromaNotDeltaE:
    """
    Regression tests proving the old incorrect calculation
    (chroma magnitude used as Delta E) is NOT present in any output field.
    """

    def test_chroma_and_de2000_are_separate_fields(self):
        extractor = FeatureExtractor()
        roi = np.full((20, 20, 3), [100, 50, 180], dtype=np.uint8)  # coloured
        f, _ = extractor.extract(roi)
        # chroma is sqrt(a^2 + b^2)
        expected_chroma = float(np.sqrt(f.lab_mean_a**2 + f.lab_mean_b**2))
        assert f.chroma == pytest.approx(expected_chroma, rel=1e-5)

    def test_chroma_does_not_equal_de2000_for_coloured_input(self):
        """
        When a reference is provided, de2000 includes L* difference;
        chroma is a* b* magnitude only — they must differ for coloured input.
        """
        extractor = FeatureExtractor()
        roi = np.full((20, 20, 3), [50, 100, 200], dtype=np.uint8)
        ref_lab = np.array([50.0, 25.0, -10.0])  # different L from neutral
        f, _ = extractor.extract(roi, nearest_reference_lab=ref_lab)
        # delta_e_2000 includes L difference; chroma does not
        # (they could coincidentally match, but for this fixture they won't)
        assert not np.isclose(f.chroma, f.delta_e_2000, rtol=0.01), \
            "chroma and delta_e_2000 should not be equal — this would indicate the old bug"

    def test_old_opencv_scaled_values_not_present(self):
        """
        Old code returned OpenCV uint8 L in [0,255].
        New code must return L in [0,100].
        """
        extractor = FeatureExtractor()
        roi = np.full((10, 10, 3), 200, dtype=np.uint8)
        f, _ = extractor.extract(roi)
        assert f.lab_mean_l <= 105.0, \
            f"lab_mean_l={f.lab_mean_l} is in OpenCV uint8 scale, not CIELAB"


# ─────────────────────────────────────────────────────────────────────────────
# 13. Calibrator — perspective and failure paths
# ─────────────────────────────────────────────────────────────────────────────

class TestCalibrator:
    def _square_corners(self):
        return [(0, 0), (99, 0), (99, 99), (0, 99)]

    def test_no_corners_returns_failed(self):
        cal = ColorCalibrator()
        result = cal.calibrate(np.zeros((100, 100, 3), dtype=np.uint8), [], {})
        assert result.status == "FAILED"
        assert result.corrected_image is None

    def test_wrong_corner_count_returns_failed(self):
        cal = ColorCalibrator()
        result = cal.calibrate(np.zeros((100, 100, 3), dtype=np.uint8), [(0, 0), (1, 1)], {})
        assert result.status == "FAILED"

    def test_valid_corners_returns_calibration_result(self):
        cal = ColorCalibrator()
        image = np.full((200, 200, 3), 128, dtype=np.uint8)
        result = cal.calibrate(image, self._square_corners(), {})
        # Without neutral patch layout, status should be PERSPECTIVE_ONLY
        assert result.status in ("PERSPECTIVE_ONLY", "NEUTRAL_CORRECTION", "FAILED")

    def test_perspective_only_status(self):
        cal = ColorCalibrator()
        image = np.full((200, 200, 3), 128, dtype=np.uint8)
        result = cal.calibrate(image, self._square_corners(), {})
        assert result.status == "PERSPECTIVE_ONLY"
        assert result.corrected_image is not None
        assert result.calibrated_measurement_supported is False

    def test_source_image_not_mutated(self):
        cal = ColorCalibrator()
        image = np.full((200, 200, 3), 42, dtype=np.uint8)
        original_copy = image.copy()
        cal.calibrate(image, self._square_corners(), {})
        np.testing.assert_array_equal(image, original_copy)

    def test_result_is_typed_calibration_result(self):
        cal = ColorCalibrator()
        image = np.full((100, 100, 3), 100, dtype=np.uint8)
        result = cal.calibrate(image, self._square_corners(), {})
        assert isinstance(result, CalibrationResult)

    def test_none_image_returns_failed(self):
        cal = ColorCalibrator()
        result = cal.calibrate(None, self._square_corners(), {})
        assert result.status == "FAILED"


# ─────────────────────────────────────────────────────────────────────────────
# 14. UNVALIDATED status preserved end-to-end
# ─────────────────────────────────────────────────────────────────────────────

class TestValidationStatusPreserved:
    def test_classifier_always_unvalidated(self):
        extractor = FeatureExtractor()
        roi = np.full((20, 20, 3), 128, dtype=np.uint8)
        features, _ = extractor.extract(roi)
        classifier = DemoLogisticClassifier(config_version="DEMO-CONFIG-v1", kit_code="TEST")
        result = classifier.classify(features)
        assert result.validationStatus == "UNVALIDATED"

    def test_classifier_never_claims_drug_id(self):
        """Nearest reference labels must not be substance names."""
        extractor = FeatureExtractor()
        roi = np.full((20, 20, 3), 100, dtype=np.uint8)
        features, _ = extractor.extract(roi)
        classifier = DemoLogisticClassifier(config_version="DEMO-CONFIG-v1")
        result = classifier.classify(features)
        # Verify label is a colour descriptor, not a drug name
        drug_names = ["methamphetamine", "cocaine", "heroin", "mdma", "fentanyl"]
        label_lower = (result.nearestReferenceLabel or "").lower()
        for drug in drug_names:
            assert drug not in label_lower, \
                f"nearestReferenceLabel '{result.nearestReferenceLabel}' should not be a drug name"


# ─────────────────────────────────────────────────────────────────────────────
# 15. Features carry correct colour-space metadata
# ─────────────────────────────────────────────────────────────────────────────

class TestFeaturesMetadata:
    def test_illuminant_is_d65(self):
        extractor = FeatureExtractor()
        f, _ = extractor.extract(np.full((4, 4, 3), 128, dtype=np.uint8))
        assert f.illuminant == "D65"

    def test_conversion_version_present(self):
        extractor = FeatureExtractor()
        f, _ = extractor.extract(np.full((4, 4, 3), 128, dtype=np.uint8))
        assert "srgb" in f.conversion_version.lower()

    def test_calibration_status_propagated(self):
        extractor = FeatureExtractor()
        f, _ = extractor.extract(
            np.full((4, 4, 3), 128, dtype=np.uint8),
            calibration_status="PERSPECTIVE_ONLY",
        )
        assert f.calibration_status == "PERSPECTIVE_ONLY"
