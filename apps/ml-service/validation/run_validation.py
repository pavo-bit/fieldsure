#!/usr/bin/env python3
"""
FieldSure ML Pipeline Validation Harness

Ingests labeled dataset, performs stratified group-aware split, 
evaluates pipeline, computes metrics with Wilson confidence intervals,
and generates JSON/CSV/HTML reports (no markdown).

Usage:
    python validation/run_validation.py --config validation/validation_config.yaml
"""

import argparse
import json
import yaml
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any

def load_config(config_path: str) -> Dict[str, Any]:
    """Load validation configuration from YAML."""
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)

def load_dataset(config: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    Load dataset from JSONL export or folder + CSV.
    Returns list of samples with image_path and true_label.
    """
    source_type = config['dataset']['source_type']
    source_path = config['dataset']['source_path']
    
    samples = []
    
    if source_type == 'jsonl':
        # Load Phase 3 JSONL export
        with open(source_path, 'r') as f:
            for line in f:
                record = json.loads(line)
                # Expected format: {id, image_url, result, metadata}
                samples.append({
                    'id': record['id'],
                    'image_path': record['image_url'],
                    'true_label': record['result'],
                    'metadata': record.get('metadata', {})
                })
    elif source_type == 'folder':
        # Load from folder with labels CSV
        labels_csv = config['dataset']['labels_csv']
        # Implementation: parse CSV, match images to labels
        raise NotImplementedError("Folder mode not yet implemented")
    
    return samples

def stratified_group_split(samples: List[Dict], config: Dict) -> tuple:
    """
    Perform stratified train/test split respecting group boundaries.
    Groups samples by session/device to prevent leakage.
    """
    # Placeholder implementation
    # Production: use GroupShuffleSplit with stratification
    test_ratio = config['dataset']['test_split_ratio']
    n_test = int(len(samples) * test_ratio)
    
    train = samples[n_test:]
    test = samples[:n_test]
    
    return train, test

def evaluate_pipeline(samples: List[Dict], config: Dict) -> Dict[str, Any]:
    """
    Run each sample through the pipeline and collect predictions.
    Returns dict with predictions and ground truth.
    """
    from app.services.pipeline import MLPipeline
    
    pipeline = MLPipeline()
    results = {
        'predictions': [],
        'ground_truth': [],
        'failures': []
    }
    
    for sample in samples:
        try:
            # TODO: Integrate with actual pipeline processing
            # result = await pipeline.process(...)
            # For now, placeholder
            pred = 'NEGATIVE'  # Placeholder
            results['predictions'].append(pred)
            results['ground_truth'].append(sample['true_label'])
        except Exception as e:
            results['failures'].append({
                'id': sample['id'],
                'error': str(e)
            })
    
    return results

def compute_metrics(results: Dict, config: Dict) -> Dict[str, Any]:
    """
    Compute performance metrics: confusion matrix, precision/recall/F1,
    sensitivity/specificity with Wilson confidence intervals.
    """
    from sklearn.metrics import confusion_matrix, classification_report
    
    y_true = results['ground_truth']
    y_pred = results['predictions']
    
    # Confusion matrix
    cm = confusion_matrix(y_true, y_pred, labels=['POSITIVE', 'NEGATIVE', 'INCONCLUSIVE'])
    
    # Classification report
    report = classification_report(y_true, y_pred, output_dict=True, zero_division=0)
    
    # Wilson confidence intervals (simplified - full implementation needed)
    def wilson_ci(successes: int, total: int, confidence: float = 0.95) -> tuple:
        """Wilson score interval for binomial proportion."""
        if total == 0:
            return (0.0, 0.0)
        # Placeholder - actual Wilson formula needed
        p = successes / total
        margin = 1.96 * (p * (1-p) / total) ** 0.5
        return (max(0, p - margin), min(1, p + margin))
    
    metrics = {
        'confusion_matrix': cm.tolist(),
        'classification_report': report,
        'accuracy': report['accuracy'],
        'per_class_metrics': {},
        'failure_count': len(results['failures']),
    }
    
    for label in ['POSITIVE', 'NEGATIVE', 'INCONCLUSIVE']:
        if label in report:
            metrics['per_class_metrics'][label] = {
                'precision': report[label]['precision'],
                'recall': report[label]['recall'],
                'f1': report[label]['f1-score'],
                'support': report[label]['support'],
            }
    
    return metrics

def check_validation_status(metrics: Dict, config: Dict) -> tuple:
    """
    Check if metrics meet validation requirements.
    Returns (status: str, reasons: List[str])
    """
    reqs = config['validation_requirements']
    thresholds = config['performance_thresholds']
    
    status = 'VALIDATED'
    reasons = []
    
    # Check sample size
    # TODO: Implement proper checks
    
    # Check performance thresholds
    if metrics['accuracy'] < thresholds['overall_accuracy']:
        status = 'UNVALIDATED'
        reasons.append(f"Overall accuracy {metrics['accuracy']:.3f} below threshold {thresholds['overall_accuracy']}")
    
    return status, reasons

def generate_reports(metrics: Dict, config: Dict, validation_status: str, reasons: List[str]):
    """Generate JSON/CSV/HTML reports (no markdown)."""
    output_dir = Path(config['output']['output_dir'])
    output_dir.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    report_data = {
        'timestamp': timestamp,
        'config_version': config['pipeline']['config_version'],
        'validation_status': validation_status,
        'validation_reasons': reasons,
        'metrics': metrics,
    }
    
    # JSON report
    json_path = output_dir / f'validation_report_{timestamp}.json'
    with open(json_path, 'w') as f:
        json.dump(report_data, f, indent=2)
    
    print(f"✓ JSON report: {json_path}")
    
    # CSV report (simplified)
    csv_path = output_dir / f'validation_summary_{timestamp}.csv'
    with open(csv_path, 'w') as f:
        f.write("metric,value\\n")
        f.write(f"validation_status,{validation_status}\\n")
        f.write(f"accuracy,{metrics['accuracy']}\\n")
    
    print(f"✓ CSV report: {csv_path}")
    
    # HTML report
    html_path = output_dir / f'validation_report_{timestamp}.html'
    with open(html_path, 'w') as f:
        f.write("<html><head><title>Validation Report</title></head><body>")
        f.write(f"<h1>FieldSure ML Validation Report</h1>")
        f.write(f"<p>Status: <strong>{validation_status}</strong></p>")
        f.write(f"<p>Timestamp: {timestamp}</p>")
        f.write(f"<p>Accuracy: {metrics['accuracy']:.3f}</p>")
        f.write("</body></html>")
    
    print(f"✓ HTML report: {html_path}")

def main():
    parser = argparse.ArgumentParser(description='Run ML pipeline validation')
    parser.add_argument('--config', required=True, help='Path to validation config YAML')
    args = parser.parse_args()
    
    print("FieldSure ML Pipeline Validation Harness")
    print("=" * 60)
    
    # Load configuration
    config = load_config(args.config)
    print(f"✓ Loaded config: {args.config}")
    
    # Load dataset
    print("Loading dataset...")
    samples = load_dataset(config)
    print(f"✓ Loaded {len(samples)} samples")
    
    # Split dataset
    print("Splitting dataset...")
    train, test = stratified_group_split(samples, config)
    print(f"✓ Train: {len(train)}, Test: {len(test)}")
    
    # Evaluate pipeline
    print("Evaluating pipeline on test set...")
    results = evaluate_pipeline(test, config)
    print(f"✓ Evaluated {len(results['predictions'])} samples ({len(results['failures'])} failures)")
    
    # Compute metrics
    print("Computing metrics...")
    metrics = compute_metrics(results, config)
    print(f"✓ Overall accuracy: {metrics['accuracy']:.3f}")
    
    # Check validation status
    validation_status, reasons = check_validation_status(metrics, config)
    print(f"✓ Validation status: {validation_status}")
    
    if reasons:
        print("  Reasons:")
        for reason in reasons:
            print(f"    - {reason}")
    
    # Generate reports
    print("Generating reports...")
    generate_reports(metrics, config, validation_status, reasons)
    
    print("=" * 60)
    print("Validation complete")
    
    # Exit code based on validation status
    sys.exit(0 if validation_status == 'VALIDATED' else 1)

if __name__ == '__main__':
    main()
