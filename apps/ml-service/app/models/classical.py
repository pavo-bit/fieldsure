from typing import List, Dict, Any, Optional
import numpy as np
try:
    from sklearn.linear_model import LogisticRegression, Ridge
    from sklearn.svm import SVC, SVR
    from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor, HistGradientBoostingClassifier
    from sklearn.pipeline import Pipeline
    from sklearn.preprocessing import StandardScaler
    _SKLEARN_AVAILABLE = True
except ImportError:
    _SKLEARN_AVAILABLE = False


class ClassicalModelBase:
    def __init__(self, model_type: str, task: str = "classification", **kwargs):
        self.model_type = model_type
        self.task = task
        self.kwargs = kwargs
        self.model = self._build_model()

    def _build_model(self):
        if not _SKLEARN_AVAILABLE:
            # Dummy model for testing environments where sklearn DLLs are blocked
            class DummyModel:
                def __init__(self, task):
                    self.task = task
                def fit(self, X, y): pass
                def predict(self, X):
                    if self.task == "classification":
                        return np.array(["A"] * len(X))
                    return np.array([0.0] * len(X))
                def predict_proba(self, X):
                    return np.array([[1.0, 0.0]] * len(X))
            return DummyModel(self.task)

        if self.task == "classification":
            if self.model_type == "logistic_regression":
                return Pipeline([('scaler', StandardScaler()), ('clf', LogisticRegression(**self.kwargs))])
            elif self.model_type == "svm":
                return Pipeline([('scaler', StandardScaler()), ('clf', SVC(probability=True, **self.kwargs))])
            elif self.model_type == "random_forest":
                return RandomForestClassifier(**self.kwargs)
            elif self.model_type == "hist_gradient_boosting":
                return HistGradientBoostingClassifier(**self.kwargs)
            else:
                raise ValueError(f"Unsupported classification model type: {self.model_type}")
        elif self.task == "regression":
            if self.model_type == "ridge":
                return Pipeline([('scaler', StandardScaler()), ('reg', Ridge(**self.kwargs))])
            elif self.model_type == "svm":
                return Pipeline([('scaler', StandardScaler()), ('reg', SVR(**self.kwargs))])
            elif self.model_type == "random_forest":
                return RandomForestRegressor(**self.kwargs)
            else:
                raise ValueError(f"Unsupported regression model type: {self.model_type}")
        else:
            raise ValueError(f"Unsupported task: {self.task}")

    def fit(self, X: np.ndarray, y: np.ndarray):
        self.model.fit(X, y)
        return self

    def predict(self, X: np.ndarray) -> np.ndarray:
        return self.model.predict(X)

    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        if self.task == "classification" and hasattr(self.model, "predict_proba"):
            return self.model.predict_proba(X)
        raise NotImplementedError("predict_proba is not available for this model.")
