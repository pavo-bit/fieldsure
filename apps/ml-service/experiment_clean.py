import pandas as pd
import numpy as np
from sklearn.ensemble import HistGradientBoostingClassifier, RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report
import warnings
warnings.filterwarnings('ignore')

df = pd.read_csv(r'c:\Users\00dem\Desktop\FieldSure\docs\FieldSure_Scientific_Narcotics_50Page_Dataset.csv')
df = df[df['Validation_Status'] == 'VALIDATED_LAB_CONFIRMED']
df = df[df['QC_Status'] == 'PASS']

base_features = [
    'Calibrated_L_t60s', 'Calibrated_a_t60s', 'Calibrated_b_t60s',
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

def random_oversample(X, y):
    max_count = y.value_counts().max()
    dfs_x = []
    dfs_y = []
    for c in y.unique():
        x_c = X[y == c]
        y_c = y[y == c]
        n_c = len(x_c)
        if n_c < max_count:
            idx = np.random.choice(x_c.index, max_count, replace=True)
            dfs_x.append(X.loc[idx])
            dfs_y.append(y.loc[idx])
        else:
            dfs_x.append(x_c)
            dfs_y.append(y_c)
    return pd.concat(dfs_x), pd.concat(dfs_y)

X_train_os, y_train_os = random_oversample(X_train, y_train)

models = {
    'RF': RandomForestClassifier(n_estimators=500, max_depth=None, random_state=42),
    'HGB': HistGradientBoostingClassifier(random_state=42, max_iter=200, l2_regularization=0.1)
}

for name, model in models.items():
    model.fit(X_train_os, y_train_os)
    val_preds = model.predict(X_val)
    print(f"{name} Validation Accuracy: {accuracy_score(y_val, val_preds):.4f}")

    test_preds = model.predict(X_test)
    print(f"{name} Test Accuracy: {accuracy_score(y_test, test_preds):.4f}")
    if name == 'RF':
        print(classification_report(y_test, test_preds))
