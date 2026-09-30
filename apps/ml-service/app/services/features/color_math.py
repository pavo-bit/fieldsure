import numpy as np

# Standard Illuminants (2-degree observer)
ILLUMINANTS = {
    "D65": {"X": 0.95047, "Y": 1.00000, "Z": 1.08883},
    "D50": {"X": 0.96422, "Y": 1.00000, "Z": 0.82521},
}

# sRGB to XYZ matrix (D65)
SRGB_TO_XYZ_MATRIX = np.array([
    [0.4124564, 0.3575761, 0.1804375],
    [0.2126729, 0.7151522, 0.0721750],
    [0.0193339, 0.1191920, 0.9503041]
])

def srgb_to_linear(srgb: np.ndarray) -> np.ndarray:
    """
    Convert non-linear sRGB (0-1) to linear RGB (0-1).
    Handles non-finite values safely.
    """
    srgb = np.clip(srgb, 0.0, 1.0)
    linear = np.where(
        srgb <= 0.04045,
        srgb / 12.92,
        np.power((srgb + 0.055) / 1.055, 2.4)
    )
    return linear

def linear_to_srgb(linear: np.ndarray) -> np.ndarray:
    """
    Convert linear RGB (0-1) to non-linear sRGB (0-1).
    """
    linear = np.clip(linear, 0.0, 1.0)
    srgb = np.where(
        linear <= 0.0031308,
        linear * 12.92,
        1.055 * np.power(linear, 1 / 2.4) - 0.055
    )
    return srgb

def linear_rgb_to_xyz(linear_rgb: np.ndarray) -> np.ndarray:
    """
    Convert linear RGB (0-1) to XYZ.
    Input shape: (..., 3)
    Output shape: (..., 3)
    """
    # Matrix multiplication: XYZ = RGB @ matrix.T
    return np.tensordot(linear_rgb, SRGB_TO_XYZ_MATRIX, axes=([[-1], [1]]))

def xyz_to_lab(xyz: np.ndarray, illuminant: str = "D65") -> np.ndarray:
    """
    Convert CIE XYZ to CIELAB using the specified reference white.
    Input shape: (..., 3)
    Output shape: (..., 3)
    """
    ref = ILLUMINANTS.get(illuminant)
    if not ref:
        raise ValueError(f"Unknown illuminant {illuminant}")
    
    # Scale by reference white
    xyz_normalized = xyz / np.array([ref["X"], ref["Y"], ref["Z"]])
    
    # Piecewise function
    epsilon = (6.0 / 29.0) ** 3
    kappa = (29.0 / 3.0) ** 3
    
    f = np.where(
        xyz_normalized > epsilon,
        np.power(np.maximum(xyz_normalized, 1e-8), 1.0 / 3.0),
        (kappa * xyz_normalized + 16.0) / 116.0
    )
    
    fx, fy, fz = f[..., 0], f[..., 1], f[..., 2]
    
    L = 116.0 * fy - 16.0
    a = 500.0 * (fx - fy)
    b = 200.0 * (fy - fz)
    
    lab = np.stack([L, a, b], axis=-1)
    return lab

def bgr_image_to_lab(bgr_image: np.ndarray, illuminant: str = "D65") -> np.ndarray:
    """
    End-to-end conversion for OpenCV uint8 BGR images to true CIELAB float.
    Returns array of shape (H, W, 3) with LAB values.
    """
    # 1. BGR to RGB
    rgb = bgr_image[..., ::-1]
    
    # 2. Scale to 0-1
    rgb_float = rgb.astype(np.float64) / 255.0
    
    # 3. sRGB to Linear
    linear = srgb_to_linear(rgb_float)
    
    # 4. Linear to XYZ
    xyz = linear_rgb_to_xyz(linear)
    
    # 5. XYZ to CIELAB
    lab = xyz_to_lab(xyz, illuminant=illuminant)
    return lab

def delta_e_76(lab1: np.ndarray, lab2: np.ndarray) -> np.ndarray:
    """
    Calculate CIE76 Delta E between two LAB colors/arrays.
    """
    return np.sqrt(np.sum((lab1 - lab2) ** 2, axis=-1))

