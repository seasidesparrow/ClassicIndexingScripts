#!/bin/bash
#
# $Id: mkcodes.sh,v 1.6 2011/01/10 07:12:58 ads Exp ads $
#
# This program is part of the NASA Astrophysics Data System
# abstract service loading/indexing procedure.
#
# Copyright (C): 1996 Smithsonian Astrophysical Observatory.
# You may do anything you like with this file except remove
# this copyright.  The Smithsonian Astrophysical Observatory
# makes no representations about the suitability of this
# software for any purpose.  It is provided "as is" without
# express or implied warranty.  It may not be incorporated into
# commercial products without permission of the Smithsonian
# Astrophysical Observatory.
#
# $Log: mkcodes.sh,v $
# Revision 1.6  2011/01/10 07:12:58  ads
# Added creation of shortbib.dat
#
# Revision 1.5  2005/08/23 15:37:35  ads
# Fixed bug introduced with last modification (*.dat.nocheck files)
#
# Revision 1.4  2005/08/22 15:04:05  ads
# Added processing of *.dat.nocheck files
#
# Revision 1.3  2004/03/26 16:42:37  ads
# reintroduced translation of bibcodes in all.links to their
# canonical form via call to canonicalbib()
#
# Revision 1.2  2003/12/10 18:14:15  ads
# Updated creation of global bib2accno and bibcodes files so that both
# current and latest index directories are included.  Also updated the
# creation of TIMESTAMP.codes and VERSION_codes.
#
# Revision 1.1  2003/02/20 20:56:16  ads
# Initial revision
#
# Revision 1.17  2002/06/27 17:16:47  alberto
# added sorting of input codes directories when -all is specified
#
# Revision 1.16  2002/06/20 14:21:34  alberto
# Fixed bug introduced with last revision
#
# Revision 1.15  2002/06/19 20:38:40  alberto
# Updated creation of list of codes directories when -all is specified
# on the command line.
#
# Revision 1.14  2002/06/19 19:52:32  ads
# Added option to skip index, list, and codes files if the flag file
# NOCODES is present in the build directory
#
# Revision 1.13  2001/12/12 19:52:35  ads
# Added creation of COUNT files in links directories
#
# Revision 1.12  2001/10/08 16:54:28  ads
# Added mirroring of HTML documents (which are modified by
# the article updating procedures).
#
# Revision 1.11  2001/09/10 14:07:13  ads
# Modified mysort() to properly deal with read-only files
# (which used to crash the procedure).
#
# Revision 1.10  2001/07/27 14:23:56  ads
# Modified mybackup() to keep current version of file
# being backed up.  This avoids having important files
# (like bib2accno) disappear even temporarily as we are
# in the process of creating a new version.
# The new procedure now is as follows:
#     1) Make compressed copy of existing file for backup
#     2) Create new copy to temporary file
#     3) Move new file over old one using mv
#
# Revision 1.9  2001/07/12 21:19:53  ads
# fixed bug with settings of CONST_DIRECTORY when -indexdir
# is specified on the command line.
#
# Revision 1.8  2000/11/29 19:26:08  ads
# Introduction of file $BIB2ACCNO.state allows us to keep track of what
# files have been used in the creation of the global bib2accno file.
# Added more contingency rules to avoid the creation of index and list
# files unless necessary.
#
# Revision 1.7  2000/06/01 20:48:59  ads
# Implemented retrieval of remote URLs from *.uri files,
# introduced timestamp checks to avoid recreation of local
# *.rej or *.dat files unless warranted by dependency changes.
#
# Revision 1.6  1999/11/22 15:37:04  ads
# Modified to avoid creation of inverted dictionary files ($dict)
#
# Revision 1.5  1999/01/25 13:58:49  ads
# Fixed generation of reject bibcodes so that no alternate bibcodes appear
# in them.  This was implemented by creating a global lookup table for
# all bibcodes ($ALLBIB), which may be useful in other cases.
# Added a "-db" command line option to save keystrokes when recreating
# codes just in a particular DB index directory.
#
# Revision 1.4  1998/08/07 20:58:58  ads
# changed to use new setup with alternate bibcodes stored in a separate
# file and incorporated creation of bibliographic group files.
# Also, codes files now contain only bibcodes in preparation for complete
# dropping of accnos.
#
# Revision 1.3  1997/07/18 13:54:25  ads
# Added handling of *.kill files, fixed script behaviour
# when global bib2accno does not exist.
#
# Revision 1.2  1996/11/22  22:32:27  ads
# Changed behaviour of script when recreating codes files
# for just one index directory.  Bibcodes are now merged
# into existing ones instead of being skipped.
#
# Revision 1.1  1996/07/16  17:46:00  ads
# Initial revision
#
#

# set this for debugging
#set -x

# take into account the termination status of all commands in a pipe
set -o pipefail

p=`basename $0`

# set environment for kubernetes containerization
# The container image must have an abbreviated .adsrc file in /app

[ "x$ADS_ENVIRONMENT" = "x" ] && [ -x "/app/.adsrc" ] && eval `/app/.adsrc sh`

merge="YES"
dorejects=
fullscript=`readlink -f $0`
dir=`dirname $fullscript`
export PATH="$dir:$PATH"
export TMPDIR=${ADS_TMP-/tmp}

