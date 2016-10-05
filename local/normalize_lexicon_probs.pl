#!/usr/bin/perl

#
# this script changes the probs in a lexicon/dict file so that for each entry the highest prob is 1
# rather than all pronounciation probs for a term summing up to 1, apparently, this gives better results
#

sub flush_current {
    my ($max)=sort {$b <=> $a} values %prob;
    if ($max>0) {
        foreach $pron (sort {$prob{$a} <=> $prob{$b}} keys %prob) {
            if ($prob{$pron}) {print "$currentterm\t".$prob{$pron}/$max."\t$pron\n";}
        }
    }
}

while(<STDIN>) {
    chop;
    @terms=split(/\t/);
    if(scalar(@terms)==2) {                         # line without a pronunciation prob:
        print "$terms[0]\t1.0\t$terms[1]\n";        #   add prob
        next;
    }
    if ($currentterm && ($terms[0] ne $currentterm)) {
        flush_current;
        undef %prob;
    }
    $currentterm=$terms[0];
    $prob{$terms[2]}=$terms[1];     # store prob for each pronounciation
}
flush_current;
