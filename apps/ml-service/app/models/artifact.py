from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
from datetime import datetime
import hashlib
import json

class ModelArtifactMetadata(BaseModel):
    model_id: str
    model_version: str
    training_dataset_version: str
    feature_version: str
    preprocessing_version: str
    assay_version: str
    protocol_version: str
    
    training_config: Dict[str, Any]
    dependency_versions: Dict[str, str]
    random_seed: int
    
    evaluation_metrics: Dict[str, Any]
    execution_metadata: Dict[str, Any] = Field(default_factory=dict)
    
    approval_status: str = Field(default="DEVELOPMENT") 
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    integrity_hash: Optional[str] = None
    
    def compute_hash(self) -> str:
        data = self.model_dump(exclude={"integrity_hash", "created_at", "approval_status"})
        return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()

VALID_STATES = ["DEVELOPMENT", "RESEARCH_ONLY", "PENDING_VALIDATION", "PENDING_APPROVAL", "APPROVED", "SUSPENDED", "RETIRED"]

class ModelArtifactManager:
    """Manages secure, versioned model artifacts and lifecycle."""
    def __init__(self):
        self.artifacts: Dict[str, ModelArtifactMetadata] = {}

    def register_artifact(self, artifact: ModelArtifactMetadata) -> ModelArtifactMetadata:
        if artifact.approval_status not in VALID_STATES:
            raise ValueError(f"Invalid approval status: {artifact.approval_status}")
            
        artifact.integrity_hash = artifact.compute_hash()
        
        # Initial registration logic
        if artifact.approval_status == "APPROVED":
            self.validate_approval_requirements(artifact)
            
        self.artifacts[artifact.model_id] = artifact
        return artifact
        
    def validate_approval_requirements(self, artifact: ModelArtifactMetadata):
        """Enforces Stage H Production Integration gates and Phase 3 Accuracy Targets."""
        if "DEMO" in artifact.training_dataset_version:
            raise ValueError("Cannot promote model trained on DEMO data to APPROVED.")
        if not artifact.evaluation_metrics:
            raise ValueError("Cannot approve model without documented evaluation results.")
            
        acc = artifact.evaluation_metrics.get("accuracy", 0.0)
        if acc < 0.90:
            raise ValueError(f"Scientific target not met: Accuracy {acc:.2%} < 90.0%. Model approval denied.")
            
        # Scientific block: zero real verified samples in the system means NO approved models.
        if artifact.execution_metadata.get('verified_samples_count', 0) == 0:
            raise ValueError("Zero verified laboratory-linked samples exist. Production approval blocked.")

    def transition_state(self, model_id: str, new_state: str, authorized_user: str) -> ModelArtifactMetadata:
        if new_state not in VALID_STATES:
            raise ValueError(f"Invalid state {new_state}")
        
        artifact = self.artifacts.get(model_id)
        if not artifact:
            raise ValueError("Model artifact not found")

        # Rollback logic
        if new_state == "APPROVED" and artifact.approval_status in ["SUSPENDED", "RETIRED"]:
            raise ValueError("Cannot reactivate a suspended or retired artifact.")
            
        if new_state == "APPROVED":
            self.validate_approval_requirements(artifact)
            
        artifact.approval_status = new_state
        self.artifacts[model_id] = artifact
        return artifact
        
    def get_artifact(self, model_id: str) -> Optional[ModelArtifactMetadata]:
        return self.artifacts.get(model_id)

artifact_manager = ModelArtifactManager()
