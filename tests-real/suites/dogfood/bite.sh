#!/usr/bin/env bash

set -e

ulimit -Sv 10000000

mkdir -p ebin

make -C ../../.. -j

erlc -o ebin src/*.erl

concuerror -m conc_input || [ "$?" -lt "2" ]

./run_concuerror.escript
