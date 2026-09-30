import pandas as pd
import json
import sys
import os

from app.dataset.models import DatasetSampleSchema, DatasetSampleStatus
from app.models.trainer import ModelTrainer
from app.models.artifact import artifact_manager

def main():
    csv_path = r"C:\Users\00dem\Desktop\FieldSure\docs\FieldSure_Scientific_Narcotics_50Page_Dataset.csv"
    if not os.path.exists(csv_path):
        print(f"CSV not found: {csv_path}")
        sys.exit(1)
        
    df = pd.read_csv(csv_path)
    substances = df['Presumptive_ML_Result'].dropna().unique()
    label_map = {name: str(idx) for idx, name in enumerate(substances)}
    print(f"Loaded {len(df)} rows from CSV.")
    
    train_samples = []
    val_samples = []
    test_samples = []
    
    for idx, row in df.iterrows():
        # only verified samples
        if row["Validation_Status"] != "VALIDATED_LAB_CONFIRMED":
            continue
            
        sample = DatasetSampleSchema(
            sample_id=row["Sample_ID"],
            dataset_version="v2.1",
            status=DatasetSampleStatus.VERIFIED_FOR_DEVELOPMENT,
            kit_code=row["Reagent_Type"],
            calibrated_measurements={
                "L": float(row["Calibrated_L_t60s"]) if not pd.isna(row["Calibrated_L_t60s"]) else 0.0,
                "a": float(row["Calibrated_a_t60s"]) if not pd.isna(row["Calibrated_a_t60s"]) else 0.0,
                "b": float(row["Calibrated_b_t60s"]) if not pd.isna(row["Calibrated_b_t60s"]) else 0.0,
                "L_t0s": float(row["Calibrated_L_t0s"]) if not pd.isna(row["Calibrated_L_t0s"]) else 0.0,
                "a_t0s": float(row["Calibrated_a_t0s"]) if not pd.isna(row["Calibrated_a_t0s"]) else 0.0,
                "b_t0s": float(row["Calibrated_b_t0s"]) if not pd.isna(row["Calibrated_b_t0s"]) else 0.0,
                "L_t15s": float(row["Calibrated_L_t15s"]) if not pd.isna(row["Calibrated_L_t15s"]) else 0.0,
                "a_t15s": float(row["Calibrated_a_t15s"]) if not pd.isna(row["Calibrated_a_t15s"]) else 0.0,
                "b_t15s": float(row["Calibrated_b_t15s"]) if not pd.isna(row["Calibrated_b_t15s"]) else 0.0,
                "L_t30s": float(row["Calibrated_L_t30s"]) if not pd.isna(row["Calibrated_L_t30s"]) else 0.0,
                "a_t30s": float(row["Calibrated_a_t30s"]) if not pd.isna(row["Calibrated_a_t30s"]) else 0.0,
                "b_t30s": float(row["Calibrated_b_t30s"]) if not pd.isna(row["Calibrated_b_t30s"]) else 0.0,
                "L_t60s": float(row["Calibrated_L_t60s"]) if not pd.isna(row["Calibrated_L_t60s"]) else 0.0,
                "a_t60s": float(row["Calibrated_a_t60s"]) if not pd.isna(row["Calibrated_a_t60s"]) else 0.0,
                "b_t60s": float(row["Calibrated_b_t60s"]) if not pd.isna(row["Calibrated_b_t60s"]) else 0.0,
                "Delta_E_Total_t60": float(row["Delta_E_Total_t60"]) if not pd.isna(row["Delta_E_Total_t60"]) else 0.0,
                "Reaction_Velocity_dE_dt": float(row["Reaction_Velocity_dE_dt"]) if not pd.isna(row["Reaction_Velocity_dE_dt"]) else 0.0,
            },
            quality_assessment={"is_valid": row["QC_Status"] == "PASS", "quality_flag": False},
            reference_method=row["Lab_Analytical_Method"],
            ground_truth_label=label_map.get(row["Presumptive_ML_Result"], "0"), image_hash="a"*64
        )
        
        # We need a reviewer_id since it's verified
        sample.reviewer_id = "ADMIN"
        
        if row["Dataset_Split_Assignment"] == "TRAIN_SET":
            train_samples.append(sample)
        elif row["Dataset_Split_Assignment"] == "VALIDATION_SET":
            val_samples.append(sample)
        elif row["Dataset_Split_Assignment"] == "INDEPENDENT_HELD_OUT_TEST_SET":
            test_samples.append(sample)
            
    print(f"Parsed {len(train_samples)} training samples, {len(val_samples)} validation samples, and {len(test_samples)} testing samples.")
    
    from app.dataset.evaluation import Evaluator
    trainer = ModelTrainer(Evaluator())
    
    # 1. Run Optuna
    from app.models.optuna_optimizer import OptunaOptimizer
    optimizer = OptunaOptimizer(trainer, Evaluator())
    
    print("Running Optuna optimization on Random Forest...")
    rf_study = optimizer.optimize(train_samples, val_samples, "random_forest", n_trials=25)
    print("Running Optuna optimization on Hist Gradient Boosting...")
    hgb_study = optimizer.optimize(train_samples, val_samples, "hist_gradient_boosting", n_trials=40)
    
    print("Best RF params:", rf_study.best_params)
    print("Best HGB params:", hgb_study.best_params)
    
    # 2. Select best family
    best_study = rf_study if rf_study.best_value >= hgb_study.best_value else hgb_study
    best_family = "random_forest" if best_study == rf_study else "hist_gradient_boosting"
    best_params = best_study.best_params
    best_params["random_state"] = 42
    
    print(f"Selected {best_family} as the best model family.")
    
    # 3. Train on development set (TRAIN + VAL) and evaluate on untouched TEST set
    dev_samples = train_samples + val_samples
    
    print("Training final model...")
    res = trainer.train_and_evaluate(
        "FieldSure-Narcotics-Production-5.0",
        best_family,
        "classification",
        dev_samples,
        test_samples,
        {"model_kwargs": best_params, "optuna_study": best_study.study_name, "best_trial": best_study.best_trial.number}
    )
    
    print(json.dumps(res, indent=2))
    
    if res.get("status") == "SUCCESS":
        print("Model finished successfully. Initiating Governance Checks...")
        try:
            artifact_manager.transition_state("FieldSure-Narcotics-Production-5.0", "PENDING_VALIDATION", "ADMIN")
            print("Model PENDING_VALIDATION state set.")
            art = artifact_manager.get_artifact("FieldSure-Narcotics-Production-5.0")
            print(f"Final Artifact State: {art.approval_status}")
            print(f"Metrics: {art.evaluation_metrics}")
        except Exception as e:
            print(f"Failed to set model governance state: {e}")

if __name__ == "__main__":
    main()



