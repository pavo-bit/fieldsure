import os
import torch
import torch.nn as nn
import torch.optim as optim
from typing import Dict, Any, Tuple
import numpy as np

class TorchMLP(nn.Module):
    def __init__(self, input_dim: int, hidden_dim: int, output_dim: int, task: str):
        super().__init__()
        self.task = task
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, output_dim)
        )
        
    def forward(self, x):
        out = self.net(x)
        if self.task == "classification":
            # Output logits; CrossEntropyLoss handles softmax
            return out
        return out.squeeze(-1) # Regression

class DeepLearningModelBase:
    def __init__(self, model_type: str = "mlp", task: str = "classification", device_mode: str = "AUTO", seed: int = 42, **kwargs):
        self.model_type = model_type
        self.task = task
        self.device_mode = device_mode.upper()
        self.seed = seed
        self.kwargs = kwargs
        self.device = self._select_device()
        self.model = None
        
        self._set_seed(self.seed)
        
    def _set_seed(self, seed: int):
        torch.manual_seed(seed)
        if torch.cuda.is_available():
            torch.cuda.manual_seed_all(seed)
            # Some operations on CUDA might still be non-deterministic, documented limitation
            torch.backends.cudnn.deterministic = True
            torch.backends.cudnn.benchmark = False
        np.random.seed(seed)

    def _select_device(self) -> torch.device:
        if self.device_mode == "GPU":
            if not torch.cuda.is_available():
                raise RuntimeError("Explicit GPU mode requested, but CUDA is unavailable.")
            return torch.device("cuda")
        elif self.device_mode == "CPU":
            return torch.device("cpu")
        elif self.device_mode == "AUTO":
            return torch.device("cuda" if torch.cuda.is_available() else "cpu")
        else:
            raise ValueError(f"Invalid device_mode: {self.device_mode}")
            
    def get_execution_metadata(self) -> Dict[str, Any]:
        return {
            "device": self.device.type,
            "cuda_available": torch.cuda.is_available(),
            "cuda_version": torch.version.cuda if torch.cuda.is_available() else None,
            "device_mode_requested": self.device_mode,
            "seed": self.seed
        }

    def _prepare_data(self, X: np.ndarray, y: np.ndarray = None) -> Tuple[torch.Tensor, torch.Tensor]:
        X_tensor = torch.tensor(X, dtype=torch.float32).to(self.device)
        if y is not None:
            if self.task == "classification":
                y_tensor = torch.tensor(y, dtype=torch.long).to(self.device)
            else:
                y_tensor = torch.tensor(y, dtype=torch.float32).to(self.device)
            return X_tensor, y_tensor
        return X_tensor, None

    def fit(self, X: np.ndarray, y: np.ndarray):
        # Handle empty datasets or invalid inputs
        if len(X) == 0 or len(y) == 0:
            raise ValueError("Cannot train on empty dataset.")
            
        self._set_seed(self.seed)
        
        input_dim = X.shape[1]
        
        if self.task == "classification":
            output_dim = len(np.unique(y))
            if output_dim < 2:
                raise ValueError("Classification requires at least 2 distinct classes.")
            criterion = nn.CrossEntropyLoss()
        else:
            output_dim = 1
            criterion = nn.MSELoss()
            
        hidden_dim = self.kwargs.get("hidden_dim", 64)
        lr = self.kwargs.get("lr", 0.01)
        epochs = self.kwargs.get("epochs", 100)
        
        self.model = TorchMLP(input_dim, hidden_dim, output_dim, self.task).to(self.device)
        optimizer = optim.Adam(self.model.parameters(), lr=lr)
        
        X_tensor, y_tensor = self._prepare_data(X, y)
        
        self.model.train()
        for _ in range(epochs):
            optimizer.zero_grad()
            outputs = self.model(X_tensor)
            loss = criterion(outputs, y_tensor)
            loss.backward()
            optimizer.step()
            
    def predict(self, X: np.ndarray) -> np.ndarray:
        if self.model is None:
            raise RuntimeError("Model is not fitted yet.")
        if len(X) == 0:
            return np.array([])
            
        self.model.eval()
        X_tensor, _ = self._prepare_data(X)
        
        with torch.no_grad():
            outputs = self.model(X_tensor)
            if self.task == "classification":
                predictions = torch.argmax(outputs, dim=1).cpu().numpy()
            else:
                predictions = outputs.cpu().numpy()
                
        return predictions

    def save(self, path: str):
        if self.model is not None:
            torch.save(self.model.state_dict(), path)
            
    def load(self, path: str, input_dim: int, output_dim: int):
        hidden_dim = self.kwargs.get("hidden_dim", 64)
        self.model = TorchMLP(input_dim, hidden_dim, output_dim, self.task).to(self.device)
        
        # weights_only=True required for secure deserialization in newer PyTorch
        self.model.load_state_dict(torch.load(path, map_location=self.device, weights_only=True))
        self.model.eval()
