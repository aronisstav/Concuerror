#!/usr/bin/env bash

T=linexp

cat <<EOF
\begin{tabular}{lrrrrrr}
\toprule
           & \multicolumn{3}{c}{Traces Explored} & \multicolumn{2}{c}{Time} \\\\
             \cmidrule(r){2-4}\cmidrule(r){5-6}
\texttt{n} & source & optimal & sleep set blocked & source & optimal \\\\
\midrule
EOF
for i in $(seq 1 9); do

    echo -n "$i & "

    Prefix="./concuerror_mem --noprogress -f testsuite/suites/dpor/src/$T.erl -t $T test $i -p inf"
    Suffix=""

    Source=$($Prefix --dpor_source | grep "OUT" | sed 's/OUT//' | cut -d'&' -f 1,3,7)

    echo -n $Source | cut -d'&' -f1 | tr '\n' ' '
    echo -n "& "

    Optimal=$($Prefix --dpor_optimal | grep "OUT" | sed 's/OUT//' | cut -d'&' -f 1,7)

    echo -n $Optimal | cut -d'&' -f1 | tr '\n' ' '
    echo -n "&"
    echo -n $Source | cut -d'&' -f2 | tr '\n' ' '
    echo -n "&"
    echo -n $Source | cut -d'&' -f3 | tr '\n' ' '
    echo -n "&"
    echo -n $Optimal | cut -d'&' -f2 | tr '\n' ' '
    echo "\\\\"
done
cat <<EOF
\bottomrule
\end{tabular}
EOF