###### auxiliary functions:


# writes a message to stderr
vecho () {
    [ "x$verbose" = "x" ] || echo "$p:" "$@" 1>&2
}

# writes a message to stderr
warn () {
    echo "$p: $@" 1>&2
}

# sorts a file in place
mysort () {
    vecho "sorting file $1"
    if [ -w $1 ] ; then
	sort -fuo $1 $1 || return 1
    elif [ -r $1 ] ; then
	mv $1 $1.tmp || return 2
	sort -fuo $1 $1.tmp || return 1
	rm -f $1.tmp || return 3
    else 
        vecho "file $1 not readable!"
	exit 1
    fi
}


# backs up a file by maintaining multiple copies
mybackup () {
    if [ -f $1 ] ; then 
	i=1
	while [ -f "$1.bck.$i" -o -f "$1.bck.$i.gz" ] ; do
	    i=`expr $i + 1`
	done
	[ $i -ge 4 ] && i=3
	while [ $i -gt 1 ] ; do
	    pi=`expr $i - 1`
	    [ -f "$1.bck.$pi" ] && \
		(mv -f "$1.bck.$pi" "$1.bck.$i" || return 1)
	    [ -f "$1.bck.$pi.gz" ] && \
		(mv -f "$1.bck.$pi.gz" "$1.bck.$i.gz" || return 2)
	    i=$pi
	done
	gzip -cf "$1" > "$1.bck.1.gz" || return 3
	touch --reference "$1" "$1.bck.1.gz" || return 4
	vecho "file $1 backed up to $1.bck.1.gz"
    else
	vecho "file $1 not backed up (doesn't exist)"
    fi
}


# restores a previous copy of a backup file
myrestore () {
    [ -f "$1" ] && (mv -f $1 "$1.tmp" || return 1)
    [ -f "$1.bck.1.gz" ] && (gunzip -f "$1.bck.1.gz" || return 2)
    if [ -f "$1.bck.1" ] ; then 
	mv -f "$1.bck.1" $1 || return 3
    else
	vecho "cannot find backup copy of file $1"
	return 0
    fi
    i=2
    while [ -f "$1.bck.$i" -o -f "$1.bck.$i.gz" ] ; do
	pi=`expr $i - 1`
	[ -f "$1.bck.$i" ] && \
	    (mv -f "$1.bck.$i" "$1.bck.$pi" || return 4)
	[ -f "$1.bck.$i.gz" ] && \
	    (mv -f "$1.bck.$i.gz" "$1.bck.$pi.gz" || return 5)
	i=`expr $i + 1`
    done
    vecho "file $1 restored from $1.bck.1.gz"
}

# replaces "alternate" bibcodes in first column of file 1 
# with good bibcodes in second column of file 2
# both files must be sorted case-insensitive
fixaltbib () {
    [ -f "$1" ] || return 1
    [ -f "$2" ] || return 0
    vecho "fixing alternate bibcodes in $1 using lookup file $2"
    join -t "	" -i $2 $1 | cut -f2- > $1.tmp || return 3
    if [ -s "$1.tmp" ] ; then
	join -t "	" -i -v 1 $1 $2 >> $1.tmp || return 4
	sort -fuo $1 $1.tmp || return 5
    fi
    /bin/rm -f $1.tmp
}

# joins in case-insensitive way input files
# based on timestamps
joinfiles () {
    target="$1"; shift
    doalllinks=
    dobackup=YES
    founddat=
    datfiles=
    if [ ! -f $target -o ! -s $target ] ; then
	doalllinks="YES"
	dobackup="NO"
	[ -f "$target" ] || cp /dev/null "$target"
    fi

    # make sure all files are sorted case insensitively
    for dat in "$@" ; do
	[ -f $dat ] || continue
	founddat=YES
	datfiles="$datfiles $dat"
	if sort -fuc $dat 2>/dev/null ; then
	    : # file is already sorted and uniqued
	else
	    vecho "sorting and uniquing file $dat..."
	    mysort $dat || return 1
	fi
        /usr/bin/test $dat -nt $target && doalllinks="YES"
    done

    [ "x$founddat" = "xYES" ] || return 0

    if sort -fuc $target 2>/dev/null ; then
	: # $target already sorted and uniqued
    else 
	vecho "sorting and uniquing file $target..."
	sort -fuo $target $target || return 2
    fi

    if [ "x$doalllinks" = "xYES" ] ; then
	# recreate a new $target file only if we are doing a full build
	tmp="$target.tmp.$$"
	if [ "x$localbib" = "x" ] ; then
	    if [ "x$dobackup" = "xYES" ] ; then
		mybackup "$target" || return 3
	    fi
	fi
	[ -f "$tmp" ] || cp /dev/null "$tmp"

	# join all data files
	vecho "joining entries from individual dat files into $tmp"
	echo "$datfiles" | xargs sort -fmuo "$tmp" "$tmp" || return 4
	/bin/mv -f "$tmp" "$target" || return 5
    else 
	vecho "file $target is up to date"
    fi

    # translate alternate bibcodes in good ones
    if /usr/bin/test $target -nt $ALTBIB ; then
	fixaltbib $target $ALTBIB || return 5
    fi

    return 0
}

