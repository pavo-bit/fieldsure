import optuna
import numpy as np
from typing import List, Dict, Any, Callable
from app.dataset.models import DatasetSampleSchema
from app.dataset.evaluation import Evaluator
from app.models.classical import ClassicalModelBase
from sklearn.model_selection import StratifiedKFold
from sklearn.metrics import f1_score, accuracy_score, recall_score, precision_score
import logging

class OptunaOptimizer:
    def __init__(self, trainer, evaluator: Evaluator):
        self.trainer = trainer
        self.evaluator = evaluator

    def oversample(self, X, y):
        if len(y) == 0:
            return X, y
        unique_classes, counts = np.unique(y, return_counts=True)
        max_count = counts.max()
        X_resampled = []
        y_resampled = []
        for cls, count in zip(unique_classes, counts):
            idx = np.where(y == cls)[0]
            if count < max_count:
                resampled_idx = np.random.choice(idx, max_count, replace=True)
                X_resampled.append(X[resampled_idx])
                y_resampled.append(y[resampled_idx])
            else:
                X_resampled.append(X[idx])
                y_resampled.append(y[idx])
        return np.vstack(X_resampled), np.concatenate(y_resampled)

    def optimize(self, 
                 train_samples: List[DatasetSampleSchema], 
                 val_samples: List[DatasetSampleSchema],
                 model_family: str, 
                 n_trials: int = 20, 
                 timeout: int = 600,
                 seed: int = 42,
                 task: str = "classification") -> optuna.study.Study:
                 
        # We perform internal K-Fold cross validation on the Train+Val samples 
        # or just train on train_samples and evaluate on val_samples.
        # Since the objective strictly forbids using the independent test set, we use Train+Val.
        
        all_dev_samples = train_samples + val_samples
        
        try:
            X_dev = self.trainer._extract_features(all_dev_samples)
            y_dev = self.trainer._extract_labels(all_dev_samples, task)
        except ValueError as e:
            logging.error(f"Failed to extract features: {e}")
            raise e
            
        def objective(trial):
            # Define hyperparameter search spaces
            kwargs = {"random_state": seed}
            if model_family == "hist_gradient_boosting":
                kwargs["learning_rate"] = trial.suggest_float("learning_rate", 1e-3, 0.2, log=True)
                kwargs["max_iter"] = trial.suggest_int("max_iter", 50, 500)
                kwargs["max_leaf_nodes"] = trial.suggest_int("max_leaf_nodes", 15, 63)
                kwargs["max_depth"] = trial.suggest_int("max_depth", 3, 15)
                kwargs["min_samples_leaf"] = trial.suggest_int("min_samples_leaf", 5, 40)
                kwargs["l2_regularization"] = trial.suggest_float("l2_regularization", 1e-5, 10.0, log=True)
                
            elif model_family == "random_forest":
                kwargs["n_estimators"] = trial.suggest_int("n_estimators", 100, 600)
                kwargs["max_depth"] = trial.suggest_int("max_depth", 5, 30)
                kwargs["min_samples_split"] = trial.suggest_int("min_samples_split", 2, 10)
                kwargs["min_samples_leaf"] = trial.suggest_int("min_samples_leaf", 1, 10)
                
            else:
                raise ValueError(f"Unsupported model family: {model_family}")

            # Cross validation
            skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=seed)
            cv_scores = []
            
            for train_idx, val_idx in skf.split(X_dev, y_dev):
                X_t, y_t = X_dev[train_idx], y_dev[train_idx]
                X_v, y_v = X_dev[val_idx], y_dev[val_idx]
                
                # Apply Random Oversampling ONLY on training fold
                if task == "classification":
                    X_t, y_t = self.oversample(X_t, y_t)
                    
                model = ClassicalModelBase(model_type=model_family, task=task, **kwargs)
                model.fit(X_t, y_t)
                
                preds = model.predict(X_v)
                
                # Optimize primarily for Macro F1 to respect class imbalance
                # while checking critical per-class metrics
                macro_f1 = f1_score(y_v, preds, average='macro', zero_division=0)
                cv_scores.append(macro_f1)
                
            return np.mean(cv_scores)

        sampler = optuna.samplers.TPESampler(seed=seed)
        pruner = optuna.pruners.MedianPruner()
        
        study_name = f"fieldsure-{model_family}-optimization"
        study = optuna.create_study(
            direction="maximize", 
            sampler=sampler, 
            pruner=pruner,
            study_name=study_name
        )
        
        study.optimize(objective, n_trials=n_trials, timeout=timeout)
        
        return study
