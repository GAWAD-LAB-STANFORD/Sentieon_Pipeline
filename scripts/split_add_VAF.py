import numpy as np
import sys
import os
import random

from optparse import OptionParser


def prepare_options(parser):
    """Prepare options parser
    """
    parser.add_option("-i", "--input", dest="input_file",
                      help="Input FILE", metavar="FILE")
    parser.add_option("-o", "--output", dest="output_file",
                      help="Output FILE", metavar="FILE")


def process(input_file, output_file):
    """
    """
    o = open(output_file, 'w')
    f = open(input_file)
    lines = f.readlines()
    f.close()
    targetCol = lines[0].split('\t').index('AD')
    for l in lines:
        if l == '\n':
            continue
        if l.strip().find('#') == 0:
            continue
        o.write(l.rstrip())
        spt = l.split('\t')
        if spt[targetCol] == 'AD':
            o.write('\t'+'Var_AF1'+'\n')
            continue
        spt1 = spt[targetCol].split(',')
        floatArray = [float(i) for i in spt1]
        colsum = sum(floatArray)
        if colsum == 0:
           val = 0
        else:
            targetSum = colsum - float(spt1[0])
            val = targetSum / colsum
        #div = float(spt1[0]) + float(spt1[1])
        #if div == 0:
        #   val = 0
        #else:
        #   val = float(spt1[1]) / (float(spt1[0]) + float(spt1[1]))
        o.write('\t'+str(val)+'\n')
    o.close()

def parse_input(input_file):
    """Parse the input file

    """
    f = open(input_file)
    lines = f.readlines()
    f.close()

    inputs = []

    for l in lines:
        if l == '\n':
            continue
        if l.strip().find('#') == 0:
            continue
        spt = l.split('\t')
        val = float(spt[1]) / (float(spt[0]) + float(spt[1]))
        spt = [s.strip() for s in spt]
        inputs.append(np.asarray(spt))

    return np.asarray(inputs)

def generate_output(inputs):
    """Generate output
    """
    outputs = []
    targetCol = np.where(inputs[0] == 'DV')
    #targetCol = inputs[0].index('DV')
    # add new col
    #outputs[0].append('AF_new')
    outputs.append(np.append(inputs[0],'Var_AF'))
    for num, line in enumerate(inputs):
        #print line[targetCol]
        spt = "".join(line[targetCol]).split(',')
        if len(spt) == 1:
            continue
        val = float(spt[1]) / (float(spt[0]) + float(spt[1]))
        outputs.append(np.append(inputs[num], val))
        #outputs[num].append(val)

    return outputs


if __name__ == '__main__':
    parser = OptionParser("usage: %prog [options]")
    prepare_options(parser)
    (options, args) = parser.parse_args()

    if not options.input_file or not options.output_file:
        parser.error("Invalid arguments. Use -h for help.")

    process(options.input_file, options.output_file)
    #inputs = parse_input(options.input_file)
    #outputs = generate_output(inputs)
    #np.savetxt(options.output_file, outputs, delimiter='\t', fmt='%s')
