# Color Calibration Pipeline

## Overview
FieldSure utilizes a physical reference card to standardize captured images against varying lighting conditions, camera sensors, and environmental factors. This pipeline ensures that color features extracted from the presumptive drug test are reliable and scientifically reproducible.

## Pipeline Flow

1. **Card Detection:** 
   The pipeline identifies the geometric boundary (corners) of the reference card within the captured frame.
   
2. **Perspective Correction:** 
   Using the detected 4 corners of the reference card, a homography matrix is computed using `cv2.getPerspectiveTransform()`. The image is then warped (`cv2.warpPerspective()`) to a normalized, flat view (e.g., 600x800). This corrects any angle or tilt introduced by the operator holding the device.
   
3. **Patch Extraction & Calibration:** *(Foundation Configured)*
   The standardized image allows predictable extraction of specific known color patches (e.g., pure white, neutral grays, pure RGB).
   Currently, the system is architected to support transformation into robust color spaces (e.g., CIE Lab and HSV).

## Constraints
Color correction algorithms (such as polynomial color correction or gray world assumptions) will be strictly configuration-driven based on the detected `kit_id`. No universal standard is assumed across disparate kit manufacturers.
