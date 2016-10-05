#!/bin/bash

#
# Create an ARPA language model, based on various sources as specified in a 'sources' file.
# Sources can be grouped. First an LM is generated for each group, with automatic weighting
# of sources depending on a specified 'target text'. Then the group-LMs are combined in a
# similar manner with groups weighted for minimizing perplexity for a 'target text'.
#
# The 'sources' file is simply a list of lines each of which are either
#   - a group name between [ ], e.g. '[Ebooks]'
#   - a shorthand name, followed by a full path for the source, e.g. 'HarryPotter  /text/ebooks/harrypotter.txt'
# A source is assumed to belong to the group it is placed directly under.
#
#
# Usage: CreateArpaLM.sh [options] <sources-file> <LM-name> <output-location>
#

[ -f path.sh ] && . ./path.sh

force_overwrite=false
remove_temp=false
interpolate=true
interpolopts=
lmtarget=
working_dir=
lmtarget=
vocab=
vocabopts=
ngramorder=4
prune="1e-10"
triprune="1e-8"
prune_lowprobs=true

. parse_options.sh || exit 1;

if [ $# != 3 ]; then
    echo "Wrong #arguments ($#, expected 3)"
    echo "Usage: CreateArpaLM.sh [options] <sources-file> <LM-name> <output-location>"
    echo "  "
    echo "main options (for others, see top of script file)"
    echo "  --working-dir <directory>       # place to create intermediate LM and PPL files, default: location of source text file."
    echo "  --force-overwrite (true|false)  # default: ${force_overwrite}, overwrite existing PPL and LM intermediate files."
    echo "  --lmtarget <txt-file>           # target text-file for optimizing source-combination, if not specified use equal weighting for all sources and groups"
    echo "  --vocab <vocab-file|dict-file>  # limit LM to given vocab"
    echo "  --ngramorder <ngram order>      # default: $ngramorder"
    echo "  --interpolate (true|false)      # default: $interpolate"
    echo "  --prune <threshold>             # default: $prune"
    echo "  --prune-lowprobs (true|false)   # default: $prune_lowprobs"
    echo "  --remove-temp (true|false)      # default: ${remove_temp}, removes temporary files, such as PPL and intermediate LM files."
    exit 1;
fi

sources=$1
lmname=$2
outdir=$3

working=$working_dir

mkdir -p $outdir/temp
if [ ! -z $working_dir ]; then
    mkdir -p $working_dir
fi

# set the ngram options and output name
if [ ! -z $vocab ]; then
    vocabopts="-limit-vocab -vocab $outdir/temp/vocab"
    cat $vocab | awk '{print $1."\n"}' | sort | uniq >$outdir/temp/vocab
fi
if $interpolate; then
    interpolopts="-interpolate"
fi
ngramopts="-order $ngramorder $vocabopts -kndiscount -unk $interpolopts -gt2min 0 -gt3min 1 -gt4min 2"
# ngramopts="-order $ngramorder $vocabopts -kndiscount -unk $interpolopts"

if $prunelowprobs; then
    prunelpopts="-prune-lowprobs"
fi

ngramname="${ngramorder}g.kn.int"
prunedname="${ngramorder}gpr.kn.int"
trigramname="3gpr.kn.int"

# make the arpa LM if it doesn't exist yet
if $force_overwrite || [ ! -e $outdir/${lmname}.${ngramname}.arpa.gz ]; then
    # read each source, and create a basic ARPA-lm
    # then apply the lm to a target text to get its perplexity
    while read line; do
        firstchar=`echo "$line" | cut -c1`      
        if [ "$firstchar" == "#" ]; then            # handle commented lines
            continue
        elif [ "$firstchar" == "[" ]; then          # new group definition
            groupno=$((groupno+1))
            groupname[$groupno]=`echo "$line" | sed -E 's/^\[(.*)\]$/\1/'`           
            continue
        fi
        name=`echo "$line" | cut -f1`
        source=`echo "$line" | cut -f2`
        if [ -e $source ]; then
            if [ -z working_dir ]; then working=$(dirname $source); fi
            if $force_overwrite || [ ! -e $working/${name}.${ngramname}.binlm ]; then
                echo "Creating LM for $name using options: $ngramopts"
                ngram-count -text $source -write-binary-lm -lm $working/${name}.${ngramname}.binlm $ngramopts
            fi
            if $force_overwrite || [ ! -e $working/${name}.ppl ]; then
                ngram -lm $working/${name}.${ngramname}.binlm -order 4 -unk -ppl $lmtarget -debug 2 >$working/${name}.ppl
            fi
            ppls[$groupno]="${ppls[$groupno]} $working/${name}.ppl"
            sourceno=$((sourceno+1))
            groupsource[$groupno]="${groupsource[$groupno]} $sourceno"              # store the list of sources for each group
            sourcesname[$sourceno]=$name
            sourcesloc[$sourceno]=$working
        fi
    done < $sources

    # based on the perplexities of the individual sources, calculate the optimal
    # combination weight to get the lowest perplexity of the final model on the target text
    # first do this for each group

    ## calculate optimal mix
    for i in "${!ppls[@]}"; do
        lambdas=$(compute-best-mix ${ppls[$i]} | grep best | perl -e '$_=<STDIN>; s/^.*\((.*)\).*$/$1/; print $_;')
        read -r -a la <<< "$lambdas"
        rm -f $outdir/temp/${groupname[$i]}.lambdas
        counter=0
        for sourceno in ${groupsource[$i]}; do
            name=${sourcesname[$sourceno]}
            working=${sourcesloc[$sourceno]}
            echo "$working/${name}.${ngramname}.binlm -weight ${la[$counter]} -order $ngramorder" >>$outdir/temp/${groupname[$i]}.lambdas
            counter=$((counter+1))
        done
    done

    ## create LM's for each group
    for i in "${!groupname[@]}"; do
        name=${groupname[$i]}
        if $force_overwrite || [ ! -e $outdir/temp/${name}.${ngramname}.binlm ]; then
            echo "Creating LM for $name using options: $ngramopts"
            ngram -read-mix-lms -lm $outdir/temp/${name}.lambdas -order $ngramorder -renorm -unk -write-bin-lm $outdir/temp/${name}.${ngramname}.binlm
        fi
        if $force_overwrite || [ ! -e $outdir/temp/${name}.ppl ]; then
            ngram -lm $outdir/temp/${name}.${ngramname}.binlm -order $ngramorder -unk -ppl $lmtarget -debug 2 >$outdir/temp/${name}.ppl
        fi
        gppl="$gppl $outdir/temp/${name}.ppl"
    done

    ## calculate optimal mix of groups
    lambdas=$(compute-best-mix $gppl | grep best | perl -e '$_=<STDIN>; s/^.*\((.*)\).*$/$1/; print $_;')
    read -r -a la <<< "$lambdas"
    rm -f $outdir/temp/groups.lambdas
    counter=0
    for i in "${!groupname[@]}"; do
        name=${groupname[$i]}
        echo "$outdir/temp/${name}.${ngramname}.binlm -weight ${la[$counter]} -order $ngramorder" >>$outdir/temp/groups.lambdas
        counter=$((counter+1))
    done

    ## Build a combined lm. Since it will typically be rather large, it must be pruned, even for rescoring
    echo "Creating final LM $outdir/${lmname}.${ngramname}.arpa.gz"
    ngram -read-mix-lms -lm $outdir/temp/groups.lambdas -order $ngramorder -renorm -unk -write-lm $outdir/${lmname}.${ngramname}.arpa.gz
    echo "Pruning final LM $outdir/${lmname}.${ngramname}.arpa.gz"
    ngram -lm $outdir/${lmname}.${ngramname}.arpa.gz -order $ngramorder $prunelpopts -prune $prune -unk -write-lm $outdir/${lmname}.${prunedname}.arpa.gz
	if [ $ngramorder -gt 3 ]; then	 
		echo "Creating pruned trigram version for decoding"
		ngram -lm $outdir/${lmname}.${ngramname}.arpa.gz -order 3 -unk -prune $triprune -write-lm $outdir/${lmname}.${trigramname}.arpa.gz
	fi
fi
