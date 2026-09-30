from app.datasets.dataset import ValidationDataset
from app.schemas.responses import ClassificationResult
from typing import Callable, Dict, Any

class ModelEvaluator:
    def __init__(self, dataset: ValidationDataset):
        self.dataset = dataset

    def evaluate(self, predict_fn: Callable[[str, str], ClassificationResult]) -> Dict[str, Any]:
        correct = 0
        total = len(self.dataset.records)
        inconclusive = 0
        
        confusion_matrix = {"POSITIVE": {}, "NEGATIVE": {}, "INCONCLUSIVE": {}}
        
        for record in self.dataset.records:
            result = predict_fn(record.image_id, record.kit_id)
            pred = result.result
            truth = record.ground_truth
            
            if pred == truth:
                correct += 1
            if pred == "INCONCLUSIVE":
                inconclusive += 1
                
            if truth not in confusion_matrix.get(pred, {}):
                if pred not in confusion_matrix:
                    confusion_matrix[pred] = {}
                confusion_matrix[pred][truth] = 0
            confusion_matrix[pred][truth] += 1
            
        return {
            "total": total,
            "accuracy": correct / total if total > 0 else 0,
            "inconclusive_rate": inconclusive / total if total > 0 else 0,
            "confusion_matrix": confusion_matrix
        }
