
# coding: utf-8

# In[ ]:


import numpy as np
import pandas as pd


# In[ ]:


import sys
import os
import random

from optparse import OptionParser


#def prepare_options(parser):

parser = OptionParser()

parser.add_option("-n", "--normal_sample_name", dest="normal_sample_name",
	      help="Input FILE", metavar="FILE")
parser.add_option("-d", "--df_path", dest="df_path",
	      help="Output FILE", metavar="FILE")
parser.add_option("-p", "--path", dest="path",
	      help="Output FILE", metavar="FILE")

(options, args) = parser.parse_args()

df_path = options.df_path
normal_sample_name = options.normal_sample_name
path = options.path


# In[ ]:

print('\n[Debug]: Print options:', options)
print('\n[Debug]: Print args:', args)



def removeRows(df_path, normal_sample_name):
    df = pd.read_csv(df_path, sep='\t', index_col=False)
    return df[~df["SAMPLE"].str.contains(normal_sample_name)]


# In[ ]:

#if __name__ == '__main__':
#    parser = OptionParser("usage: %prog [options]")
#    prepare_options(parser)
#    (options, args) = parser.parse_args()

#    if not options.input_file or not options.output_file:
#        parser.error("Invalid arguments. Use -h for help.")

    #process(options.normal_sample_name, options.df, options.path)
    #inputs = parse_input(options.input_file)
    #outputs = generate_output(inputs)
    #np.savetxt(options.output_file, outputs, delimiter='\t', fmt='%s')

print(removeRows(df_path, normal_sample_name).head(10))

removeRows(df_path, normal_sample_name).to_csv(path, index=False, sep = '\t')


# In[ ]:





# In[ ]:

