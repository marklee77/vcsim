#!/bin/sh

TYPE="$1"
DATASET="$2"
UBOUND="$3"
POSTFIX="$4"
LOAD="$5"

if [ -z "${TYPE}" ]; then
    TYPE="png"
fi

LOADCOND="1 = 1"
SUFFIX=""
if [ ! -z "${LOAD}" ]; then
    LOADCOND="sload = ${LOAD}"
    SUFFIX="-load-${LOAD}"
fi

if [ -z "${DATASET}" ]; then
    DATASET="lubscaled-128"
fi

SALGOS="greedy-pmtn-migr greedy-pmtn"
MINVTS="300 600"
TMPFILE=$(mktemp)

for SALGO in ${SALGOS}; do
    for MINVT in ${MINVTS}; do
        mysql --skip-column-names hpcdata2 >> ${TMPFILE} <<EOF
select algo, 
       cast(substr(algo, instr(algo, 'per:') + 4, 5) as unsigned) as period,
       cast(substr(algo, instr(algo, 'minvt:') + 6, 3) as unsigned) as minvt,
       avg(maxstretch) as avgmaxstretch,
       avg((util_integral - cpusecs) / cpusecs) as migcost,
       avg((demand_integral - cpusecs) / cpusecs) as avgunderutil,
       8 * avg((mrest + mtrans) / makespan) / 100 as avgbandwidth,
       avg(maxstretch / msbound) as avgmaxsdfbound
  from problems, solutions 
 where problems.dataset = solutions.dataset 
   and problems.trace = solutions.trace 
   and solutions.dataset = '${DATASET}'
   and delay = 300 
   and algo like '${SALGO}_activeres_opttarget:maxminyield_per:%_minvt:${MINVT}'
   and ${LOADCOND}
group by algo 
order by minvt, period;
EOF
        echo >> ${TMPFILE}
        echo >> ${TMPFILE}
    done
done

mysql --skip-column-names hpcdata2 >> ${TMPFILE} <<EOF
select algo, algo, algo,
       avg(maxstretch) as avgmaxstretch,
       avg((util_integral - cpusecs) / cpusecs) as migcost,
       avg((demand_integral - cpusecs) / cpusecs) as avgunderutil,
       8 * avg((mrest + mtrans) / makespan) / 100 as avgbandwidth,
       avg(maxstretch / msbound) as avgmaxsdfbound
  from problems, solutions 
 where problems.dataset = solutions.dataset 
   and problems.trace = solutions.trace 
   and solutions.dataset = '${DATASET}'
   and delay = 300 
   and algo = 'easy'
   and ${LOADCOND}
EOF

