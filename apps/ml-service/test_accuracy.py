import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
import json

df = pd.read_csv(r'c:\Users\00dem\Desktop\FieldSure\docs\FieldSure_Scientific_Narcotics_50Page_Dataset.csv')
train = df[df['Dataset_Split_Assignment'] == 'TRAIN_SET'].dropna(subset=['Lab_Confirmed_Substance'])
test = df[df['Dataset_Split_Assignment'] == 'INDEPENDENT_HELD_OUT_TEST_SET'].dropna(subset=['Lab_Confirmed_Substance'])

features = ['Calibrated_L_t0s', 'Calibrated_a_t0s', 'Calibrated_b_t0s', 
            'Calibrated_L_t15s', 'Calibrated_a_t15s', 'Calibrated_b_t15s',
            'Calibrated_L_t30s', 'Calibrated_a_t30s', 'Calibrated_b_t30s',
            'Calibrated_L_t60s', 'Calibrated_a_t60s', 'Calibrated_b_t60s',
            'Delta_E_Total_t60', 'Reaction_Velocity_dE_dt', 'Ambient_Temp_Celsius']
            
train_x = pd.get_dummies(train[features + ['Reagent_Type', 'Physical_Form']]).fillna(0)
test_x = pd.get_dummies(test[features + ['Reagent_Type', 'Physical_Form']]).fillna(0)

# Align columns
train_x, test_x = train_x.align(test_x, join='left', axis=1, fill_value=0)

train_y = train['Presumptive_ML_Result']
test_y = test['Presumptive_ML_Result']

clf = RandomForestClassifier(n_estimators=200, random_state=42)
clf.fit(train_x, train_y)
preds = clf.predict(test_x)
print(f'Accuracy: {accuracy_score(test_y, preds)}')

importances = list(zip(train_x.columns, clf.feature_importances_))
importances.sort(key=lambda x: x[1], reverse=True)
print(importances[:10])

