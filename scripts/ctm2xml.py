#!/usr/bin/env python3

import sys, pdb
import re
import wave
import contextlib
import xml.etree.cElementTree as ET
import xml.dom.minidom


# This script is written to convert ctm files into xml format. It is based on the following assuptions:
# 1- the CTM file corresponds to a single audio file.
# 2- No segementaion info is available, so the wole audion file is transcribed into one segment
# 3- Single speaker/ No speaker identification

ResFolder = sys.argv[1]
UttId = sys.argv[2]
AudioFolder = sys.argv[3]

with open(ResFolder+'/'+UttId+'.ctm','r',encoding='utf-8') as f:
    lines=[]
    for line in f:
        lines.append(line)



CTM=[]
Res={}
for line in lines:
    if line.find('\n')>0:
        line=re.sub("\n"," ",line)
    tmp=line.split(" ")

    Res={}
    Res['fname']=tmp[0]
    Res['channel']=tmp[1]
    Res['stime']='%.2f' %float(tmp[2])
    Res['dur']=tmp[3]
    Res['word']=tmp[4]
    Res['conf']=tmp[5]

    CTM.append(Res)


sdur=str(float(CTM[-1]['stime'])+float(CTM[-1]['dur'])) #file duration
nwords=str(len(CTM))
# get the signal duration from the wav file
fname = CTM[0]['fname']+".wav"
with contextlib.closing(wave.open(AudioFolder+'/'+fname,'r')) as f:
    frames = f.getnframes()
    rate = f.getframerate()
    duration = frames / float(rate)
##    print(duration)
tdur='%.2f' %duration

# write to xml
root = ET.Element("AudioDoc", path=AudioFolder, name=CTM[0]['fname']+".wav")

ProcList = ET.SubElement(root, "ProcList")
ChannelList = ET.SubElement(root, "ChannelList")
SpeakerList = ET.SubElement(root, "SpeakerList")
SegmentList = ET.SubElement(root, "SegmentList")

ET.SubElement(ProcList, "Proc", name="OH-rec", version="1.0", editor="Radboud Research")

ET.SubElement(ChannelList, "Channel", tconf="1.0", nw=nwords, spdur=sdur, sigdur=tdur, num=CTM[0]['channel'])

ET.SubElement(SpeakerList, "Speaker", lang="dut", tconf="1.0", nw=nwords, lconf="1.00", spkid="Int", gender="1", dur=sdur, ch="1")

SpeechSegment=ET.SubElement(SegmentList, "SpeechSegment", lang="dut", lconf="1.00", spkid="Int", ch="1", trs="1", stime=CTM[0]['stime'], etime=sdur, sconf="1.00")

for line in CTM:
    ET.SubElement(SpeechSegment, "Word", stime=line['stime'], dur=line['dur'], conf=line['conf']).text=line['word']


tree = ET.ElementTree(root)
tree.write(ResFolder+'/'+CTM[0]['fname']+".xml",encoding="UTF-8",xml_declaration=True)

xml = xml.dom.minidom.parse(ResFolder+'/'+CTM[0]['fname']+".xml")
pretty_xml = xml.toprettyxml()
with open(ResFolder+'/'+CTM[0]['fname']+".xml",'w',encoding='utf-8') as fid:
    fid.write(pretty_xml)
    fid.close()
