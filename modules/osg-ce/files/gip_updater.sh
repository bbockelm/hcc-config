#!/bin/sh
alias cp=/bin/cp
source /opt/osg/app/etc/cic-functions.sh
cic_update_pubtag /opt/osg/app/cmssoft/cms 2>&1 | tee /var/log/cic_update_pugtag.log
