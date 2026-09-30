import pandas as pd
import numpy as np
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.metrics import confusion_matrix
import warnings
warnings.filterwarnings('ignore')

df = pd.read_csv(r'c:\Users\00dem\Desktop\FieldSure\docs\FieldSure_Scientific_Narcotics_50Page_Dataset.csv')
df = df[df['Validation_Status'] == 'VALIDATED_LAB_CONFIRMED']
df = df[df['QC_Status'] == 'PASS']

base_features = ['Delta_E_Total_t60', 'Calibrated_L_t60s', 'Calibrated_a_t60s', 'Calibrated_b_t60s', 'Reagent_Type']
df_features = pd.get_dummies(df[base_features])
target = df['Presumptive_ML_Result']

train_mask = df['Dataset_Split_Assignment'] == 'TRAIN_SET'
test_mask = df['Dataset_Split_Assignment'] == 'INDEPENDENT_HELD_OUT_TEST_SET'

X_train = df_features[train_mask]
y_train = target[train_mask]
X_test = df_features[test_mask]
y_test = target[test_mask]

model = HistGradientBoostingClassifier(random_state=42)
model.fit(X_train, y_train)

test_preds = model.predict(X_test)
labels = sorted(y_test.unique())
cm = confusion_matrix(y_test, test_preds, labels=labels)
print(labels)
print(cm)
