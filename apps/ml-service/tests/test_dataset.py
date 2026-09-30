import pytest
from app.dataset import DatasetSampleSchema, DatasetSampleStatus, DatasetValidator, DataSplitter, SplitStrategy, Evaluator, DataLoader

def test_dataset_schema_validation():
    # Valid schema
    sample = DatasetSampleSchema(
        sample_id="test-1",
        image_hash="a" * 64,
        kit_code="KIT-1"
    )
    assert sample.kit_code == "KIT-1"

def test_image_hash_mismatch():
    validator = DatasetValidator()
    # Invalid hash length
    sample = DatasetSampleSchema(
        sample_id="test-1",
        image_hash="invalid_hash",
        kit_code="KIT-1"
    )
    result = validator.validate_ingestion(sample)
    assert not result.is_valid
    assert result.status == DatasetSampleStatus.EXCLUDED
    assert any("hash" in err for err in result.errors)

def test_missing_metadata():
    validator = DatasetValidator()
    # Missing reference card version
    sample = DatasetSampleSchema(
        sample_id="test-1",
        image_hash="a" * 64,
        kit_code="KIT-1"
    )
    result = validator.validate_ingestion(sample)
    assert result.is_valid
    assert result.status == DatasetSampleStatus.PENDING_VERIFICATION
    assert any("reference card" in warn for warn in result.warnings)

def test_unverified_ground_truth():
    validator = DatasetValidator()
    # Has label but missing method/reviewer
    sample = DatasetSampleSchema(
        sample_id="test-1",
        image_hash="a" * 64,
        kit_code="KIT-1",
        ground_truth_label="Positive"
    )
    result = validator.validate_ingestion(sample)
    assert not result.is_valid
    assert result.status == DatasetSampleStatus.EXCLUDED
    assert any("reference laboratory method" in err for err in result.errors)
    assert any("requires an authorized reviewer" in err for err in result.errors)

def test_valid_ground_truth():
    validator = DatasetValidator()
    sample = DatasetSampleSchema(
        sample_id="test-1",
        image_hash="a" * 64,
        kit_code="KIT-1",
        ground_truth_label="Positive",
        reference_method="GC-MS",
        reviewer_id="rev-1"
    )
    result = validator.validate_ingestion(sample)
    assert result.is_valid
    assert result.status == DatasetSampleStatus.ELIGIBLE_FOR_EVALUATION

def test_split_reproducibility_and_leakage():
    splitter = DataSplitter()
    
    samples = []
    # 60 samples across 3 operators
    for i in range(60):
        samples.append(DatasetSampleSchema(
            sample_id=f"test-{i}",
            image_hash="a" * 64,
            kit_code="KIT-1",
            operator_id=f"operator-{i % 3}",
            status=DatasetSampleStatus.ELIGIBLE_FOR_EVALUATION
        ))
        
    strategy = SplitStrategy(group_by=["operator_id"], train_ratio=0.7, val_ratio=0.15, test_ratio=0.15, seed=42)
    
    train1, val1, test1 = splitter.split_dataset(samples, strategy)
    train2, val2, test2 = splitter.split_dataset(samples, strategy)
    
    # Reproducibility check
    assert [s.sample_id for s in train1] == [s.sample_id for s in train2]
    assert [s.sample_id for s in val1] == [s.sample_id for s in val2]
    
    # Leakage check
    train_ops = set([s.operator_id for s in train1])
    val_ops = set([s.operator_id for s in val1])
    test_ops = set([s.operator_id for s in test1])
    
    assert not train_ops.intersection(val_ops)
    assert not train_ops.intersection(test_ops)

def test_split_blocked_on_insufficient_groups():
    splitter = DataSplitter()
    
    # Only 2 groups, can't split into 3 sets safely
    samples = [
        DatasetSampleSchema(sample_id="1", image_hash="a"*64, kit_code="K", operator_id="op-1"),
        DatasetSampleSchema(sample_id="2", image_hash="a"*64, kit_code="K", operator_id="op-2")
    ]
    
    strategy = SplitStrategy(group_by=["operator_id"])
    
    with pytest.raises(ValueError, match="Insufficient independent groups"):
        splitter.split_dataset(samples, strategy)

def test_evaluation_blocked_when_no_data():
    evaluator = Evaluator()
    samples = []
    preds = []
    
    result = evaluator.evaluate_classification(samples, preds)
    assert result.blocked
    assert "No eligible verified samples" in result.blocked_reason

