from typing import List, Dict, Any, Tuple
import hashlib
from .models import DatasetSampleSchema

class SplitStrategy:
    def __init__(self, group_by: List[str], train_ratio: float = 0.7, val_ratio: float = 0.15, test_ratio: float = 0.15, seed: int = 42):
        self.group_by = group_by
        self.train_ratio = train_ratio
        self.val_ratio = val_ratio
        self.test_ratio = test_ratio
        self.seed = seed
        
        if abs(train_ratio + val_ratio + test_ratio - 1.0) > 1e-5:
            raise ValueError("Split ratios must sum to 1.0")

class DataSplitter:
    def __init__(self):
        pass
        
    def _get_group_key(self, sample: DatasetSampleSchema, group_by: List[str]) -> str:
        """Deterministically generates a group key based on metadata to prevent leakage."""
        parts = []
        for field in group_by:
            if field == 'operator_id':
                parts.append(str(sample.operator_id or 'UNKNOWN'))
            elif field == 'collection_site':
                parts.append(str(sample.collection_site or 'UNKNOWN'))
            elif field == 'reagent_lot':
                parts.append(str(sample.reagent_lot or 'UNKNOWN'))
            elif field == 'capture_session_id':
                parts.append(str(sample.capture_session_id or 'UNKNOWN'))
            else:
                parts.append('UNKNOWN')
        return "_".join(parts)
        
    def split_dataset(self, samples: List[DatasetSampleSchema], strategy: SplitStrategy) -> Tuple[List[DatasetSampleSchema], List[DatasetSampleSchema], List[DatasetSampleSchema]]:
        """Splits the dataset using a leakage-resistant grouping strategy."""
        
        # Group samples
        groups: Dict[str, List[DatasetSampleSchema]] = {}
        for sample in samples:
            key = self._get_group_key(sample, strategy.group_by)
            if key not in groups:
                groups[key] = []
            groups[key].append(sample)
            
        if len(groups) < 3 and len(samples) > 0:
            # Not enough independent groups to split safely without leakage
            raise ValueError(f"Insufficient independent groups ({len(groups)}) to perform leakage-resistant splitting. Evaluation is blocked.")
            
        train, val, test = [], [], []
        
        # Deterministic assignment based on hash of the group key and seed
        for key, group_samples in sorted(groups.items()):
            hash_input = f"{strategy.seed}_{key}".encode('utf-8')
            hash_val = int(hashlib.sha256(hash_input).hexdigest(), 16)
            
            normalized_hash = (hash_val % 10000) / 10000.0
            
            if normalized_hash < strategy.train_ratio:
                train.extend(group_samples)
            elif normalized_hash < strategy.train_ratio + strategy.val_ratio:
                val.extend(group_samples)
            else:
                test.extend(group_samples)
                
        # Validate that no groups leaked across splits
        train_keys = set(self._get_group_key(s, strategy.group_by) for s in train)
        val_keys = set(self._get_group_key(s, strategy.group_by) for s in val)
        test_keys = set(self._get_group_key(s, strategy.group_by) for s in test)
        
        if train_keys.intersection(val_keys) or train_keys.intersection(test_keys) or val_keys.intersection(test_keys):
            raise RuntimeError("CRITICAL: Data leakage detected across splits!")
            
        return train, val, test
