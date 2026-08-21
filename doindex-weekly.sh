#!/bin/sh

script=`basename $0`
fullscript=`readlink -f $0`
dir=`dirname $fullscript`
# writes an error message and exits
die () {
    echo "$script: fatal error: $1 occurred at " `date` 1>&2
    exit 1
}

# set environment for kubernetes containerization
# The container image must have an abbreviated .adsrc file in /app

[ "x$ADS_ENVIRONMENT" = "x" ] && [ -x "/app/.adsrc" ] && eval `/app/.adsrc sh`

db="$1"
[ "x$db" = "x" ] && die "usage: $script DB"

# the pre index needs to point to sources/ArXiv/meta/master.list
if [ $db = "pre" ]; then
    master="$ADS_ABSTRACTS/sources/ArXiv/meta/master.list"
else
    master="$ADS_ABSTRACTS/$db/update/master.list"
fi

[ -f $master ] || die "master list $master not found"
logfile="$ADS_ABSTRACTS/$db/index/LOGS/"`date '+%F'`".log"
cd "$ADS_ABSTRACTS/$db/index"
echo $script started at `date`

nodm=""
if [ "$db" = "gen" ]; then
    nodm="--no-docmatch"
fi
$dir/doindex $nodm $db $master > $logfile 2>&1 || \
    die "error running index for $db"

echo $script ended at `date`
