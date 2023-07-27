#!/bin/bash
#

df=$1
name=$2

#head -1 $df | tr -s ' ' '\n' | nl -nln |  grep ${name} | cut -f1
#gets a column number by name

awk -F '\t' -v col=${name} 'NR==1{for (i=1; i<=NF; i++) if ($i==col) {print i;exit}}' $df

