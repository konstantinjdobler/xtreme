#!/bin/bash
# Copyright 2020 Google and DeepMind.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Script to train a model on SQuAD v1.1 or the English TyDiQA-GoldP train data.

REPO=$PWD
MODEL=${1:-bert-base-multilingual-cased}
SRC=${2:-squad}
TGT=${3:-xquad}
GPU=${4:-0}
DATA_DIR=${5:-"$REPO/download/"}
OUT_DIR=${6:-"$REPO/outputs/"}
TRAIN_LG=${7:-"en"}
TEST_LG=${8:-"en"}


BATCH_SIZE=4
GRAD_ACC=8

MAXL=384
LR=3e-5
NUM_EPOCHS=3.0
if [ $MODEL == "bert-base-multilingual-cased" ]; then
  MODEL_TYPE="bert"
elif [ $MODEL == "xlm-mlm-100-1280" ] || [ $MODEL == "xlm-mlm-tlm-xnli15-1024" ]; then
  MODEL_TYPE="xlm"
elif [ $MODEL == "xlm-roberta-large" ] || [ $MODEL == "xlm-roberta-base" ]; then
  MODEL_TYPE="xlm-roberta"
fi

MODEL_TYPE="xlm-roberta"

# Model path where trained model should be stored
MODEL_PATH=$OUT_DIR/$SRC/${MODEL}_LR${LR}_EPOCH${NUM_EPOCHS}_maxlen${MAXL}_batchsize${BATCH_SIZE}_gradacc${GRAD_ACC}
mkdir -p $MODEL_PATH
# Train either on the SQuAD or TyDiQa-GoldP English train file
if [ $SRC == 'squad' ]; then
  TASK_DATA_DIR=${DATA_DIR}/squad
  TRAIN_FILE=${TASK_DATA_DIR}/train-v1.1.json
  PREDICT_FILE=${TASK_DATA_DIR}/dev-v1.1.json
  if [TRAIN_LG != "en"]; then
      TRAIN_FILE=${TASK_DATA_DIR}/squad.translate.train.en-${TRAIN_LG}.json
  fi
  if [TEST_LG != "en"]; then
      TRAIN_FILE=${TASK_DATA_DIR}/squad.translate.dev.en-${TEST_LG}.json
  fi

else
  TASK_DATA_DIR=${DATA_DIR}/tydiqa
  TRAIN_FILE=${TASK_DATA_DIR}/tydiqa-goldp-v1.1-train/tydiqa.${TRAIN_LG}.train.json
  PREDICT_FILE=${TASK_DATA_DIR}/tydiqa-goldp-v1.1-dev/tydiqa.goldp.${TEST_LG}.dev.json
fi

# train
CUDA_VISIBLE_DEVICES=$GPU python third_party/run_squad.py \
  --model_type ${MODEL_TYPE} \
  --model_name_or_path ${MODEL} \
  --do_train \
  --do_eval \
  --data_dir ${TASK_DATA_DIR} \
  --train_file ${TRAIN_FILE} \
  --predict_file ${PREDICT_FILE} \
  --per_gpu_train_batch_size ${BATCH_SIZE} \
  --learning_rate ${LR} \
  --num_train_epochs ${NUM_EPOCHS} \
  --max_seq_length $MAXL \
  --doc_stride 128 \
  --save_steps -1 \
  --overwrite_output_dir \
  --gradient_accumulation_steps ${GRAD_ACC} \
  --warmup_steps 500 \
  --output_dir ${MODEL_PATH} \
  --weight_decay 0.0001 \
  --threads 8 \
  --train_lang $TRAIN_LG \
  --eval_lang $TEST_LG

# predict
bash scripts/predict_qa.sh $MODEL $MODEL_PATH $TGT $GPU $DATA_DIR