def delta_e_2000(lab1: np.ndarray, lab2: np.ndarray) -> np.ndarray:
    """
    Calculate CIEDE2000 Delta E between two LAB colors/arrays.
    Implementation based on Sharma et al. (2005).
    Inputs should be arrays of shape (..., 3).
    """
    L1, a1, b1 = lab1[..., 0], lab1[..., 1], lab1[..., 2]
    L2, a2, b2 = lab2[..., 0], lab2[..., 1], lab2[..., 2]
    
    C1 = np.sqrt(a1**2 + b1**2)
    C2 = np.sqrt(a2**2 + b2**2)
    C_bar = (C1 + C2) / 2.0
    
    G = 0.5 * (1.0 - np.sqrt(C_bar**7 / (C_bar**7 + 25.0**7)))
    
    a1_prime = (1.0 + G) * a1
    a2_prime = (1.0 + G) * a2
    
    C1_prime = np.sqrt(a1_prime**2 + b1**2)
    C2_prime = np.sqrt(a2_prime**2 + b2**2)
    C_bar_prime = (C1_prime + C2_prime) / 2.0
    
    # Hue computation with safety for small chroma
    h1_prime = np.degrees(np.arctan2(b1, a1_prime))
    h1_prime = np.where(h1_prime < 0, h1_prime + 360, h1_prime)
    h1_prime = np.where(C1_prime == 0, 0.0, h1_prime)
    
    h2_prime = np.degrees(np.arctan2(b2, a2_prime))
    h2_prime = np.where(h2_prime < 0, h2_prime + 360, h2_prime)
    h2_prime = np.where(C2_prime == 0, 0.0, h2_prime)
    
    # Delta L, C, H
    dL_prime = L2 - L1
    dC_prime = C2_prime - C1_prime
    
    dh_prime = h2_prime - h1_prime
    dh_prime = np.where(np.abs(dh_prime) > 180.0,
                        np.where(h2_prime <= h1_prime, dh_prime + 360.0, dh_prime - 360.0),
                        dh_prime)
    dh_prime = np.where((C1_prime == 0) | (C2_prime == 0), 0.0, dh_prime)
    
    dH_prime = 2.0 * np.sqrt(C1_prime * C2_prime) * np.sin(np.radians(dh_prime / 2.0))
    
    L_bar_prime = (L1 + L2) / 2.0
    h_bar_prime = np.abs(h1_prime - h2_prime)
    h_bar_prime = np.where((C1_prime != 0) & (C2_prime != 0),
                           np.where(np.abs(h1_prime - h2_prime) > 180.0,
                                    (h1_prime + h2_prime + 360.0) / 2.0,
                                    (h1_prime + h2_prime) / 2.0),
                           h1_prime + h2_prime)
    
    T = (1.0 - 0.17 * np.cos(np.radians(h_bar_prime - 30.0)) +
         0.24 * np.cos(np.radians(2.0 * h_bar_prime)) +
         0.32 * np.cos(np.radians(3.0 * h_bar_prime + 6.0)) -
         0.20 * np.cos(np.radians(4.0 * h_bar_prime - 63.0)))
    
    Sl = 1.0 + (0.015 * (L_bar_prime - 50.0)**2) / np.sqrt(20.0 + (L_bar_prime - 50.0)**2)
    Sc = 1.0 + 0.045 * C_bar_prime
    Sh = 1.0 + 0.015 * C_bar_prime * T
    
    dTheta = 30.0 * np.exp(-((h_bar_prime - 275.0) / 25.0)**2)
    Rc = 2.0 * np.sqrt(C_bar_prime**7 / (C_bar_prime**7 + 25.0**7))
    Rt = -np.sin(np.radians(2.0 * dTheta)) * Rc
    
    # Delta E 2000
    de2000 = np.sqrt(
        (dL_prime / Sl)**2 +
        (dC_prime / Sc)**2 +
        (dH_prime / Sh)**2 +
        Rt * (dC_prime / Sc) * (dH_prime / Sh)
    )
    
    return de2000
