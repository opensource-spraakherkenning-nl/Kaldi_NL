#!/usr/bin/perl

open(CTM, "$ARGV[0]/1Best.ctm");
open(SEG, "$ARGV[0]/Intermediate/Data/ALL/segments");

if (-e "$ARGV[0]/Intermediate/Data/ALL/segconv") {
	open(CONV, "$ARGV[0]/Intermediate/Data/ALL/segconv");
} else {
	open(CONV, "$ARGV[0]/Intermediate/Data/ALL_orig/segconv") || die "segconvert not found";
}

while(<CONV>) {
	chop;
	($testseg, $name)=split;
	$convert{$testseg}=$name;
}

while(<SEG>) {
	chop;
	($testseg, $name, $start, $end)=split;
	$segname=$convert{$testseg};
	$starttime{$segname}=$start;
	$endtime{$segname}=$end;
	$filename{$segname}=$name;
}

while(<CTM>) {
	chop;
	($file, $ch, $start, $dur, $word, $post)=split;
	if($word eq "<ALT_BEGIN>") {
		next;	
	} elsif ($word eq "<ALT>") {
		$ignore=1;
		next;	
	} elsif ($word eq "<ALT_END>") {
		$ignore=0;
		next;	
	}
	if($ignore) {next;}
	$filenames{$file}=1;
	foreach $segname (keys %filename) {
		if(($filename{$segname} eq $file) && ($start>=$starttime{$segname}) && ($start<$endtime{$segname})) {
			$transcription{$segname}.=$word." ";
			last;
		}	
	}
}

# output the transcriptions
foreach $name (sort keys %filenames) {
	foreach $segname (sort {$starttime{$a}<=>$starttime{$b}} keys %starttime) {
		if ($name eq $filename{$segname}) {		
			print $transcription{$segname}.'('.$segname." ".$starttime{$segname}.")\n";
		}
	}
}