# replaces "alternate" bibcodes in file 1 
# with good bibcodes in second column of file 2 (bibcodes.list.all)
# both files must be sorted case-insensitive
canonicalbib () {
    [ -f "$1" ] || return 1
    [ -f "$2" ] || return 0
    if $3 ; then
	join -v2 -t "	" -i $2 $1 
	join -t "	" -i $2 $1 | cut -f2- 
    else
	join -t "	" -i $2 $1 | cut -f2- 
    fi | sort -fu || return 2
}

# cleans up bibcodes in bibliographic groups and
# for each arxiv bibcode adds corresponding published record
cleanupgroup () {
    [ -f "$1" ] || return 1
    [ -f "$2" ] || return 1
    [ -f "$3" ] || return 1
    vecho "updating deleted and published bibcode in file $1"
    arxiv2pub="$2"
    del2can="$3"
    perl -pe 's/\t.*$//;         # kill everything after tab
              s/\s+//g;          # cleanup all blanks
              s/[\x7f-\xff]//g;  # remove all high-bit stuff
              $_ .= "\n";' "$1" > "$1.tmp.$$" || return 2
    sort -fuo "$1.tmp.$$" "$1.tmp.$$" || return 3
    # translate preprints to their published records
    join -i -o 1.2 "$arxiv2pub" "$1.tmp.$$" | sort -fo "$1.tmp.$$.1" - "$1.tmp.$$" || return 4
    # translate deleted to canonical
    join -i -o 1.2 "$del2can" "$1.tmp.$$.1" | sort -fo "$1.tmp.$$.2" - "$1.tmp.$$.1" || return 5
    cat "$1.tmp.$$.2"
    /bin/rm "$1.tmp.$$" "$1.tmp.$$.1" "$1.tmp.$$.2" || return 6
}

# writes out strings that set environment variables read from input file
getenv () {
    [ -f "$1" ] || return 1
    cat "$1" | grep -s = | \
        sed -e 's/^\(.*\)=\(.*\)$/\1="\2"; export \1;/' || return 2
}

# writes an error message to stderr, and bails out
error () {
    warn "fatal error: $1 occurred"
    exit 1
}

# downloads a web resource if more recent that local copy
download () {
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1
    output="$2"
    lastmod=
    [ -f "$output" ] && lastmod="-z '$output'"
    vecho curl -k -s -S -L -A 'ADS crawler; ads@cfa.harvard.edu' -o "$output" $lastmod "$1"
    curl -k -s -S -L -A 'ADS crawler; ads@cfa.harvard.edu' -o "$output" $lastmod "$1" || return 1
}


# writes usage message
usage () {
    warn "$1
Usage: $p [options] code ...
Options:
   --db DB               use files in current operational directory for 
                         database DB (one of $ADS_DATABASES)
   --changebibs          change all deleted bibcodes in *.dat and *.tab files
   --config config_dir   use config_dir as the abstract configuration directory
   --dorejects           create .rej files for bibcodes not in current list
   --forcenew            force the creation of new codes files even if they
                         have less entries than old ones
   --index index_dir     use files in index_dir instead of the operational
                         server directories
   --mirror              mirror codes files at end of creation
   --noretrieve          use static copy of input data files instead of 
                         retrieving new ones 
   --noexe               do not recreate .dat files from .exe and .ftl
                         executables
   --nomerge             recreate global bib2accno file rather than merging
			 into existing one
   --noindex             do not create index and list files in version
                         independent directory
   --nocodes             do not create codes files in version independent
                         directory
   --nodepend            do not follow dependency rules when recreating codes
   --reload              reload segments when done
   --touch               recreate the global bib2accno file even if its time
                         stamp is more recent than the ones for the individual
                         bib2accno files
   --verbose             write diagnostic information to stdout
   --help                print this message
Examples: 
    $p data electr
will build data_codes, electr_codes in the three servers' operational
index directories and the auxiliary index and list files in the
configuration directory
    $p --db AST article electr
will build article_codes and electr_codes in the current operational directory
for database AST
" 

    exit 1
}


###### processing

indexdir=
linksdir="$ADS_ABSTRACTS/links"

