#!/bin/bash

[ $(which dialog) ] || { echo 'Please install "dialog" to use this configurator.' >&2; exit; };

local/configure_basic.sh && \
local/configure_download.sh && \
local/configure_decode.sh
