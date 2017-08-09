cat $1 | grep -a 'MS\|FS\|MT\|FT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "A : %7d %7d - %5.2f %% WER\n", s, e, e/s*100 } { s += $1; e += $2 }' >$2	
cat $1 | grep -a 'MS\|MT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "M : %7d %7d - %5.2f %% WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep -a 'FS\|FT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "F : %7d %7d - %5.2f %% WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep -a 'MS\|FS' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "S : %7d %7d - %5.2f %% WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep -a 'MS' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "MS: %7d %7d - %5.2f %% WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep -a 'FS' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "FS: %7d %7d - %5.2f %% WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep -a 'MT\|FT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "T : %7d %7d - %5.2f %% WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2
cat $1 | grep -a 'MT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "MT: %7d %7d - %5.2f %% WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep -a 'FT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "FT: %7d %7d - %5.2f %% WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2
