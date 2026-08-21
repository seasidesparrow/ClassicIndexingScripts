#!/bin/sh
# Master ArXiv daily indexing script -- M. Templeton, 2026 Jul 12
#
# This script combines the three scripts in the ArXiv/bin directory used
# to generate the codes files update and the index.status file for the
# daily ArXiv harvest: ArXiv/bin/update.sh, ArXiv/bin/postprocess, and
# ArXiv/bin/index.sh

script=`basename $0`

die () {
    echo "$script: fatal error: $@ at "`date` 1>&2
    exit 1
}

warn () {
    echo "$script: $1 at " `date` 1>&2
}

checklog () {
    log="$1"
    [ -f $log ] || return 0
    w=`grep -i error $log | wc -l`
    [ $w -gt 0 ] && warn "found $w errors in log file $log"
    w=`grep -i warning $log | wc -l`
    [ $w -gt 0 ] && warn "found $w warnings in log file $log"
}

bindir=`dirname $0` ; [ "$bindir" = "." ] && bindir=""
# if bindir is a relative path, append current working directory
echo "$bindir" | grep -s -q '^/' || bindir=`pwd`"/$bindir"

PATH="$PATH:$bindir" ; export PATH

topdir="$ADS_ABSTRACTS/sources/ArXiv"
dataset=`basename $topdir`
topdir="$ADS_ABSTRACTS/sources/ArXiv"
master="$topdir/meta/master.list"
mapfile="$topdir/meta/mapids.list"
delfile="$topdir/meta/deleted.list"
update="$ADS_ABSTRACTS/pre/update"
linksdir="$ADS_ABSCONFIG/links"
indexdir="$ADS_ABSTRACTS/pre/load/latest"
indexstatus="$indexdir/index.status"
lastdir="$ADS_ABSTRACTS/pre/load/current"
laststatus="$lastdir/index.status"

timestamp=`date -I -d "-1 day"`

warn "update started"
warn "updating dataset $dataset in dir $topdir"
cd $topdir || die "cannot cd to $topdir"

# note, LOGDIR is created by the harvester -- assume it is present

LOGDIR="$topdir/log/$timestamp"; export LOGDIR
upfile="$LOGDIR/parse.out"
newrecs="$LOGDIR/new_records.tsv"

warn "output file is $upfile"
warn "log dir is $LOGDIR"

# The timeout loop is based on whether there's a parse.out.tmp file on /proj/ads
# and will continue this check every 10 minutes until it times out after
# two hours.

sleeptimeout=7200
sleepdelay=600
totdelay=0

while /bin/true ; do
    if [ -f "$upfile.tmp" ] ; then

        if [ -f $newrecs ] ; then
            warn "found "`wc -l < $newrecs`" new records"
            break
        elif [ $totdelay -ge $sleeptimeout ] ; then
            warn "timed out looking for new records"
            exit 1
        else
            warn "sleeping $sleepdelay seconds"
            sleep $sleepdelay
            totdelay=$(($totdelay + $sleepdelay))
        fi
    fi
done


if [ -s "$upfile.tmp" ] ; then

    # This section is ArXiv/bin/postprocess

    # index new preprints

    ## This section is ArXiv/bin/index.sh

    warn "Starting daily arxiv doindex"

    perl $bindir/arxiv_index_delalt_bibs.pl $update < $delfile && $bindir/doindex.sh --bytes --force-cache pre "$master" || die "indexing pre $master"

    perl -lane 'print $F[1], "\t", $F[0]' < $mapfile | \
        sort -fu > "$topdir/meta/bib2id.dat" || \
            die "cannot create $topdir/meta/bib2id.dat"
    cp -pv "$topdir/meta/bib2id.dat" "$linksdir/preprint/arxiv.dat" || \
        die "updating file $linksdir/preprint/arxiv.dat"


    for file in $topdir/meta/arxiv_* ; do
        f="$indexdir/"`basename $file`"_codes"
        join -o 1.2 $mapfile $file | sort -fu > "$f" || \
            die "cannot join $mapfile and $file into $f"
        $bindir/addcount.sh --lines "$f" || \
            die "cannot add count to file $f"
    done

    echo "Daily arxiv doindex ended at `date`"

    ## End of section ArXiv/bin/index.sh


    log="$LOGDIR/index"

    if [ -f "$log.error" ]; then
        echo "command '"`cat $log.error`"' terminated with error status"
        echo "check log file $log.log"
        checklog "$log.log"
        die "creating index; check log file $log.log"
    else
        warn "ArXiv index successful, start recreating codes"
    fi

    # note: preprint codes are recreated in match.sh above
    # XXX used to have simbad codes here as well
    $bindir/mkcodes.sh -noretrieve -nodepend \
        preprint eprint_html eprint_pdf DOI data electr pdf pub_pdf author_pdf \
        pub_html author_html postscript associated reads \
        spires alsoread_bib bibgroup_02 bibgroup_12 openaccess \
        reference citation data facet_datasources > \
            "$LOGDIR/mkcodes.log" 2>&1 || \
                die "recreating codes; check log file $LOGDIR/mkcodes.log"
    checklog "$LOGDIR/mkcodes.log"


    warn "creating $indexstatus"
    cut -f2 "$upfile.tmp" | \
        $bindir/bibsignature --update \
            --status-file "$laststatus" "$indexdir" > "$indexstatus.tmp" 2> "$LOGDIR/bibsignature.log" || \
            warn "creating index status; check log file $LOGDIR/bibsignature.log"
    sort -fuo "$indexstatus" "$indexstatus.tmp" && /bin/rm "$indexstatus.tmp"

    warn "making index operational"
    $bindir/mkop.sh pre > "$LOGDIR/mkop.log" 2>&1 || \
        warn "making pre operational; check log file $LOGDIR/mkop.log"
    checklog "$LOGDIR/mkop.log"

    # End of ArXiv/bin/postprocess

    cat "$upfile.tmp" >> "$upfile" || \
        die "cannot append file $upfile.tmp to $upfile"
    /bin/rm -f "$upfile.tmp"

    warn "update is in $upfile"
    warn "update completed on "`date`
else
    warn "no output file generated"
    exit 1
fi