# see if any command line options override these settings:
while [ $# -ne 0 ]; do
    case "$1" in
    -all|--all)
        # use all directories for links
        # items=`/bin/ls -1 $ADS_ABSCONFIG/links`
	items=`find $ADS_ABSCONFIG/links -mindepth 1 -maxdepth 1 -type d -name '[A-Za-z]*' -printf "%f\n" | sort`
	;;
    -config|--config)
	# override constant config directory
	shift
	linksdir="$1"
	[ -d $linksdir ] || \
	    error "directory $linksdir not found"
	;;
    -forcenew|--forcenew) 
	# force creation of new *_codes file even if with less
	# entries than original ones
	forcenew="YES"
	;;
    -dorejects|--dorejects) 
	# force creation of new *_codes file even if with less
	# entries than original ones
	dorejects="YES"
	;;

    -changebibs|--changebibs)
        # change all deleted bibcodes in *.dat and *.tab* files 
        changebibs="YES"
	;;

    -db|--db)
	# override index directory for one or more of the DBs
        shift
	indexdir="$ADS_ABSTRACTS/"`echo $1 | tr '[A-Z]' '[a-z]'`"/load/latest"
	bib2accno="$indexdir/bib2accno.list"
	altbib="$indexdir/bibcodes.list.alt"
	allbib=
	localbib="YES"
        ;;
    -index|--index)
	# override index directory for one or more of the DBs
        shift
	indexdir="$1"
	bib2accno="$indexdir/bib2accno.list"
	altbib="$indexdir/bibcodes.list.alt"
	allbib=
	localbib="YES"
        ;;
    -reload|--reload)
	# if this flag is turned on, segments are reloaded
	reload="YES"
	;;
    -mirror|--mirror)
	# if this flag is turned on, segments are reloaded
	mirror="YES"
	;;
    -touch|--touch)
	# if set, the global bib2accno file is recreated even if its
   	# time stamp is more recent that the individual bib2accno files
	dobib="YES"
	;;
    -noindex|--noindex)
	# if set, do not create list and index files in $linksdir
	noindex="YES"
	;;
    -nocodes|--nocodes)
	# if set, do not create list and index files in $linksdir
	nocodes="YES"
	;;
    -noretrieve|--noretrieve)
	# if set, do not create new dynamic data files
	noretrieve="YES"
	;;
    -noexe|--noexe)
	# if set, do not create .dat files from .exe and .flt executables
	noexe="YES"
	;;
    -nodepend|--nodepend)
	# if set, do not check DEPEND files
	nodepend="YES"
	;;
    -nomerge|--nomerge)
	# if set, merge bib2accno files in the index directories
	# with the global bib2accno file, 
	merge="NO"
	;;
    -verbose|--verbose) 
	# be verbose
	verbose="YES"
	;;
    -help|--help) 
        usage 
	;;
    -*)
        usage "unknown option \"$1\""
        ;;
    *) 
	break
	;;
    esac
    shift
done


