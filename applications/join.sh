#!/bin/sh

echo "Join.sh <plain> <clustered> joins the records for packages"
echo "analysed for brokenn Impact Set in plain and clustered mode"
echo " plain and clustered come from the analysis of strongpred,"
echo " like this: grep Changing logalldata-upgrades-downto-debversions > plain"

plain=$1
splain=`basename $1`
clustered=$2
sclustered=`basename $2`

tmplain=/tmp/plain.$$
tmpclustered=/tmp/clustered.$$


sed -f cleanup.sed $plain | cut -f 4 -d ' ' --complement > $plain.csv
sed -f cleanup.sed $clustered | cut -f 4 -d ' ' --complement > $clustered.csv

sed -e 's/,/###JOIN###/' $plain.csv | sort -k 1b,1 > $tmplain
sed -e 's/,/###JOIN###/' $clustered.csv | sort -k 1b,1 > $tmpclustered

cat > plainclustered.csv<<EOF
Package, current version,current cudf,new version, new cudf, #(IS(p)), broken plain, plain %, broken clustered, clustered %
EOF


join -j 1 -t, -o 0,1.2,1.4,1.5,1.7,1.6,1.8,2.6,2.8 $tmplain $tmpclustered | sed 's/###JOIN###/,/' >> plainclustered.csv

rm -f $tmplain $tmpclustered


