from pydantic import BaseModel
from typing import Optional, List

class ImageMetadata(BaseModel):
    capture_setup: str
    lighting_condition: str
    device: str
    timestamp: str

class DatasetRecord(BaseModel):
    image_id: str
    kit_id: str
    ground_truth: str
    metadata: ImageMetadata
    test_batch: Optional[str] = None

class ValidationDataset(BaseModel):
    dataset_version: str
    records: List[DatasetRecord]

    def get_distribution(self) -> dict:
        counts = {}
        for r in self.records:
            counts[r.ground_truth] = counts.get(r.ground_truth, 0) + 1
        return counts
