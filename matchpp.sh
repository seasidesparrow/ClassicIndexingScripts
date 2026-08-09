#!/bin/sh
#
# $Id$
#
# Usage: matchpp.sh db loaddir
#
# $Log$
#
# This script controls weekly matching of new content to existing eprints
#
# ===================================
# Adjusting call to doc matching pipeline to use command set for
# ADSDocMatchPipeline v3+
# Revision: 2023 March 06 [MT]
#
# ===================================
#
# The new doc matching pipeline assumes there's a file called
# "match_oracle.input" in # .../[collection]/index/current
# The commands for generating the match_oracle.input file were removed some
# time since 2023 Jan, and this edit replaces them.  
# Revision: 2023 May 05 [MT]
#
# ===================================
#
# This revision replaces classic matching via match.pl with doc matching
# pipeline exclusively.  The classic match.pl is no longer used.
# Revision: 2023 Jun 16 [MT]
#
# ===================================
#

script=`basename $0`
DMSERVER="adsnest"

# writes an error message and exits
die () {
    echo "$script: fatal error: $1 occurred at " `date` 1>&2
    exit 1
}

warn () {
    echo "$script: $1 at " `date` 1>&2
}

[ $# -gt 1 ] || die "Usage: $script db loaddir [olddir]"


# setting up needed variables for matching

db="$1"
loaddir="$2"
if [ "x$3" = "x" ] ; then
    curload=`dirname $loaddir`"/current"
else 
    curload="$3"
fi

curind="$ADS_ABSTRACTS/$db/index/current"

[ -d $loaddir ] || die "$loaddir is not a directory"
[ -d $curload ] || die "$curload is not a directory"
[ -d $curind  ] || die "$curind  is not a directory"

cd $curind || die "cannot cd to $curind"

if [ $db = "pre" ] ; then
    warn "skipping matching for preprint index"
    exit 0
fi

warn "previous load directory is $curload"
warn "latest   load directory is $loaddir"


join -i -v1 -t "	" "$loaddir/bib2accno.list" "$curload/bib2accno.list" | \
    tail -n +2 | perl -lane 'print "$F[0]\t$F[1]" if $F[2] > 199200' \
	> matches.input.tmp || die "error creating file matches.input"

[ -s matches.input.tmp ] || die "no new records to match"
mv matches.input.tmp matches.input || die "cannot move matches.input.tmp to matches.input"

# first generate list of which bibcodes are refereed in input list
$ADS_ABSCONFIG/links/refereed/all.flt < matches.input | \
    sort -fuo refereed.dat || die "cannot generate list of refereed bibcodes"

warn "starting matching of "`wc -l < matches.input`" new records at "`date`

## START classic matching process
#/proj/ads/abstracts/sources/ArXiv/bin/match.pl --exclude /dev/null \
#    --refereed ./refereed.dat --db $db \
#    < ./matches.input > ./match.out 2> ./matches.log || \
#	die "error running match.pl"
# END classic matching process



# START doc matching process

ilist=`pwd`"/match_oracle.input"
olist=`pwd`"/matched_pub.output.csv"

cut -f2 matches.input | sort -f | join -i -t "	" - accnos.input | cut -f2 > $ilist || \
    die "cannot generate $ilist"
warn "submitting the list of "`wc -l < $ilist`" metadata records to docmatch scripts at "`date`

command="/usr/local/bin/rjob -j process python3 /app/run.py -me -p"`pwd`"/"

remote="$DMSERVER docker exec -i -u ads backoffice_prod_doc_matching_pipeline_1 bash -l -s"

echo "$script: executing \"$command\" via: \"ssh $remote\""
echo "$command" | ssh $remote || \
    warn "error running script $remote"

clout="./match.out"

# 2023Jun15 -MT: temporary fix to convert docmatch output file to match.out
#     To do: update ADSDocMatchPipeline to optionally output a tsv file with 
#     source bib, matched bib, and score only
#     similar to daily pp matching, but note you want the arxiv bibcode first
#     and cut always outputs the input order, so you need the awk statement
#     to reverse columns 1 and 2 in the output

if [ -e $olist ]; then
    grep ',Match,' $olist | sed -r 's/""https[^,]+"",//g' | sed -r 's/"=HYPERLINK\(""//g' | sed -r 's/""\)"//g' | cut -d ',' -f 1,3,5 --output-delimiter="`echo '\t'`" - | awk '{print($2,"\t",$1,"\t",$3)}' | sed -e 's/ //g' > $clout || die "error writing $clout"
else
    die "$olist not found."
fi

echo "$script: matched "`wc -l < $clout`" records at "`date`

cat $clout >> $ADS_ABSTRACTS/sources/ArXiv/published/matches_pub2pre.list

# Upload matches in $clout to oracledb
command="/usr/local/bin/rjob -j process python3 /app/run.py -mf $clout -as ADS"

remote="$DMSERVER docker exec -i -u ads backoffice_prod_doc_matching_pipeline_1 bash -l -s"

echo "$script: executing \"$command\" via: \"ssh $remote\""
echo "$command" | ssh $remote || \
    warn "error running script $remote"

echo "$script completed at `date`"
