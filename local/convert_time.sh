#!/bin/sh
#Convert seconds to h:m:s format

read S
((h=S/3600))
((m=S%3600/60))
((s=S%60))
printf "%dh:%dm:%ds\n" $h $m $s
