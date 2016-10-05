#!/bin/bash

#
# configure decode.sh:
#
# 	- set available acoustic/language model options
#	- provide simple aliases for modelcombinations
#	- set default model
#

#
# Select acoustic model
#

[ -f ./path.sh ] && . ./path.sh; # source the path.
[ ! -e decode.sh ] && touch decode.sh 

model=
version=
lmodel=
lversion=
llmodel=
llversion=
extractor=
graphloc=
return_value=0

skip_nochoice=$(cat local/settings | grep "skip_nochoice" | awk -F'=' '{print $2}')
auto_latest=$(cat local/settings | grep "auto_latest" | awk -F'=' '{print $2}')

exec 3>&1

myRadioDialog () {
	selected=
	list=
	i=1
	
	# add numbers & remove unwanted versions
	for mem in $3; do
		[ $auto_latest -eq 1 ] && [[ $mem == v* ]] && continue
		[ ! $auto_latest -eq 1 ] && [[ $mem == latest* ]] && continue
		list="${list}$i $mem off " && ((i++))
	done

	# select current option
	[ $4 ] && list=$(echo $list | sed "s%$4 off%$4 on%")

	selecteda=($list)
	if [ ${#selecteda[@]} -eq 3 ] && [ $skip_nochoice -eq 1 ]; then
		selected=1
	else
		while [ ! "$selected" ] && [ $return_value -eq 0 ]; do
			selected=$(dialog --backtitle "$1" --radiolist "$2" 0 0 0 $list 2>&1 1>&3 )
			return_value=$?
		done
	fi
	
	echo $selected
	if [ $return_value -eq 0 ]; then
		returnval="${selecteda[ $(( (($selected-1)*3)+1 )) ]}"
	else 
		echo "Cancelled"
		exit
	fi
}

##
## Select Acoustic Model
##
[ -e decode.sh ] && curmodel=$(cat decode.sh | grep "^model=" | awk -F'=' '{print $2}' | cut -d'/' -f2-8)
models=$(ls -1 models/*/*/*/AM/*/*/*/*/*.mdl | cut -d'/' -f2-8 | uniq)
myRadioDialog "Model Selection" "Choose Acoustic Model:" "$models" "$curmodel"
model="models/${returnval}"

lang=$(echo $model | awk -F'/' '{print $2}')
cat $model/../../phones.txt | awk -F'[_ ]' '{print $1}' | sort | uniq >mphones

[ -e decode.sh ] && curversion=$(cat decode.sh | grep "^model=$model" | awk -F'=' '{print $2}' | rev | cut -d'/' -f1 | rev)
versions=$(ls -1 -d ${model}/*/ | rev | cut -d'/' -f2 | rev)
myRadioDialog "Model Selection" "Choose AM Version:" "$versions" "$curversion"
model=$(realpath --relative-to=models $model/$returnval)
model="models/$model"

##
## Select Lexicon
##
dialog --backtitle "Model Selection" --infobox "Finding compatible Lexicons.. " 5 30
lexicons=$(ls -1 models/$lang/*/*/Lexicon/*.lex)
>lexicons
for lexicon in $lexicons; do
	cat $lexicon | awk -F'\t' '{print $NF}' | sed 's/ /\n/g' | sort | uniq >phones
	phoneprobs=$(comm -13 mphones phones)
	if [ "$phoneprobs" == "" ]; then
		size=$(( $(cat $lexicon | wc -l) / 1000 ))
		echo "${lexicon}(${size}k)" >>lexicons
	fi
	rm -f phones mphones 
done

[ -e decode.sh ] && curlex=$(cat decode.sh | grep "^lexicon=" | awk -F'=' '{print $2}' | sed "s%\'%%")
lexicons=$(cat lexicons)
myRadioDialog "Model Selection" "Choose Lexicon:" "$lexicons" "$curlex"
lexiconlit=$returnval
lexicon=$(echo $returnval | sed -r "s%\([0-9]+k\)%%")
rm -f lexicons

##
## Select Language Model
##
[ -e decode.sh ] && curlmodel=$(cat decode.sh | grep "^lmodel=" | awk -F'=' '{print $2}' | cut -d'/' -f2-6)
lmodels=$(ls -1 models/$lang/*/*/LM/*/*/*.arpa.gz | cut -d'/' -f1-6 | cut -d'/' -f2-6 | uniq)
myRadioDialog "Model Selection" "Choose Language Model:" "$lmodels" "$curlmodel"
lmodel="models/${returnval}"

[ -e decode.sh ] && curlversion=$(cat decode.sh | grep "^lmodel=$lmodel" | awk -F'=' '{print $2}' | rev | cut -d'/' -f1-2 | rev)
lversions=$(ls -1 $lmodel/*/*.arpa.gz | rev | cut -d'/' -f1-2 | rev | uniq)
myRadioDialog "Model Selection" "Choose LM Version:" "$lversions" "$curlversion"
lmodel=$(realpath --relative-to=models $lmodel/$returnval)
lmodel="models/$lmodel"

##
## Select Rescore Language Model
##
[ -e decode.sh ] && curllmodel=$(cat decode.sh | grep "^llmodel=" | awk -F'=' '{print $2}' | cut -d'/' -f2-6)
llmodels=$(ls -1 models/$lang/*/*/LM/*/*/*.arpa.gz | cut -d'/' -f1-6 | cut -d'/' -f2-6 | uniq)
llmodels="None $llmodels"
myRadioDialog "Model Selection" "Choose Rescore (Large) Language Model:" "$llmodels" "$curllmodel"
llmodel="models/${returnval}"
if [ "$llmodel" == "models/None" ]; then
	llmodel=
else
	[ -e decode.sh ] && curllversion=$(cat decode.sh | grep "^llmodel=$llmodel" | awk -F'=' '{print $2}' | rev | cut -d'/' -f1-2 | rev)
	llversions=$(ls -1 $llmodel/*/*.arpa.gz | rev | cut -d'/' -f1-2 | rev | uniq)
	myRadioDialog "Model Selection" "Choose Rescore LM Version:" "$llversions" "$curllversion"
	llmodel=$(realpath --relative-to=models $llmodel/$returnval)
	llmodel="models/$llmodel"
fi
extractstr=
[ $extractor ] && extractstr="Extractor:\n${extractor}\n\n"
llmodelstr=
[ $llmodel ] && llmodelstr="Rescore LM:\n${llmodel}"

## Give warning if the graph has to be created, as this takes a long time
graphwarnstr=
lmodelpath=$(dirname $lmodel)
LGpath=$(echo $lexicon | cut -d'/' -f3,4,6 | sed "s%\.lex%%" | tr '/' '_')
LM=$(basename $lmodel | sed "s%\.arpa.gz%%")
LGpath="${LM}_${LGpath}"
graphloc=$(cat ${model}/*.info | sed -n '/\[Graph\]/{:a;n;/^\[/q;p;ba}' | head -1)
graphpath=$(echo $lmodelpath | cut -d'/' -f3,4,6,7 | tr '/' '_')
[ ! "$graphloc" ] && graphloc=$model
graphpath="${graphloc}/graph_${graphpath}_${LGpath}"

[ ! -d $lmodelpath/LG_${LGpath} ] || [ ! -d ${graphpath} ] && graphwarnstr="\nWARNING: for this configuration a decode graph needs to be created. For large language models, this may take a while.\n\n"

dialog --stdout --yesno "Confirm your choices:\n\nAcoustic Model:\n${model}\n\nLexicon:\n${lexiconlit}\n\n${extractstr}Language Model:\n${lmodel}\n\n${llmodelstr}\n${graphwarnstr}" 0 0
return_value=$?
if [ ! $return_value -eq 0 ]; then
	echo "Cancelled"
	exit
fi

##
## Generate graphs
##
if [ ! -d $lmodelpath/LG_${LGpath} ]; then 
	dialog --backtitle "Graph Generation" --infobox "Creating Decode Graph, This May Take A While \n\nCreating LG" 8 30
	local/Arpa2LG.sh $lmodel $lexicon $lmodelpath/LG_${LGpath} >>configure.log 2>&1
fi
if [ ! -d ${graphpath} ]; then
	dialog --backtitle "Graph Generation" --infobox "Creating Decode Graph, This May Take A While \n\nCreating HCLG" 8 30
	graph_options=$(cat ${model}/*.info | sed -n '/\[Graph_options\]/{:a;n;/^\[/q;p;ba}')
	utils/mkgraph.sh $graph_options $lmodelpath/LG_${LGpath} $graphloc $graphpath >>configure.log 2>&1 || exit 1;
fi

constLMpath=
if [ "$llmodel" ]; then
	LLM=$(basename $llmodel | sed "s%\.arpa.gz%%")
	constLMpath=$(echo $llmodel | cut -d'/' -f3,4,6,7 | tr '/' '_')
	constLMpath="$lmodelpath/LG_${LGpath}/Const_${constLMpath}_${LLM}"
	if [ ! -d ${constLMpath} ]; then
		dialog --backtitle "Const LM Generation" --infobox "Creating ConstLM for rescore, This May Take A While \n\nCreating ConstLM" 8 30
		utils/build_const_arpa_lm.sh $llmodel $lmodelpath/LG_${LGpath}/lang $constLMpath >>configure.log 2>&1 || exit 1;	
	fi
fi

##
## Generate decode.sh
##
dialog --backtitle "Decode.sh Generation" --infobox "Creating Decode.sh" 3 30
mv -f decode.sh decode.last.sh 2>/dev/null
cat local/decode_template | sed -n '/^#$/{:a;n;/^\*\*\*\* INSERT DECODE_OPTIONS \*\*\*\*/b;p;ba}' >decode.sh
echo "model=$model" >>decode.sh 
echo "lexicon='${lexiconlit}'" >>decode.sh 
echo "lmodel=$lmodel" >>decode.sh
echo "lpath=$lmodelpath/LG_${LGpath}" >>decode.sh 
echo "llmodel=$llmodel" >>decode.sh
echo "llpath=$constLMpath" >>decode.sh 
echo "extractor=$extractor" >>decode.sh 
echo >>decode.sh 

cat ${model}/*.info | sed -n '/\[Decode_options\]/{:a;n;/^\[/q;p;ba}' >>decode.sh
cat local/decode_template | sed -n '/^\*\*\*\* INSERT DECODE_OPTIONS \*\*\*\*/{:a;n;/^\*\*\*\* INSERT FEATURES \*\*\*\*/b;p;ba}' >>decode.sh
cat ${model}/*.info | \
	sed -n '/\[Features\]/{:a;n;/^\[/q;p;ba}' | \
	sed 's%\[data\]%$data/ALL%g' | \
	sed 's%\[log\]%$data/ALL/log%g' | \
	sed "s%\[graph\]%$graphpath%g" | \
	sed "s%\[models\]%$model%g" | \
	sed 's/--nj/--nj $this_nj/' | \
	sed 's/--mfcc-config/--mfcc-config $inter\/mfcc.conf/' | \
	sed 's/ mfcc/ $inter\/mfcc/'| \
	sed -r 's/^(\W*steps.*)$/\1 >>$logging 2>\&1/' >>decode.sh
cat local/decode_template | sed -n '/^\*\*\*\* INSERT FEATURES \*\*\*\*/{:a;n;/^\*\*\*\* INSERT DECODE \*\*\*\*/b;p;ba}' >>decode.sh

cat ${model}/*.info | \
	sed -n '/\[Decode\]/{:a;n;/^\[/q;p;ba}' | \
	sed 's%\[data\]%$data/ALL%g' | \
	sed 's%\[log\]%$data/ALL/log%g' | \
	sed "s%\[graph\]%$graphpath%g" | \
	sed "s%\[models\]%$model%g" | \
	sed 's%\[extractor\]%$extractor%g' | \
	sed 's/--nj/--nj $this_nj/' | \
	sed -r 's%\[out\]%${inter}/decode%' | \
	sed -r 's/^(\W*steps\/.*)$/\1 >>$logging 2>\&1/' | \
	sed -r 's/^(\W*eval \$timer steps\/.*)$/\1 >>$logging 2>\&1 \&/' >>decode.sh

cat local/decode_template | sed -n '/^\*\*\*\* INSERT DECODE \*\*\*\*/{:a;n;/^\*\*\*\* INSERT RESCORE \*\*\*\*/b;p;ba}' >>decode.sh

# sed -r "s%^(eval .*)$%\1 >>\$logging 2>\&1 &\\n${progress}%" | \
	
# cat ${model}/*.info | sed -n '/\[Decode\]/{:a;n;/^\[/b;p;ba}'
chmod +x decode.sh

## 
## Fix ivector_extractor.conf, this only needs to be done once
##

if [ -e ${model}/conf/ivector_extractor.conf ] && [ ! -e ${model}/conf/.fixed ]; then
	modeldir=$(realpath $model)
	mv ${model}/conf/ivector_extractor.conf ${model}/conf/ivector_extractor.conf.orig
	cat ${model}/conf/ivector_extractor.conf.orig | \
		sed "s%--splice-config.*%--splice-config=${modeldir}/conf/splice.conf%" | \
		sed "s%--cmvn-config.*%--cmvn-config=${modeldir}/conf/online_cmvn.conf%" | \
		sed "s%--lda-matrix.*%--lda-matrix=${modeldir}/ivector_extractor/final.mat%" | \
		sed "s%--global-cmvn-stats.*%--global-cmvn-stats=${modeldir}/ivector_extractor/global_cmvn.stats%" | \
		sed "s%--diag-ubm.*%--diag-ubm=${modeldir}/ivector_extractor/final.dubm%" | \
		sed "s%--ivector-extractor.*%--ivector-extractor=${modeldir}/ivector_extractor/final.ie%" >${model}/conf/ivector_extractor.conf
	if [ -e ${model}/conf/online_nnet2_decoding.conf ]; then 
		mv ${model}/conf/online_nnet2_decoding.conf ${model}/conf/online_nnet2_decoding.conf.orig
		cp ${model}/conf/online_nnet2_decoding.conf.orig ${model}/conf/online.conf.orig
	fi
	[ -e ${model}/conf/online.conf ] && mv ${model}/conf/online.conf ${model}/conf/online.conf.orig
	
	cat ${model}/conf/online.conf.orig | \
		sed "s%--mfcc-config.*%--mfcc-config=${modeldir}/conf/mfcc.conf%" | \
		sed "s%--ivector-extraction-config.*%--ivector-extraction-config=${modeldir}/conf/ivector_extractor.conf%" >${model}/conf/online.conf
	
	[ -e ${model}/conf/online_nnet2_decoding.conf.orig ] && mv ${model}/conf/online.conf ${model}/conf/online_nnet2_decoding.conf
				
	touch ${model}/conf/.fixed
fi

dialog --backtitle "Done" --infobox "Done" 3 30