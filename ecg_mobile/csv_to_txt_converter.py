#!/usr/bin/env python3
"""
CSV to TXT Converter
===================
Simple script to convert CSV files to TXT format
"""

import pandas as pd
import os
import sys

def convert_csv_to_txt(input_file, output_file=None, format_type='comma'):
    """Convert CSV to TXT with specified format."""
    try:
        # Check if input file exists
        if not os.path.exists(input_file):
            print(f"❌ File not found: {input_file}")
            return False
        
        # Read CSV file
        print(f"📄 Reading CSV file: {input_file}")
        df = pd.read_csv(input_file)
        
        print(f"📊 Data shape: {df.shape[0]} rows × {df.shape[1]} columns")
        print(f"📋 Columns: {list(df.columns)}")
        
        # Show preview
        print(f"\n📖 Data Preview:")
        print(df.head())
        
        # Generate output filename if not provided
        if output_file is None:
            base_name = os.path.splitext(input_file)[0]
            output_file = f"{base_name}.txt"
        
        # Convert based on format type
        print(f"\n🔄 Converting to TXT format...")
        
        if format_type == 'comma':
            # Comma-separated (keep original CSV format)
            content = df.to_csv(index=False)
        elif format_type == 'space':
            # Space-separated
            content = df.to_csv(sep=' ', index=False)
        elif format_type == 'tab':
            # Tab-separated
            content = df.to_csv(sep='\t', index=False)
        elif format_type == 'single_line':
            # All values in single line, comma-separated
            values = []
            for _, row in df.iterrows():
                values.extend(row.astype(str).tolist())
            content = ','.join(values)
        else:
            content = df.to_csv(index=False)
        
        # Save to TXT file
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"✅ Successfully converted to: {output_file}")
        print(f"📏 Output file size: {os.path.getsize(output_file)} bytes")
        
        # Show output preview
        print(f"\n📖 Output Preview:")
        lines = content.split('\n')[:5]
        for i, line in enumerate(lines, 1):
            if line.strip():
                print(f"   {i}: {line[:100]}{'...' if len(line) > 100 else ''}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error converting file: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("CSV to TXT Converter")
        print("=" * 30)
        input_file = input("📁 Enter CSV file path: ").strip().strip('"\'')
        
        print("\n🎯 Choose output format:")
        print("1. Comma-separated (CSV format)")
        print("2. Space-separated")
        print("3. Tab-separated") 
        print("4. Single line (all values comma-separated)")
        
        choice = input("\nEnter choice (1-4): ").strip()
        
        format_map = {
            '1': 'comma',
            '2': 'space', 
            '3': 'tab',
            '4': 'single_line'
        }
        
        format_type = format_map.get(choice, 'comma')
        
        output_file = input("💾 Output file (press Enter for auto): ").strip().strip('"\'')
        if not output_file:
            output_file = None
            
    else:
        input_file = sys.argv[1]
        format_type = sys.argv[2] if len(sys.argv) > 2 else 'comma'
        output_file = sys.argv[3] if len(sys.argv) > 3 else None
    
    convert_csv_to_txt(input_file, output_file, format_type)

if __name__ == "__main__":
    main() 