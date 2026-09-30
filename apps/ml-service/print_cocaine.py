import pandas as pd
df = pd.read_csv(r'c:\Users\00dem\Desktop\FieldSure\docs\FieldSure_Scientific_Narcotics_50Page_Dataset.csv')
cocaine = df[df['Presumptive_ML_Result'] == 'POS_COCAINE']
print('TRAIN:', cocaine[cocaine['Dataset_Split_Assignment'] == 'TRAIN_SET']['Calibrated_b_t60s'].values)
print('TEST:', cocaine[cocaine['Dataset_Split_Assignment'] == 'INDEPENDENT_HELD_OUT_TEST_SET']['Calibrated_b_t60s'].values)
print('VAL:', cocaine[cocaine['Dataset_Split_Assignment'] == 'VALIDATION_SET']['Calibrated_b_t60s'].values)
