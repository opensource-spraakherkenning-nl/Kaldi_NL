#!/usr/bin/perl

#
# Remove arcs from lattice that contain certain words
#
# usage: remove_from_lat <input-lat> <words.txt> <remove-words.txt> <output-lat>
#

if(substr($ARGV[0], -2) eq 'gz') {
    $command="zcat ";
} else {
    $command="cat ";
}
$command.=$ARGV[0]." | lattice-copy ark:- ark,t:foo.lat.txt";
system("$command");

open(REMOVE, $ARGV[2]);
while(<REMOVE>) {
    chop;
    $wordstoremove{$_}=1;
    print $_."\n";
}

open(WORDS, $ARGV[1]);
while(<WORDS>) {
    chop;
    @parts=split(/ /);
    if(exists($wordstoremove{$parts[0]})) {
        $toremove{$parts[1]}=1;
        print "$parts[0] $parts[1]\n";
    }
}

open(LAT, "foo.lat.txt");
open(OUT, ">$ARGV[3]");
$newseg=1;
while(<LAT>) {
    chop;
    if($_ eq "") {
        # flush
        print OUT "$segname\n";
        $changes=1;
        
        my %replacesource;
        my %replacetarget;
        
        # figure out what to do with each of the nodes on removable arcs
        foreach $arcno (sort {$a <=> $b} keys %arcaway) {
            if (($incoming{$source[$arcno]}==0) && ($incoming{$target[$arcno]}==0)) {
                $replacesource{$target[$arcno]}=$source[$arcno];
            }
            if ($incoming{$source[$arcno]}>0) {
                $replacetarget{$source[$arcno]}=$target[$arcno];
            }
            if (($incoming{$source[$arcno]}==0) && ($incoming{$target[$arcno]}>0)) {
                $replacetarget{$source[$arcno]}=$target[$arcno];
                $replacesource{$target[$arcno]}=$source[$arcno];
            }
        }
        
        # then do it
        while($changes>0) {
            $changes=0;
            for(my $t=0; $t<$count; $t++) {
                if(!exists($arcaway{$t})) {
                    if(exists($replacesource{$source[$t]})) {
                        $source[$t]=$replacesource{$source[$t]};
                        $changes++;
                    }
                    if(exists($replacetarget{$target[$t]})) {
                        $target[$t]=$replacetarget{$target[$t]};
                        $changes++;
                    }
                }
            }
            print "$segname $changes\n"
        }
        
        # and output the corrected arcs
        for(my $t=0; $t<$count; $t++) {
            if(!exists($arcaway[$t])) {
                print OUT "$start[$t]\t$target[$t]\t$word[$t]\t$scorepath[$t]\n";
            }
        }
        print OUT "\n";
        $newseg=1;
        $count=0;
        %incoming=();
        next;
    }
    @parts=split;
    if($newseg) {
        $segname=$_;
        $newseg=0;
        next;
    } else {
        $source[$count]=$parts[0];
        $target[$count]=$parts[1];
        $word[$count]=$parts[2];
        $scorepath[$count]=$parts[3];
        if (! exists($toremove{$word[$count]})) {
            $incoming{$target[$count]}++;             # keep track of # of non-removable incoming nodes
        } else {
            $arcaway{$count}=1;                       # keep track of which arcs to remove
        }
        $count++;
    }
}