[ $# -gt 0 ] && items="$@"
[ "x$items" = "x" ] && usage "no code specified"
echo "$p: codes creation started at" `date`

CONFIG="$ADS_ABSCONFIG"
BIB2ACCNO="$CONFIG/bib2accno.dat"
ALTBIB="$CONFIG/bibcodes.list.alt"
ALLBIB="$CONFIG/bibcodes.list.all"
DELBIB="$CONFIG/bibcodes.list.del"
SHORTBIB="$CONFIG/shortbib.dat"
ARXIV2PUB="$CONFIG/links/preprint/arxiv2pub.list"

# FYI, canonical bibcode lists are now created in the preprint codes post-processing
# (see /proj/ads/abstracts/config/links/preprint/makefile.post)
# this is here just so we back it up for posterity
CANBIB="$CONFIG/bibcodes.list.can"
ALL2CAN="$CONFIG/bibcodes.list.all2can"

if [ "x$indexdir" = "x" ]; then
    update=
    for db in $ADS_DATABASES ; do
	# find current index (overridden by -index)
	current="$ADS_ABSTRACTS/"`echo $db | tr '[A-Z]' '[a-z]'`"/load/current"
	indexdir="$indexdir $current"
	# see if there is a new version available, in which case include it
	latest="$ADS_ABSTRACTS/"`echo $db | tr '[A-Z]' '[a-z]'`"/load/latest"
	[ $current -ef $latest ] || indexdir="$indexdir $latest"
    done
    # save the list of individual bib2accno files used to create
    # the global bib2accno
    touch "$BIB2ACCNO.state.$$"
    # see if we need to create new version of global bib2accno file
    for ind in $indexdir ; do
	/usr/bin/test $ind/bib2accno.list -nt $BIB2ACCNO \
	    && dobib="YES"
	/bin/ls -l "$ind/bib2accno.list" >> "$BIB2ACCNO.state.$$"
    done
    [ -f $BIB2ACCNO.state ] || touch $BIB2ACCNO.state
    if cmp "$BIB2ACCNO.state.$$" "$BIB2ACCNO.state" ; then
	vecho "$BIB2ACCNO.state file not modified"
	/bin/rm "$BIB2ACCNO.state.$$"
    else 
	vecho "$BIB2ACCNO.state file has been modified, recreating bib2accno"
	/bin/mv -f "$BIB2ACCNO.state.$$" "$BIB2ACCNO.state"
	dobib="YES"
    fi
    [ "x$dobib" = "x" ] && vecho "bib2accno file $BIB2ACCNO is up to date"
else 
    update="YES"
    dobib="YES"
fi

[ -f "$BIB2ACCNO" ] || dobib="YES"
echo "$p: bib2accno is $BIB2ACCNO"

if [ "x$dobib" != "x" ] ; then
    mklock -s 60 -r 20 bibcodes.list $$ || \
	warn "could not create lock for bibcodes.list $$"
    echo "$p: alternate biblist is $ALTBIB"
    echo "$p: complete biblist is $ALLBIB"
    echo "$p: deleted biblist is $DELBIB"
    echo "$p: canonical biblist is $CANBIB"
    echo "$p: complete to canonical biblist is $ALL2CAN"
    echo "$p: short biblist is $SHORTBIB"
    if [ "x$update" = "xYES" ]; then
	vecho "updating global bib2accno file $BIB2ACCNO"
	b2a="$BIB2ACCNO"
	bla="$ALTBIB"
	bld="$DELBIB"
    else
        vecho "creating global bib2accno file $BIB2ACCNO"
	b2a=""
	bla=""
	bld=""
    fi
    [ -f $BIB2ACCNO ] || touch $BIB2ACCNO
    [ -f $ALTBIB ] || touch $ALTBIB
    blines=1
    dlines=1
    alines=1
    for ind in $indexdir ; do
	if [ -f "$ind/bib2accno.list" ] ; then
	    b2a="$b2a $ind/bib2accno.list"
	    blines=`expr $blines + 1`
	fi
	if [ -f "$ind/bibcodes.list.alt" ] ; then
	    bla="$bla $ind/bibcodes.list.alt"
	    alines=`expr $alines + 1`
	fi
	if [ -f "$ind/bibcodes.list.del" ] ; then
	    bld="$bld $ind/bibcodes.list.del"
	    dlines=`expr $dlines + 1`
	fi
    done
    vecho "joining files $b2a..."
    sort -f -m $b2a | tail -n +$blines | uniq -i -w 20 \
	> $BIB2ACCNO.tmp || error "cannot join files $b2a: $?"
    mybackup $BIB2ACCNO || error "backing up $BIB2ACCNO: $?"
    mybackup $ALTBIB    || error "backing up $ALTBIB: $?"
    mybackup $DELBIB    || error "backing up $DELBIB: $?"
    mybackup $ALLBIB    || error "backing up $ALLBIB: $?"
    mybackup $CANBIB    || error "backing up $CANBIB: $?"
    mybackup $ALL2CAN    || error "backing up $ALL2CAN: $?"
    mv -f $BIB2ACCNO.tmp $BIB2ACCNO || \
	error "cannot move $BIB2ACCNO.tmp to $BIB2ACCNO: $?"
    count=`wc -l < $BIB2ACCNO`
    echo $count > $BIB2ACCNO.COUNT || \
	error "cannot create file $BIB2ACCNO.COUNT"
    vecho "$BIB2ACCNO file has $count entries"
    nlines=`echo $bla | awk '{print NF}'`
    vecho "joining files $bla..."
    sort -f $bla | cut -f 1-3 | tail -n +$alines | uniq -i -w 20 \
	> $ALTBIB.tmp || error "cannot join files $bla: $?"
    join -i -v1 -t"	" $ALTBIB.tmp $BIB2ACCNO > $ALTBIB || \
	error "cannot create file $ALTBIB: $?"
    count=`wc -l < $ALTBIB`
    echo $count > $ALTBIB.COUNT || \
	error "cannot create file $ALTBIB.COUNT"
    vecho "$ALTBIB file has $count entries"
    cp -p "$ALTBIB" "$linksdir/" || \
	error "copying file $ALTBIB to $linksdir"
    addcount.sh "$linksdir/"`basename $ALTBIB` || \
	error "adding count to $linksdir/"`basename $ALTBIB`
    # now see if there are any alternate bibcodes that also appear
    # in bib2accno list (comparisons are done in a case-insensitive way)
    join -i -v1 -t"	" $ALTBIB.tmp $ALTBIB | \
	perl -lane 'print if (uc($F[0]) ne uc($F[1]))' > $ALTBIB.dups || \
	error "cannot create file $ALTBIB.dups: $?"    
    # remove dups file if empty
    if [ -s "$ALTBIB.dups" ] ; then
        warn `wc -l < $ALTBIB.dups` "duplicate bibcodes saved in file " \
	    "$ALTBIB.dups.  Please check them!"
    else
	/bin/rm -f "$ALTBIB.dups" 
    fi
    /bin/rm -f $ALTBIB.tmp
    # now create global bibcode file
    vecho "creating file $ALLBIB..."
    cut -f1 $BIB2ACCNO | sed -e 'p' | paste - - | \
	sort -fuo "$ALLBIB.tmp" - $ALTBIB \
	    || error "creating $ALLBIB"
    [ -f "$ALLBIB.COUNT" ] && oldcount=`cat $ALLBIB.COUNT`
    mv -f "$ALLBIB.tmp" $ALLBIB || \
	error "moving $ALLBIB.tmp to $ALLBIB"
    count=`wc -l < $ALLBIB`
    echo $count > $ALLBIB.COUNT || \
	error "cannot create file $ALLBIB.COUNT"
    vecho "$ALLBIB file has $count entries (was $oldcount)"
    # now update inverted bibcode list
    perl -lane 'print $F[1], "\t", $F[0]' < $ALLBIB > "$ALLBIB.inv.tmp" || \
	error "creating $ALLBIB.inv.tmp from $ALLBIB"
    sort -fuo "$ALLBIB.inv.tmp" "$ALLBIB.inv.tmp" || \
	error "sorting $ALLBIB.inv.tmp"
    mv -f "$ALLBIB.inv.tmp" "$ALLBIB.inv" || \
	error "moving $ALLBIB.inv.tmp to $ALLBIB.inv"
    if [ "x$bld" != "x" ] ; then
	sort -f -m $bld | tail -n +$dlines | sort -fu | \
	    join -i -v1 -t"	" - $ALTBIB > $DELBIB.tmp || \
	    error "creating file $DELBIB.tmp"
	mv -f "$DELBIB.tmp" "$DELBIB" || \
	    error "moving file $DELBIB.tmp to $DELBIB"
	sort -f -m $bld | tail -n +$dlines | sort -fu | \
	    join -i -t"	" - $ALTBIB > $DELBIB.dups || \
	    error "creating file $DELBIB.dups"
	if [ -s "$DELBIB.dups" ] ; then
            warn `wc -l < $DELBIB.dups` "bibcodes marked as deleted but still in bib2accno have been saved in file " \
		"$DELBIB.dups.  Please check them!"
	else
	    /bin/rm -f "$DELBIB.dups" 
	fi
	perl -lane 'next unless (length($F[0]) == 19 and length($F[1]) == 19);
                    print $F[1], "\t", $F[0]' < "$DELBIB" > "$DELBIB.inv.tmp" || \
    	    error "creating file $DELBIB.inv.tmp"
	sort -fuo "$DELBIB.inv.tmp" "$DELBIB.inv.tmp" || \
	    error "sorting $DELBIB.inv.tmp"
	mv -f "$DELBIB.inv.tmp" "$DELBIB.inv" || \
	    error "moving $DELBIB.inv.tmp to $DELBIB.inv"
	addcount.sh "$linksdir/"`basename $DELBIB` || \
	    error "adding count to $linksdir/"`basename $DELBIB`
    fi
    # finally create shortened bibcode mapping file
    vecho "creating file $SHORTBIB"
    perl -lane '$s=$F[0]; $s =~ s/\.+/./g; $s =~ s/\.$//g; print "$s\t$F[1]"' \
	"$ALLBIB" > "$SHORTBIB.tmp" || \
	error "creating file $SHORTBIB.tmp"
    sort -fuo "$SHORTBIB" "$SHORTBIB.tmp" || \
	error "sorting $SHORTBIB.tmp"
    # now created inverse shortbib file
    # XXX we should create different mappings for temporary bibcodes
    # (e.g. use their DOIs)
    vecho "creating file $SHORTBIB.inv"
    perl -lane '$s=$F[0]; $s =~ s/\.+/./g; $s =~ s/\.$//g; print "$F[0]\t$s"' \
	"$BIB2ACCNO" > "$SHORTBIB.inv.tmp" || \
	error "creting file $SHORTBIB.inv.tmp"
    sort -fuo "$SHORTBIB.inv" "$SHORTBIB.inv.tmp" || \
	error "sorting $SHORTBIB.inv.tmp"

    rmlock bibcodes.list $$ || \
	warn "error removing lock for bibcodes.list"
fi

# export config directories, files
export CONFIG
export ARTICLES_DIR
export BIB2ACCNO
export ALTBIB
export ALLBIB
export ARXIV2PUB
export CANBIB
export ALL2CAN
export localbib

# get dependencies for each item
allitems=
newitems=
for i in $items; do
    depend=
    if [ ! -d "$CONFIG/links/$i" ] ; then
	warn "links directory $i does not exist"
	continue
    fi
    if [ -n "$newitems" ] ; then
	newitems="$newitems $i"
    else 
	newitems="$i"
    fi
    [ -f "$CONFIG/links/$i/DEPENDS" ] && \
	depend=`cat $CONFIG/links/$i/DEPENDS`
    if [ "x$depend" != "x" ] ; then
	echo $allitems | grep -q "\<$depend\>" || \
	    allitems="$allitems $depend"
    fi
    if [ "x$i" != "x" ] ; then
	echo $allitems | grep -q "\<$i\>" || \
	    allitems="$allitems $i"
    fi
done

items="$newitems"
[ "x$nodepend" = "x" ] && items="$allitems"
if [ -n "$newitems" ] ; then
    vecho "processing files in directories: $items"
else
    warn "nothing to do"
    exit 0
fi

# now put timestamp for codes in index directories
if [ "x$nocodes" = "x" ] ; then
    for ind in $indexdir ; do
	date '+%Y-%m-%d %H:%M:%S' > "$ind/TIMESTAMP.startcodes"
	date '+%m%d' > "$ind/VERSION_codes"
    done
fi

for links in $items ; do
    datadir="$CONFIG/links/$links"
    index="$linksdir/"$links"_link.index"
    list="$linksdir/"$links"_link.list"
    count="$linksdir/"$links"_link.count"

    if [ -f "$datadir/SKIP" ] ; then 
        vecho "skipping creation of codes files for $links"
	continue
    else
	echo "$p: processing files in directory $datadir at "`date`	
    fi

    cd $datadir

    vecho "creating lock file for $links"
    mklock -s 60 -r 20 $datadir $$ || {
	warn "could not create lock for $datadir $$"
	continue
    }

    # if this file is present, we will keep noncanonical bibcodes in *.links files
    if [ -f "KEEP_NONCANONICAL" ] ; then
	keepnc=/bin/true
    else
	keepnc=/bin/false
    fi

    # see if there is a makefile to be run prior to any processing
    if [ -f "makefile.pre" ] ; then
	vecho "running make on $datadir/makefile.pre"
	make -f makefile.pre
    fi

    # retrieve remote URLs if .uri files are present
    if [ "x$noretrieve" = "x" ] ; then
	for uri in *.uri ; do
	    [ ! -f $uri ] && continue
	    root=`basename $uri .uri`
	    i=0
	    while read url ; do
		i=`expr $i + 1`
		tab="$root.tab.$i"
		vecho "curl $url -> $tab"
		download "$url" "$tab" || \
		    warn "warning: error retrieving URL $url"
	    done < $uri
        done
    else
	vecho "skipping retrieval of URI-based resources"
    fi

    if [ "x$changebibs" = "xYES" ] ; then
	tocheck=
	for t in `/bin/ls -1 *.tab* 2>/dev/null | egrep -v '~$'` ; do
	    # skip symbolic links
	    [ -L $t ] && continue
	    [ -f $t ] && tocheck="$tocheck $t"
	done
	for t in `/bin/ls -1 *.dat 2>/dev/null` ; do
	    # skip symbolic links
	    [ -L $t ] && continue     
	    root=`basename $t .dat`
	    [ -f "$root.flt" ] && continue
	    [ -f "$root.exe" ] && continue
	    tocheck="$tocheck $t"
	done

	if [ -f "$datadir/NOCHANGEBIBS" ] ; then 
	    vecho "skipping changing of bibcodes for $links due to NOCHANGEBIBS flag"
	elif [ "$tocheck" ] ; then
	    vecho "changing bibcodes for files $tocheck"
	    changebibs --mapfile $DELBIB --prefix "OLD/" --suffix ".bck" $tocheck || \
		warn "warning: error running changebibs $tocheck"
	fi
    fi

    # create list of dependencies for .dat files if an .exe or .flt is present
    if [ "x$noexe" = "x" ] ; then
	for exe in *.exe *.flt ; do
	    [ ! -f $exe ] && continue
	    root=`echo $exe | sed -e 's/\..*$//'`
	    ext=`echo $exe | sed -e 's/^.*\.//'`
	    if [ "x$ext" = "xflt" ] ; then
 	        # filter
		args="$BIB2ACCNO"
	    else
	        # regular executable
		args=
		for t in `/bin/ls -1 $root.tab* 2>/dev/null | egrep -v '~$'` ; do
		    [ -f $t ] && args="$args $t"
		done
	    fi
	    dat="$root.dat"
	    dodat=
	    if [ ! -f $dat ] ; then
		dodat="YES"
	    else
		for file in $exe $args ; do
		    /usr/bin/test $file -nt $dat && dodat="YES"
		done
	    fi
	    if [ "x$dodat" = "x" ] ; then
		vecho "file $dat does not need updating"
		continue
	    fi
	    vecho "$exe $args -> $dat"
	    if ./$exe $args > "$dat.tmp.$$" ; then
		if [ -f "$dat" ] ; then
		    oldcount=`wc -l < "$dat" | awk '{print $1}'`
		    vecho "old $dat contained $oldcount entries"
		    newcount=`wc -l < "$dat.tmp.$$" | awk '{print $1}'`
		    vecho "new $dat contains $newcount entries"
		    if [ $newcount -lt $oldcount ] ; then
			warn "warning: new $dat file has $newcount entries, old file had $oldcount"
		    fi
		fi
		mybackup "$dat" || \
		    error "cannot backup $dat: $?"
		/bin/mv -f "$dat.tmp.$$" "$dat" || \
		    error "moving file $dat.tmp.$$ to $dat"
	    else 
		warn "warning: error executing \"$exe $args "'>'" $dat.tmp.$$\": $?"
		warn "warning: skipping updating of $dat file"
		continue
	    fi
	done

    else  # -noexe
       vecho "skipping creation of .dat files from .exe and .flt"
    fi

    if [ ! -s all.links ] ; then
	vecho "removing empty file all.links in $links directory"
	/bin/rm -f all.links
    fi
    joinfiles all.links *.dat *.dat.nocheck || \
	error "joining .dat files for $links: $?"

    joinfiles all.kills *.kill || \
	error "joining .kill files for $links: $?"

    joinfiles all.counts *.count || \
	error "joining .count files for $links: $?"

    if [ -s all.kills ] ; then
	# remove entries in kill files from all.links
	join -t "	" -v 1 -i all.links all.kills > all.links.tmp || \
	    error "cannot remove all.kills from all.links: $?"
	mv all.links.tmp all.links || \
	    error "cannot move all.links.tmp to all.links: $?"
    fi

    # translate bibcodes in all.counts into their canonical form
    if [ -s all.counts ] ; then
	canonicalbib all.counts $ALLBIB $keepnc > all.counts.tmp || \
	    error "cannot translate all.counts bibcodes into their canonical form"
	mv all.counts.tmp all.counts || \
	    error "cannot move all.counts.tmp to all.counts: $?"
    fi

    # if this is a group, add published and deleted bibcodes
    if [ "bibgroup_" = `expr substr "$links" 1 9` ] ; then
	cleanupgroup all.links "$ARXIV2PUB" "$DELBIB" > all.links.tmp || \
	    error "cleaning up bibcodes in group $links: $?"
	mv all.links.tmp all.links || \
	    error "cannot move all.links.tmp to all.links: $?"
    fi

    # translate bibcodes into their canonical form
    for l in *.links ; do
	[ -s $l ] || continue
	canonicalbib $l $ALLBIB $keepnc > $l.tmp || \
	    error "cannot translate bibcodes in $l into their canonical form"
	mv $l.tmp $l || \
	    error "cannot move $l.tmp to $l: $?"
    done

    # see if there is a makefile and if so, run it
    if [ -f "makefile.post" ] ; then
	vecho "running make on $datadir/makefile.post"
	make -f makefile.post
    fi

    if [ "x$localbib" = "x" -a "x$dorejects" = "xYES" ] ; then
   	# now create list of rejected bibcodes
	warnrej=
	for dat in *.dat ; do
            [ ! -f $dat ] && break
	    rej="$dat.rej"
	    /usr/bin/test -f $rej -a $rej -nt $ALLBIB -a $rej -nt $dat && continue
	    join -t"	" -i -v 1 $dat $ALLBIB > $rej || \
                error "cannot create $rej file: $?"
	    # remove reject file if empty
	    if [ -s $rej ] ; then
		[ "x$warnrej" = "x" ] && \
		    warn "reject bibcodes found in directory $links:"
		warnrej="YES"
		wc -l $rej
	    fi
	done
    else
	 vecho "$p: skipping reject codes creation"
    fi

    if [ -f "$datadir/NOCODES" ] ; then 
        vecho "skipping creation of codes files for $links"
	rmlock $datadir $$ || \
	    warn "error removing lock for $datadir $$"
	continue
    fi

    # create list and index files if necessary
    if [ "x$noindex" = "x" -a -f "$index" -a -s all.links ] ; then
        if /usr/bin/test all.links -nt $index ; then
	    vecho "updating index file $index and list file $list"
	    opts=
	    if [ -f "$datadir/BINARY" ] ; then
		vecho "creating $links list file in binary mode"
		opts="--binary"
	    fi
	    mkpart.pl ./all.links | 
		mkbinindex.pl $opts --index $index.tmp --list $list.tmp \
		    --count ./COUNT - || \
			error "cannot create files $index and $list: $?"
	    mv -f $index.tmp $index || error "cannot move $index.tmp to $index"
	    mv -f $list.tmp $list || error "cannot move $list.tmp to $list"
	else 
	    vecho "files $index and $list are up to date"
	fi
    else 
	vecho "updating COUNT in $links"
	wc -l < ./all.links > ./COUNT
    fi

    # create count index if necessary
    if [ "x$noindex" = "x" -a -s "all.counts" ] ; then
        if /usr/bin/test all.counts -nt $count ; then
	    vecho "updating count file $count"
	    sort -f all.counts | \
		/usr/bin/perl -ane 'print pack("a20NNN",@F)' > $count.tmp || \
		warn "error updating file $count"
	    mv -f $count.tmp $count || error "cannot move $count.tmp to $count"
	fi
    fi

    if [ "x$nocodes" = "x" ] ; then
        # now create codes files for all databases
	for ind in $indexdir ; do
	    codes="$ind/"$links"_codes"
	    b2a="$ind/bib2accno.list"
	    dir=`dirname $ind`
	    dir=`dirname $dir`
	    db=`basename $dir |  tr '[a-z]' '[A-Z]'`
	    
	    if /usr/bin/test $codes -nt $b2a -a $codes -nt all.links ; then
		vecho "file $codes is up to date"
		continue
	    else
		vecho "updating file $codes"
	    fi
	    
	    join -t"	" -i -o 1.1 $ind/bib2accno.list ./all.links | \
		uniq -i > $codes || \
		    error "cannot create $codes file: $?"

	    if [ -s $codes ] ; then
		addcount.sh --lines $codes || \
		    error "addcount.sh $codes returned status of $?"
		newcount=`wc -l $codes | awk '{print $1 - 1}'`
		vecho "new $codes contains $newcount entries"
	    else
		vecho "no entries in $codes, deleting file"
		/bin/rm -f $codes
		newcount=0
	    fi
	    echo $newcount > COUNT.$db || \
		warn "warning: cannot update file $links/COUNT.$db"

	done
    else 
	vecho "skipping codes creation"
    fi

    vecho "removing lock for $links"
    rmlock $datadir $$ || \
	warn "error removing lock for $datadir $$"

done

# now put timestamp for codes in index directories
if [ "x$nocodes" = "x" ] ; then
    for ind in $indexdir ; do
	date '+%Y-%m-%d %H:%M:%S' > "$ind/TIMESTAMP.endcodes"
    done
fi

#if [ "x$reload" != "x" ] ; then
#    for s in $ADS_SEGMENTS ; do
#	echo "$p: reloading shared memory segments ($s)"
#	$HTTPD_BIN/maint/load_sh $s
#    done
#fi


[ "x$mirror" != "x" ] && \
    $HOME/mirror/bin/mirror sites="$ADS_MIRRORS" \
	update="codes html" mkop="codes html"


echo "$p: script ended at" `date`

exit 0
