#!/bin/sh

##############################################################################
##############################################################################
#
#       DO NOT EDIT - file is being maintained by puppet
#
##############################################################################
##############################################################################


# fix for new osg-wn-client-glexec RPM installs, CEs still point at old location
if [ -f /usr/sbin/glexec ]
   then export OSG_GLEXEC_LOCATION="/usr/sbin/glexec"
fi


if [ -n "$MY_INITIAL_DIR" ]
then
    eval cd $MY_INITIAL_DIR
fi

export GLOBUS_LOCATION=/usr

# Glite will sleep for many hours trying to stage in/out without this setting.
export GLITE_LOCAL_COPY_RETRY_COUNT=2
export GLITE_LOCAL_COPY_RETRY_FIRST_WAIT=120

export OSG_APP=/cvmfs/oasis.opensciencegrid.org
export OSG_DATA=UNAVAILABLE

export http_proxy=red-squid1.unl.edu:3128

export OSG_WN_TMP=$_CONDOR_SCRATCH_DIR
export PATH=/bin:/usr/bin:$PATH
exec "$@"
