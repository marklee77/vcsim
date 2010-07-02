#!/bin/bash
MYSQL="mysql hpcdata2 --batch --skip-column-names"
TMPDIR=$(mktemp -d) 
SAVEDIR=$PWD
cd $TMPDIR
for DELAY in 0 300; do
    for DATASET in lubtraces-128 lubscaled-128 hpc2n-120; do
${MYSQL} > dfbest-${DELAY}-${DATASET}.txt  <<EOF
    select algo,
           format(avg(maxstretch / minmaxstretch), 1),
           format(stddev_samp(maxstretch / minmaxstretch), 1),
           format(max(maxstretch / minmaxstretch), 1)
    from solutions, (
        select dataset, delay, trace, min(maxstretch) as minmaxstretch 
        from solutions
        where (algo not like '%per:%' or algo like '%per:600%') 
          and algo not like '%per:6000%'
        group by dataset, delay, trace) as best
    where solutions.dataset = best.dataset and solutions.delay = best.delay
      and solutions.trace = best.trace
      and (algo not like '%per:%' or algo like '%per:600%') 
      and algo not like '%per:6000%'
      and solutions.dataset = '${DATASET}' and solutions.delay = ${DELAY}
    group by algo
    order by replace(algo, "_", " ");
EOF
    done 
  join dfbest-${DELAY}-hpc2n-120.txt dfbest-${DELAY}-lubtraces-128.txt |\
  join - dfbest-${DELAY}-lubscaled-128.txt |\
  perl -pe 's/ /&/g; s/_/ /g; s/\n/\\\\\n/;' >\
  ${SAVEDIR}/deg-from-best-${DELAY}-delay.tex

    for DATASET in lubtraces-128 lubscaled-128 hpc2n-120; do
${MYSQL} > dfbound-${DELAY}-${DATASET}.txt <<EOF
    select algo,
           format(avg(maxstretch / msbound), 1),
           format(stddev_samp(maxstretch / msbound), 1),
           format(max(maxstretch / msbound), 1)
    from problems, solutions
    where problems.dataset = solutions.dataset
      and problems.trace = solutions.trace 
      and solutions.dataset = '${DATASET}' and solutions.delay = ${DELAY}
      and (algo not like '%per:%' or algo like '%per:600%') 
      and algo not like '%per:6000%'
    group by algo
    order by replace(algo, "_", " ");
EOF
    done 
  join dfbound-${DELAY}-hpc2n-120.txt dfbound-${DELAY}-lubtraces-128.txt |\
  join - dfbound-${DELAY}-lubscaled-128.txt |\
  perl -pe 's/ /&/g; s/_/ /g; s/\n/\\\\\n/;' >\
  ${SAVEDIR}/deg-from-bound-${DELAY}-delay.tex

(${MYSQL} <<EOF
select algo, 
    format(8 * avg(mrest / makespan) / 100, 2), 
    format(8 * max(mrest / makespan) / 100, 2), 
    format(8 * avg(mtrans / makespan) / 100, 2), 
    format(8 * max(mtrans / makespan) / 100, 2), 
    format(3600 * avg(jrest / makespan), 2),
    format(3600 * max(jrest / makespan), 2),
    format(3600 * avg(jtrans / makespan), 2),
    format(3600 * max(jtrans / makespan), 2),
    format(avg(jrest) / 1000, 2),
    format(max(jrest) / 1000, 2),
    format(avg(jtrans) / 1000, 2),
    format(max(jtrans) / 1000, 2)
from problems, solutions 
where problems.dataset = solutions.dataset
  and problems.trace = solutions.trace
  and solutions.dataset = 'lubscaled-128' and solutions.delay = $DELAY and sload > 6
  and (algo not like '%per:%' or algo like '%per:600%') 
  and algo not like '%per:6000%'
  and algo not in ('easy','fcfs')
group by algo
order by replace(algo, "_", " ");
EOF
) | while read LINE; do
    printf "%s&%s (%s)&%s (%s)&%s (%s)&%s (%s)&%s (%s)&%s (%s)\\\\\\\\\n" ${LINE}
done | perl -pe 's/_/ /g;' > ${SAVEDIR}/costs-lubscaled-128-sload-gte-7-${DELAY}-delay.tex
done

cd ${SAVEDIR}
rm -r ${TMPDIR}
