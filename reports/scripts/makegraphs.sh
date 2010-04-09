#!/bin/bash
LINETYPES=(1 2 3 4 5 7 8 10 11 12)
MYSQL="mysql hpcdata --batch --skip-column-names"
TMPDIR="$PWD/temp"
OUTDIR="${PWD}"
cd ${TMPDIR}

(
echo "set xrange [0.1:0.9]"
echo "set logscale y"
echo "set key on outside right top box width +1"
echo "set xlabel \"Load\""
#echo "set term png"
#EXT="png"
echo "set term postscript eps color"
EXT="eps"

DATASETS=$(${MYSQL} -e "select distinct dataset from flat where dataset like '%scaled%' order by dataset;")
for DATASET in ${DATASETS}; do
    DELAYS=$(${MYSQL} -e "select distinct delay from flat where dataset = '${DATASET}' order by delay;")
    for DELAY in ${DELAYS}; do

        STRETCHDIR="${TMPDIR}/${DATASET}/${DELAY}/stretch"
        mkdir -p ${STRETCHDIR}

        DEGDIR="${TMPDIR}/${DATASET}/${DELAY}/degredation"
        mkdir -p ${DEGDIR}

        ALGOS=$(${MYSQL} -e "select distinct algo from flat where dataset = '${DATASET}' and delay = ${DELAY} and algo <> 'fredo' order by algo;")
        for ALGO in ${ALGOS}; do 
            PERIODS=$(${MYSQL} -e "select distinct period from flat where dataset = '${DATASET}' and delay = ${DELAY} and algo = '${ALGO}' and period <> 60 and period <> 3600 order by period;")
            for PERIOD in ${PERIODS}; do
${MYSQL} > ${STRETCHDIR}/${ALGO}_${PERIOD}.dat <<EOF
    select sload / 10, avg(avgstretch), avg(maxstretch)
    from flat
    where dataset = '${DATASET}' and delay = ${DELAY} and algo = '${ALGO}' and period = ${PERIOD}
    group by sload;
EOF
${MYSQL} > ${DEGDIR}/${ALGO}_${PERIOD}.dat <<EOF
    select sload / 10, avg(avgstretch / minavgstretch), avg(maxstretch / minmaxstretch)
    from problems, solutions, (
        select problems.id as id, min(avgstretch) as minavgstretch, min(maxstretch) as minmaxstretch
        from problems, solutions
        where problems.id = solutions.problem and
        dataset = '${DATASET}' and delay = ${DELAY} and algo <> 'fredo' and
        period <> 60 and period <> 3600
        group by problems.id) as best
    where problems.id = best.id and problems.id = solutions.problem and
    dataset = '${DATASET}' and delay = ${DELAY} and algo = '${ALGO}' and period = ${PERIOD}
    group by sload;
EOF
            done
        done

        cd ${STRETCHDIR}
        echo "set ylabel \"Stretch\""
        echo "set yrange [1:100000]"

        echo "set title \"Average Stretch vs. System Load, ${DELAY} second restart penalty.\""
        echo "set output \"avgs-vs-load-${DELAY}-delay.${EXT}\""
        FILES=($(ls ${PWD}/*.dat))
        #FILES=("${PWD}/fcfs_0.dat" "${PWD}/easy_0.dat" "${PWD}/greedy_0.dat" "${PWD}/greedyp_0.dat" "${PWD}/greedypm_0.dat" "${PWD}/mcb_0.dat" "${PWD}/mcbp_600.dat" "${PWD}/gmcbp_600.dat" "${PWD}/mcbsp_600.dat")
        echo -n "plot "
        LASTFILE=${FILES[${#FILES[@]}-1]}
        LINETYPEIDX="0"
        for FILE in "${FILES[@]}"; do
            SCHEDNAME=$(basename ${FILE} .dat | tr "a-z_" "A-Z ")
            LINETYPE=${LINETYPES[${LINETYPEIDX}]}
            LINETYPEIDX=$((${LINETYPEIDX}+1))
            echo -n "\"${FILE}\" using 1:2 with linespoints title \"${SCHEDNAME/ 0/}\" lt ${LINETYPE} lw 2"
            if [ ${FILE} != ${LASTFILE} ]; then
              echo ",\\"
            fi  
        done
        echo

        echo "set title \"Maximum Stretch vs. System Load, ${DELAY} second restart penalty.\""
        echo "set output \"maxs-vs-load-${DELAY}-delay.${EXT}\""
        echo -n "plot "
        FILES=($(ls ${PWD}/*.dat))
        #FILES=("${PWD}/fcfs_0.dat" "${PWD}/easy_0.dat" "${PWD}/greedy_0.dat" "${PWD}/greedyp_0.dat" "${PWD}/greedypm_0.dat" "${PWD}/mcb_0.dat" "${PWD}/mcbp_600.dat" "${PWD}/gmcbp_600.dat" "${PWD}/mcbsp_600.dat")
        LASTFILE=${FILES[${#FILES[@]}-1]}
        LINETYPEIDX="0"
        for FILE in "${FILES[@]}"; do
            SCHEDNAME=$(basename ${FILE} .dat | tr "a-z_" "A-Z ")
            LINETYPE=${LINETYPES[${LINETYPEIDX}]}
            LINETYPEIDX=$((${LINETYPEIDX}+1))
            echo -n "\"${FILE}\" using 1:3 with linespoints title \"${SCHEDNAME/ 0/}\" lt ${LINETYPE} lw 2"
            if [ ${FILE} != ${LASTFILE} ]; then
              echo ",\\"
            fi  
        done
        echo

        cd ${DEGDIR}
        echo "set ylabel \"Stretch Degredation Factor\""
        echo "set yrange [1:10000]"

        echo "set title \"Average Stretch Degredation Factor vs. System Load, ${DELAY} second restart penalty.\""
        echo "set output \"avgsdeg-vs-load-${DELAY}-delay.${EXT}\""
        echo -n "plot "
        FILES=($(ls ${PWD}/*.dat))
        #FILES=("${PWD}/fcfs_0.dat" "${PWD}/easy_0.dat" "${PWD}/greedy_0.dat" "${PWD}/greedyp_0.dat" "${PWD}/greedypm_0.dat" "${PWD}/mcb_0.dat" "${PWD}/mcbp_600.dat" "${PWD}/gmcbp_600.dat" "${PWD}/mcbsp_600.dat")
        LASTFILE=${FILES[${#FILES[@]}-1]}
        LINETYPEIDX="0"
        for FILE in "${FILES[@]}"; do
            SCHEDNAME=$(basename ${FILE} .dat | tr "a-z_" "A-Z ")
            LINETYPE=${LINETYPES[${LINETYPEIDX}]}
            LINETYPEIDX=$((${LINETYPEIDX}+1))
            echo -n "\"${FILE}\" using 1:2 with linespoints title \"${SCHEDNAME/ 0/}\" lt ${LINETYPE} lw 2"
            if [ ${FILE} != ${LASTFILE} ]; then
              echo ",\\"
            fi  
        done
        echo

        echo "set title \"Maximum Stretch Degredation Factor vs. System Load, ${DELAY} second restart penalty.\""
        echo "set output \"maxsdeg-vs-load-${DELAY}-delay.${EXT}\""
        echo -n "plot "
        FILES=($(ls ${PWD}/*.dat))
        #FILES=("${PWD}/fcfs_0.dat" "${PWD}/easy_0.dat" "${PWD}/greedy_0.dat" "${PWD}/greedyp_0.dat" "${PWD}/greedypm_0.dat" "${PWD}/mcb_0.dat" "${PWD}/mcbp_600.dat" "${PWD}/gmcbp_600.dat" "${PWD}/mcbsp_600.dat")
        LASTFILE=${FILES[${#FILES[@]}-1]}
        LINETYPEIDX="0"
        for FILE in "${FILES[@]}"; do
            SCHEDNAME=$(basename ${FILE} .dat | tr "a-z_" "A-Z ")
            LINETYPE=${LINETYPES[${LINETYPEIDX}]}
            LINETYPEIDX=$((${LINETYPEIDX}+1))
            echo -n "\"${FILE}\" using 1:3 with linespoints title \"${SCHEDNAME/ 0/}\" lt ${LINETYPE} lw 2"
            if [ ${FILE} != ${LASTFILE} ]; then
              echo ",\\"
            fi  
        done
        echo
    done
done

) > graphs.plt

cd ${OUTDIR}

#rm -r ${TMPDIR}

#for EPSFILE in *.eps; do
#    FILE=$(basename ${EPSFILE} .eps)
#    echo "processing ${FILE}"
#    epstopdf ${EPSFILE}
#    rm ${EPSFILE}
#    pdfembed ${FILE}.pdf ${FILE}.tmp.pdf
#    mv ${FILE}.tmp.pdf ${FILE}.pdf
#done
