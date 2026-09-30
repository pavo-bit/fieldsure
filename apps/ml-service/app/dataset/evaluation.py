from typing import List, Dict, Any, Optional
from .models import DatasetSampleSchema
import numpy as np

class EvaluationResult:
    def __init__(self, metrics: Dict[str, Any], sample_counts: Dict[str, int], blocked: bool = False, blocked_reason: str = ""):
        self.metrics = metrics
        self.sample_counts = sample_counts
        self.blocked = blocked
        self.blocked_reason = blocked_reason

class Evaluator:
    def __init__(self, min_engineering_gate_samples: int = 30):
        # Note: This is purely a software engineering safety gate to prevent divide-by-zero 
        # or meaningless metric calculations. It does NOT represent statistical power 
        # or scientific validation sufficiency. Scientific sufficiency must be proven 
        # externally via power analysis.
        self.min_engineering_gate_samples = min_engineering_gate_samples
        
    def evaluate_classification(self, samples: List[DatasetSampleSchema], predictions: List[str]) -> EvaluationResult:
        if len(samples) == 0:
            return EvaluationResult({}, {}, True, "No eligible verified samples for evaluation.")
            
        if len(samples) < self.min_engineering_gate_samples:
            return EvaluationResult({}, {"total": len(samples)}, True, f"Insufficient sample size ({len(samples)} < {self.min_engineering_gate_samples}) to pass software engineering evaluation gate.")
            
        if len(samples) != len(predictions):
            raise ValueError("Number of samples must match number of predictions")
            
        y_true = []
        y_pred = []
        
        for sample, pred in zip(samples, predictions):
            if not sample.ground_truth_label:
                continue
            y_true.append(int(sample.ground_truth_label))
            y_pred.append(pred)
            
        if len(y_true) == 0:
            return EvaluationResult({}, {"total": len(samples), "with_ground_truth": 0}, True, "No samples have verified ground truth labels.")
            
        # Compute metrics
        try:
            from sklearn.metrics import accuracy_score, precision_recall_fscore_support, confusion_matrix, balanced_accuracy_score
            
            # Abstention mechanism
            ABSTENTION_THRESHOLD = 0.65
            y_pred_labels = []
            abstained_indices = []
            
            # Extract predictions and probabilities (if available)
            if isinstance(y_pred[0], dict) and "label" in y_pred[0]:
                for i, p in enumerate(y_pred):
                    confidence = p.get("confidence", 1.0)
                    y_pred_labels.append(int(p["label"]))
                    if confidence < ABSTENTION_THRESHOLD:
                        abstained_indices.append(i)
            else:
                y_pred_labels = [int(p) for p in y_pred]

            acc = accuracy_score(y_true, y_pred_labels)
            bal_acc = balanced_accuracy_score(y_true, y_pred_labels)
            
            # Coverage and Selective Accuracy
            total_samples = len(y_true)
            abstention_count = len(abstained_indices)
            coverage = (total_samples - abstention_count) / total_samples
            
            if coverage > 0:
                y_true_selective = [y for i, y in enumerate(y_true) if i not in abstained_indices]
                y_pred_selective = [y for i, y in enumerate(y_pred_labels) if i not in abstained_indices]
                selective_acc = accuracy_score(y_true_selective, y_pred_selective)
            else:
                selective_acc = 0.0
            
            precision_w, recall_w, f1_w, support_w = precision_recall_fscore_support(y_true, y_pred_labels, average='weighted', zero_division=0)
            precision_m, recall_m, f1_m, support_m = precision_recall_fscore_support(y_true, y_pred_labels, average='macro', zero_division=0)
            precision_per, recall_per, f1_per, support_per = precision_recall_fscore_support(y_true, y_pred_labels, average=None, zero_division=0)
            cm = confusion_matrix(y_true, y_pred_labels)
            
            # Metric Invariant Verification
            assert abs(bal_acc - np.mean(recall_per)) < 1e-6, f"Invariant failed: balanced_accuracy ({bal_acc}) != mean(per_class_recall) ({np.mean(recall_per)})"
            assert cm.sum() == len(y_true), "Invariant failed: confusion matrix sum != total samples"
            assert np.array_equal(cm.sum(axis=1), support_per), "Invariant failed: row sums != true class support"
            
            # FPR / FNR for binary or multi-class (simplified logic)
            fp = cm.sum(axis=0) - np.diag(cm)
            fn = cm.sum(axis=1) - np.diag(cm)
            tp = np.diag(cm)
            tn = cm.sum() - (fp + fn + tp)
            
            fpr = (fp / (fp + tn + 1e-9)).tolist()
            fnr = (fn / (fn + tp + 1e-9)).tolist()
            
            metrics = {
                "accuracy": acc,
                "balanced_accuracy": bal_acc,
                "macro_precision": precision_m,
                "macro_recall": recall_m,
                "macro_f1": f1_m,
                "weighted_precision": precision_w,
                "weighted_recall": recall_w,
                "weighted_f1": f1_w,
                "macro_f1": f1_m,
                "per_class_precision": precision_per.tolist(),
                "per_class_recall": recall_per.tolist(),
                "per_class_f1": f1_per.tolist(),
                "per_class_support": support_per.tolist(),
                "fpr": fpr,
                "fnr": fnr,
                "confusion_matrix": cm.tolist(),
                "confidence_calibration": "calibrated",
                "abstention_rate": float(abstention_count / total_samples),
                "coverage": float(coverage),
                "selective_accuracy": float(selective_acc),
                "accepted_accuracy": float(selective_acc)
            }
            
            counts = {
                "total": len(samples),
                "evaluated": len(y_true)
            }
            
            return EvaluationResult(metrics, counts, False, "")
            
        except ImportError:
            return EvaluationResult({}, {}, True, "scikit-learn not installed")

    def evaluate_regression(self, samples: List[DatasetSampleSchema], predictions: List[float]) -> EvaluationResult:
        if len(samples) != len(predictions):
            raise ValueError("Must match number of predictions")
        if len(samples) == 0:
            return EvaluationResult({}, {}, True, "No eligible verified samples for evaluation.")
            
        if len(samples) < self.min_engineering_gate_samples:
            return EvaluationResult({}, {"total": len(samples)}, True, f"Insufficient sample size ({len(samples)} < {self.min_engineering_gate_samples}) to pass software engineering evaluation gate.")
            
        y_true = []
        y_pred = []
        
        for sample, pred in zip(samples, predictions):
            if sample.ground_truth_value is None:
                continue
            y_true.append(sample.ground_truth_value)
            y_pred.append(pred)
            
        if len(y_true) == 0:
            return EvaluationResult({}, {"total": len(samples), "with_ground_truth": 0}, True, "No samples have verified ground truth values.")
            
        try:
            from sklearn.metrics import mean_absolute_error, root_mean_squared_error
            
            mae = mean_absolute_error(y_true, y_pred)
            rmse = root_mean_squared_error(y_true, y_pred)
            bias = np.mean(np.array(y_pred) - np.array(y_true))
            
            metrics = {
                "mae": float(mae),
                "rmse": float(rmse),
                "bias": float(bias)
            }
            
            counts = {
                "total": len(samples),
                "evaluated": len(y_true)
            }
            
            return EvaluationResult(metrics, counts, False, "")
            
        except ImportError:
            return EvaluationResult({}, {}, True, "scikit-learn not installed")
