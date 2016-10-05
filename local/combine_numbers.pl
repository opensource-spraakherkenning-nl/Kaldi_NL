#!/usr/bin/env perl

## combine numbers in ctm files accordig to `onze taal' rules.
## http://www.onzetaal.nl/advies/getallen.php

## input:  ctm formatted file with numbers as seperate words
## output: ctm formatted file with numbers as words according to rules of `onze taal'

## some changes by LvdW, 09-2016 : we can now correctly combine stuff ending in 'jarige', etc.

$dumplevel=99;

# contents of hashes changed by LvdW, 09-2016
%level=("één", 1, "een", 1,
		"twee", 2, "drie", 2, "vier", 2,
		"vijf", 3, "zes", 3, "zeven", 3, "acht", 3, "negen", 3,
		"tien", 4,
		"elf", 5, "twaalf", 5, "dertien", 5, "veertien", 5,
		"twintig", 6 , "dertig", 6, "veertig", 6, "vijftig", 6, "zestig", 6, "zeventig", 6, "tachtig", 6, "negentig", 6,
		"honderd", 7,
		"duizend", 8,
		"en", 9, "ën", 9,
		"jarige", 11, "jarig", 11, "plusser", 11, "plussers", 11, "maal", 11, "delig", 11, "delige", 11, 
		"tallig", 11, "tallige", 11, "ponder", 11, "persoons", 11, "kops", 11, "tonner", 11, "voudig", 11, "voudige", 11
		);

%combinations=("3 4", 5,
               "1 9 6", 23, "2 9 6", 23, "3 9 6", 23, "26 9 6", 23,
               "10 6", 23, 
			   "2 7", 21, "3 7", 21, "5 7", 22, "23 7", 22,
			   "21 23", 24, "22 23", 25,
			   "21 1", 26, "21 2", 26, "21 3", 26,
			   "7 1", 26, "7 2", 26, "7 3", 26,
			   "7 4", 27, "7 5", 27, "7 6", 27, "21 4", 27, "21 5", 27, "21 6", 27,
			   "2 8", 90, "3 8", 90, "4 8", 90, "5 8", 90, "6 8", 90, "7 8", 90, "21 8", 90, "23 8", 90, "24 8", 90, "26 8", 90, "27 8", 90,
			   "1 11", 91, "2 11", 91, "3 11", 91, "4 11", 91, "5 11", 91, "6 11", 95, "7 11", 92, "8 11", 93, 
			   "21 11", 94, "22 11", 94, "23 11", 94, "24 11", 94, "25 11", 94, "26 11", 94, "27 11", 94, "90 11", 94,
               "7 91", 96, "8 91", 96, "21 91", 96, "22 91", 96,
               "7 95", 96, "8 95", 96, "21 95", 96, "22 95", 96,  
               "2 92", 96, "3 92", 96, "4 92", 96, "5 92", 96, "23 92", 96,
               "7 93", 96, "21 93", 96, "23 91", 96, "24 91", 96, "26 91", 96, "27 91", 96,
               "1 9 95", 96, "2 9 95", 96, "3 9 95", 96, "26 9 95", 96,
               "10 95", 96
			   );

%detection=(%combinations, "1 9", 10, "2 9", 10, "3 9", 10, "26 9", 10);

sub writeresult {
	for ($t=0; $t<@{$readlines}; $t++) {
		if ($readlines->[$t][$numcols]==$dumplevel) {		
			$readlines->[$t][4]=~s/tweeen/tweeën/;
    		$readlines->[$t][4]=~s/drieen/drieën/;
    		$readlines->[$t][4]=~s/éénen/eenen/;
			for ($k=0; $k<$numcols; $k++) {
				print $readlines->[$t][$k]." ";
			}
			print "\n";
			splice(@{$readlines}, $t, 1);
		}
	}
}

sub matchlevel {
	# find if $word matches any of the levels %testlevels
	$curlevel=$dumplevel;
	foreach $baseterm (keys(%level)) {
		if (exists($testlevels{$level{$baseterm}}) && ($word=~m/^$baseterm/)) {
			$curlevel=$testlevels{$level{$baseterm}};
			$word=substr($word, length($baseterm));	
			last;
		}
	}
}

sub setlevel {
	my $lastone=@{$readlines}-1;
	if (exists($level{$readlines->[$lastone][4]})) {
		$readlines->[$lastone][$numcols]=$level{$readlines->[$lastone][4]};
	} else {
		# added by LvdW, 09-2016
		# determine level for pre-combined words
		$readlines->[$lastone][$numcols]=$dumplevel;		# if this isn't a precombined word, then dump
		$word=$readlines->[$lastone][4];
		# find a start
		%testlevels=(1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8);
		while((scalar keys %testlevels>0) && (length($word)>0)) {
			&matchlevel;
			%testlevels=();
			foreach $combo (keys(%detection)) {
				@levels=split(" ", $combo);
				if ((scalar @levels==2) && ($curlevel==$levels[0])) {
					$testlevels{$levels[1]}=$detection{$combo};
				}							
			}
		}
		$readlines->[$lastone][$numcols]=$curlevel;
	}
}

sub combinelines {
	my $lastone=@{$readlines}-1;
	my $tomatch;
	
	if ($lastone==0) {return;}
	
	for($t=0; $t<@{$readlines}; $t++) {
		$tomatch.=$readlines->[$t][$numcols]." ";				# put levels in a string
	}
	chop($tomatch);
	if	(exists($combinations{$tomatch})) {						# if string can be rewritten
		for($t=1; $t<@{$readlines}; $t++) {
			$readlines->[0][4].=$readlines->[$t][4];			# cascade words in strings
			$readlines->[0][3]+=$readlines->[$t][3];			# set new duration
		}
		$readlines->[0][$numcols]=$combinations{$tomatch};		# set new level
		splice(@{$readlines}, 1);								# and remove integrated lines
	} elsif ($readlines->[$lastone][$numcols]!=9) {
		$readlines->[0][$numcols]=$dumplevel;					# if words cannot be combined, write to file
	}
}

while(<STDIN>) {
	my (@words)=split;
	$numcols=@words;
	push (@{$readlines}, \@words);				# store new line in readlines;
	&setlevel();
	&combinelines();
	&writeresult();
}

if (@{$readlines}>0) {
	$readlines->[0][$numcols]=$dumplevel;
	&writeresult;
}