def test_evaluation_blocked_on_insufficient_size():
    evaluator = Evaluator()
    samples = [DatasetSampleSchema(sample_id="1", image_hash="a"*64, kit_code="K")] * 20
    preds = ["A"] * 20
    
    result = evaluator.evaluate_classification(samples, preds)
    assert result.blocked
    assert result.sample_counts["total"] == 20
    assert "Insufficient sample size" in result.blocked_reason

def test_evaluation_sample_counts():
    evaluator = Evaluator()
    
    # Needs >= 30 samples to not be blocked
    samples = []
    for i in range(35):
        s = DatasetSampleSchema(sample_id=str(i), image_hash="a"*64, kit_code="K")
        if i < 20:
            s.ground_truth_label = "1" if i % 2 == 0 else "0"
        samples.append(s)
        
    preds = ["1"] * 35
    
    result = evaluator.evaluate_classification(samples, preds)
    assert not result.blocked
    assert result.sample_counts["total"] == 35
    assert result.sample_counts["evaluated"] == 20
    
def test_infrastructure_training_readiness():
    loader = DataLoader()
    
    # Attempting to prepare splits with < 50 eligible samples should fail
    samples = [
        DatasetSampleSchema(sample_id=str(i), image_hash="a"*64, kit_code="K", status=DatasetSampleStatus.ELIGIBLE_FOR_EVALUATION)
        for i in range(40)
    ]
    
    with pytest.raises(ValueError, match="Insufficient eligible samples"):
        loader.prepare_training_splits(samples, ["operator_id"])

def test_cohort_readiness_zero_samples():
    from app.dataset.cohort import CohortAnalyzer, CohortPlanningInput
    from app.dataset.protocol import PilotProtocol
    
    protocol = PilotProtocol(protocol_version="1.0", description="Test", assay_configs={})
    analyzer = CohortAnalyzer(protocol)
    
    report = analyzer.assess_readiness([])
    assert report.status == "NOT_READY"
    assert "Zero legitimate samples collected." in report.blockers

def test_cohort_readiness_planning_estimates():
    from app.dataset.cohort import CohortAnalyzer, CohortPlanningInput
    from app.dataset.protocol import PilotProtocol
    
    protocol = PilotProtocol(protocol_version="1.0", description="Test", assay_configs={})
    analyzer = CohortAnalyzer(protocol)
    
    planning = CohortPlanningInput(
        target_sensitivity=0.95,
        target_specificity=0.95,
        expected_prevalence=0.10,
        confidence_level=0.95,
        expected_attrition_rate=0.05,
        independent_grouping_factor="operator_id"
    )
    
    samples = [DatasetSampleSchema(sample_id=str(i), image_hash="a"*64, kit_code="K", operator_id=f"op_{i}") for i in range(120)]
    for i, s in enumerate(samples):
        if i < 110:
            s.ground_truth_label = "Pos"
            s.reviewer_id = "rev-1"
    
    report = analyzer.assess_readiness(samples, planning)
    
    assert report.total_collected_samples == 120
    assert report.verified_reference_results == 110
    assert report.independent_groups_count == 120
    assert report.status == "READY"
    assert report.planning_estimates is not None
    assert "theoretical planning estimates" in report.planning_estimates["disclaimer"]
    assert report.planning_estimates["estimated_required_samples"] > 0
    
def test_protocol_configuration_validation():
    from app.dataset.protocol import PilotProtocol, AssayConfig
    
    assay = AssayConfig(
        assay_id="FENT-01",
        kit_identity="FENT-STRIP-V1",
        intended_measurement="Fentanyl presence",
        approved_sample_types=["Powder", "Liquid"],
        reference_laboratory_method="GC-MS",
        measurement_units="ng/mL",
        reporting_limits={"LOD": 50.0},
        sample_collection_requirements="Standard",
        storage_conditions="Room temp",
        transport_conditions="Room temp",
        reference_card_version="V1",
        image_capture_procedure="Standard",
        environmental_metadata_required=["temperature", "lighting"],
        quality_control_requirements="Standard",
        exclusion_criteria=["Expired lot"],
        retention_policy="30 days",
        scientifically_approved=False
    )
    
    protocol = PilotProtocol(
        protocol_version="1.0.0",
        description="Pilot 1",
        assay_configs={"FENT-01": assay}
    )
    
    assert protocol.validate_assay("FENT-01") is True
    assert protocol.validate_assay("INVALID") is False

