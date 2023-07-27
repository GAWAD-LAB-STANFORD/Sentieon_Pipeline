import pandas as pd
import sys

variant_file = sys.argv[1]
circle_file = sys.argv[2]
output_file = sys.argv[3]

variant_df = pd.read_csv(variant_file, sep = "\t", header = 0, dtype=str)
variant_df['POS'] = variant_df['POS'].astype(int)
circle_df = pd.read_csv(circle_file, sep = "\t", header = None)

circle_variants_df = pd.DataFrame()
for row in circle_df.index:
    row_chr = circle_df.iloc[row, 0]
    row_start = circle_df.iloc[row, 1]
    row_end = circle_df.iloc[row, 2]
    new_variants_df = variant_df[(variant_df['CHROM'] == row_chr) & (variant_df['POS'] > row_start) & (variant_df['POS'] <= row_end)]
    circle_variants_df = pd.concat([circle_variants_df, new_variants_df])
    circle_variants_df = circle_variants_df.drop_duplicates()

circle_variants_df.to_csv(output_file, sep = "\t", header = True, index = None)