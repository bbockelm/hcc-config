#!/bin/sh

##############################################################################
##############################################################################
#
#       DO NOT EDIT - file is being maintained by puppet
#
##############################################################################
##############################################################################


if [ -n "$MY_INITIAL_DIR" ]
then
    eval cd $MY_INITIAL_DIR
fi

export OSG_WN_TMP=$_CONDOR_SCRATCH_DIR

exec "$@"