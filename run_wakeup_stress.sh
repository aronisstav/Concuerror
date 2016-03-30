#!/usr/bin/env bash

T=wakeup_stress

cat <<EOF
\begin{tabular}{lrrrrrrr}
\toprule
        & & \multicolumn{3}{c}{source} & \multicolumn{3}{c}{optimal} \\\\
             \cmidrule(r){3-5}\cmidrule(r){6-8}
\texttt{n} & Traces explored & max & time & memory & max & time & memory \\\\
\midrule
EOF
for i in $(seq 1 9); do

    echo -n "$i &"

    Prefix="./concuerror_mem --noprogress -f testsuite/suites/dpor/src/$T.erl -t $T test $i -p inf"
    Suffix=""

    Source=$($Prefix --dpor_source | grep "OUT" | sed 's/OUT//' | cut -d'&' -f1,5,7,8)

    echo -n "$Source" | sed 's.\\\\.\&.'

    Optimal=$($Prefix --dpor_optimal | grep "OUT" | sed 's/OUT//' | cut -d'&' -f5,7,8)

    echo "$Optimal"

done
cat <<EOF
\bottomrule
\end{tabular}
EOF
