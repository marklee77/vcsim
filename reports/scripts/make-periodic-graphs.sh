#!/bin/sh

DATAFILE=$1

#mysql hpcdata2 > ${DATAFILE} <<EOF
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
#     and solutions.dataset = 'lubscaled-128'
#     and delay = 300 
#     and algo like 'greedy-pmtn%_activeres_opttarget:maxminyield_per:%_minvt:%'
#group by algo 
#order by substr(algo, 1, instr(algo, 'per:')), minvt, period;
#EOF

#exit

(
echo "set xrange [300:12000]"
echo "set xlabel \"Period (seconds)\""
echo "set term postscript eps color"
#echo "set term.eps"

echo "set title \"Average Maxstretch vs. Period\""
echo "set ylabel \"Average Maxstretch\""
echo "set output \"maxstretch-vs-period.eps\""
echo -n "plot "
echo -n "\"${DATAFILE}\" using 2:4 index 0 with linespoints title \"migr minvt:300\" lt 1,"
echo -n "\"${DATAFILE}\" using 2:4 index 1 with linespoints title \"migr minvt:600\" lt 2,"
echo -n "\"${DATAFILE}\" using 2:4 index 2 with linespoints title \"nomigr minvt:300\" lt 3,"
echo    "\"${DATAFILE}\" using 2:4 index 3 with linespoints title \"nomigr minvt:600\" lt 4"

echo "set title \"Average Migration Underutilization vs. Period\""
echo "set ylabel \"Average Migration Underutilization\""
echo "set output \"migunderutil-vs-period.eps\""
echo -n "plot "
echo -n "\"${DATAFILE}\" using 2:5 index 0 with linespoints title \"migr minvt:300\" lt 1,"
echo -n "\"${DATAFILE}\" using 2:5 index 1 with linespoints title \"migr minvt:600\" lt 2,"
echo -n "\"${DATAFILE}\" using 2:5 index 2 with linespoints title \"nomigr minvt:300\" lt 3,"
echo    "\"${DATAFILE}\" using 2:5 index 3 with linespoints title \"nomigr minvt:600\" lt 4"

echo "set title \"Average Underutilization vs. Period\""
echo "set ylabel \"Average Underutilization\""
echo "set output \"underutil-vs-period.eps\""
echo -n "plot 0.38360198 with lines title \"EASY\" lt 0,"
echo -n "\"${DATAFILE}\" using 2:6 index 0 with linespoints title \"migr minvt:300\" lt 1,"
echo -n "\"${DATAFILE}\" using 2:6 index 1 with linespoints title \"migr minvt:600\" lt 2,"
echo -n "\"${DATAFILE}\" using 2:6 index 2 with linespoints title \"nomigr minvt:300\" lt 3,"
echo    "\"${DATAFILE}\" using 2:6 index 3 with linespoints title \"nomigr minvt:600\" lt 4"
echo

echo "set title \"Average Migration+Preemption Bandwidth vs. Period\""
echo "set ylabel \"Average Bandwidth (GB/s)\""
echo "set output \"bandwidth-vs-period.eps\""
echo -n "plot "
echo -n "\"${DATAFILE}\" using 2:7 index 0 with linespoints title \"migr minvt:300\" lt 1,"
echo -n "\"${DATAFILE}\" using 2:7 index 1 with linespoints title \"migr minvt:600\" lt 2,"
echo -n "\"${DATAFILE}\" using 2:7 index 2 with linespoints title \"nomigr minvt:300\" lt 3,"
echo    "\"${DATAFILE}\" using 2:7 index 3 with linespoints title \"nomigr minvt:600\" lt 4"
echo
) | gnuplot
