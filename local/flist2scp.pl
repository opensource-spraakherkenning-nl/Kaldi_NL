#!/usr/bin/perl

use File::Find;

$|=1;
$diarisation=1;
$lium="lib/lium_spkdiarization-8.4.1.jar";

# use default names for output files
open(UTT, ">$ARGV[0]/ALL/utt2spk.tmp");
open(SEG, ">$ARGV[0]/ALL/segments");
open(SPK, ">$ARGV[0]/ALL/spk2gender");
open(TXT, ">$ARGV[0]/ALL/text_ref");
open(SCP, ">$ARGV[0]/ALL/wav.scp");

sub do_diarization {
    my %channel;
    my %seg;
    my $starttime=shift(@_);
    if (! -e "$ARGV[0]/ALL/liumlog/$newsegname.seg") {
        system("java -Xmx2024m -jar $lium --fInputMask=$ARGV[0]/foo.wav --sOutputMask=$ARGV[0]/ALL/liumlog/$newsegname.seg $newsegname 2>$ARGV[0]/ALL/liumlog/$newsegname.log");
    }
    open(DIA, "$ARGV[0]/ALL/liumlog/$newsegname.seg") || die "seg file $ARGV[0]/ALL/liumlog/$newsegname.seg not found";
    while(<DIA>) {
        next if (/^;/);
        chop;
        @parts=split;
        # 0 - foo
        # 1 - channel
        # 2 - startframe
        # 3 - duration (frames)
        # 4 - gender
        # 5 - bandwidth
        # 6 - environment
        # 7 - speaker label
        $seg{$parts[2]}{end}=($parts[2]+$parts[3])/100;     # endtime in seconds
        $seg{$parts[2]}{gender}=lc($parts[4]);
        $seg{$parts[2]}{band}=lc($parts[5]);
        $seg{$parts[2]}{speaker}=$parts[7];
    }
    # now make the output files based on our new diarisation
    my $count;
    foreach $start (sort {$a <=> $b} keys %seg) {
        $count++;
        my $fullnewsegname=sprintf("%s.%03d", $newsegname, $count);
        my $speaker=$seg{$start}{speaker};
        $speakername="$newsegname-$seg{$start}{speaker}";
        if ($ARGV[1] eq 'true') {
            # make sure the correct channel is picked for the ASR
            if (!$channel{$speaker}) {
                $channel{$speaker}=`local/spk2channel.sh $speaker $ARGV[0]/foo.wav $ARGV[0]/ALL/liumlog/$newsegname.seg`;
                chop($channel{$speaker});
            }
            $line=sprintf("%s %s %.3f %.3f", $fullnewsegname, "$basefile.$channel{$speaker}", $starttime+($start/100), $starttime+$seg{$start}{end});
        } else {
            $line=sprintf("%s %s %.3f %.3f", $fullnewsegname, $basefile, $starttime+($start/100), $starttime+$seg{$start}{end});
        }
        print SEG "$line\n";
        $line=sprintf("%s %s", $fullnewsegname, $speakername);
        print UTT "$line\n";
        
        print SPEAKERS uc($seg{$start}{gender}).uc($seg{$start}{band})." $fullnewsegname\n";
        $speakerlist{$speakername}=$seg{$start}{gender};
    }
    print STDERR "$newsegname: $count segments found\r";
    
    if(exists($transcriptions{$basefile})) {
        print TXT "$newsegname ";
        foreach $start (sort {$a <=> $b} keys %{$transcriptions{$basefile}}) {
            if (exists($uemstuff{$basefile})) {
                if (($start>=$uemstuff{$basefile}{$n}{start}) && ($start<$uemstuff{$basefile}{$n}{end})) {
                    print TXT "$transcriptions{$basefile}{$start} ";
                }
            } else {
                print TXT "$transcriptions{$basefile}{$start} ";
            }
        }
        print TXT "\n";
    }
}

if (-e <$ARGV[0]/*.uem>) {
    system("cat $ARGV[0]/*.uem | sort >$ARGV[0]/ALL/test.uem");
}

if (-s "$ARGV[0]/ALL/test.uem") {
    open(UEM, "$ARGV[0]/ALL/test.uem");
    while(<UEM>) {
        chop;
        @parts=split(/\s+/);
        if (exists($uemstuff{$parts[0]})) {
            $n++;
        } else {
            $n=1;
        }
        $uemstuff{$parts[0]}{$n}{start}=$parts[2];
        $uemstuff{$parts[0]}{$n}{end}=$parts[3];
    }
}

if (-e <$ARGV[0]/*.stm>) {
    system("cat $ARGV[0]/*.stm >$ARGV[0]/ALL/test.stm");
}

if (-s "$ARGV[0]/ALL/test.stm") {
    open(STM, "$ARGV[0]/ALL/test.stm");
    while(<STM>) {
        chop;
        @parts=split;
        m/>\s(.*)$/;
        $transcriptions{$parts[0]}{$parts[3]}=lc($1);
        $duration{$parts[0]}{$parts[3]}=$parts[4]-$parts[3];
        $gender{$parts[0]}{$parts[3]}=lc(substr($parts[2],0,1));
    }
}

if($diarisation) {
    print STDERR "Diarisation by LIUM in use\n";
    open(SPEAKERS, ">$ARGV[0]/BWGender");
}

open(IN, "$ARGV[0]/test.flist");
while(<IN>) {
   chop;
 	m:^\S+/(.+)\.[a-zA-Z0-9]+$: || die "Bad line $_";
    $basefile = "$1";
    $fullfile=$_;
    $numchannels=`soxi -c $fullfile`;
        
    if (exists($uemstuff{$basefile})) {
        # TODO: Multichannel UEM stuff
        foreach $n (sort {$a <=> $b} keys %{$uemstuff{$basefile}}) {
            $newsegname=sprintf("%s.%02d", $basefile, $n);
            $duration=$uemstuff{$basefile}{$n}{end}-$uemstuff{$basefile}{$n}{start};
            system("sox $fullfile $ARGV[0]/foo.wav trim $uemstuff{$basefile}{$n}{start} $duration");
            do_diarization($uemstuff{$basefile}{$n}{start});
        }
       if ($numchannels==2) {
       	print SCP "$basefile sox $fullfile -r 16k -e signed-integer -t wav - remix 1,2 |\n";
       } else {
       	print SCP "$basefile sox $fullfile -r 16k -e signed-integer -t wav - |\n";
       }
    } else {
        $newsegname=$basefile;
        system("sox $fullfile $ARGV[0]/foo.wav");
        do_diarization(0);      # no uem, so file starts at 0
        if  ($ARGV[1] eq 'true') {            
            for my $ch (1..$numchannels) {
                print SCP "$basefile.$ch sox $fullfile -r 16k -e signed-integer -t wav - remix $ch |\n";
            }
        } else {
        		if ($numchannels==2) {
            	print SCP "$basefile sox $fullfile -r 16k -e signed-integer -t wav - remix 1,2 |\n";
            } else {
            	print SCP "$basefile sox $fullfile -r 16k -e signed-integer -t wav - |\n";
            }
        }
    }
    print STDERR "\n";
}

# create spk2gender file
foreach $speaker (sort keys %speakerlist) {
    print SPK "$speaker $speakerlist{$speaker}\n";
}
