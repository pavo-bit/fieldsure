from typing import List, Dict, Any, Optional
from .models import DatasetSampleSchema
from .splitting import DataSplitter, SplitStrategy
import json

class DataLoader:
    def __init__(self):
        self.splitter = DataSplitter()
        
    def load_dataset_from_json(self, file_path: str) -> List[DatasetSampleSchema]:
        """Loads a dataset manifest from JSON (infrastructure readiness)."""
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
        samples = []
        for item in data:
            samples.append(DatasetSampleSchema(**item))
            
        return samples
        
    def prepare_training_splits(self, samples: List[DatasetSampleSchema], group_by: List[str], seed: int = 42):
        """Prepares splits and ensures infrastructure is ready for reproducible training."""
        
        # Verify eligibility
        eligible_samples = [s for s in samples if s.status == 'ELIGIBLE_FOR_EVALUATION']
        
        if len(eligible_samples) < 50:
            raise ValueError(f"Insufficient eligible samples ({len(eligible_samples)}) for model training. Minimum 50 required for robust training splits.")
            
        strategy = SplitStrategy(group_by=group_by, seed=seed)
        
        # Leakage-resistant splitting
        train, val, test = self.splitter.split_dataset(eligible_samples, strategy)
        
        # Metadata regarding the splits
        split_manifest = {
            "version": eligible_samples[0].dataset_version if eligible_samples else "unknown",
            "seed": seed,
            "group_by": group_by,
            "counts": {
                "train": len(train),
                "val": len(val),
                "test": len(test)
            }
        }
        
        return train, val, test, split_manifest
