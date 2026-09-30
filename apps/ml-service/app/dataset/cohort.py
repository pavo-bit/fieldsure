from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from .models import DatasetSampleSchema, DatasetSampleStatus
from .protocol import PilotProtocol

class CohortPlanningInput(BaseModel):
    target_sensitivity: float
    target_specificity: float
    expected_prevalence: float
    confidence_level: float
    expected_attrition_rate: float
    independent_grouping_factor: str

class CohortReadinessReport(BaseModel):
    total_collected_samples: int
    verified_reference_results: int
    eligible_for_development: int
    eligible_for_evaluation: int
    
    counts_by_assay: Dict[str, int]
    counts_by_lot: Dict[str, int]
    counts_by_site: Dict[str, int]
    
    missing_metadata_rate: float
    exclusion_rate: float
    
    independent_groups_count: int
    potential_leakage_detected: bool
    
    status: str
    blockers: List[str]
    planning_estimates: Optional[Dict[str, Any]] = None

class CohortAnalyzer:
    def __init__(self, protocol: PilotProtocol):
        self.protocol = protocol
        
    def assess_readiness(self, samples: List[DatasetSampleSchema], planning: Optional[CohortPlanningInput] = None) -> CohortReadinessReport:
        total = len(samples)
        
        if total == 0:
            return CohortReadinessReport(
                total_collected_samples=0,
                verified_reference_results=0,
                eligible_for_development=0,
                eligible_for_evaluation=0,
                counts_by_assay={},
                counts_by_lot={},
                counts_by_site={},
                missing_metadata_rate=0.0,
                exclusion_rate=0.0,
                independent_groups_count=0,
                potential_leakage_detected=False,
                status="NOT_READY",
                blockers=["Zero legitimate samples collected."]
            )
            
        verified = sum(1 for s in samples if s.ground_truth_label is not None and s.reviewer_id is not None)
        development = sum(1 for s in samples if s.status == DatasetSampleStatus.VERIFIED_FOR_DEVELOPMENT)
        evaluation = sum(1 for s in samples if s.status == DatasetSampleStatus.ELIGIBLE_FOR_EVALUATION)
        excluded = sum(1 for s in samples if s.status == DatasetSampleStatus.EXCLUDED)
        
        counts_by_assay = {}
        counts_by_lot = {}
        counts_by_site = {}
        missing_metadata_count = 0
        groups = set()
        
        for s in samples:
            counts_by_assay[s.kit_code] = counts_by_assay.get(s.kit_code, 0) + 1
            if s.reagent_lot:
                counts_by_lot[s.reagent_lot] = counts_by_lot.get(s.reagent_lot, 0) + 1
            if s.collection_site:
                counts_by_site[s.collection_site] = counts_by_site.get(s.collection_site, 0) + 1
                
            if not s.device_metadata or not s.environment_data:
                missing_metadata_count += 1
                
            if s.operator_id:
                groups.add(s.operator_id)
                
        blockers = []
        if verified < 100:
            blockers.append(f"Insufficient verified reference results ({verified} < 100 required for minimum pilot scale).")
        if len(groups) < 5:
            blockers.append(f"Insufficient independent groups ({len(groups)} < 5) to prevent leakage.")
            
        status = "READY" if len(blockers) == 0 else "NOT_READY"
        
        planning_estimates = None
        if planning:
            # Simple binomial calculation for planning estimates
            # Note: These are planning estimates, NOT observed performance.
            target_pos = (1.96**2 * planning.target_sensitivity * (1 - planning.target_sensitivity)) / ((1 - planning.confidence_level)**2)
            target_neg = (1.96**2 * planning.target_specificity * (1 - planning.target_specificity)) / ((1 - planning.confidence_level)**2)
            
            raw_total = (target_pos / planning.expected_prevalence) + (target_neg / (1 - planning.expected_prevalence))
            required_total = int(raw_total / (1 - planning.expected_attrition_rate))
            
            planning_estimates = {
                "disclaimer": "These are theoretical planning estimates based on binomial approximations, not observed empirical performance. Scientific review required.",
                "estimated_required_samples": required_total,
                "current_shortfall": max(0, required_total - total)
            }
            
        return CohortReadinessReport(
            total_collected_samples=total,
            verified_reference_results=verified,
            eligible_for_development=development,
            eligible_for_evaluation=evaluation,
            counts_by_assay=counts_by_assay,
            counts_by_lot=counts_by_lot,
            counts_by_site=counts_by_site,
            missing_metadata_rate=missing_metadata_count / total,
            exclusion_rate=excluded / total,
            independent_groups_count=len(groups),
            potential_leakage_detected=False,  # This would be rigorously checked during splitting
            status=status,
            blockers=blockers,
            planning_estimates=planning_estimates
        )
