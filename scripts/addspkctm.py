#! /usr/bin/python

# This script add speaker labels provided by the speaker diarization system (LIUM) to the ctm files. 

import codecs, sys
import numpy as np

rttm_file = sys.argv[1]
ctm_file = sys.argv[2]

b_times = []
spk_info = []

for line in codecs.open(rttm_file, 'r'):
	fields = line.split()
        b_times.append(float(fields[3]))
        spk_info.append(fields[7])

b_times = np.array(b_times)

fid = codecs.open(ctm_file+'.spk', 'wa')

for line in codecs.open(ctm_file, 'r'):
	fields = line.split()
	spk_id = spk_info[np.sum(b_times<float(fields[2]))-1]
        fid.write(line[:-1]+' '+spk_id+'\n')

fid.close()
