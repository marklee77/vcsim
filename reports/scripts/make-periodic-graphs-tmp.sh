#!/bin/sh

# add in bandwidth...
#mysql hpcdata2 > periodic-info.txt <<EOF
#  select algo, 
#         cast(substr(algo, instr(algo, 'per:') + 4, 5) as unsigned) as period,
#         cast(substr(algo, instr(algo, 'minvt:') + 6, 3) as unsigned) as minvt,
#         avg(maxstretch) as avgmaxstretch,
#         avg((util_integral - cpusecs) / cpusecs) as migcost,
#         avg((demand_integral - cpusecs) / cpusecs) as avgunderutil,
#         8 * avg((mrest + mtrans) / makespan) / 100 as avgbandwidth
#    from problems, solutions 
#   where problems.dataset = solutions.dataset 
#     and problems.trace = solutions.trace 
#     and delay = 300 
#     and algo like 'smart_greedy-pmtn%_activeres_opttarget:maxminyield_per:%_minvt:%'
#group by algo 
#order by substr(algo, 1, instr(algo, 'per:')), minvt, period;
#EOF

#exit

DATAFILE=$1

(
echo "set xrange [300:30000]"
echo "set xlabel \"Period (seconds)\""
echo "set term png"

echo "set title \"Average Maxstretch vs. Period\""
echo "set ylabel \"Average Maxstretch\""
echo "set output \"maxstretch-vs-period.png\""
echo "plot \"${DATAFILE}\" using 2:4 with linespoints title \"nomigr minvt:600\""
echo

echo "set title \"Average Migration Underutilization vs. Period\""
echo "set ylabel \"Average Migration Underutilization\""
echo "set output \"migunderutil-vs-period.png\""
echo "plot \"${DATAFILE}\" using 2:5 with linespoints title \"nomigr minvt:600\""
echo

echo "set title \"Average Underutilization vs. Period\""
echo "set ylabel \"Average Underutilization\""
echo "set output \"underutil-vs-period.png\""
echo "plot \"${DATAFILE}\" using 2:6 with linespoints title \"nomigr minvt:600\""
echo

echo "set title \"Average Migration+Preemption Bandwidth vs. Period\""
echo "set ylabel \"Average Bandwidth (GB/s)\""
echo "set output \"bandwidth-vs-period.png\""
echo "plot \"${DATAFILE}\" using 2:7 with linespoints title \"nomigr minvt:600\""
echo
) | gnuplot
