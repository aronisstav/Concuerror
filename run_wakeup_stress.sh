#!/usr/bin/env bash

T=wakeup_stress

cat <<EOF
\begin{tabular}{lrrrrr}
\toprule
        & & \multicolumn{2}{c}{source} & \multicolumn{2}{c}{optimal} \\\\
             \cmidrule(r){3-4}\cmidrule(r){5-6}
\texttt{n} & Traces explored & max & memory & max & memory \\\\
\midrule
EOF
for i in $(seq 1 9); do

    echo -n "$i &"

    Prefix="./concuerror_mem --noprogress -f testsuite/suites/dpor/src/$T.erl -t $T test $i -p inf"
    Suffix=""

    Source=$($Prefix --dpor_source | grep "OUT" | sed 's/OUT//' | cut -d'&' -f1,5,8)

    echo -n "$Source" | sed 's.\\\\.\&.'

    Optimal=$($Prefix --dpor_optimal | grep "OUT" | sed 's/OUT//' | cut -d'&' -f5,8)

    echo "$Optimal"

done
cat <<EOF
\bottomrule
\end{tabular}
EOF
