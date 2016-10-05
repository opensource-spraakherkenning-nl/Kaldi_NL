cat $1 | grep 'MS\|FS\|MT\|FT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "A : %7d %7d - %5.2f % WER\n", s, e, e/s*100 } { s += $1; e += $2 }' >$2	
cat $1 | grep 'MS\|MT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "M : %7d %7d - %5.2f % WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep 'FS\|FT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "F : %7d %7d - %5.2f % WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep 'MS\|FS' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "S : %7d %7d - %5.2f % WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep 'MS' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "MS: %7d %7d - %5.2f % WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep 'FS' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "FS: %7d %7d - %5.2f % WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep 'MT\|FT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "T : %7d %7d - %5.2f % WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2
cat $1 | grep 'MT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "MT: %7d %7d - %5.2f % WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2	
cat $1 | grep 'FT' | awk '{printf "%7d %7d\n", $5, ($5*$11/100)+0.5}' | \
	awk 'END { printf "FT: %7d %7d - %5.2f % WER\n", s, e, e/s*100 } { s += $1; e += $2 }' 2>/dev/null >>$2
	