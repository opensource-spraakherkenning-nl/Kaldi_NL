#!/usr/bin/env perl

#***************************************************************************
#*   This file is part of the 'Shout LVCS Recognition toolkit'.            *
#***************************************************************************
#*   Copyright (C) 2005, 2006 by Marijn Huijbregts                         *
#*   m.a.h.huijbregts@ewi.utwente.nl                                       *
#*   http://wwwhome.cs.utwente.nl/~huijbreg/                               *
#*                                                                         *
#*   This program is free software; you can redistribute it and/or modify  *
#*   it under the terms of the GNU General Public License as published by  *
#*   the Free Software Foundation; either version 2 of the License, or     *
#*   (at your option) any later version.                                   *
#*                                                                         *
#*   This program is distributed in the hope that it will be useful,       *
#*   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
#*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
#*   GNU General Public License for more details.                          *
#*                                                                         *
#*   You should have received a copy of the GNU General Public License     *
#*   along with this program; if not, write to the                         *
#*   Free Software Foundation, Inc.,                                       *
#*   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
#***************************************************************************/

use strict;
use POSIX;

use Cwd;
my $dir = getcwd;

my $mapping = "$dir/local/compounds-release.lst";

my %compound  = ();

open(COMPOUND    , "< $mapping");
while(<COMPOUND>)
{
  chomp;
  if(/^([^\t]+)\t+([^\s]+)\s+(.*)\s([^\s]+)$/)
  {
    if($3 eq "+" or $3 eq "+ s +" or $3 eq "+ n +")
    {
      $compound{$2}{$4} = $1;
    }
  }
}
close(COMPOUND);

runThisFile();

sub runThisFile {
    my $ctmcount;
    my @ctm;
    while(<STDIN>) {
        chomp;
        my @parts=split;
        $ctm[$ctmcount]{key}=$parts[0];
        $ctm[$ctmcount]{ch}=$parts[1];
        $ctm[$ctmcount]{start}=$parts[2];
        $ctm[$ctmcount]{duration}=$parts[3];
        $ctm[$ctmcount]{word}=$parts[4];
      # if ($#parts>5) {
          $ctm[$ctmcount]{confidence}=$parts[5];
      # } else {
        #    $ctm[$ctmcount]{confidence}=99;
      # }
      
        $ctmcount++;
    }

  my $i;
    my $j;
  for($i=1;$i<$ctmcount;$i++) {
      if($ctm[$i-1]{key} eq $ctm[$i]{key}) {
          if(exists($compound{$ctm[$i-1]{word}}{$ctm[$i]{word}})) {
              print STDERR "Found compound: $compound{$ctm[$i-1]{word}}{$ctm[$i]{word}}\n";
              $ctm[$i-1]{duration}+=$ctm[$i]{duration};
              $ctm[$i-1]{word}=$compound{$ctm[$i-1]{word}}{$ctm[$i]{word}};
              $j=1;
          } else {
              $j=0;
          }
      }
      print "$ctm[$i-1]{key} $ctm[$i-1]{ch} $ctm[$i-1]{start} $ctm[$i-1]{duration} $ctm[$i-1]{word} $ctm[$i-1]{confidence}\n";
      $i+=$j;
  }
  if($i == $ctmcount) {
      print "$ctm[$i-1]{key} $ctm[$i-1]{ch} $ctm[$i-1]{start} $ctm[$i-1]{duration} $ctm[$i-1]{word} $ctm[$i-1]{confidence}\n";
  }
}
