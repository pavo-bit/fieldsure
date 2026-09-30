import pandas as pd
df = pd.read_csv(r'c:\Users\00dem\Desktop\FieldSure\docs\FieldSure_Scientific_Narcotics_50Page_Dataset.csv')
df = df[df['Validation_Status'] == 'VALIDATED_LAB_CONFIRMED']
print(df.groupby('Presumptive_ML_Result')[['Delta_E_Total_t60', 'Calibrated_L_t60s', 'Calibrated_a_t60s', 'Calibrated_b_t60s']].mean())
