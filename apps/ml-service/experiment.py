import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier, HistGradientBoostingClassifier, ExtraTreesClassifier
from sklearn.neural_network import MLPClassifier
from sklearn.svm import SVC
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

# One-hot encode Reagent_Type
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

models = {
    'RF': RandomForestClassifier(n_estimators=300, max_depth=None, random_state=42, class_weight='balanced'),
    'ET': ExtraTreesClassifier(n_estimators=300, random_state=42, class_weight='balanced'),
    'HGB': HistGradientBoostingClassifier(random_state=42),
    'SVC': SVC(probability=True, class_weight='balanced', random_state=42),
    'MLP': MLPClassifier(hidden_layer_sizes=(128, 64), max_iter=500, random_state=42)
}

print("Benchmarking on Validation Set:")
best_acc = 0
best_model_name = ""
for name, model in models.items():
    model.fit(X_train, y_train)
    preds = model.predict(X_val)
    acc = accuracy_score(y_val, preds)
    print(f"{name}: {acc:.4f}")
    if acc > best_acc:
        best_acc = acc
        best_model_name = name

print(f"\nEvaluating Best Model ({best_model_name}) on TEST set:")
best_model = models[best_model_name]
test_preds = best_model.predict(X_test)
test_acc = accuracy_score(y_test, test_preds)
print(f"Test Accuracy: {test_acc:.4f}")
print(classification_report(y_test, test_preds))

