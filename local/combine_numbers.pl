#!/usr/bin/env perl

## combine numbers in ctm files accordig to `onze taal' rules.
## http://www.onzetaal.nl/advies/getallen.php

## input:  ctm formatted file with numbers as seperate words
## output: ctm formatted file with numbers as words according to rules of `onze taal'

$dumplevel=99;

%level=("één", 1, "een", 1,
		"twee", 2, "drie", 2, "vier", 2,
		"vijf", 3, "zes", 3, "zeven", 3, "acht", 3, "negen", 3,
		"tien", 4,
		"elf", 5, "twaalf", 5, "dertien", 5, "veertien", 5, "vijftien", 5, "zestien", 5, "zeventien", 5, "achttien", 5, "negentien", 5,
		"twintig", 6 , "dertig", 6, "veertig", 6, "vijftig", 6, "zestig", 6, "zeventig", 6, "tachtig", 6, "negentig", 6,
		"honderd", 7,
		"duizend", 8,
		"en", 9,
		"tweeën", 10, "drieën", 10, "vieren", 10, "vijfen", 10, "zesen", 10, "zevenen", 10, "achten", 10, "negenen", 10, 
		"tweehonderd", 21, "driehonderd", 21, "vierhonderd", 21, "vijfhonderd", 21, "zeshonderd", 21, "zevenhonderd", 21, "achthonderd", 21, "negenhonderd", 21, 
		"vijftienhonderd", 22, "zestienhonderd", 22, "zeventienhonderd", 22, "elfhonderd", 22, "twaalfhonderd", 22, "dertienhonderd", 22, "veertienhonderd", 22, 
		"achttienhonderd", 22,
		"tweeëntwintig", 23, "drieëntwintig", 23, "drieëndertig", 23, "vierentwintig", 23, "vijfentwintig", 23, "vijfendertig", 23, 
		"vijfenveertig", 23, "vijfenzeventig", 23, "vijfenzestig", 23, "vijfenvijftig", 23, "zesentwintig", 23, "zesendertig", 23, 
		"zevenentwintig", 23, "achtentwintig", 23, 
		"tweehonderdvijftig", 27, "honderdvijftig", 27, "honderdzestig", 27
		);

%combinations=("3 4", 5,
			   "2 7", 21, "3 7", 21, "5 7", 22, "23 7", 22,
			   "1 9 6", 23, "2 9 6", 23, "3 9 6", 23, "26 9 6", 23, "10 6", 23,
			   "21 23", 24, "22 23", 25,
			   "21 1", 26, "21 2", 26, "21 3", 26,
			   "7 1", 26, "7 2", 26, "7 3", 26,
			   "7 4", 27, "7 5", 27, "7 6", 27, "21 4", 27, "21 5", 27, "21 6", 27,
			   "2 8", 99, "3 8", 99, "4 8", 99, "5 8", 99, "6 8", 99, "7 8", 99, "21 8", 99, "23 8", 99, "24 8", 99, "26 8", 99, "27 8", 99);
			 
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

sub setlevel {
	my $lastone=@{$readlines}-1;
	if (exists($level{$readlines->[$lastone][4]})) {
		$readlines->[$lastone][$numcols]=$level{$readlines->[$lastone][4]};
	} else {
		$readlines->[$lastone][$numcols]=$dumplevel;
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
