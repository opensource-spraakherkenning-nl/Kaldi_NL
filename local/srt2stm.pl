#!/usr/bin/perl

use Time::Piece;
open(IN, $ARGV[0]);
while(<IN>) {
    chop;
    chop;
    if (m/.*-->.*/) {
        my $line="$ARGV[1] 1 unk ";
        my @times=split(/ --> /);
        my @timeb=split(/:/, substr($times[0],0,-4));
        my $startsec=($timeb[0]*3600)+($timeb[1]*60)+$timeb[2];
        @timeb=split(/:/, substr($times[1],0,-4));
        my $endsec=($timeb[0]*3600)+($timeb[1]*60)+$timeb[2];
        $line.=$startsec.".".substr($times[0],-3)." ".$endsec.".".substr($times[1],-3)." <o,F0,M>";
        { do {
            $inputline=<IN>;
            chop($inputline);
            chop($inputline);
            # print "-- $inputline --\n";
            last if ($inputline eq "");
            $inputline=~s/\.|,//g;
            $inputline=lc($inputline);
            $line.=" ".$inputline;
        } while 1; }
        my $num;
        $num++ while $line=~/\S+/g;
        if ($num>6) {
            print $line."\n";
        }
    }
}