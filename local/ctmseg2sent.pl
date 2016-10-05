#!/usr/bin/perl

$ident=$ARGV[2];
open(CTM, "$ARGV[0]/1Best.".$ident."ctm");
open(SEG, "$ARGV[0]/intermediate/data/ALL/segments");
open(TXT, ">$ARGV[0]/1Best.".$ident."txt");
$splittext=$ARGV[1];

while(<SEG>) {
	chop;
	($segname, $name, $start, $end)=split;
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
	if ($splittext) {open(OUT, ">$ARGV[0]/$name.".$ident."txt");}
	foreach $segname (sort {$starttime{$a}<=>$starttime{$b}} keys %transcription) {
		if ($name eq $filename{$segname}) {		
			print TXT ucfirst(substr($transcription{$segname},0,-1).'. ('.$segname." ".$starttime{$segname}.")\n");
			if ($splittext) {
				print OUT ucfirst(substr($transcription{$segname},0,-1).'. ('.$segname." ".$starttime{$segname}.")\n");
			}
		}
	}
}