(
echo "set xrange [600:${UBOUND}]"
echo "set xlabel \"Period (seconds)\""
echo "set rmargin 4"
if [ "${TYPE}" = "png" ]; then
    echo "set term png"
else
    echo "set term postscript eps color"
fi
 
EASYVAL=$(tail -1 ${TMPFILE} | perl -ane 'print "$F[3]\n";')
echo "set title \"Average Maxstretch vs. Period\""
echo "set ylabel \"Average Maxstretch\""
echo "set output \"maxstretch-vs-period${SUFFIX}${POSTFIX}.${TYPE}\""
echo -n "plot "
#echo -n "plot ${EASYVAL} with lines title \"EASY\" lt 0,"
echo -n "\"${TMPFILE}\" using 2:4 index 2 with linespoints title \"GreedyP*/per/opt=min/mvt=300\" lt 3,"
echo -n "\"${TMPFILE}\" using 2:4 index 3 with linespoints title \"GreedyP*/per/opt=min/mvt=600\" lt 4,"
echo -n "\"${TMPFILE}\" using 2:4 index 0 with linespoints title \"GreedyPM*/per/opt=min/mvt=300\" lt 1,"
echo -n "\"${TMPFILE}\" using 2:4 index 1 with linespoints title \"GreedyPM*/per/opt=min/mvt=600\" lt 2"
echo

EASYVAL=$(tail -1 ${TMPFILE} | perl -ane 'print "$F[7]\n";')
echo "set title \"Average Maxstretch Degradation from Bound vs. Period\""
echo "set ylabel \"Average Maxstretch Degradation\""
echo "set output \"maxsdfbound-vs-period${SUFFIX}${POSTFIX}.${TYPE}\""
echo -n "plot "
#echo -n "plot ${EASYVAL} with lines title \"EASY\" lt 0,"
echo -n "\"${TMPFILE}\" using 2:8 index 2 with linespoints title \"GreedyP*/per/opt=min/mvt=300\" lt 3,"
echo -n "\"${TMPFILE}\" using 2:8 index 3 with linespoints title \"GreedyP*/per/opt=min/mvt=600\" lt 4,"
echo -n "\"${TMPFILE}\" using 2:8 index 0 with linespoints title \"GreedyPM*/per/opt=min/mvt=300\" lt 1,"
echo -n "\"${TMPFILE}\" using 2:8 index 1 with linespoints title \"GreedyPM*/per/opt=min/mvt=600\" lt 2"
echo

echo "set title \"Average Migration Underutilization vs. Period\""
echo "set ylabel \"Average Migration Underutilization\""
echo "set output \"migunderutil-vs-period${SUFFIX}${POSTFIX}.${TYPE}\""
echo -n "plot "
echo -n "\"${TMPFILE}\" using 2:5 index 2 with linespoints title \"GreedyP*/per/opt=min/mvt=300\" lt 3,"
echo -n "\"${TMPFILE}\" using 2:5 index 3 with linespoints title \"GreedyP*/per/opt=min/mvt=600\" lt 4,"
echo -n "\"${TMPFILE}\" using 2:5 index 0 with linespoints title \"GreedyPM*/per/opt=min/mvt=300\" lt 1,"
echo -n "\"${TMPFILE}\" using 2:5 index 1 with linespoints title \"GreedyPM*/per/opt=min/mvt=600\" lt 2"
echo

EASYVAL=$(tail -1 ${TMPFILE} | perl -ane 'print "$F[5]\n";')
echo "set title \"Average Underutilization vs. Period\""
echo "set ylabel \"Average Underutilization\""
echo "set output \"underutil-vs-period${SUFFIX}${POSTFIX}.${TYPE}\""
echo -n "plot ${EASYVAL} with lines title \"EASY\" lt 0,"
echo -n "\"${TMPFILE}\" using 2:6 index 2 with linespoints title \"GreedyP*/per/opt=min/mvt=300\" lt 3,"
echo -n "\"${TMPFILE}\" using 2:6 index 3 with linespoints title \"GreedyP*/per/opt=min/mvt=600\" lt 4,"
echo -n "\"${TMPFILE}\" using 2:6 index 0 with linespoints title \"GreedyPM*/per/opt=min/mvt=300\" lt 1,"
echo -n "\"${TMPFILE}\" using 2:6 index 1 with linespoints title \"GreedyPM*/per/opt=min/mvt=600\" lt 2"
echo

echo "set title \"Average Migration+Preemption Bandwidth vs. Period\""
echo "set ylabel \"Average Bandwidth (GB/s)\""
echo "set output \"bandwidth-vs-period${SUFFIX}${POSTFIX}.${TYPE}\""
echo -n "plot "
echo -n "\"${TMPFILE}\" using 2:7 index 2 with linespoints title \"GreedyP*/per/opt=min/mvt=300\" lt 3,"
echo -n "\"${TMPFILE}\" using 2:7 index 3 with linespoints title \"GreedyP*/per/opt=min/mvt=600\" lt 4,"
echo -n "\"${TMPFILE}\" using 2:7 index 0 with linespoints title \"GreedyPM*/per/opt=min/mvt=300\" lt 1,"
echo -n "\"${TMPFILE}\" using 2:7 index 1 with linespoints title \"GreedyPM*/per/opt=min/mvt=600\" lt 2"
echo

) | gnuplot

rm ${TMPFILE}
