import pandas as pd
df = pd.read_csv(r'c:\Users\00dem\Desktop\FieldSure\docs\FieldSure_Scientific_Narcotics_50Page_Dataset.csv')
df = df[df['Validation_Status'] == 'VALIDATED_LAB_CONFIRMED']
sub = df[df['Presumptive_ML_Result'].isin(['POS_COCAINE', 'FALSE_POS_LOCAL_ANESTHETIC'])]
print(sub.groupby('Presumptive_ML_Result').mean(numeric_only=True).T)
