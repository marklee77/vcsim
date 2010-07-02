#!/bin/bash
MYSQL="mysql hpcdata2 --batch --skip-column-names"

for DATASET in $(${MYSQL} -e "select distinct dataset from solutions order by dataset desc;"); do
    for DELAY in $(${MYSQL} -e "select distinct delay from solutions where dataset = '${DATASET}' order by delay;"); do

        echo "Average Stretch Statistics for ${DATASET/_/ } dataset with ${DELAY} second migration penalty:"
        echo
        (echo -e "algorithm\tminimum\tmaximum\taverage\tdeviation"
${MYSQL} <<EOF
    select algo as algorithm, 
           format(min(avgstretch), 2) as minimum, 
           format(max(avgstretch), 2) as maximum, 
           format(avg(avgstretch), 2) as average,
           format(stddev_samp(avgstretch), 2) as deviation
    from solutions
    where dataset = '${DATASET}' and delay = ${DELAY} 
      and (algo not like '%per:%' or algo like '%per:600%') 
      and algo not like '%per:6000%'
    group by algo
    order by if(instr(algo, 'per:'), substr(algo, 1, instr(algo, 'per:')), algo),
             if(instr(algo, 'minft:'), 2, if(instr(algo, 'minvt:'), 1, 0)), 
             cast(substr(algo, instr(algo, '_min') + 7) as unsigned), 
             cast(substr(algo, instr(algo, 'per:') + 4) as unsigned);
EOF
) | while read LINE; do
    printf "%-74s %9s %9s %9s %9s\n" ${LINE}
done

        echo
        echo "Average Stretch Degredation From Best Statistics for ${DATASET/_/ } dataset with ${DELAY} second migration penalty:"
        echo
        (echo -e "algorithm\tminimum\tmaximum\taverage\tdeviation"
${MYSQL} <<EOF
    select algo,
           format(min(avgstretch / minavgstretch), 2),
           format(max(avgstretch / minavgstretch), 2),
           format(avg(avgstretch / minavgstretch), 2),
           format(stddev_samp(avgstretch / minavgstretch), 2)
    from solutions, (
        select dataset, delay, trace, min(avgstretch) as minavgstretch 
        from solutions
       where (algo not like '%per:%' or algo like '%per:600%') 
         and algo not like '%per:6000%'
        group by dataset, delay, trace) as best
    where solutions.dataset = best.dataset and solutions.delay = best.delay 
      and solutions.trace = best.trace
      and solutions.dataset = '${DATASET}' and solutions.delay = ${DELAY}
      and (algo not like '%per:%' or algo like '%per:600%') 
      and algo not like '%per:6000%'
    group by algo
    order by if(instr(algo, 'per:'), substr(algo, 1, instr(algo, 'per:')), algo),
             if(instr(algo, 'minft:'), 2, if(instr(algo, 'minvt:'), 1, 0)), 
             cast(substr(algo, instr(algo, '_min') + 7) as unsigned), 
             cast(substr(algo, instr(algo, 'per:') + 4) as unsigned);
EOF
) | while read LINE; do
    printf "%-74s %9s %9s %9s %9s\n" ${LINE}
done
        echo
        echo "Maximum Stretch Statistics for ${DATASET/_/ } dataset with ${DELAY} second migration penalty:"
        echo
        (echo -e "algorithm\tminimum\tmaximum\taverage\tdeviation"
${MYSQL} <<EOF
    select algo,
           format(min(maxstretch), 2), 
           format(max(maxstretch), 2),
           format(avg(maxstretch), 2),
           format(stddev_samp(maxstretch), 2)
    from solutions
    where dataset = '${DATASET}' and delay = ${DELAY}
      and (algo not like '%per:%' or algo like '%per:600%')
      and algo not like '%per:6000%'
    group by algo
    order by if(instr(algo, 'per:'), substr(algo, 1, instr(algo, 'per:')), algo),
             if(instr(algo, 'minft:'), 2, if(instr(algo, 'minvt:'), 1, 0)), 
             cast(substr(algo, instr(algo, '_min') + 7) as unsigned), 
             cast(substr(algo, instr(algo, 'per:') + 4) as unsigned);
EOF
) | while read LINE; do
    printf "%-74s %9s %9s %9s %9s\n" ${LINE}
done
        echo
        echo "Maximum Stretch Degredation From Best Statistics for ${DATASET/_/ } dataset with ${DELAY} second migration penalty:"
        echo
        (echo -e "algorithm\tminimum\tmaximum\taverage\tdeviation"
${MYSQL} <<EOF
    select algo,
           format(min(maxstretch / minmaxstretch), 2),
           format(max(maxstretch / minmaxstretch), 2),
           format(avg(maxstretch / minmaxstretch), 2),
           format(stddev_samp(maxstretch / minmaxstretch), 2)
    from solutions, (
        select dataset, delay, trace, min(maxstretch) as minmaxstretch 
        from solutions
       where (algo not like '%per:%' or algo like '%per:600%')
         and algo not like '%per:6000%'
        group by dataset, delay, trace) as best
    where solutions.dataset = best.dataset and solutions.delay = best.delay
      and solutions.trace = best.trace
      and solutions.dataset = '${DATASET}' and solutions.delay = ${DELAY}
      and (algo not like '%per:%' or algo like '%per:600%')
      and algo not like '%per:6000%'
    group by algo
    order by if(instr(algo, 'per:'), substr(algo, 1, instr(algo, 'per:')), algo),
             if(instr(algo, 'minft:'), 2, if(instr(algo, 'minvt:'), 1, 0)), 
             cast(substr(algo, instr(algo, '_min') + 7) as unsigned), 
             cast(substr(algo, instr(algo, 'per:') + 4) as unsigned);
EOF
) | while read LINE; do
    printf "%-74s %9s %9s %9s %9s\n" ${LINE}
