#!/usr/bin/perl

sub change_names {
    my $file=shift(@_);
    my $column=shift(@_);
    my @out;
    
    open(IN, "$file");
    while(<IN>) {
        chop;
        @parts=split;
        $parts[$column]=$newname{$parts[$column]};
        push(@out, join(" ", @parts));
    }
    
    open(OUT, ">$file");
    foreach $line (@out) {
        print OUT "$line\n";
    }
}

open(CONV, ">$ARGV[0]/ALL/segconv");

open(IN, "$ARGV[0]/ALL/utt2spk");
while(<IN>) {
    chop;
    @parts=split;
    $name=sprintf("testseg%010d", $count++);
    $newname{$parts[0]}=$name;
    print CONV "$name $parts[0]\n";         # so we can change things back after reco
    $parts[0]=$newname{$parts[0]};
    push(@utt2spk, join(" ", @parts));
}

open(OUT, ">$ARGV[0]/ALL/utt2spk");
foreach $line (@utt2spk) {
    print OUT "$line\n";
}

# system("cp $ARGV[0]/ALL/segments $ARGV[0]/ALL/segments.orig");
change_names("$ARGV[0]/ALL/segments", 0);
# system("cp $ARGV[0]/BWGender $ARGV[0]/BWGender.orig");
change_names("$ARGV[0]/BWGender", 1);

