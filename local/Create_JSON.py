#!/usr/bin/env python
# -*- coding: utf-8 -*-

#
# Combine the outputs (ctm, utt2spk, segments) of the ASR run and create a JSON
# One JSON file is generated for each input soundfile.
# Can also output the transcriptions to .txt files
#
# Transcription alternatives are not included, only the #1 result is used.
#
# 2018, Laurens van der Werff
#


import json
import uuid
import argparse
from operator import itemgetter

parser = argparse.ArgumentParser(description='Convert ASR outputs into .txt and .json.')
parser.add_argument('-i', '--ident', default=[''], nargs=1, help='select a specific output when using multiple settings')
parser.add_argument('-t', '--text', action='store_true', help='Create .txt file')
parser.add_argument('-j', '--json', action='store_true', help='Create .json files')
parser.add_argument('-s', '--split', action='store_true', help='Make .txt file for each input file')
parser.add_argument('resultdir')
args = parser.parse_args()

transcription = {}

# Read/Create segments and speakerinfo
utt2spk = {}
utt2spkfile = open(args.resultdir + '/intermediate/data/ALL/utt2spk')
for line in utt2spkfile:
    utt,spk = line.rstrip().split()
    utt2spk[utt] = spk

segmentsfile = open(args.resultdir + '/intermediate/data/ALL/segments')
for line in segmentsfile:
    utt, file, start, end = line.rstrip().split()

    # Each input soundfile gets its own entry. A uuid4 code is used as unique identifier (similar to what
    # the kaldi-gst-streamer online system uses).
    if not file in transcription:
        transcription[file] = {}
        transcription[file]['id'] = str(uuid.uuid4())
        transcription[file]['title'] = file
        transcription[file]['segments'] = []
        transcription[file]['speakers'] = []

    spk = utt2spk[utt].replace(file, '',1).lstrip('.').lstrip('-')

    for spknum, spkname in enumerate(transcription[file]['speakers']):
        if spkname['name'] == spk:
            break
    else:
        transcription[file]['speakers'].append({'name': spk, 'active': "true", 'realid': 'none'});

    for spknum, spkname in enumerate(transcription[file]['speakers']):
        if spkname['name'] == spk:
            transcription[file]['segments'].append(
                {'status': 0, 'segment-start': float(start), 'segment-length': round(float(end) - float(start), 3),
                 'total-length': float(end), 'speakerid': spknum,
                 'result': {'final' : True, 'hypotheses' : [ {'confidence': 1.0, 'likelihood': 10,
                                                              'transcript': '', 'word-alignment': []}] } })
            break

# segments are sorted by speaker by default, but we need sorting by starting time
for file in transcription:
    transcription[file]['segments'].sort(key=itemgetter('segment-start'))

# Add transcription info
ctmfile = open(args.resultdir + '/1Best.' + args.ident[0].strip("'") + 'ctm')
ignore = False
for line in ctmfile:
    if '<ALT_BEGIN>' in line:
        continue
    elif '<ALT>' in line:
        ignore = True
    elif '<ALT_END>' in line:
        ignore = False
        continue
    if ignore: continue

    file, channel, start, duration, word, posterior = line.rstrip().split()
    # figure out which segment this word belongs to
    for segno, segname in enumerate(transcription[file]['segments']):
        if transcription[file]['segments'][segno]['segment-start'] <= float(start) and transcription[file]['segments'][segno]['total-length'] >= (float(start)+float(duration)):
            break
    start = round(float(start) - float(transcription[file]['segments'][segno]['segment-start']), 2)
    transcription[file]['segments'][segno]['result']['hypotheses'][0]['word-alignment'].append({'word': word, 'start': start, 'length': float(duration), 'confidence': posterior})
    transcription[file]['segments'][segno]['result']['hypotheses'][0]['transcript'] += word + ' '

# write results
if args.json:
    for file in transcription:
        f = open(args.resultdir +'/' + file + '.' + args.ident[0].strip("'") + 'json', 'w')
        f.write(json.dumps(transcription[ file  ]))
        f.close()

if args.text:
    f = open(args.resultdir + '/1Best.txt', 'w')
    for file in sorted(transcription.iterkeys()):
        if args.split:
            fs = open(args.resultdir + '/' + file + '.' + args.ident[0].strip("'") + 'txt', 'w')
        for segno, segname in enumerate(transcription[file]['segments']):
            if len(segname['result']['hypotheses'][0]['word-alignment']) > 0:
                f.write(segname['result']['hypotheses'][0]['transcript'].rstrip().capitalize() + '. (' + file + ' ' + str(segname['segment-start']) + ')\n')
                if args.split:
                    fs.write(segname['result']['hypotheses'][0]['transcript'].rstrip().capitalize() + '. (' + str(segname['segment-start']) + ')\n')
        if args.split:
            fs.close()
    f.close()

exit()
