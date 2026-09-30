import pandas as pd
df = pd.read_csv(r'c:\Users\00dem\Desktop\FieldSure\docs\FieldSure_Scientific_Narcotics_50Page_Dataset.csv')
df = df[df['Validation_Status'] == 'VALIDATED_LAB_CONFIRMED']
df = df[df['QC_Status'] == 'PASS']
target = df['Presumptive_ML_Result']
train_mask = df['Dataset_Split_Assignment'] == 'TRAIN_SET'
print(target[train_mask].value_counts())
