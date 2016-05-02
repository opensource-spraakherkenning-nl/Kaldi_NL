#!/usr/bin/env perl

# removes hyphens from words in .ctm file

while(<STDIN>) {
    chop;
    @cols=split;
    @subwords=split('-', $cols[4]);
    if (scalar(@subwords)>1) {
        $subwdur=$cols[3]/scalar(@subwords);
        for($t=0; $t<scalar(@subwords); $t++) {
            printf "%s %s %.3f %.2f %s %s\n" , $cols[0], $cols[1], $cols[2]+($t*$subwdur), $subwdur, $subwords[$t], $cols[5];
        }
    } else {
        print "$_\n";
    }
}