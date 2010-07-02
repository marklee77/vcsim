#!/bin/sh
FILE=$1
cat ${FILE} |\
perl -pe 's/greedy-pmtn-migr /\\greedypm /; s/greedy-pmtn /\\greedyp /; s/greedy /\\greedy /;' |\
perl -pe 's/opttarget:/opt=/; s/minft:/mft=/; s/minvt:/mvt=/;' |\
perl -pe 's/per:600/per/; s/ activeres/\\activeres/;' |\
perl -pe 's/opt=(.*) per/per opt=\1/;' |\
perl -pe 's/avgyield/avg/; s/maxminyield/min/; s/avgstretch/avg/; s/minmaxstretch/max/;' |\
perl -pe 's/mcb8/\\mcb/; s/stretch per/\\mcbs/;' |\
perl -pe 's/per/\\periodic/;' |\
perl -pe 's/ /\//g;' |\
cat > ${FILE}.tmp
mv ${FILE}.tmp ${FILE}
