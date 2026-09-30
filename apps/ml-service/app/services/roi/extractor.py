import numpy as np

class RegionExtractor:
    def extract(self, image: np.ndarray, config: dict) -> np.ndarray:
        roi_cfg = config.get("testRegion", {})
        h, w = image.shape[:2]
        x = int(roi_cfg.get("x", 0.3) * w)
        y = int(roi_cfg.get("y", 0.4) * h)
        rw = int(roi_cfg.get("width", 0.4) * w)
        rh = int(roi_cfg.get("height", 0.2) * h)
        # Prevent 0-sized arrays
        if rw <= 0 or rh <= 0 or x >= w or y >= h:
            return image[0:1, 0:1]
        return image[y:min(y+rh, h), x:min(x+rw, w)]
