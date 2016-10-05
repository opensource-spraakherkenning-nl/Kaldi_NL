#!/usr/bin/perl

open(IN, $ARGV[0]);
while(<IN>) {
    chop;
    @parts=split;
    $seg2file{$parts[0]}=$parts[1];
    $seg2offset{$parts[0]}=$parts[2];
}

while(<STDIN>) {
    chop;
    @parts=split;
    $parts[2]+=$seg2offset{$parts[0]};
    $parts[0]=$seg2file{$parts[0]};
    print join(" ", @parts)."\n";
}