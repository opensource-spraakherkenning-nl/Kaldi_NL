#!/bin/bash

[ $(which dialog) ] || exit

local/configure_basic.sh && \
local/configure_download.sh && \
local/configure_decode.sh
