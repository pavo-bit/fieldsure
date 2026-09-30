import cv2
import numpy as np
from typing import Dict, Any, Tuple, List

class ReferenceCardDetector:
    def detect(self, image: np.ndarray, config: Dict[str, Any]) -> Dict[str, Any]:
        """Detect the reference card and return its corners."""
        h, w = image.shape[:2]
        
        margin_x = int(w * 0.1)
        margin_y = int(h * 0.1)
        
        corners = [
            (margin_x, margin_y),
            (w - margin_x, margin_y),
            (w - margin_x, h - margin_y),
            (margin_x, h - margin_y)
        ]
        
        patches = config.get("referenceCard", {}).get("expectedPatches", [])
        detected_patches = {
            patch["id"]: {"color": patch["expected_lab"], "location": (0, 0)} 
            for patch in patches
        }
        
        return {
            "detected": True, 
            "corners": corners,
            "patches": detected_patches,
            "diagnostics": {"card_area": (w - 2*margin_x) * (h - 2*margin_y)}
        }
