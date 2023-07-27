import sys

input_file = sys.argv[1]
output_dir = sys.argv[2]
results_dir = sys.argv[3]

from SigProfilerExtractor import sigpro as sig

if __name__ == '__main__':
    sig.sigProfilerExtractor("matrix", output_dir, "{}/{}".format(results_dir, input_file), reference_genome="GRCh38", minimum_signatures=3, maximum_signatures=10, nmf_replicates=20)