#!/usr/bin/env python3

# This script add speaker labels provided by the speaker diarization system (LIUM) to the ctm files.

import sys
import numpy as np

rttm_file = sys.argv[1]
ctm_file = sys.argv[2]

b_times = []
spk_info = []

for line in open(rttm_file, 'r', encoding='utf-8'):
    fields = line.split()
    b_times.append(float(fields[3]))
    spk_info.append(fields[7])

b_times = np.array(b_times)

with open(ctm_file+'.spk', 'a', encoding='utf-8') as fid:
    for line in open(ctm_file, 'r', encoding='utf-8'):
        fields = line.split()
        spk_id = spk_info[np.sum(b_times<float(fields[2]))-1]
        fid.write(line[:-1]+' '+spk_id+'\n')