done
        echo
        echo "Maximum Stretch Degredation From Bound Statistics for ${DATASET/_/ } dataset with ${DELAY} second migration penalty:"
        echo
        (echo -e "algorithm\tminimum\tmaximum\taverage\tdeviation"
${MYSQL} <<EOF
    select algo,
           format(min(maxstretch / msbound), 2),
           format(max(maxstretch / msbound), 2),
           format(avg(maxstretch / msbound), 2),
           format(stddev_samp(maxstretch / msbound), 2)
    from problems, solutions
    where problems.dataset = solutions.dataset and problems.trace = solutions.trace 
      and solutions.dataset = '${DATASET}' and solutions.delay = ${DELAY}
      and (algo not like '%per:%' or algo like '%per:600%')
      and algo not like '%per:6000%'
    group by algo
    order by if(instr(algo, 'per:'), substr(algo, 1, instr(algo, 'per:')), algo),
             if(instr(algo, 'minft:'), 2, if(instr(algo, 'minvt:'), 1, 0)), 
             cast(substr(algo, instr(algo, '_min') + 7) as unsigned), 
             cast(substr(algo, instr(algo, 'per:') + 4) as unsigned);
EOF
) | while read LINE; do
    printf "%-74s %9s %9s %9s %9s\n" ${LINE}
done
        echo
        echo "Normalized Underutilization Statistics for ${DATASET/_/ } dataset with ${DELAY} second migration penalty:"
        echo
        (echo -e "algorithm\tminimum\tmaximum\taverage\tdeviation"
${MYSQL} <<EOF
    select algo,
           format(min((demand_integral - cpusecs) / cpusecs), 2), 
           format(max((demand_integral - cpusecs) / cpusecs), 2),
           format(avg((demand_integral - cpusecs) / cpusecs), 2),
           format(stddev_samp((demand_integral - cpusecs) / cpusecs), 2)
    from solutions, problems
    where solutions.dataset = problems.dataset and solutions.trace = problems.trace 
      and solutions.dataset = '${DATASET}' and solutions.delay = ${DELAY}
      and (algo not like '%per:%' or algo like '%per:600%')
      and algo not like '%per:6000%'
    group by algo
    order by if(instr(algo, 'per:'), substr(algo, 1, instr(algo, 'per:')), algo),
             if(instr(algo, 'minft:'), 2, if(instr(algo, 'minvt:'), 1, 0)), 
             cast(substr(algo, instr(algo, '_min') + 7) as unsigned), 
             cast(substr(algo, instr(algo, 'per:') + 4) as unsigned);
EOF
) | while read LINE; do
    printf "%-74s %9s %9s %9s %9s\n" ${LINE}
done
        echo
        echo "Underutilization Scaled Difference From Best Statistics for ${DATASET/_/ } dataset with ${DELAY} second migration penalty:"
        echo
        (echo -e "algorithm\tminimum\tmaximum\taverage\tdeviation"
${MYSQL} <<EOF
    select algo,
           format(min((demand_integral - mindemand_integral) / cpusecs), 2),
           format(max((demand_integral - mindemand_integral) / cpusecs), 2),
           format(avg((demand_integral - mindemand_integral) / cpusecs), 2),
           format(stddev_samp((demand_integral - mindemand_integral) / cpusecs), 2)
    from problems, solutions, (
        select solutions.dataset, delay, solutions.trace, min(demand_integral) as mindemand_integral
        from solutions
       where (algo not like '%per:%' or algo like '%per:600%')
         and algo not like '%per:6000%'
        group by dataset, delay, trace) as best
    where problems.dataset = solutions.dataset and problems.trace = solutions.trace
      and solutions.dataset = best.dataset and solutions.delay = best.delay
      and solutions.trace = best.trace
      and solutions.dataset = '${DATASET}' and solutions.delay = ${DELAY}
      and (algo not like '%per:%' or algo like '%per:600%')
      and algo not like '%per:6000%'
    group by algo
    order by if(instr(algo, 'per:'), substr(algo, 1, instr(algo, 'per:')), algo),
             if(instr(algo, 'minft:'), 2, if(instr(algo, 'minvt:'), 1, 0)), 
             cast(substr(algo, instr(algo, '_min') + 7) as unsigned), 
             cast(substr(algo, instr(algo, 'per:') + 4) as unsigned);
EOF
) | while read LINE; do
    printf "%-74s %9s %9s %9s %9s\n" ${LINE}
done
        echo
    done
done
