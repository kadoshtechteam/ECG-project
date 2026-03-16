import pandas as pd
import os

def convert_finaltest():
    # Read the CSV file
    print('📄 Reading finaltest.csv...')
    df = pd.read_csv('finaltest.csv')
    print(f'📊 Shape: {df.shape[0]} rows × {df.shape[1]} columns')

    # Display first few values
    print('\n📖 First few values:')
    print(df.head())

    # Convert to different TXT formats
    print('\n🔄 Converting to TXT formats...')

    # Format 1: Keep as CSV (comma-separated)
    with open('finaltest_comma.txt', 'w') as f:
        f.write(df.to_csv(index=False))
    print('✅ Created: finaltest_comma.txt (comma-separated)')

    # Format 2: Space-separated
    with open('finaltest_space.txt', 'w') as f:
        f.write(df.to_csv(sep=' ', index=False))
    print('✅ Created: finaltest_space.txt (space-separated)')

    # Format 3: Tab-separated
    with open('finaltest_tab.txt', 'w') as f:
        f.write(df.to_csv(sep='\t', index=False))
    print('✅ Created: finaltest_tab.txt (tab-separated)')

    # Format 4: Each row as single line (for ECG prediction)
    print('\n🧠 Creating ECG prediction format...')
    with open('finaltest_ecg_format.txt', 'w') as f:
        for i, row in df.iterrows():
            # Convert each row to comma-separated values (excluding header)
            values = ','.join(row.astype(str).tolist())
            f.write(f'Row {i+1}: {values}\n')
    print('✅ Created: finaltest_ecg_format.txt (ECG prediction format)')

    # Show file sizes
    print('\n📏 File sizes:')
    for filename in ['finaltest_comma.txt', 'finaltest_space.txt', 'finaltest_tab.txt', 'finaltest_ecg_format.txt']:
        if os.path.exists(filename):
            size = os.path.getsize(filename)
            print(f'   {filename}: {size} bytes')

    print('\n🎉 Conversion completed!')

if __name__ == "__main__":
    convert_finaltest() 