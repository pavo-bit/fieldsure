import pandas as pd
import numpy as np
from sklearn.ensemble import HistGradientBoostingClassifier, RandomForestClassifier
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline
from sklearn.metrics import accuracy_score, classification_report
import warnings
warnings.filterwarnings('ignore')

df = pd.read_csv(r'c:\Users\00dem\Desktop\FieldSure\docs\FieldSure_Scientific_Narcotics_50Page_Dataset.csv')
df = df[df['Validation_Status'] == 'VALIDATED_LAB_CONFIRMED']
df = df[df['QC_Status'] == 'PASS']

# Create features
def compute_delta_e(L1, a1, b1, L2, a2, b2):
    return np.sqrt((L1 - L2)**2 + (a1 - a2)**2 + (b1 - b2)**2)

for t1, t2 in [('t0s', 't15s'), ('t15s', 't30s'), ('t30s', 't60s')]:
    df[f'dL_{t2}_{t1}'] = df[f'Calibrated_L_{t2}'] - df[f'Calibrated_L_{t1}']
    df[f'da_{t2}_{t1}'] = df[f'Calibrated_a_{t2}'] - df[f'Calibrated_a_{t1}']
    df[f'db_{t2}_{t1}'] = df[f'Calibrated_b_{t2}'] - df[f'Calibrated_b_{t1}']
    df[f'dE_{t2}_{t1}'] = compute_delta_e(df[f'Calibrated_L_{t1}'], df[f'Calibrated_a_{t1}'], df[f'Calibrated_b_{t1}'],
                                          df[f'Calibrated_L_{t2}'], df[f'Calibrated_a_{t2}'], df[f'Calibrated_b_{t2}'])

df['max_dE_step'] = df[['dE_t15s_t0s', 'dE_t30s_t15s', 'dE_t60s_t30s']].max(axis=1)

base_features = [
    'Calibrated_L_t0s', 'Calibrated_a_t0s', 'Calibrated_b_t0s',
    'Calibrated_L_t15s', 'Calibrated_a_t15s', 'Calibrated_b_t15s',
    'Calibrated_L_t30s', 'Calibrated_a_t30s', 'Calibrated_b_t30s',
    'Calibrated_L_t60s', 'Calibrated_a_t60s', 'Calibrated_b_t60s',
    'Delta_E_Total_t60', 'Reaction_Velocity_dE_dt',
    'dL_t15s_t0s', 'da_t15s_t0s', 'db_t15s_t0s', 'dE_t15s_t0s',
    'dL_t30s_t15s', 'da_t30s_t15s', 'db_t30s_t15s', 'dE_t30s_t15s',
    'dL_t60s_t30s', 'da_t60s_t30s', 'db_t60s_t30s', 'dE_t60s_t30s',
    'max_dE_step'
]

df_features = pd.get_dummies(df[base_features + ['Reagent_Type']]).fillna(0)
target = df['Presumptive_ML_Result']

train_mask = df['Dataset_Split_Assignment'] == 'TRAIN_SET'
val_mask = df['Dataset_Split_Assignment'] == 'VALIDATION_SET'
test_mask = df['Dataset_Split_Assignment'] == 'INDEPENDENT_HELD_OUT_TEST_SET'

X_train = df_features[train_mask]
y_train = target[train_mask]
X_val = df_features[val_mask]
y_val = target[val_mask]
X_test = df_features[test_mask]
y_test = target[test_mask]

# Ensure SMOTE handles small classes by finding min class count
min_class = y_train.value_counts().min()
k_neighbors = min(5, min_class - 1) if min_class > 1 else 1

pipeline = Pipeline([
    ('smote', SMOTE(random_state=42, k_neighbors=k_neighbors)),
    ('model', RandomForestClassifier(n_estimators=500, max_depth=None, random_state=42))
])

pipeline.fit(X_train, y_train)

val_preds = pipeline.predict(X_val)
print(f"Validation Accuracy: {accuracy_score(y_val, val_preds):.4f}")

test_preds = pipeline.predict(X_test)
print(f"Test Accuracy: {accuracy_score(y_test, test_preds):.4f}")
print(classification_report(y_test, test_preds))
