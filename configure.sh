#!/bin/bash

[ -f ./path.sh ] && . ./path.sh; # source the path.

# put the place where you would like to download (and unpack the modelpack)
modelpack=/home/laurensw/TestModelpack

# the graph should match the lm_small language model, if this graph does not exist it will be created
lm_small=$modelpack/LM/3gpr
lm_large=$modelpack/LM/4gpr_const
graph_name=graph_ModelPack

# under model_root, a BN subdir is expected, each with subdirs equal to the am_* variables below
model_root=$modelpack/AM
am_fp=tri3
am_fmmi=tri3_fmmi_b0.1
am_sgmm2=sgmm2_3b
am_sgmm2_mmi=sgmm2_3b_mmi_b0.1
am_fmllr_bn=dnn8c_fmllr-gmm
am_nnet_bn=dnn8f_pretrain-dbn_dnn_smbr
bn_feat=dnn8a_bn-feat

if [ ! -d $KALDI_ROOT ]; then
	echo "KALDI_ROOT not properly set in path.sh";
	exit;
fi

# create symlinks to the scripts
if [ ! -h steps ]; then
    ln -s $KALDI_ROOT/egs/wsj/s5/steps steps
fi

if [ ! -h utils ]; then
    ln -s $KALDI_ROOT/egs/wsj/s5/utils utils
fi

# download the models if needed
if [ ! -d $modelpack ]; then
	mkdir -p $modelpack
	wget -P $modelpack http://beehub.nl/open-source-spraakherkenning-NL/ModelPack.tar.gz
	tar -xvzf $modelpack/ModelPack.tar.gz -C $modelpack
fi

# create symlinks to the acoustic models
for model_sub in BN; do
	mkdir -p models/$model_sub  	
	for model in ${am_fp} ${am_fp_ali} ${am_fmmi} ${am_sgmm2} ${am_sgmm2_mmi} ${am_nnet} ${am_nnet2} ${extractor} ${am_fmllr_bn} ${am_nnet_bn} ${bn_feat}; do				
		if [ ! -d $model_root/$model_sub/$model ]; then		
			continue		
		fi 
		
		case "$model" in 
			"${am_fp}") tgtmodel=fmllr;;
			"${am_fp_ali}") tgtmodel=fmllr_ali;;
			"${am_fmmi}") tgtmodel=fmmi;;
			"${am_sgmm2}") tgtmodel=sgmm2;;
			"${am_sgmm2_mmi}") tgtmodel=sgmm2_mmi;;
			"${am_nnet}") tgtmodel=nnet;;			
			"${am_nnet2}") tgtmodel=nnet_ms_a;;
			"${am_nnet_bn}") tgtmodel=nnet_bn;; 
			"${am_fmllr_bn}") tgtmodel=fmllr_bn;;
			"${extractor}") tgtmodel=extractor;;
			"${bn_feat}") tgtmodel=bn-feat;;
		esac              
      
		if [ -h models/$model_sub/$tgtmodel ]; then
			rm models/$model_sub/$tgtmodel
		fi
		ln -s $model_root/$model_sub/$model models/$model_sub/$tgtmodel

		# don't make a graph for these models
		for skipgraph in ${am_nnet_bn} ${am_fp_ali} ${am_sgmm2_mmi} ${am_nnet} ${am_nnet2} ${extractor} ${bn_feat}; do
			if [ "$model" = "$skipgraph" ]; then continue 2; fi
		done

		if [ ! -e $model_root/$model_sub/$model/$graph_name/HCLG.fst ]; then
			echo "Creating graph directory. This may take awhile."
			utils/mkgraph.sh $lm_small models/$model_sub/$tgtmodel $model_root/$model_sub/$model/$graph_name || exit 1;
		fi
      
		# the decode script expects the graph-directory to be named graph_lm_small
		if [ -h $model_root/$model_sub/$model/graph_lm_small ]; then
			rm $model_root/$model_sub/$model/graph_lm_small
		fi
		ln -s $model_root/$model_sub/$model/$graph_name $model_root/$model_sub/$model/graph_lm_small		
	done
done

# create symlinks to the language models
mkdir -p models/LM
if [ -h models/LM/3gpr ]; then
    rm models/LM/3gpr
fi
ln -s $lm_small models/LM/3gpr
if [ -h models/LM/4gpr_const ]; then
    rm models/LM/4gpr_const
fi
ln -s $lm_large models/LM/4gpr_const
