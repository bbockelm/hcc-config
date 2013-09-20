#!/bin/sh
# version=0.5.4
cic_functions_version=0.5.4
cmssw_installation_topdir=@@cmssw_installation_topdir@@

[ -f $cmssw_installation_topdir/cic_site_config ] || { echo ERROR cic-functions configuration issue with cic_site_config. Maybe OK ; } ;

[ -f $cmssw_installation_topdir/cic_site_config ] && source $cmssw_installation_topdir/cic_site_config

pubtag_files=$(dirname $cmssw_installation_topdir)/etc/grid3-locations.txt
requirement_file=$cmssw_installation_topdir/cic/cmssoft_retire_requirement_arch

#cmssw_installation_topdir=/tmp # /state/partition1/coldhead/services/csdogrid

#cmssoft_install_cmssw_get_tags () { # func description: to get a CMSSW release list

# wget without stdout
# wget --no-check-certificate -q -O- https://cmsweb.cern.ch/sitedb/json/index/CMSNametoSE?name | sed 's#},#},\n#g' | sed 's#}}#}}\n#g'


cic_get_tags () { # func description: to get a CMSSW release list
   relcat=production
   deprel=
   [ $# -gt 0 ] && { deprel="?anytype=1&deprel=$1" ; relcat=deprecate ; } ;
   [ "x$1" == "xall" ] && { deprel="?anytype=1" ; relcat=all ; } ;
   xmltag="${cic_xmltag}$deprel"
   #echo INFO doing xmltag $xmltag
   # wget or curl 
   #executable="${cic_wget_location} --no-check-certificate -q -O"
   #$executable $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt $xmltag 2>/dev/null
   #[ $? -eq 0 ] || { executable="${cic_curl_location} -k -o" ; $executable $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt $xmltag 2>/dev/null ; } ;
   echo DEBUG cic_timed_download $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt $xmltag
   random_out=$cmssw_installation_topdir/cmssoft_${relcat}_tag.txt.$(date +%s)
   #cic_timed_download $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt $xmltag 2>&1 #>/dev/null
   cic_timed_download $random_out $xmltag 2>&1 #>/dev/null
   status=$?
   cp $random_out $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt
   rm -f $random_out
   [ $status -eq 0 ] || return 1
   archs=$(grep "<architecture " $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt | cut -d\" -f2)
   [ "x$(echo archs)" == "x" ] && return 2
   nline=$(cat $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt | wc -l)
   [ $nline -lt 4 ] && return 3
   allrel=
   for arch in $archs ; do
       releases=$(grep -A $nline "<architecture " $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt | grep -A $nline "$arch" | grep -m 1 -B $nline "</architecture>" | grep "<project label=" | cut -d\" -f2)
       allrel="$allrel $releases"
       for rel in $releases ; do
           echo $rel $arch
       done
   done
   [ "x$(echo $allrel)" == "x" ] && return 4
   return 0
}

cic_get_project_retire_next () { # func description: to get a next removable project
   # inputs
   relcat=deprecate
   tagfile=$cmssw_installation_topdir/cmssoft_${relcat}_tag.txt
   tag_time=$cmssw_installation_topdir/cic/cmssoft_deprecate_tag.time.txt
   #requirement_file=$cmssw_installation_topdir/cic/cmssoft_retire_requirement_arch
   cmssoft_minimumvers=CMSSW_2_9_90
   n_1=$(echo $cmssoft_minimumvers | cut -d_ -f2) ; n_1=$(expr $n_1 \* 1000000)
   n_2=$(echo $cmssoft_minimumvers | cut -d_ -f3) ; n_2=$(expr $n_2 \* 1000)
   n_3=$(echo $cmssoft_minimumvers | cut -d_ -f4) ; n_3=$(expr $n_3 \* 1)
   minimum_cmsswproject=$(expr $n_1 + $n_2 + $n_3)

   grace_period=432000 # 5 days $cmssoft_grace_period
   [ -f $tagfile ] || touch $tagfile
   [ -f $tag_time ] || touch $tag_time
   echo DEBUG "+1+"cic_get_project_retire_next"+" getting $tagfile
   cic_get_tags 1
   echo DEBUG "+2+"cic_get_project_retire_next"+" 
   ls -al $tagfile
   CMSSW_CATALOG_TMP=$(cat $tagfile | grep "<project label=" | grep CMSSW_ | cut -d\" -f2 | sort -u 2>/dev/null)
   if [ "x$CMSSW_CATALOG_TMP" == "x" ] ; then
      CMSSW_PROJECT_NEXT=
      CMSSW_ARCH_NEXT=
      export CMSSW_PROJECT_NEXT
      export CMSSW_ARCH_NEXT
      return 1
   fi
   hostname=$gatekeeper_hostname
   # 0 start from min
   CMSSW_CATALOG=
   for cmsswrelease in $CMSSW_CATALOG_TMP ; do
    n_1=$(echo $cmsswrelease | cut -d_ -f2)
    n_2=$(echo $cmsswrelease | cut -d_ -f3)
    n_3=$(echo $cmsswrelease | cut -d_ -f4)
    is_int $n_1 ; [ $? -eq 0 ] || { echo Warning CONT $cmsswrelease n_1 $n_1 not integer ; continue ; } ;
    is_int $n_2 ; [ $? -eq 0 ] || { echo Warning CONT $cmsswrelease n_2 $n_2 not integer ; continue ; } ;
    is_int $n_3 ; [ $? -eq 0 ] || { echo Warning CONT $cmsswrelease n_3 $n_3 not integer ; continue ; } ;
    n_1=$(expr $n_1 \* 1000000)
    n_2=$(expr $n_2 \* 1000)
    n_3=$(expr $n_3 \* 1)
    numbered_cmsswproject=$(expr $n_1 + $n_2 + $n_3)
    [ $numbered_cmsswproject -lt $minimum_cmsswproject ] && continue
    CMSSW_CATALOG="$CMSSW_CATALOG $cmsswrelease"
   done
   CMSSW_CATALOG_TMP=$CMSSW_CATALOG
   echo DEBUG "+3.0+"cic_get_project_retire_next"+" cmssw list after the min. cmssw version $cmssoft_minimumvers
   for cmssw in $CMSSW_CATALOG ; do
       echo DEBUG "+3.0+"cic_get_project_retire_next"+"$cmssw
   done

   # 1 get rid of it if in cicdb=$cmssw_installation_topdir/cic_db.txt
   CMSSW_CATALOG=
   for cmssw in $CMSSW_CATALOG_TMP ; do
      # skip if it is not installed
      grep -q "$cmssw " $cicdb
      [ $? -eq 0 ] || continue
      # skip if it is already INSTALLED_RETIRED
      grep "$cmssw " $cicdb | grep -q "INSTALLED_RETIRED"
      [ $? -eq 0 ] && continue
      CMSSW_CATALOG="$CMSSW_CATALOG $cmssw"
   done
   echo DEBUG "+3+"cic_get_project_retire_next"+" cmssw list after cic_db.txt skim
   for cmssw in $CMSSW_CATALOG ; do
       echo DEBUG "+3+"cic_get_project_retire_next"+"$cmssw
   done
   # 2 get rid of it if it did not meet the grace time
   CMSSW_CATALOG_TMP=$CMSSW_CATALOG
   CMSSW_CATALOG=
   currenttime=$(date +%s)
   currentdate=$(date)
   for cmssw in $CMSSW_CATALOG_TMP ; do
      thearchs=$(cic_get_arch_from_tag $tagfile $cmssw)
      deprecationtime=$currenttime
      for arch in $thearchs ; do
         grep -q "$cmssw $arch " "$tag_time"
         [ $? -ne 0 ] && echo "$cmssw $arch" "$currentdate" "$currenttime" >> $tag_time
         deprecationtime=$(grep "$cmssw $arch " $tag_time | awk '{print $NF}')
         is_int $deprecationtime
         if [ $? -ne 0 ] ; then
            echo DEBUG deprecationtime=$deprecationtime is not an integer
            return 1
         fi
      done
      gracetime=$(expr $currenttime - $deprecationtime)
      if [ $gracetime -lt $grace_period ] ; then
         echo DEBUG "+4.0+" $gracetime " [ = $currenttime - $deprecationtime ] " -lt $grace_period
         continue
      fi
      CMSSW_CATALOG="$CMSSW_CATALOG $cmssw"
   done
   echo DEBUG "+4+"cic_get_project_retire_next"+" cmssw list after grace period skim based on $tag_time
   for cmssw in $CMSSW_CATALOG ; do
       echo DEBUG "+4+"cic_get_project_retire_next"+"$cmssw
   done

#   # 3 get rid of it if it is in the 'do not remove' list
#   CMSSW_CATALOG_TMP=$CMSSW_CATALOG
#   CMSSW_CATALOG=
#   for cmssw_keep in $cmssw_keeps ; do
#      for cmssw in $CMSSW_CATALOG_TMP ; do
#          [ "xCMSSW_${cmssw_keep}" == "x$cmssw" ] && continue
#          CMSSW_CATALOG="$CMSSW_CATALOG $cmssw"
#      done
#   done

   # 3 get rid of it if it is in the 'do not remove' list
   cmssw_keeps=$(grep "######## cmssw_keep_$gatekeeper_hostname" $requirement_file | cut -d\" -f2)
   echo DEBUG "================ cmssw_keeps " 
   for cmssw_keep in $cmssw_keeps ; do
       echo cmssw_keep $cmssw_keep CMSSW_${cmssw_keep}
   done

   #grep "######## cmssw_keep_$gatekeeper_hostname" $requirement_file

   if [ "x$cmssw_keeps" == "x" ] ; then
      echo INFO no deprecated release needs to be kept
      #CMSSW_CATALOG=$CMSSW_CATALOG_TMP
   else
      CMSSW_CATALOG_TMP=$(for cmssw in $CMSSW_CATALOG ; do echo $cmssw ; done | sort -u)
      CMSSW_CATALOG=
      #for cmssw_keep in $cmssw_keeps ; do
      #   echo DEBUG "+5.0+" cmssw_keep CMSSW_${cmssw_keep}
      for cmssw in $CMSSW_CATALOG_TMP ; do
        ifound=0
        for cmssw_keep in $cmssw_keeps ; do
            if [ "xCMSSW_${cmssw_keep}" == "x$cmssw" ] ; then
               echo DEBUG "+5.1+" CMSSW_${cmssw_keep} == $cmssw will not remove it
               ifound=1
               break # continue
            else
               echo DEBUG "+5.2+" CMSSW_${cmssw_keep} not eq $cmssw will remove it
            fi
            #CMSSW_CATALOG="$CMSSW_CATALOG $cmssw"
         done
         [ $ifound -eq 0 ] && CMSSW_CATALOG="$CMSSW_CATALOG $cmssw"
      done
   fi
   CMSSW_CATALOG_TMP=$(for cmssw in $CMSSW_CATALOG ; do echo $cmssw ; done | sort -u)
   CMSSW_CATALOG=$CMSSW_CATALOG_TMP
   echo DEBUG "+5+"cic_get_project_retire_next"+" cmssw list after 'do not remove list' skim
   for cmssw in $CMSSW_CATALOG ; do
       echo DEBUG "+5+"cic_get_project_retire_next"+"$cmssw
   done
   CMSSW_PROJECT_NEXT=$(for cmssw in $CMSSW_CATALOG_TMP ; do echo $cmssw ; done | sort -u | head -1)
   if [ "x$CMSSW_PROJECT_NEXT" != "x" ] ; then
      cmssoft_find_arch $CMSSW_PROJECT_NEXT
      CMSSW_ARCH_NEXT=$(cmssoft_find_arch $CMSSW_PROJECT_NEXT | grep slc | head -1)      
   fi
   
   echo INFO $hostname CMSSW_PROJECT_NEXT=$CMSSW_PROJECT_NEXT
   echo INFO $hostname CMSSW_ARCH_NEXT=$CMSSW_ARCH_NEXT
   export CMSSW_PROJECT_NEXT
   export CMSSW_ARCH_NEXT
   return 0

}

cic_get_arch_from_tag () { # func description: to get an arch for a release from the downloaded tag file
   tagfile=$1
   cmssw_release=$2
   [ "x$tagfile" == "x" ] && return 1
   [ -f "$tagfile" ] || return 1
   fline=$(cat $tagfile | wc -l)
   archs=$(grep "<architecture" $tagfile | grep slc | cut -d\" -f2 | sort -u)
   thearchs=
   for arch in $archs ; do
      #arch_releases=$(grep -A $fline "<architecture" $tagfile | grep -A $fline $arch | grep -B $fline -m 1 "</architecture>" | sed "s#<project#${arch}#g" | sed "s# #+#g")
      grep -A $fline "<architecture" $tagfile | grep -A $fline $arch | grep -B $fline -m 1 "</architecture>" | grep -q "\"${cmssw_release}\""
      [ $? -eq 0 ] &&  thearchs="$thearchs $arch"
   done
   #echo DEBUG $cmssw_release archs = $thearchs
   echo $thearchs
   return 0
   
}

cic_get_project_next () { # func description: to get a next installable project
   # inputs
   relcat=deprecate
   # retire requirement file
   #requirement_file=$cmssw_installation_topdir/cic/cmssoft_retire_requirement_arch
   #[ -s $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt ] || cic_get_tags 1
   echo DEBUG "+1+"cic_get_project_next"+" getting $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt
   cic_get_tags 1
   [ $? -eq 0 ] || return 1
   relcat=production
   echo DEBUG "+2+"cic_get_project_next"+" getting $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt
   #[ -s $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt ] || cic_get_tags
   cic_get_tags
   [ $? -eq 0 ] || return 1
   #CMSSW_CATALOG=$(cat $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt | awk '{print $1}' | sort -u 2>/dev/null)
   CMSSW_CATALOG=$(cat $cmssw_installation_topdir/cmssoft_${relcat}_tag.txt | grep "<project label=" | cut -d\" -f2 | sort -u 2>/dev/null)
   hostname=$gatekeeper_hostname
   
   #executable="${cic_wget_location} --no-check-certificate -q -O"
   #$executable $cmssw_installation_topdir/cic_site_config_global "$gc" 2>/dev/null
   #[ $? -eq 0 ] || { executable="${cic_curl_location} -k -o" ; $executable $cmssw_installation_topdir/cic_site_config_global "$gc" 2>/dev/null ; } ;
   #cic_timed_download $cmssw_installation_topdir/cic_site_config_global "$gc" 2>/dev/null
   #cic.tar.gz $cic_tarball
   # cic_get_global_control called inside cic.sh should have downloaded cic_site_config_global
   echo DEBUG "+3+"cic_get_project_next checking $cmssw_installation_topdir/cic_site_config_global

   # manual push
   if [ -s $cmssw_installation_topdir/cic_site_config_global ] ; then
      echo DEBUG "+3.0+"cic_get_project_next sourcing $cmssw_installation_topdir/cic_site_config_global
      source $cmssw_installation_topdir/cic_site_config_global
      [ "x$cic_cmssw_other_releases" == "x" ] || { echo echo DEBUG cic_get_project_next getting all tags ; cic_get_tags all ; } ;
      echo DEBUG "+3.1+"cic_get_project_next cic_cmssw_other_releases=$cic_cmssw_other_releases
      for v in $cic_cmssw_other_releases ; do
          echo "${v}" | grep -q "+$gatekeeper_hostname\|+ALL"
          if [ $? -eq 0 ] ; then
             echo INFO got $v for this host $gatekeeper_hostname
             #this_other_release="$(echo $v | cut -d+ -f1)/$(echo $v | cut -d+ -f2)"
             this_other_release=$(echo $v | cut -d+ -f1)
             [ -s $cmssw_installation_topdir/cmssoft_all_tag.txt ] || echo DEBUG cic_get_project_next nothing in the $cmssw_installation_topdir/cmssoft_all_tag.txt
             grep -q "$this_other_release" $cmssw_installation_topdir/cmssoft_all_tag.txt
             if [ $? -eq 0 ] ; then
                echo INFO got "$this_other_release" in $cmssw_installation_topdir/cmssoft_all_tag.txt
                echo INFO adding "$this_other_release" to the NEXT CMSSW Catalog
                CMSSW_CATALOG="$CMSSW_CATALOG $this_other_release/$(echo $v | cut -d+ -f2)"
             else
                echo INFO we did not find "$this_other_release" in $cmssw_installation_topdir/cmssoft_all_tag.txt
             fi
          else
             echo INFO $v not found for this host $gatekeeper_hostname
          fi
      done
   else # if [ -s $cmssw_installation_topdir/cic_site_config_global ] ; then
      echo DEBUG "+3.2+"cic_get_project_next empty/does_not_exist: $cmssw_installation_topdir/cic_site_config_global
   fi

   # 02FEB2012
   # email request per twiki https://twiki.cern.ch/twiki/bin/view/CMS/CMSSoftDeployOSG
   cic_request_db="http://oo.ihepa.ufl.edu:8080/cmssoft/aptinstall/cmssoft_check_cmssw_install_request.db.txt"
   cic_request_exclude_db="http://oo.ihepa.ufl.edu:8080/cmssoft/aptinstall/cmssoft_check_cmssw_install_request.bad.db.txt"
   cic_timed_download $cmssw_installation_topdir/$(basename $cic_request_db) "$cic_request_db" 2>/dev/null
   if [ $? -eq 0 ] ; then
      echo DEBUG "+3.3+" got $cmssw_installation_topdir/$(basename $cic_request_db)   
      cic_timed_download $cmssw_installation_topdir/$(basename $cic_request_exclude_db) "$cic_request_exclude_db" 2>/dev/null
      if [ $? -eq 0 ] ; then
         echo DEBUG "+3.4+" got $cmssw_installation_topdir/$(basename $cic_request_exclude_db)
      else
         echo DEBUG "+3.5+" fail to get $cmssw_installation_topdir/$(basename $cic_request_exclude_db)
      fi
   else
      echo DEBUG "+3.6+" fail to get $cmssw_installation_topdir/$(basename $cic_request_db)
   fi
   echo DEBUG "+3.7+" checking request db files
   ls -al $cmssw_installation_topdir/$(basename $cic_request_db)
   ls -al $cmssw_installation_topdir/$(basename $cic_request_exclude_db)
   # only if the db files have non-zero content, condier the processing
   if [ -s $cmssw_installation_topdir/$(basename $cic_request_db) ] ; then
      if [ -s $cmssw_installation_topdir/$(basename $cic_request_exclude_db) ] ; then
         echo DEBUG "+3.8+" checking if there is more to addd to the CMSSW_CATALOG
         cmssw_catalog_email_exclude=$(echo $(grep " CMSSW" $cmssw_installation_topdir/$(basename $cic_request_exclude_db) | sort -u | awk '{print $(NF-2)"/"$(NF-1)}'))
         cmssw_catalog_email_exclude=$(echo $cmssw_catalog_email_exclude | sed "s# #\\\|#g")
         echo DEBUG exclude list
         for f in $cmssw_catalog_email_exclude ; do echo $f ; done
         cmssw_catalog_email=$(echo $(grep " CMSSW" $cmssw_installation_topdir/$(basename $cic_request_db) | sort -u | awk '{print $(NF-2)"/"$(NF-1)}' | sort -u | grep -v "$cmssw_catalog_email_exclude"))
         echo DEBUG new requests
         for f in $cmssw_catalog_email ; do echo $f ; done
         CMSSW_EMAIL_CATALOG=
         for cmssw_arch_host in $cmssw_catalog_email ; do
             echo "$cmssw_arch_host" | grep -q "$gatekeeper_hostname"
             [ $? -eq 0 ] || continue
             cmssw_email=$(echo $cmssw_arch_host | cut -d/ -f1)
             arch_email=$(echo $cmssw_arch_host | cut -d/ -f2)
             echo DEBUG "+3.88+" adding ${cmssw_email}/${arch_email} to CMSSW_EMAIL_CATALOG
             CMSSW_EMAIL_CATALOG="$CMSSW_EMAIL_CATALOG ${cmssw_email}/${arch_email}"
         done
         echo DEBUG new requests=$CMSSW_EMAIL_CATALOG
      fi
   fi
   # set it empty until there is no bug. 23AUG2012 it looks good and experimenting it with purdue 6_0_0_pre8 request
   # CMSSW_EMAIL_CATALOG=
   # email request 
   # 02FEB2012
   echo DEBUG "4.0+" adding cic_get_not_installed list:
   cic_get_not_installed
   CMSSW_CATALOG="$CMSSW_CATALOG $(cic_get_not_installed)"
   CMSSW_CATALOG=$(for cmssw in $CMSSW_CATALOG ; do echo $cmssw ; done | sort -u)
   echo DEBUG "+4+"cic_get_project_next
   echo 
   echo INFO cicdb $cicdb
   echo INFO relcat $relcat
   echo INFO hostname $hostname
   echo INFO minimumvers $minimumvers
   echo 
   # output
   CMSSW_PROJECT_NEXT=
   # input/output
   if [ -d $cmssw_installation_topdir ] ; then
      if [ ! -s $cicdb ] ; then
         echo DEBUG checking mysql 1
         printf "quit\n" | mysql 2>/dev/null 1>/dev/null
         status=$?
         [ $status -eq 0 ] || { echo DEBUG checking mysql 2 ; printf "quit\n" | /usr/bin/mysql 2>/dev/null 1>/dev/null ; status=$? ; } ;
         #return 1
         if [ $status -eq 0 ] ; then
            echo Warning cic_populate_cicdb $gatekeeper_hostname
            cic_populate_cicdb $gatekeeper_hostname > $cicdb
            sed -i "s#@@hostname@@#$gatekeeper_hostname#g" > $cicdb
            status=$?
         else
            #echo Warning fetching 
            #wget -q -O $cicdb http://oo.ihepa.ufl.edu:8080/cmssoft/cic/$(basename $cicdb).$gatekeeper_hostname
            #status=$?
         #fi
         #if [ $status -eq 0 ] ; then
            cp $cmssw_installation_topdir/cic/$(basename $cicdb).$gatekeeper_hostname $cicdb
            status=$?
            [ -s $cicdb ] || { echo "$gatekeeper_hostname | CMSSW_0_0_0 | slc0_amd0_gcc0 | NOTINSTALLED" > $cicdb ; status=$? ; } ;
         fi
         [ $status -eq 0 ] || { echo ERROR status is not zero ; return $status ; } ;

      fi
   else
      return 1
   fi
   echo DEBUG "+5+"cic_get_project_next
   i=0 ; nproject=$(echo $CMSSW_CATALOG |  wc -w)
   #02FEB2012 email request for cmsswproject in $CMSSW_CATALOG ; do
   for cmssw_arch in $CMSSW_CATALOG $CMSSW_EMAIL_CATALOG ; do
    cmsswproject=$(echo $cmssw_arch | cut -d/ -f1)
    cmssw_email_arch=$(echo $(echo $cmssw_arch | grep / | cut -d/ -f2 | grep -v default))
    echo DEBUG "+6+" cmssw_arch=$cmssw_arch cmsswproject$cmsswproject cmssw_email_arch=$cmssw_email_arch
    #02FEB2012 email request for cmsswproject in $CMSSW_CATALOG ; do
    echo $cmsswproject | grep -q "^CMSSW"
    [ $? -eq 0 ] || { echo INFO $cmsswproject does not start with CMSSW ; continue ; } ;


    #echo DEBUG $hostname $cmsswproject starts with CMSSW

    n_1=`echo $cmsswproject | cut -d_ -f2` ; n_1=`expr $n_1 \* 1000000`
    n_2=`echo $cmsswproject | cut -d_ -f3` ; n_2=`expr $n_2 \* 1000`
    n_3=`echo $cmsswproject | cut -d_ -f4` ; n_3=`expr $n_3 \* 1`
    numbered_cmsswproject=`expr $n_1 + $n_2 + $n_3`

    n_1=`echo $minimumvers | cut -d_ -f2` ; n_1=`expr $n_1 \* 1000000`
    n_2=`echo $minimumvers | cut -d_ -f3` ; n_2=`expr $n_2 \* 1000`
    n_3=`echo $minimumvers | cut -d_ -f4` ; n_3=`expr $n_3 \* 1`
    minimum_cmsswproject=`expr $n_1 + $n_2 + $n_3`
    i=$(expr $i + 1)
    echo INFO "[ $i ( $cmsswproject ) / $nproject ] " $hostname at $(date) minimum version $minimum_cmsswproject
    #echo INFO $hostname cmsswproject $cmsswproject $numbered_cmsswproject

    # Limit minimum project number only if it is not a special project
    #if [ $ihost -ne 1 ] ; then
    ispecialproject=0
    for theproje in $cmssoft_special_projects ; do
        #if [ $ihost -eq 1 ] ; then 
        echo $theproje | grep -q "^${cmsswproject}$"
        [ $? -eq 0 ] && { ispecialproject=1 ; break ; } ;
        #fi
    done
    if [ $ispecialproject -ne 1 ] ; then
       # This is not constrained by minimum cmsswproject $minimum_cmsswproject
       #echo DEBUG host: $hostname this porject $cmsswproject is a special project
       #echo DEBUG host: $hostname This is not constrained by minimum cmsswproject $minimum_cmsswproject
    #else
       #echo DEBUG host: $hostname this porject $cmsswproject is not a special project
       if [ $numbered_cmsswproject -lt $minimum_cmsswproject ] ; then
          echo INFO "[ $i / $nproject ] " $hostname numbered_cmsswproject $numbered_cmsswproject vs minimum_cmsswproject $minimum_cmsswproject
          continue
       fi
    fi

    echo DEBUG checking cmssoft_find_arch $cmsswproject
    #cmssoft_find_arch $cmsswproject
    thearchitecture=$(cmssoft_find_arch $cmsswproject | grep slc | head -1)
    [ "x$(echo $thearchitecture)" == "x" ] && thearchitecture=$(cmssoft_find_arch $cmsswproject | grep slc | head -1)
    echo DEBUG found arch for $cmsswproject = $thearchitecture
    # 02FEB2012
    echo "$cmssw_email_arch" | grep -q slc
    if [ $? -eq 0 ] ; then
       echo DEBUG "+7+" looks like an email request changing arch from $$thearchitecture to $cmssw_email_arch
       thearchitecture=$cmssw_email_arch
    fi
    # 02FEB2012
    #echo INFO checking the release with $cmssw_installation_topdir/cmssoft_deprecate_tag.txt
    #cat $cmssw_installation_topdir/cmssoft_deprecate_tag.txt | sort -u | awk '{print $1"/"$2}' 2>/dev/null | grep -q ${cmsswproject}/${thearchitecture}
    grep -q \"${cmsswproject}\" $cmssw_installation_topdir/cmssoft_deprecate_tag.txt
    if [ $? -eq 0 ] ; then
       #echo "$gatekeeper_hostname" | grep -q ce02.cmsaf.mit.edu
       #if [ $? -eq 0 ] ; then
       #   echo "${cmsswproject}" | grep -q CMSSW_3_9_9
       #   if [ $? -eq 0 ] ; then
       #      echo DEBUG $gatekeeper_hostname and ${cmsswproject} not skipping because it is in the keep list
       #   else
       #      echo DEBUG "+8+" skip because ${cmsswproject} ${thearchitecture}  is already deprecated according to $cmssw_installation_topdir/cmssoft_deprecate_tag.txt
       #      continue
       #   fi
       #else
       #   echo DEBUG "+8+" skip because ${cmsswproject} ${thearchitecture}  is already deprecated according to $cmssw_installation_topdir/cmssoft_deprecate_tag.txt
       #   continue
       #fi
       echo DEBUG "+8+" skip because ${cmsswproject} ${thearchitecture}  is already deprecated according to $cmssw_installation_topdir/cmssoft_deprecate_tag.txt
       continue
    fi

    # cicdb table fields
    # no | hostname | cmssw | arch | status | ymdt | ymdt_installed | ymdt_removed | status_reason
    #    
    #echo DEBUG "grep -q $hostname | $cmsswproject | $thearchitecture | INSTALLED \| $hostname | $cmsswproject | $thearchitecture | VERIFIED \| $hostname | $cmsswproject | $thearchitecture | INSTALLED_RETIRED " $cicdb
    grep -q " $hostname | $cmsswproject | $thearchitecture | INSTALLED$\| $hostname | $cmsswproject | $thearchitecture | VERIFIED$\| $hostname | $cmsswproject | $thearchitecture | INSTALLED_RETIRED$"    $cicdb
    if [ $? -eq 0 ] ; then
       echo DEBUG "+9+" skip because ${cmsswproject} ${thearchitecture}  is in the db $cicdb
       continue
    fi
    CMSSW_PROJECT_NEXT=$cmsswproject
    echo INFO $hostname Last CMSSW_PROJECT_LAST_VERIFIED Next Project $CMSSW_PROJECT_NEXT
    CMSSW_ARCH_NEXT=${thearchitecture}
    echo INFO $hostname Last CMSSW_PROJECT_LAST_VERIFIED Next Arch $CMSSW_ARCH_NEXT
    break
   done #   for cmsswproject in $CMSSW_CATALOG ; do

   # 29AUG2012 reinstall removed using the keep list in cmssoft_retire_requirement_arch
   if [ "x$CMSSW_PROJECT_NEXT" == "x" ] ; then
      echo DEBUG checking retire requirement file
      cmssw_keeps=$(grep "######## cmssw_keep_$gatekeeper_hostname" $requirement_file | cut -d\" -f2)
      for cmssw_keep in $cmssw_keeps ; do
          thecmssw=CMSSW_$cmssw_keep
          grep "| $thecmssw |" $cmssw_installation_topdir/cic_db.txt | grep -q INSTALLED_RETIRED
          if [ $? -eq 0 ] ; then
             #all=0
             #thestring=$(grep "| $thecmssw |" $cmssw_installation_topdir/cic_db.txt | grep INSTALLED_RETIRED)
             #cic_sed_del_line "$thestring" $cicdb
             CMSSW_PROJECT_NEXT=$thecmssw
             CMSSW_ARCH_NEXT=$(cmssoft_find_arch $thecmssw | grep slc | head -1)
             echo Warning removed release $thecmssw $CMSSW_ARCH_NEXT needs to be reinstalled II
             ls -al $cmssw_installation_topdir/cic_db.txt
             grep "| $thecmssw |" $cmssw_installation_topdir/cic_db.txt

             break
          fi
      done
   fi
   # 29AUG2012 reinstall removed using the keep list in cmssoft_retire_requirement_arch

   if [ "x$CMSSW_PROJECT_NEXT" == "x" ] ; then
      echo INFO $hostname CMSSW_PROJECT_NEXT is empty nothing to install any more
      return 0
   fi
   if [ "x$CMSSW_ARCH_NEXT" == "x" ] ; then
       echo Warning $hostname CMSSW_ARCH_NEXT is empty attempting to fill it again 
       CMSSW_ARCH_NEXT=$(cmssoft_find_arch $CMSSW_PROJECT_NEXT | grep slc | head -1)
       echo INFO $hostname CMSSW_ARCH_NEXT is empty attempting to have filled  it again = $CMSSW_ARCH_NEXT
   fi
   echo DEBUG grep "$CMSSW_PROJECT_NEXT" $cmssw_installation_topdir/cic_db.txt
   grep "$CMSSW_PROJECT_NEXT" $cmssw_installation_topdir/cic_db.txt
   echo INFO $hostname CMSSW_PROJECT_NEXT=$CMSSW_PROJECT_NEXT
   echo INFO $hostname CMSSW_ARCH_NEXT=$CMSSW_ARCH_NEXT
   export CMSSW_PROJECT_NEXT
   export CMSSW_ARCH_NEXT
   return 0
}

cic_populate_cicdb () { # func description: populates $cicdb. Use case is for h in $(cmssoft_hosts.sh) ; do echo $h ; cic_populate_cicdb $h | sed "s#@@hostname@@#$h#g" > cic_db.txt.$h ; done
   hostname=$1
   mysql_host=oo.ihepa.ufl.edu
   mysql_port=3307
   printf "SELECT name,version,status FROM cmssoftprojects WHERE hostname='$hostname' ; \n quit \n" | /usr/bin/mysql -P $mysql_port -h $mysql_host -u nobody csdogrid | grep slc | grep -v version | awk '{print " @@hostname@@ | "$1" | "$2" | "$3}'
   return 0
}

cic_sed_del_line () { # func description: It deletes a line                     
  if [ $# -lt 2 ] ; then
     echo ERROR cic_sed_del_line string file
     return 1
  fi
  string=$1
  infile=$2
  sed -i "/$(echo $string | sed 's^/^\\\/^g')/ d" $infile
}

cic_get_global_control () { #
   echo BEFORE cic_cron $cic_cron
   echo BEFORE cic_destroy_cron $cic_destroy_cron
   cic_cron_global_val=
   cic_destroy_cron_global_val=
   i=0
   for gc in "$cic_global_control_1" "$cic_global_control_1" "$cic_global_control_1" ; do
       thetime=$(date +%s)
       i=$(expr $i + 1)
       echo INFO checking $gc
       #executable="${cic_wget_location} --no-check-certificate -q -O"
       #$executable $cmssw_installation_topdir/cic_site_config_global "$gc" 2>/dev/null
       
       #[ $? -eq 0 ] || { executable="${cic_curl_location} -k -o" ; $executable $cmssw_installation_topdir/cic_site_config_global "$gc" 2>/dev/null ; } ;
       #cic_timed_download $cmssw_installation_topdir/cic_site_config_global "$gc" 2>/dev/null
       
       echo DEBUG executing cic_timed_download $cmssw_installation_topdir/cic_site_config_global.${thetime} "$gc"

       ls -al $cmssw_installation_topdir/cic_site_config_global

       cic_timed_download $cmssw_installation_topdir/cic_site_config_global.${thetime} "$gc" #2>/dev/null

       echo DEBUG cic_site_config_global download status $?

       cp $cmssw_installation_topdir/cic_site_config_global.${thetime} $cmssw_installation_topdir/cic_site_config_global

       rm -f $cmssw_installation_topdir/cic_site_config_global.${thetime}

       ls -al $cmssw_installation_topdir/cic_site_config_global

       [ -s $cmssw_installation_topdir/cic_site_config_global ] || continue
       echo INFO got $cmssw_installation_topdir/cic_site_config_global
       cat $cmssw_installation_topdir/cic_site_config_global
       echo INFO end of $cmssw_installation_topdir/cic_site_config_global

       source $cmssw_installation_topdir/cic_site_config_global
       thevalue=
       for v in "$cic_cron_global" ; do
          [ "x$cic_cron_global_val" == "x" ] || break
          thevalue=$(echo "$v" | grep "$gatekeeper_hostname" 2>/dev/null)
          [ $? -eq 0 ] || continue
          thevalue=$(echo "$thevalue" | cut -d+ -f1)
          [ "x$thevalue" == "x" ] || cic_cron_global_val=$thevalue
       done
       thevalue=
       for v in "$cic_destroy_cron_global" ; do
          [ "x$cic_destroy_cron_global_val" == "x" ] || break
          thevalue=$(echo "$v" | grep "$gatekeeper_hostname" 2>/dev/null)
          [ $? -eq 0 ] || continue
          thevalue=$(echo "$thevalue" | cut -d+ -f1)
          [ "x$thevalue" == "x" ] || cic_destroy_cron_global_val=$thevalue
       done
       if [ "x$cic_cron_global_val" != "x" ] ; then
          echo INFO $i got cic_cron_global_val $cic_cron_global_val
          break
       fi
       if [ "x$cic_destroy_cron_global_val" != "x" ] ; then
          echo INFO $i got cic_destroy_cron_global_val $cic_destroy_cron_global_val
       fi
       break
   done
   if [ "x$cic_destroy_cron_global_val" == "x" ] ; then
      echo INFO applying exiting from cic.sh because no control found from the global control
      #rm -f $lock $thelock
      #exit 0
   else
      if [ "x$cic_destroy_cron_global_val" == "x$cic_destroy_cron" ] ; then
         echo INFO applying exiting from cic.sh because "x$cic_destroy_cron_global_val" == "x$cic_destroy_cron"
         #rm -f $lock $thelock
         #exit 0
      else
         is_int $cic_destroy_cron_global_val
         if [ $? -eq 0 ] ; then
            export cic_destroy_cron=$cic_destroy_cron_global_val
         else
            echo ERROR cic_destroy_cron_global_val $cic_destroy_cron_global_val not an integer
         fi # ; } ; # rm -f $lock $thelock ; exit 1 ; } ;
      fi
   fi
   if [ "x$cic_cron_global_val" == "x" ] ; then
      echo INFO applying exiting from cic.sh because no control found from the global control
      #rm -f $lock $thelock
      #exit 0
      #return 0
   else
      if [ "x$cic_cron_global_val" == "x$cic_cron" ] ; then
         echo INFO applying exiting from cic.sh because "x$cic_cron_global_val" == "x$cic_cron"
         #rm -f $lock $thelock
         #exit 0
         #return 0
      else
         is_int $cic_cron_global_val
         if [ $? -eq 0 ] ; then
            export cic_cron=$cic_cron_global_val
         else
            echo ERROR cic_cron_global_val $cic_cron_global_val not an integer # ; return 1 ; } ; # rm -f $lock $thelock ; exit 1 ; } ;
         fi
      fi
   fi
   echo AFTER cic_cron=$cic_cron
   echo AFTER cic_destroy_cron=$cic_destroy_cron
   return 0
}

cic_soft_link_locks() { # func description: soft link locks, especially for large or lustre filesystem sites
   files="$cmssw_installation_topdir/cms/${CMSSW_ARCH_NEXT}/var/lib/rpm $cmssw_installation_topdir/cms/${CMSSW_ARCH_NEXT}/var/lib/apt/lists $cmssw_installation_topdir/cms/${CMSSW_ARCH_NEXT}/var/lib/cache/${CMSSW_ARCH_NEXT} $cmssw_installation_topdir/cms/${CMSSW_ARCH_NEXT}/var/lib/rpm"
   for f in $files ; do
     echo INFO checking directory /tmp$f
     [ -d /tmp$f ] || { echo INFO mkdir -p /tmp$f ; mkdir -p /tmp$f ; [ $? -eq 0 ] || { echo ERROR mkdir -p /tmp$f failed ; return 1 ; } ; } ;
   done
   files="$cmssw_installation_topdir/cms/${CMSSW_ARCH_NEXT}/var/lib/rpm/__db.0 $cmssw_installation_topdir/cms/${CMSSW_ARCH_NEXT}/var/lib/apt/lists/lock $cmssw_installation_topdir/cms/${CMSSW_ARCH_NEXT}/var/lib/cache/${CMSSW_ARCH_NEXT}/lock $cmssw_installation_topdir/cms/${CMSSW_ARCH_NEXT}/var/lib/rpm/lock $cmssw_installation_topdir/cms/${CMSSW_ARCH_NEXT}/var/lib/rpm/__db.000"
   for f in $files ; do
     echo INFO checking the lock file /tmp$f
     [ -f /tmp$f ] || { echo INFO touch /tmp$f ; touch /tmp$f ; [ $? -eq 0 ] || { echo ERROR touch /tmp$f failed ; return 1 ; } ; } ;
     echo INFO Checking any stale link
     [ -f $f ] || { [ -L $f ] && { echo INFO removing the stale link `ls -al $f` ; rm -f $f ; } ; } ;
     echo INFO checking the lock file $f
     [ -L $f ] || { echo INFO rm -f $f ; rm -f $f ; [ $? -eq 0 ] || { echo ERROR rm -f $f failed ; return 1 ; } ; echo INFO ln -s /tmp$f $f ; ln -s /tmp$f $f ; [ $? -eq 0 ] || { echo ERROR ln -s /tmp$f $f failed ; return 1 ; } ; } ;
     echo INFO checking $f again
     ls -al $f
     [ $? -eq 0 ] || { echo ERROR ls -al $f failed ; return 1 ; } ;
     echo INFO checking /tmp$f
     ls -al /tmp$f
     [ $? -eq 0 ] || { echo ERROR ls -al /tmp$f failed ; return 1 ; } ;
   done
   return 0
}

cic_add_cron () { # func descriptions: cronizes cic

    # Getting the original crontab
    /usr/bin/crontab -l 2>/dev/null 1>$cmssw_installation_topdir/cic/crontab.original
    grep -v ^# $cmssw_installation_topdir/cic/crontab.original | grep -q $cmssw_installation_topdir/cic/scripts/cic.sh
    if [ $? -eq 0 ] ; then
       echo Warning cic seems to be already cronized:
       grep -v ^# $cmssw_installation_topdir/cic/crontab.original | grep $cmssw_installation_topdir/cic/scripts/cic.sh
       return 0
    fi
    echo INFO checking crontab.original
    ls -al $cmssw_installation_topdir/cic/crontab.original
    echo INFO configuring crontab
    #SS=$(/bin/date -u +%S)
    SS=$(cic_get_cron_mm)
    echo INFO SS $SS
    cp $cmssw_installation_topdir/cic/crontab.original $cmssw_installation_topdir/cic/crontab
    echo "$SS * * * * $cmssw_installation_topdir/cic/scripts/cic.sh > $cmssw_installation_topdir/cic/scripts/cic.log 2>&1" >> $cmssw_installation_topdir/cic/crontab
    echo INFO checking new crontab
    ls -al $cmssw_installation_topdir/cic/crontab
    cat $cmssw_installation_topdir/cic/crontab
    echo INFO execute the crontab command from cic_add_cron
    /usr/bin/crontab $cmssw_installation_topdir/cic/crontab 2>&1
    /usr/bin/crontab -l
    return $?
}

cic_remove_cron () { # func description: removes cic.sh from the crontab

   # needs a test
   /usr/bin/crontab -l 2>/dev/null 1>$cmssw_installation_topdir/cic/crontab.new
   echo INFO crontab content
   cat $cmssw_installation_topdir/cic/crontab.new
   echo INFO end of crontab content
   
   thestring="$(grep $cmssw_installation_topdir/cic/scripts/cic.sh $cmssw_installation_topdir/cic/crontab.new | sed 's#*#\\*#g')"
   echo INFO thestring=$thestring executing cic_sed_del_line "$thestring" $cmssw_installation_topdir/cic/crontab.new
   if [ "x$thestring" == "x" ] ; then
      echo INFO thestring empty nothing to do
      return 0
   fi
   grep -q "$thestring" $cmssw_installation_topdir/cic/crontab.new
   if [ $? -ne 0 ] ; then
      echo INFO thestring $thestring not found in $cmssw_installation_topdir/cic/crontab.new
      return 0
   fi
   cic_sed_del_line "$thestring" $cmssw_installation_topdir/cic/crontab.new
   echo INFO crontab content
   cat $cmssw_installation_topdir/cic/crontab.new
   echo INFO end of crontab content
   echo INFO crontab $cmssw_installation_topdir/cic/crontab.new from cic_remove_cron
   /usr/bin/crontab $cmssw_installation_topdir/cic/crontab.new 2>&1
   echo INFO checking /usr/bin/crontab -l
   /usr/bin/crontab -l
   return 0
}

cic_project_arch () { # func description: to execute cic_project_arch.sh
   #$cmssw_installation_topdir/cic/scripts/cic_project_arch.sh $@
   echo INFO cic_project_arch executes
   echo $cmssw_installation_topdir/cic/scripts/$cic_cmssw_install_script --cmssw=$4 --sitename=$5 --arch=$6 --repository_location=$8
   $cmssw_installation_topdir/cic/scripts/$cic_cmssw_install_script --cmssw=$4 --sitename=$5 --arch=$6 --repository_location=$8
   return $?
}

cic_remove_project () { # func description: to remove a deprecated CMSSW release
   #$cmssw_installation_topdir/cic/scripts/cic_project_arch.sh $@
   echo INFO cic_remove_project executes 
   echo $cmssw_installation_topdir/cic/scripts/cicremove.sh --cmssw=$1 --sitename=$3 --arch=$2
   $cmssw_installation_topdir/cic/scripts/cicremove.sh --cmssw=$1 --sitename=$3 --arch=$2
   return $?
}

cic_delete_cic_cron_status_from_pubtag () {
   i=0
   while : ; do
      i=$(expr $i + 1)
      [ $i -gt 200 ] && { echo ERROR cic_delete_cic_cron_status_from_pubtag too many VO-cms-cic_cron_status line in $pubtag_files ; return 1 ; } ;
      thestring=$(grep "VO-cms-cic_cron_status" $pubtag_files | tail -1 2>/dev/null)
      echo INFO thestring $thestring inside cic_delete_cic_cron_status_from_pubtag
      [ "x$thestring" == "x" ] && break
      cp $pubtag_files $cmssw_installation_topdir/grid3-locations.txt
      #cic_sed_del_line "$thestring" $(dirname $cmssw_installation_topdir)/etc/grid3-locations.txt
      echo INFO executing cic_sed_del_line for grid3-locations.txt
      cic_sed_del_line "$thestring" $cmssw_installation_topdir/grid3-locations.txt
      echo INFO updating $(dirname $cmssw_installation_topdir)/etc/grid3-locations.txt
      cp $cmssw_installation_topdir/grid3-locations.txt $pubtag_files
   done
   return 0
}

cic_update_pubtag () { # updates $OSG_APP/etc/grid3-locations.txt mainly for sites that do not run the cic cron to use CVMFS installations
   #
   # it depends on cic_timed_download
   #               cic_get_tags
   #

   # location of wget and curl binaries
   cic_wget_location=/usr/bin/wget
   cic_curl_location=/usr/bin/curl
   star='*'
   # xmltag is a location where the CMSSW releases are published within CMS
   cic_xmltag=https://cmstags.cern.ch/tc/ReleasesXML
   # RPMTOP is a web location where various CMSSW rpm packages are found
   cic_rpmtop=http://cmsrep.cern.ch/cmssw/cms

   cms_path=$cmssw_installation_topdir/cms
   if [ ! -d "$cms_path" ] ; then
      echo Warning "$cms_path" does not exist. Using argument 1=$1
      cms_path="$1"
      cmssw_installation_topdir=$(dirname $cms_path)
   fi

   if [ ! -d "$cmssw_installation_topdir" ] ; then
      echo ERROR cmssw_installation_topdir = "$cmssw_installation_topdir" does not exist
      return 1
   fi

   if [ ! -f "pubtag_files" ] ; then
      pubtag_files=$(dirname $cmssw_installation_topdir)/etc/grid3-locations.txt
   fi

   
   echo ; echo ; echo
   echo INFO executing cic_update_pubtag based on OSG_APP=$(dirname $cmssw_installation_topdir) and $pubtag_files
   echo ; echo ; echo

   # production tags
   all=
   ls -al $(dirname $cmssw_installation_topdir)/cmssoft/cms | awk '{print $NF}' | grep -q /cvmfs
   [ $? -eq 0 ] && all=all
   prod_cmssw_archs=$(cic_get_tags $all | grep ^CMSSW | awk '{print $1"|"$2}')
   # 20NOV2012
   unique_archs=$(for prod_cmssw_arch in $prod_cmssw_archs ; do echo $prod_cmssw_arch | cut -d\| -f2 ; done | sort -u)
   i=0
   # 20NOV2012
   for prod_cmssw_arch in $prod_cmssw_archs ; do
       i=$(expr $i + 1)
       #echo INFO doing $i $cmssw
       cmssw=$(echo $prod_cmssw_arch | cut -d\| -f1)
       arch=$(echo $prod_cmssw_arch | cut -d\| -f2)
       echo INFO "[ $i ]" $cmssw
       cmssw_dir=cmssw
       echo "$cmssw" | grep -q patch
       [ $? -eq 0 ] && cmssw_dir=cmssw-patch

       # 20NOV2012 find at least one arch that has the $cmssw installation
       arch_for_cmssw=
       for thearch in $unique_archs ; do
           if [ -d "$cms_path/${thearch}/cms/$cmssw_dir/$cmssw" ] ; then
              arch_for_cmssw=$thearch
              break
           fi
       done
       # 20NOV2012

       for pubtag_file in $pubtag_files ; do
          grep -q "VO-cms-$cmssw $cmssw" "$pubtag_file"
          if [ $? -eq 0 ] ; then
             # 20NOV2012
             if [ "x$arch_for_cmssw" == "x" ] ; then
               
                echo Warning "[ $i ]" "$cms_path/${star}/cms/$cmssw_dir/$cmssw" does not exist. Removing $cmssw from the $pubtag_file
                [ -f $cmssw_installation_topdir/grid3-locations.txt.$cmssw ] || cp $pubtag_file $cmssw_installation_topdir/grid3-locations.txt.$cmssw
                /bin/cp $pubtag_file $cmssw_installation_topdir/grid3-locations.txt.original
                /bin/cp $pubtag_file $cmssw_installation_topdir/grid3-locations.txt
                cic_sed_del_line "VO-cms-$cmssw $cmssw " $cmssw_installation_topdir/grid3-locations.txt
                diff $cmssw_installation_topdir/grid3-locations.txt $cmssw_installation_topdir/grid3-locations.txt.original | grep VO-cms-CMSSW | grep -v "VO-cms-$cmssw $cmssw "
                if [ $? -eq 0 ] ; then
                   echo ERROR "[ $i ]" failed to update the temporary pubtag "diff $cmssw_installation_topdir/grid3-locations.txt $cmssw_installation_topdir/grid3-locations.txt.original | grep VO-cms-CMSSW | grep -v \"VO-cms-$cmssw $cmssw \""
                   diff $cmssw_installation_topdir/grid3-locations.txt $cmssw_installation_topdir/grid3-locations.txt.original | grep VO-cms-CMSSW | grep -v "VO-cms-$cmssw $cmssw "
                   echo REQUEST "[ $i ]" please send an email to $notifytowhom
                else
                   echo INFO "[ $i ]" temporary pubtag successfully updated. Updating $pubtag_file
                   /bin/cp $cmssw_installation_topdir/grid3-locations.txt $pubtag_file
                   echo INFO "[ $i ]" checking the difference
                   diff $pubtag_file $cmssw_installation_topdir/grid3-locations.txt.original
                fi
                #return 0
             else
                echo INFO "[ $i ]" $cmssw in the $pubtag_file
                # 20NOV2012 And there is at least an installation directory for $cmssw under the arch $arch_for_cmssw
             fi
             # 20NOV2012
          else
             # 27NOV2012
             if [ "x$arch_for_cmssw" == "x" ] ; then
                echo Warning "[ $i ]" $cmssw is in the xml tag but "$cms_path/${star}/cms/$cmssw_dir/$cmssw" does not exist
             else
             # 27NOV2012
                echo Warning "[ $i ]" adding a tag for $cmssw after backing up $pubtag_file to $cmssw_installation_topdir/grid3-locations.txt.$cmssw
                [ -f $cmssw_installation_topdir/grid3-locations.txt.$cmssw ] || /bin/cp $pubtag_file $cmssw_installation_topdir/grid3-locations.txt.$cmssw
                echo "VO-cms-$cmssw $cmssw $cms_path" >> $pubtag_file
                echo INFO "[ $i ]" checking if $cmssw is inside $pubtag_file
                grep "$cmssw" "$pubtag_file"
                if [ $? -ne 0 ] ; then
                   echo ERROR "[ $i ]" checking if $cmssw is inside $pubtag_file failed
                fi
             # 27NOV2012
             fi
             # 27NOV2012
          fi
       done
   done
   i=0
   for arch in $unique_archs ; do
       i=$(expr $i + 1)
       echo INFO "[ $i ]" $arch
       for pubtag_file in $pubtag_files ; do
          grep -q "VO-cms-$arch $arch " "$pubtag_file"
          if [ $? -eq 0 ] ; then
             echo INFO "[ $i ]" $arch in the $pubtag_file
             if [ -d "$cms_path/$arch" ] ; then
                echo INFO "[ $i ]" $cmssw in the $pubtag_file
             else
                echo Warning "[ $i ]" "$cms_path/$arch" does not exist. Removing $arch from the $pubtag_file
                /bin/cp $pubtag_file $cmssw_installation_topdir/grid3-locations.txt.original
                /bin/cp $pubtag_file $cmssw_installation_topdir/grid3-locations.txt
                cic_sed_del_line "VO-cms-$arch $arch " $cmssw_installation_topdir/grid3-locations.txt
                /bin/cp $cmssw_installation_topdir/grid3-locations.txt $pubtag_file
                echo INFO "[ $i ]" checking the difference after removing $arch from $pubtag_file
                diff $pubtag_file $cmssw_installation_topdir/grid3-locations.txt.original     
             fi
          else
             echo Warning "[ $i ]" adding a tag for $arch
             echo "VO-cms-$arch $arch /" >> $pubtag_file
             echo INFO "[ $i ]" checking if $arch is inside $pubtag_file
             grep "$arch" "$pubtag_file"
             if [ $? -ne 0 ] ; then
                echo ERROR "[ $i ]" checking if $arch is inside $pubtag_file failed
             fi
          fi
       done
   done

   # deprecated tags
   i=0
   deprecated_cmssw_archs=$(cic_get_tags 1 | grep ^CMSSW | awk '{print $1"|"$2}')
   # 21NOV2012
   unique_archs_in_the_deprecated=$(for deprecated_cmssw_arch in $deprecated_cmssw_archs ; do echo $deprecated_cmssw_arch | cut -d\| -f2 ; done | sort -u)
   # 21NOV2012
   for deprecated_cmssw_arch in $deprecated_cmssw_archs ; do
       cmssw=$(echo $deprecated_cmssw_arch | cut -d\| -f1)
       arch=$(echo $deprecated_cmssw_arch | cut -d\| -f2)
       i=$(expr $i + 1)
       echo INFO "[ $i ]" $cmssw
       cmssw_dir=cmssw
       echo "$cmssw" | grep -q patch
       [ $? -eq 0 ] && cmssw_dir=cmssw-patch
       # 21NOV2012
       arch_for_cmssws=
       for thearch in $unique_archs_in_the_deprecated ; do
           if [ -d "$cms_path/${thearch}/cms/$cmssw_dir/$cmssw" ] ; then
              arch_for_cmssws="$arch_for_cmssws $thearch"
              break
           fi
       done
       # 21NOV2012
       for pubtag_file in $pubtag_files ; do
          grep -q "VO-cms-$cmssw $cmssw" "$pubtag_file"
          if [ $? -eq 0 ] ; then
             # 21NOV2012
             # nfile=$(ls "$cms_path/${thearch}/cms/$cmssw_dir/$cmssw" 2>/dev/null | wc -l)
             snfile=0
             for thearch in $arch_for_cmssws ; do
                 nfile=$(ls "$cms_path/${thearch}/cms/$cmssw_dir/$cmssw" 2>/dev/null | wc -l)
                 snfile=$(expr $snfile + $nfile)
             done
             # 21NOV2012
             # 21NOV2012 if [ $nfile -eq 0 ] ; then
             if [ $snfile -eq 0 ] ; then
                 echo Warning "[ $i ]" deleted $cmssw is in $pubtag_file
                 /bin/cp $pubtag_file $cmssw_installation_topdir/grid3-locations.txt.original
                 /bin/cp $pubtag_file $cmssw_installation_topdir/grid3-locations.txt
                 cic_sed_del_line "VO-cms-$cmssw $cmssw " $cmssw_installation_topdir/grid3-locations.txt
                 /bin/cp $cmssw_installation_topdir/grid3-locations.txt $pubtag_file
                 echo INFO "[ $i ]" checking the difference after removing $cmssw from $pubtag_file
                 diff $pubtag_file $cmssw_installation_topdir/grid3-locations.txt.original
             else
                 echo Warning "[ $i ]" $cmssw is deprecated but not deleted 
             fi
          else
             echo INFO "[ $i ]" deprecated $cmssw is not in $pubtag_file
          fi
       done       
   done
   return 0
}

cic_integrate_pubtag () {
   # mimic the one in CE-cms-swinst to make sure installed but not published ones
   source $cmssw_installation_topdir/cms/cmsset_default.sh > /dev/null
   [ $? -eq 0 ] || printf "ERROR $gatekeeper_hostname cic_integrate_pubtag failed to source $cmssw_installation_topdir/cms/cmsset_default.sh\n" | /bin/mail -s "cic_integrate_pubtag failed to source cmsset_default.sh" $cic_notifytowhom
  

   if [ ! -f $cmssw_installation_topdir/cic/CE-cms-swinst.OLD ] ; then
      touch $cmssw_installation_topdir/cic/CE-cms-swinst.OLD
   fi
   if [ ! -s $cmssw_installation_topdir/cic/CE-cms-swinst ] ; then
      cp $cmssw_installation_topdir/cic/CE-cms-swinst.OLD $cmssw_installation_topdir/cic/CE-cms-swinst
      echo ERROR $cmssw_installation_topdir/cic/CE-cms-swinst empty
      return 1
   fi
   archs_defined=
   archs_to_test=
   eval $(grep archs_ $cmssw_installation_topdir/cic/CE-cms-swinst | grep -v ^# | grep -v \\$) 2>/dev/null 1>/dev/null

   if [ "x$archs_defined" == "x" ] ; then
      echo "$gatekeeper_hostname" | grep -q "ufl.edu"
      [ $? -eq 0 ] && printf "ERROR $gatekeeper_hostname cic-funcsion function cic_integrate_pubtag archs_defined is empty\nCheck http://oo.ihepa.ufl.edu:8080/cmssoft/cic/CE-cms-swinst\nExecute eval \$(grep archs_ CE-cms-swinst | grep -v ^# | grep -v \\\\\\$)\n" | /bin/mail -s "cic_integrate_pubtag archs_defined empty" $cic_notifytowhom
      printf "ERROR $gatekeeper_hostname cic-funcsion function cic_integrate_pubtag archs_defined is empty\nCheck http://oo.ihepa.ufl.edu:8080/cmssoft/cic/CE-cms-swinst\nExecute eval \$(grep archs_ CE-cms-swinst | grep -v ^# | grep -v \\\\\\$)\n"
      return 1
   fi
   for arch in $archs_defined ; do
       echo "$arch" | grep -q slc
       if [ $? -eq 0 ] ; then
          export SCRAM_ARCH=$arch
          export BUILD_ARCH=$arch
          for cmsver in $(scramv1 list -c CMSSW | tr -s " " | cut -d " " -f2 | sort -u) ; do
              grep -q \"$cmsver\" $cmssw_installation_topdir/cmssoft_production_tag.txt
              [ $? -eq 0 ] || continue
              #grep -q "VO-cms-$cmsver $cmsver $cmssw_installation_topdir/cms" $pubtag_files
              grep -q "VO-cms-$cmsver $cmsver " $pubtag_files
              if [ $? -ne 0 ] ; then
                 echo Warning "VO-cms-$cmsver $cmsver " missing from $pubtag_files. Adding it to the file
                 echo "VO-cms-$cmsver $cmsver $cmssw_installation_topdir/cms" >> $pubtag_files
                 echo INFO checking "VO-cms-$cmsver $cmsver "
                 grep "VO-cms-$cmsver $cmsver " $pubtag_files
                 printf "INCIDENT $gatekeeper_hostname cic_integrate_pubtag VO-cms-$cmsver $cmsver was missing from $pubtag_files\nFixed $pubtag_files content follows\n$(cat $pubtag_files)\n" | /bin/mail -s "cic_integrate_pubtag $cmsver was missing from $pubtag_files" $cic_notifytowhom
              fi
          done
          #   > $cmssw_installation_topdir/scramv1_list_output.txt
          #[ $? -eq 0 ] || echo "ERROR $gatekeeper_hostname cic_integrate_pubtag scramv1 list -c CMSSW error"
          #touch $cmssw_installation_topdir/scramv1_list_output.txt
          #cat $cmssw_installation_topdir/scramv1_list_output.txt | tr -s " " | cut -d " " -f2 | sort -u > $cmssw_installation_topdir/cmssw_installed_${arch}.txt
                    
          continue
       fi
       echo "$gatekeeper_hostname" | grep -q "ufl.edu"
       [ $? -eq 0 ] && printf "ERROR $gatekeeper_hostname cic_integrate_pubtag archs_defined=$archs_defined\n" | /bin/mail -s "cic_integrate_pubtag archs_defined has strange arch" $cic_notifytowhom
       printf "ERROR $gatekeeper_hostname cic_integrate_pubtag archs_defined=$archs_defined\n"
   done
   if [ "x$archs_to_test" == "x" ] ; then
      echo "$gatekeeper_hostname" | grep -q "ufl.edu"
      [ $? -eq 0 ] && printf "ERROR $gatekeeper_hostname cic-funcsion function cic_integrate_pubtag archs_to_test is empty\nCheck http://oo.ihepa.ufl.edu:8080/cmssoft/cic/CE-cms-swinst\nExecute eval \$(grep archs_ CE-cms-swinst | grep -v ^# | grep -v \\\\\\$)\n" | /bin/mail -s "cic_integrate_pubtag archs_to_test empty" $cic_notifytowhom
      printf "ERROR cic-funcsion function cic_integrate_pubtag archs_to_test is empty\nCheck http://oo.ihepa.ufl.edu:8080/cmssoft/cic/CE-cms-swinst\nExecute eval \$(grep archs_ CE-cms-swinst | grep -v ^# | grep -v \\\\\\$)\n"
      return 1
   fi

   for arch in $archs_to_test ; do
       echo "$arch" | grep -q slc
       if [ $? -eq 0 ] ; then
          if [ ! -s $pubtag_files ] ; then
             echo "$gatekeeper_hostname" | grep -q "ufl.edu"
             [ $? -eq 0 ] && printf "ERROR $gatekeeper_hostname cic-funcsion function cic_integrate_pubtag pubtag_files=$pubtag_files empty\n" | /bin/mail -s "cic_integrate_pubtag pubtag_files=$pubtag_files empty" $cic_notifytowhom
             printf "ERROR cic-funcsion function cic_integrate_pubtag pubtag_files=$pubtag_files empty\n"
             return 1
          fi
          grep -q "VO-cms-${arch} ${arch} /" $pubtag_files
          if [ $? -ne 0 ] ; then
             echo Warning "VO-cms-${arch} ${arch} /" missing from $pubtag_files. Adding it to the file
             echo "VO-cms-${arch} ${arch} /" $pubtag_files >> $pubtag_files
             echo INFO checking "VO-cms-${arch} ${arch} /"
             grep "VO-cms-${arch} ${arch} /" $pubtag_files
             printf "INCIDENT $gatekeeper_hostname cic-funcsion function cic_integrate_pubtag VO-cms-${arch} ${arch} / was missing from $pubtag_files\nFixed $pubtag_files content follows\n$(cat $pubtag_files)\n" | /bin/mail -s "cic_integrate_pubtag ${arch} tag was missing from $pubtag_files" $cic_notifytowhom
          fi
          continue
       fi
       echo "$gatekeeper_hostname" | grep -q "ufl.edu"
       [ $? -eq 0 ] && printf "ERROR $gatekeeper_hostname cic-funcsion function cic_integrate_pubtag archs_to_test=$archs_to_test\n" | /bin/mail -s "cic_integrate_pubtag archs_to_test has strange arch" $cic_notifytowhom
       printf "ERROR cic-funcsion function cic_integrate_pubtag archs_to_test=$archs_to_test\n"
       return 1
   done
   cp $cmssw_installation_topdir/cic/CE-cms-swinst $cmssw_installation_topdir/cic/CE-cms-swinst.OLD
   return 0
}

cic_get_cron_mm () { # func description: gets cron minutes over an hour period
   SS=$(/bin/date -u +%S)
   cron_mm=$(i=0 ; while [ $i -lt 6 ] ; do new=$(expr $SS + $(expr $i \* 10)) ; i=$(expr $i + 1) ; newMM=$new ; [ $new -gt 60 ] && newMM=$(expr $new % 60) ; echo $newMM ; done | sort -n)
   echo $cron_mm | sed "s# #,#g"
}

cic_update_self () { # func description: to update the cic package and configure

# THIS HAS TO BE SYNCHRONIZED WITH install-cic.sh
(
  cd $cmssw_installation_topdir
  [ $? -eq 0 ] || { echo ERROR cd $cmssw_installation_topdir failed ; exit 1 ; } ;
  #[ -f $cmssw_installation_topdir/cic.lock ] && { echo Warning $cmssw_installation_topdir/cic.lock exists. Try it later. ; echo INFO checking processes to see if cicapt.sh is running or the cic.lock is stuck ; ps auxwww | grep "$(whoami)" ; exit 1 ; } ;
  if [ -f $cmssw_installation_topdir/cic.lock ] ; then
     echo Warning $cmssw_installation_topdir/cic.lock exists.
     echo INFO checking processes to see if cicapt.sh is running or the cic.lock is stuck
     ps auxwww | grep "$(whoami)"
     ps auxwww | grep "$(whoami)" | grep -v grep | grep -q "cicapt.sh\|cicremove.sh"
     #24AUG2012 [ $? -eq 0 ] || { echo Warning neither cicapt.sh nor cicremove.sh is not running. Removing cic.lock ; rm -f $cmssw_installation_topdir/cic.lock ; } ;
     #24AUG2012 exit 1
     if [ $? -eq 0 ] ; then
        echo INFO cic.lock seems to be legitimate
        echo INFO checking if it exists: $cmssw_installation_topdir/var/cmssoft/.cmssoft_install_circle_locked
        ls -al $cmssw_installation_topdir/var/cmssoft/.cmssoft_install_circle_locked
     else
        ncic_processes=$(ps auxwww | grep /bin/sh | grep cic.sh | grep ">" | grep cic.log | grep "2>&1" | grep -v grep | wc -l)
        
        #02OCT2012 because of Wisconsin consider ncic_processes=0 if [ $ncic_processes -eq 1 ] ; then
        if [ $ncic_processes -lt 2 ] ; then
           echo Warning neither cicapt.sh nor cicremove.sh is not running. Removing cic.lock
           rm -f $cmssw_installation_topdir/cic.lock
           if [ -f $cmssw_installation_topdir/var/cmssoft/.cmssoft_install_circle_locked ] ; then
              echo Warning also removing $cmssw_installation_topdir/var/cmssoft/.cmssoft_install_circle_locked
              rm -f $cmssw_installation_topdir/var/cmssoft/.cmssoft_install_circle_locked
           fi
        else           
           echo Warning cic.sh seems to take very long. Check "ps auxwww | grep /bin/sh | grep cic.sh | grep ">" | grep cic.log | grep 2>&1 | grep -v grep"
           ps auxwww | grep /bin/sh | grep cic.sh | grep ">" | grep cic.log | grep "2>&1" | grep -v grep
        fi
     fi
     #exit 1
     #24AUG2012
  fi
  #echo Warning either cicapt.sh or cicremove.sh may be running
  cp -pR cic.tar.gz cic.tar.gz_1
  cic_tar_ball_random=cic.tar.gz.$(date +%s)
  cic_timed_download $cic_tar_ball_random $cic_tarball
  if [ $? -ne 0 ] ; then
     echo ERROR failed to get $cic_tarball
     cp -pR cic.tar.gz_1 cic.tar.gz
     exit 1
  fi
  cp $cic_tar_ball_random cic.tar.gz
  rm -f $cic_tar_ball_random
  tar tzvf cic.tar.gz | grep -q cic/scripts/cic.sh.in
  status=$?
  echo INFO cic/scripts/cic.sh.in grep status $status
  tar tzvf cic.tar.gz | grep -q cic/scripts/cicapt.sh.in
  status=$(expr $status + $?)
  echo INFO cic/scripts/cicapt.sh.in grep status $status
  tar tzvf cic.tar.gz | grep -q cic/scripts/cic-functions.in
  status=$(expr $status + $?)
  echo INFO cic/scripts/cic-functions.in grep status $status
  if [ $status -ne 0 ] ; then
     echo ERROR failed to find required files inside $cic_tarball
     cp -pR cic.tar.gz_1 cic.tar.gz
     exit 1
  fi
  echo INFO comparing checksum 
  ls -al cic.tar.gz*
  rm -f cic.tar.gz.*
  if [ "x$(cksum cic.tar.gz_1 | sed 's#cic.tar.gz_1##')" == "x$(cksum cic.tar.gz | sed 's#cic.tar.gz##')" ] ; then
     echo INFO no change
     exit 0
  fi

  if [ "x$(echo cic/cic_db.txt*)" == "xcic/cic_db.txt*" ] ; then
     tar xzvf cic.tar.gz
     [ $? -eq 0 ] || { echo ERROR failed to extract cic.tar.gz l ; exit 1 ; } ;
  else
     tar xzvf cic.tar.gz --exclude cic_db.txt*
     [ $? -eq 0 ] || { echo ERROR failed to extract cic.tar.gz 2 ; exit 1 ; } ;
  fi
  cd cic
      
  chmod a+x configure-cic.sh
  echo INFO configuring it ./configure-cic.sh --hostname=$gatekeeper_hostname --topdir=$cmssw_installation_topdir     
  ./configure-cic.sh --hostname=$gatekeeper_hostname --topdir=$cmssw_installation_topdir 2>&1 | tee configure-cic.log
  echo INFO checking cic_site_config
  cat $cmssw_installation_topdir/cic_site_config
  #sed "s#@@workdir@@#$workdir#g" install-cic.sh.in > install-cic.sh
  chmod a+x install-cic.sh
  exit 0
)
   grep "CMSSW_6_0_0_patch1 " $cmssw_installation_topdir/cic_db.txt | grep -q slc5_amd64_gcc470
   if [ $? -eq 0 ] ; then
      cic_sed_del_line "CMSSW_6_0_0_patch1 | slc5_amd64_gcc470 |" $cmssw_installation_topdir/cic_db.txt
   fi
   return $?
}

cic_timed_download_debug() {
   # If everything is ok, it will spew the webpage and return 0
   output=$1
   webpage=$2
   timeout=60
   [ $# -gt 2 ] && timeout=$3
   
   if [ "x$output" == "x" ] ; then
      return 1
   fi

   if [ "xwebpage" == "x" ] ; then
      return 1
   fi
   
   executable="${cic_wget_location} --no-check-certificate --timeout=$timeout -q -O"
   echo INFO executing $executable $output $webpage
   ls -al $output
   $executable $output $webpage &
   thepid=$!
   wait $thepid
   status=$?
   [ $status -eq 0 ] && { echo INFO wget fine ; ls -al $output ; return 0 ; } ; # return 0 ; # { echo INFO wget fine ; return 0 ; } ;
   #echo DEBUG status $status after wget 

   #echo INFO wget did not go well. Trying curl
   executable="${cic_curl_location} -k --connect-timeout $timeout -s -o"
   $executable $output $webpage &
   thepid=$!
   wait $thepid
   status=$?
   echo DEBUG curl status $status
   return $status
}

cic_timed_download() {
   # If everything is ok, it will spew the webpage and return 0
   output=$1
   webpage=$2
   timeout=60
   [ $# -gt 2 ] && timeout=$3
   
   if [ "x$output" == "x" ] ; then
      return 1
   fi

   if [ "xwebpage" == "x" ] ; then
      return 1
   fi
   
   executable="${cic_wget_location} --no-check-certificate --timeout=$timeout -q -O"
   #echo INFO executing $executable $output $webpage
   $executable $output $webpage &
   thepid=$!
   wait $thepid
   status=$?
   [ $status -eq 0 ] && return 0 ; # { echo INFO wget fine ; return 0 ; } ;
   #echo DEBUG status $status after wget 

   #echo INFO wget did not go well. Trying curl
   executable="${cic_curl_location} -k --connect-timeout $timeout -s -o"
   $executable $output $webpage &
   thepid=$!
   wait $thepid
   return $?
}

cic_send_cic_log () { # func description: to send cic.log to the central operation web in Florida
   #09MAY2012 Sprace is crontab echo "$gatekeeper_hostname" | grep -q "osg-ce.sprace.org.br\|osg-gw-4.t2.ucsd.edu"
   echo "$gatekeeper_hostname" | grep -q "osg-gw-4.t2.ucsd.edu"
   [ $? -eq 0 ] && return 0
   status=0
   echo DEBUG preparing python env for xmlrpc
   if [ -f $cmssw_installation_topdir/cms/COMP/slc5_amd64_gcc434/external/python/2.6.4/etc/profile.d/init.sh ] ; then
      echo DEBUG COMPPython2.6.4 found
      . $cmssw_installation_topdir/cms/COMP/slc5_amd64_gcc434/external/python/2.6.4/etc/profile.d/init.sh 2>&1
   else
      echo DEBUG ERROR COMPPython2.6.4 not found
      status=99
   fi
   echo DEBUG which python
   which python 2>&1
   echo DEBUG end of which python
   cic_log=$cmssw_installation_topdir/cic/scripts/cic.log
   #[ -f $cic_log ] || cic_log=$cmssw_installation_topdir/cic/scripts/cic_cron_not_allowed.log
   echo DEBUG checking 1 $cic_log
   ls -al $cic_log # 2>/dev/null 1>/dev/null
   [ $? -eq 0 ] || { home=$(cd ; pwd) ; cic_log=$home/cic_cron_not_allowed.log ; } ;
   echo DEBUG checking 2 $cic_log
   ls -al $cic_log # 2>/dev/null 1>/dev/null
   [ $? -eq 0 ] || cic_log=$cmssw_installation_topdir/cic/scripts/cic_cron_not_allowed.log
   #[ -f $cic_log ] || { cic_log=$cmssw_installation_topdir/cic/scripts/cic.tmp.log ; echo Neither cic.log nor cic_cron_not_allowed.log found > $cic_log ; } ;
   echo DEBUG checking 3 $cic_log
   ls -al $cic_log # 2>/dev/null 1>/dev/null
   [ $? -eq 0 ] || { cic_log=$cmssw_installation_topdir/cic/scripts/cic.tmp.log ; echo Neither cic.log nor cic_cron_not_allowed.log found > $cic_log ; } ;
   echo DEBUG the cic log $cic_log
   # STRANGE for some reason at some sites. old log file is sent. avoiding it by picking a random log file name
   locallog=/tmp/$(basename $cic_log).$(date +%s).log
   cp $cic_log $locallog
   #python $cmssw_installation_topdir/cic/scripts/cic_send_log.py --sendciclog $cic_log $gatekeeper_hostname 2>&1 | tee $cmssw_installation_topdir/cic/scripts/cic_log_sent.log
   # 24AUG2012 
if [ ] ; then
   python $cmssw_installation_topdir/cic/scripts/cic_send_log.py --sendciclog $locallog $gatekeeper_hostname 2>&1 | tee $cmssw_installation_topdir/cic/scripts/cic_log_sent.log
   thestatus=$?
   if [ $thestatus -eq 0 ] ; then
      echo INFO OK: $(which python) $cmssw_installation_topdir/cic/scripts/cic_send_log.py --sendciclog $locallog $gatekeeper_hostname
   else
      echo INFO not OK: $(which python) $cmssw_installation_topdir/cic/scripts/cic_send_log.py --sendciclog $locallog $gatekeeper_hostname
      echo INFO trying with /usr/bin/python
      /usr/bin/python $cmssw_installation_topdir/cic/scripts/cic_send_log.py --sendciclog $locallog $gatekeeper_hostname 2>&1 | tee $cmssw_installation_topdir/cic/scripts/cic_log_sent.log
      thestatus=$?
   fi
fi
   echo DEBUG checking LDD
   ldd $(which python)
   echo DEBUG uname -a
   uname -a

   #echo INFO executing /usr/bin/python $cmssw_installation_topdir/cic/scripts/cic_send_log.py --sendciclog $locallog $gatekeeper_hostname
   #/usr/bin/python $cmssw_installation_topdir/cic/scripts/cic_send_log.py --sendciclog $locallog $gatekeeper_hostname 2>&1 | tee $cmssw_installation_topdir/cic/scripts/cic_log_sent.log
   echo INFO executing python $cmssw_installation_topdir/cic/scripts/cic_send_log.py --sendciclog $locallog $gatekeeper_hostname
   python $cmssw_installation_topdir/cic/scripts/cic_send_log.py --sendciclog $locallog $gatekeeper_hostname 2>&1 | tee $cmssw_installation_topdir/cic/scripts/cic_log_sent.log
   thestatus=$?
   status=$(expr $status + $thestatus)
   # 24AUG2012 status=$(expr $status + $?)
   rm -f $locallog
   return $status
}

cic_send_cic_project_arch_log () { # func description: to send cic_project_arch.*.log to the central operation web in Florida
   status=0
   cic_project_arch_log="$1"
   cic_project_arch_log_which=aptinstall
   echo "$cic_project_arch_log" | grep -q cic_remove_project
   [ $? -eq 0 ] && cic_project_arch_log_which=aptremove
   [ -f "$cic_project_arch_log" ] || { echo ERROR cic_send_cic_project_arch_log $cic_project_arch_log does not exist ; return 1 ; } ;
   CMSSW_PROJECT_NEXT=$(echo $cic_project_arch_log | cut -d. -f2)
   [ "x$CMSSW_PROJECT_NEXT" == "x" ] && { echo ERROR cic_send_cic_project_arch_log CMSSW_PROJECT_NEXT empty ; return 1 ; } ;
   CMSSW_ARCH_NEXT=$(echo $cic_project_arch_log | cut -d. -f3)
   [ "x$CMSSW_ARCH_NEXT" == "x" ] && { echo ERROR cic_send_cic_project_arch_log CMSSW_ARCH_NEXT empty ; return 1 ; } ;
   echo DEBUG preparing python env for xmlrpc
   if [ -f $cmssw_installation_topdir/cms/COMP/slc5_amd64_gcc434/external/python/2.6.4/etc/profile.d/init.sh ] ; then
      echo DEBUG COMPPython2.6.4 found
      . $cmssw_installation_topdir/cms/COMP/slc5_amd64_gcc434/external/python/2.6.4/etc/profile.d/init.sh 2>&1
   else
      echo DEBUG ERROR COMPPython2.6.4 not found
      status=99
   fi
   echo DEBUG which python
   which python 2>&1
   echo DEBUG end of which python
   python $cmssw_installation_topdir/cic/scripts/cic_send_log.py --send $cic_project_arch_log ${CMSSW_PROJECT_NEXT} ${cic_project_arch_log_which}_${CMSSW_ARCH_NEXT} $gatekeeper_hostname 2>&1 | tee $cmssw_installation_topdir/cic/scripts/cic_send_log.log
   status=$(expr $status + $?)
   return $status
}

cic_df_check_with_status () {
  thedir=$1
  echo INFO checking df -h $thedir at $(date) # mount point
  #ls -al $thedir 2>/dev/null 1>/dev/null
  #thedir=$(ftool_check_mount_point $thedir)
  ##echo INFO doing df -h $thedir
  df -h $thedir
  status=$?
  echo cic_df_check_with_status $status at $(date)
  return $status
}

cic_time_process_kill () {
  theps=$1
  timeout=$2
  [ "x$theps" == "x" ] && return 1
  [ "x$timeout" == "x" ] && return 1
  i=0
  while [ $i -lt $timeout ] ; do
    i=$(expr $i + 1)
    ps auxwww | awk '{print "|"$2"|"}' | grep -q "|${theps}|"
    [ $? -eq 0 ] || break
    #echo $i
    sleep 1
  done
  ps auxwww | awk '{print "|"$2"|"}' | grep -q "|${theps}|"
  [ $? -eq 0 ] && { echo KILLING $theps ; kill -KILL ${theps} ; return 1 ; } ;
  return 0
}

cic_check_unresponsive_drives () {
   echo DEBUG cic_check_unresponsive_drives cic_df_check_with_status
   cic_df_check_with_status >& /dev/null &
   theps=$!
   echo DEBUG cic_check_unresponsive_drives cic_time_process_kill
   cic_time_process_kill "$theps" 60
   if [ $? -eq 0 ] ; then
      echo DEBUG cic_check_unresponsive_drives df check finished within 60 seconds
   else
      echo DEBUG cic_check_unresponsive_drives df check timed out in 60 seconds. Checking /etc/mtab
      cat /etc/mtab
   fi
   return 0
}
  
cic_check_locks_processes () {
   echo ; echo ; echo 
   echo DEBUG cic_check_locks_processes checking locks 
   echo $cmssw_installation_topdir/cic*.lock
   ls -al $cmssw_installation_topdir/cic*.lock
   echo $cmssw_installation_topdir/var/cmssoft/.cmssoft_install_circle_locked
   ls -al $cmssw_installation_topdir/var/cmssoft/.cmssoft_install_circle_locked
   echo ; echo ; echo 
   echo DEBUG cic_check_locks_processes checking "ps auxwww | grep apt-get | grep update | grep -v grep"
   ps auxwww | grep -v grep | grep apt-get | grep update
   if [ $? -eq 0 ] ;  then
      echo DEBUG cic_check_locks_processes checking apt-get update process via lsof
      /usr/sbin/lsof -p $(ps auxwww | grep -v grep | grep apt-get | grep update | awk '{print $2}')
      echo DEBUG cic_check_locks_processes checking time apt-get update is running
      run_mm_ss=$(ps auxwww | grep apt-get | grep update | grep -v grep | awk '{print $10}')
      is_int $(echo $run_mm_ss | cut -d: -f1)
      if [ $? -eq 0 ] ; then
         echo DEBUG cic_check_locks_processes apt-get update is running for $(expr $(echo $run_mm_ss | cut -d: -f1) / 60 ) minutes
         echo DEBUG cic_check_locks_processes checking cic_check_unresponsive_drives
         cic_check_unresponsive_drives
      else
         echo DEBUG cic_check_locks_processes apt-get update timecheck MM is not an integer
      fi
   fi
   echo ; echo ; echo 
   echo DEBUG cic_check_locks_processes checking "ps auxwww | grep rpm -Uvh | grep -v grep"
   ps auxwww | grep -v grep | grep "rpm -Uvh"
   if [ $? -eq 0 ] ;  then
      echo DEBUG cic_check_locks_processes checking "/usr/sbin/lsof -p \$(ps auxwww | grep rpm -Uvh | grep -v grep | awk '{print \$2}')"
      /usr/sbin/lsof -p $(ps auxwww | grep -v grep | grep "rpm -Uvh" | awk '{print $2}')
      echo DEBUG cic_check_locks_processes checking time rpm -Uvh is running
      run_mm_ss=$(ps auxwww | grep "rpm -Uvh" | grep -v grep | awk '{print $10}')
      is_int $(echo $run_mm_ss | cut -d: -f1)
      if [ $? -eq 0 ] ; then
         echo DEBUG cic_check_locks_processes rpm -Uvh is running for $(expr $(echo $run_mm_ss | cut -d: -f1) / 60 ) minutes
         echo DEBUG cic_check_locks_processes checking cic_check_unresponsive_drives
         cic_check_unresponsive_drives
      else
         echo DEBUG cic_check_locks_processes rpm -Uvh timecheck MM is not an integer
      fi
      ps auxwww | grep -v grep | grep "apt-get" | grep -q install
      if [ $? -eq 0 ] ; then
         echo DEBUG cic_check_locks_processes apt-get install process exists
         ps auxwww | grep -v grep | grep "cic/scripts/cicapt.sh"
         if [ $? -eq 0 ] ;  then
            echo DEBUG cic_check_locks_processes cicapt.sh process exists
            pstree -a -l -p $(ps auxwww | grep -v grep | grep "cic/scripts/cicapt.sh" | awk '{print $2}')
         fi
      fi
   fi
   echo cic_check_locks_processes concludes
   return 0
}

cic_put_a_pause () { # func description: a simple function to pause the core script to do something fundamental
  echo INFO inside cic_put_a_pause pause hosts are $1
  for host in $1 ; do
     [ "x$host" == "x$gatekeeper_hostname" ] && return 1
     [ "x$host" == "xALL" ] && return 1
  done
  return 0
}

cic_get_gatekeeper_hosts () {
  ls -al cic_db.txt.* 2>/dev/null 1>/dev/null
  [ $? -eq 0 ] && { ls -al cic_db.txt.* | awk '{print $NF}' | cut -d. -f3- | sort -u ; return 0 ; } ;
  ls -al $cmssw_installation_topdir/cic/cic_db.txt.* 2>/dev/null 1>/dev/null
  [ $? -eq 0 ] && { ls -al $cmssw_installation_topdir/cic/cic_db.txt.* | awk '{print $NF}' | cut -d. -f3- | sort -u ; return 0 ; } ;
  ls -al $HOME/services/external/apache2/htdocs/cmssoft/cic/cic_db.txt.* 2>/dev/null 1>/dev/null
  [ $? -eq 0 ] && { ls -al $HOME/services/external/apache2/htdocs/cmssoft/cic/cic_db.txt.* | awk '{print $NF}' | cut -d. -f3- | sort -u ; return 0 ; } ;
  return 0
}

cic_apt_get_fix_broken () {
  echo INFO
  cms_path=$cmssw_installation_topdir/cms
  arch=slc5_amd64_gcc434
  [ -s $cms_path/${arch}/external/apt/*/etc/profile.d/init.sh ] || return 1
  source $cms_path/${arch}/external/apt/*/etc/profile.d/init.sh 2>&1
  echo INFO executing apt-get --fix-broken install 2>&1
  apt-get --assume-yes --fix-broken install 2>&1
  echo INFO script Done
  printf "cic_apt_get_fix_broken done at $gatekeeper_hostname\n" | mail -s "apt-get --fix-broken done at $gatekeeper_hostname" $cic_notifytowhom
  return 0
}

cic_get_not_installed () {
  #all=1
  #requirement_file=$cmssw_installation_topdir/cic/cmssoft_retire_requirement_arch
  cmssw_keeps=$(grep "######## cmssw_keep_$gatekeeper_hostname" $requirement_file | cut -d\" -f2)
  #echo DEBUG cic_update_release_db checking if all announced ones are installed
  # 24AUG2012 to filter out pre versons for rel in $(grep CMSSW_ $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt | awk '{print $2}') ; do
  cmssw_to_install=
  #for rel in $(grep CMSSW_ $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt | grep -v _pre[0-9] | awk '{print $2}') ; do
  for rel in $(grep CMSSW_ $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt | awk '{print $2}') ; do
       grep -q "| $rel |" $cmssw_installation_topdir/cic_db.txt
       #grep -v INSTALLED_RETIRED $cmssw_installation_topdir/cic_db.txt | grep -q "| $rel |"
       if [ $? -ne 0 ] ; then
          grep -q "\"$rel\"" $cmssw_installation_topdir/cmssoft_deprecate_tag.txt
          if [ $? -eq 0 ] ; then
             for cmssw_keep in $cmssw_keeps ; do
                 thecmssw=CMSSW_$cmssw_keep
                 if [ "x${thecmssw}x" == "x${rel}x" ] ; then
                    #all=0
                    #echo DEBUG ${rel} is deprecated but in the keep list
                    #echo DEBUG breaking at $rel not all announced ones are installed 2
                    #break
                    cmssw_to_install="$cmssw_to_install $rel"
                 fi
             done
          else
             #all=0
             #echo DEBUG breaking at $rel not all announced ones are installed 1
             #break
             cmssw_to_install="$cmssw_to_install $rel"
          fi
       fi
  done
  echo $cmssw_to_install | grep CMSSW_
  return 0
}

cic_update_release_db () {
  all=1 
  #requirement_file=$cmssw_installation_topdir/cic/cmssoft_retire_requirement_arch
  cmssw_keeps=$(grep "######## cmssw_keep_$gatekeeper_hostname" $requirement_file | cut -d\" -f2)
  echo DEBUG cic_update_release_db checking if all announced ones are installed
  # 24AUG2012 to filter out pre versons for rel in $(grep CMSSW_ $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt | awk '{print $2}') ; do
  #for rel in $(grep CMSSW_ $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt | grep -v _pre[0-9] | awk '{print $2}') ; do
  for rel in $(grep CMSSW_ $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt | awk '{print $2}') ; do
       grep -q "| $rel |" $cmssw_installation_topdir/cic_db.txt
       #grep -v INSTALLED_RETIRED $cmssw_installation_topdir/cic_db.txt | grep -q "| $rel |"
       if [ $? -ne 0 ] ; then
          grep -q "\"$rel\"" $cmssw_installation_topdir/cmssoft_deprecate_tag.txt
          if [ $? -eq 0 ] ; then
             for cmssw_keep in $cmssw_keeps ; do
                 thecmssw=CMSSW_$cmssw_keep
                 if [ "x${thecmssw}x" == "x${rel}x" ] ; then
                    all=0
                    echo DEBUG ${rel} is deprecated but in the keep list
                    echo DEBUG breaking at $rel not all announced ones are installed 2
                    break
                 fi
             done
          else
             all=0
             echo DEBUG breaking at $rel not all announced ones are installed 1
             break
          fi
       fi
  done

  # 29AUG2012 reinstall removed using the keep list in cmssoft_retire_requirement_arch
  echo DEBUG checking retire requirement file
  for cmssw_keep in $cmssw_keeps ; do
      thecmssw=CMSSW_$cmssw_keep
      grep "| $thecmssw |" $cmssw_installation_topdir/cic_db.txt | grep -q INSTALLED_RETIRED
      if [ $? -eq 0 ] ; then
         all=0
         thestring=$(grep "| $thecmssw |" $cmssw_installation_topdir/cic_db.txt | grep INSTALLED_RETIRED)
         echo Warning removed release $thecmssw needs to be reinstalled I.
         ls -al $cmssw_installation_topdir/cic_db.txt
         grep "| $thecmssw |" $cmssw_installation_topdir/cic_db.txt
         #cic_sed_del_line "$thestring" $cicdb
         break
      fi
  done
  # 29AUG2012 reinstall removed using the keep list in cmssoft_retire_requirement_arch

  if [ $all -eq 0 ] ; then
     echo DEBUG cic_update_release_db return 1
     return 1
  else
     
     if [ -f $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt ] ;  then
        echo DEBUG cic_update_release_db return 0
        cp $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt.0 2>&1
        return 0
     else
        echo DEBUG cic_update_release_db return 1 not found $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt
        return 0
     fi
  fi
  
}

cic_check_new_release () {
  #home=$(cd ; pwd)
  cic_new_release_announcement=http://oo.ihepa.ufl.edu:8080/cmssoft/aptinstall/cmssoft_check_cmssw_release.db.txt
  [ -f $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt.0 ] || touch $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt.0
  release_db_txt=$cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt.$(date +%s)
  wget -q -O $release_db_txt $cic_new_release_announcement 2>&1
  status=$?
  if [ $status -ne 0 ] ; then
     curl $cic_new_release_announcement > $release_db_txt
     status=$?
  fi
  #echo DEBUG cic_check_new_release at $(/bin/hostname -f) at $(date)
  #echo DEBUG got $release_db_txt
  #echo DEBUG ls -al $release_db_txt
  #ls -al $release_db_txt
  #echo DEBUG ls -al $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt
  #ls -al $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt
  #echo DEBUG tail -5 $release_db_txt
  #tail -5 $release_db_txt
  #echo DEBUG tail -5 $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt
  #tail -5 $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt
  cp $release_db_txt $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt
  rm -f $release_db_txt
  if [ $status -eq 0 ] ; then
     #diff $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt.0 $cmssw_installation_topdir/cmssoft_check_cmssw_release.db.txt 2>/dev/null 1>/dev/null
     #if [ $? -eq 0 ] ; then
     #  echo INFO cic_check_new_release no new release 
     #  echo script cic_check_new_release Done
     #  return 1
     #else
       echo INFO cic_update_release_db
       cic_update_release_db
       if [ $? -eq 1 ] ; then
          echo INFO will execute cic.sh
          #cic_update_release_db
          return 0
       else
          echo INFO All seems to be up to date and we will not execute cic.sh
          return 1
       fi
     #fi
  else
     #printf "run_cic.sh failed due to a failure with wget/curl $cic_new_release_announcement \n" | mail -s "run_cic.sh failed" $cic_notifytowhom
     echo script cic_check_new_release Done but with a failure
     return 1
  fi
  return 1
}

cic_check_bootstrap () {
  [ "x$CMSSW_ARCH_NEXT" == "x" ] && { echo Warning $CMSSW_ARCH_NEXT empty ; return 0 ; } ;
  ls $cmssw_installation_topdir/cms/${CMSSW_ARCH_NEXT}/external/apt/*/bin/apt-get 1>/dev/null 2>/dev/null
  if [ $? -eq 0 ] ; then
     echo INFO cic_check_bootstrap $CMSSW_ARCH_NEXT is already bootstrapped
  else
     echo INFO checking arch $CMSSW_ARCH_NEXT
     $cmssw_installation_topdir/cic/scripts/cmssoft_check_deps.sh $CMSSW_ARCH_NEXT | grep "not provided by any OS" | grep -q ERROR 
     if [ $? -eq 0 ] ; then
        echo INFO $CMSSW_ARCH_NEXT does not seem to be bootstrap-able
        if [ ! -f $cmssw_installation_topdir/cic/${CMSSW_ARCH_NEXT}.${gatekeeper_hostname}.mailed.txt ] ; then
           printf "cic_check_bootstrap $gatekeeper_hostname ${CMSSW_PROJECT_NEXT} $CMSSW_ARCH_NEXT missing system rpm \nExecuting $cmssw_installation_topdir/cic/scripts/cmssoft_check_deps.sh $CMSSW_ARCH_NEXT\n$($cmssw_installation_topdir/cic/scripts/cmssoft_check_deps.sh $CMSSW_ARCH_NEXT | sed 's#%#%%#g') \n" | /bin/mail -s "cic_check_bootstrap ${CMSSW_PROJECT_NEXT} $CMSSW_ARCH_NEXT missing system rpm at $gatekeeper_hostname" $cic_notifytowhom
           printf "cic_check_bootstrap $gatekeeper_hostname ${CMSSW_PROJECT_NEXT} $CMSSW_ARCH_NEXT missing system rpm \nExecuting $cmssw_installation_topdir/cic/scripts/cmssoft_check_deps.sh $CMSSW_ARCH_NEXT\n$($cmssw_installation_topdir/cic/scripts/cmssoft_check_deps.sh $CMSSW_ARCH_NEXT | sed 's#%#%%#g') \n" > $cmssw_installation_topdir/cic/${CMSSW_ARCH_NEXT}.${gatekeeper_hostname}.mailed.txt
        fi
        return 1
     else
        echo INFO $CMSSW_ARCH_NEXT seems to be bootstrap-able
     fi
  fi
  return 0
}

cmssoft_grid_cleanup_scram_list () {
  cmssoft_dir=$cmssw_installation_topdir
  if [ ! -s $cmssoft_dir/cic_db.txt ] ; then
     echo ERROR $cmssoft_dir/cic_db.txt not found on $(/bin/hostname -f)
     return 1
  fi
  thearch=
  thecmssw=
  [ $# -gt 0 ] && { thecmssw=$1 ; thearch=$SCRAM_ARCH ; } ;
  echo INFO running cmssoft_grid_cleanup_scram_list $thecmssw
  #echo INFO checking scram list before
  source $cmssoft_dir/cms/cmsset_default.sh
  #scram list
  for cmssw_arch in $(grep INSTALLED_RETIRED $cmssoft_dir/cic_db.txt | awk '{print $5"+"$3}' | sort -u) ${thearch}+${thecmssw} ; do
    arch=$(echo $cmssw_arch | cut -d+ -f1)
    cmssw=$(echo $cmssw_arch | cut -d+ -f2)
    [ "x$arch" == "x" ] && continue
    [ "x$cmssw" == "x" ] && continue
    if [ "x$thecmssw" != "x" ] ; then
       echo DEBUG 1 cmssoft_grid_cleanup_scram_list doing $thecmssw $thearch
       [ "x$thecmssw" == "x$cmssw" ] || continue
       echo DEBUG 2 cmssoft_grid_cleanup_scram_list doing $thecmssw $thearch
    fi
    thedir=cmssw
    echo $cmssw | grep -q patch
    [ $? -eq 0 ] && thedir=cmssw-patch
    if [ -d $cmssoft_dir/cms/$arch/cms/$thedir/$cmssw ] ; then
       nfiles=$(ls $cmssoft_dir/cms/$arch/cms/$thedir/$cmssw | wc -l)
       echo INFO $cmssw $arch NOT_OK nfiles=$nfiles 
       if [ $nfiles -eq 0 ] ; then
         scram list | grep -q "$cmssw "
         if [ $? -eq 0 ] ; then
            echo Warning removing $cmssoft_dir/cms/$arch/cms/$thedir/$cmssw
            ( cd $cmssoft_dir/cms/$arch/cms/$thedir ; [ $? -eq 0 ] && { echo Warning rm -rf $cmssw ; rm -rf $cmssw ; } ; ) ;
         else
            echo INFO $cmssw is not in the scram list
         fi
       else
         echo INFO listing the directory $cmssoft_dir/cms/$arch/cms/$thedir/$cmssw
         ls $cmssoft_dir/cms/$arch/cms/$thedir/$cmssw
       fi
    else
       echo INFO $cmssw $arch OK
    fi
  done
  #echo INFO checking scram list after
  #source $cmssoft_dir/cms/cmsset_default.sh
  #scram list
  return 0
}

cmssoft_find_arch() {
  cmssw_release_name=$1
  echo "$cmssw_release_name" | grep -q ^CMSSW_
  [ $? -eq 0 ] || return 1
  if [ "x$cmssw_release_name" == "xCMSSW_6_0_0_patch1" ] ; then
       grep -q "CMSSW_6_0_0_patch1 slc5_amd64_gcc470" $cmssw_installation_topdir/cic/cic_cmssw_arch_list.txt
       if [ $? -eq 0 ] ; then
          sed -i "s#CMSSW_6_0_0_patch1 slc5_amd64_gcc470#CMSSW_6_0_0_patch1 slc5_amd64_gcc462#g" $cmssw_installation_topdir/cic/cic_cmssw_arch_list.txt
       fi
   fi
  # Use it if the info is in the local cache
  cmssw_release_arch=$(echo $(grep "$cmssw_release_name " $cmssw_installation_topdir/cic/cic_cmssw_arch_list.txt 2>/dev/null | awk '{print $2}'))
  if [ $(echo $cmssw_release_arch | wc -w) -eq 1 ] ; then
     echo $cmssw_release_arch
     return 0
  fi

  cmssw_release_arch=$(python $cmssw_installation_topdir/cic/scripts/cmssoft_production_tag.py 2>/dev/null | grep "$cmssw_release_name " | awk '{print $NF}')
  echo "$cmssw_release_arch" | grep -q slc
  if [ $? -eq 0 ] ; then
     if [ $(echo "$cmssw_release_arch" | wc -w) -eq 1 ] ; then
        echo "$cmssw_release_arch"
        return 0
     fi
  fi

  n_1=`echo $cmssw_release_name | cut -d_ -f2` ; n_1=`expr $n_1 \* 1000000`
  n_2=`echo $cmssw_release_name | cut -d_ -f3` ; n_2=`expr $n_2 \* 1000`
  n_3=`echo $cmssw_release_name | cut -d_ -f4` ; n_3=`expr $n_3 \* 1`
  n_cmssw_project=`expr $n_1 + $n_2 + $n_3`
  #n_cmssw_ending=5001000
  n_cmssw_ending=5999999
  #echo DEBUG cmssoft_find_arch $cmssw_release_name n_cmssw_project $n_cmssw_project
  cmssw_release_arch=
  if [ $n_cmssw_project -lt 1005000 ] ; then
   cmssw_release_arch=slc3_ia32_gcc323
  elif [ $n_cmssw_project -ge 1005000 -a $n_cmssw_project -lt 3004000 ] ; then
   cmssw_release_arch=slc4_ia32_gcc345
  elif [ $n_cmssw_project -ge 3004000 -a $n_cmssw_project -lt 4001000 ] ; then
   cmssw_release_arch=slc5_ia32_gcc434
  elif [ $n_cmssw_project -ge 4001000 -a $n_cmssw_project -lt 5001000  ] ; then
   cmssw_release_arch=slc5_amd64_gcc434
  # 18SEP2012
  elif [ $n_cmssw_project -ge 5001000 -a $n_cmssw_project -lt $n_cmssw_ending ] ; then
   cmssw_release_arch=slc5_amd64_gcc462
  #elif [ $n_cmssw_project -ge 5001001 ] ; then
  # cmssw_release_arch=slc5_amd64_gcc461
  fi
  #if [ $n_cmssw_project -le 5000000 ] ; then
  # 18SEP2012 if [ $n_cmssw_project -lt 5001000 ] ; then
  if [ $n_cmssw_project -lt $n_cmssw_ending ] ; then
     echo ${cmssw_release_arch}
     return 0
  fi
  
  # get ARCH list
  cic_timed_download $cmssw_installation_topdir/cic_${cmssw_release_arch}.txt $cic_rpmtop/RPMS/$cmssw_release_arch/ 2>/dev/null
  [ $? -eq 0 ] || { echo ${cmssw_release_arch} ; return 1 ; } ;

  grep ${cmssw_release_name}- $cmssw_installation_topdir/cic_${cmssw_release_arch}.txt | grep -q cms+cmssw
  [ $? -eq 0 ] && { echo ${cmssw_release_arch} ; return 0 ; } ;

  # previous one did not work search all archs and see if we can find the RPM in the first arch
  #echo DEBUG previous one did not work search all archs and see if we can find the RPM in the first arch
  #echo "DEBUG executing $executable $cmssw_installation_topdir/cic_RPMS.txt http://cmsrep.cern.ch/cmssw/cms/RPMS/ 2>/dev/null"
  cic_timed_download $cmssw_installation_topdir/cic_RPMS.txt $cic_rpmtop/RPMS/ 2>/dev/null
  archs=$(grep slc $cmssw_installation_topdir/cic_RPMS.txt | grep DIR | cut -d\> -f7 | cut -d/ -f1 | sort -u | grep -v onl_ )
  for arch in $archs ; do
     #$executable $cmssw_installation_topdir/cic_${arch}.txt $cic_rpmtop/RPMS/$arch/ 2>/dev/null
     cic_timed_download $cmssw_installation_topdir/cic_${arch}.txt $cic_rpmtop/RPMS/$arch/ 2>/dev/null
     grep ${cmssw_release_name}- $cmssw_installation_topdir/cic_${arch}.txt | grep -q cms+cmssw
     [ $? -eq 0 ] && { echo ${arch} ; return 0 ; } ;
  done
  echo $cmssw_release_arch
  return 0
}


upper(){
 echo $@ | tr '[a-z]' '[A-Z]'
}

lower(){
 echo $@ | tr '[A-Z]' '[a-z]'
}

is_int() {
  if [ $1 ] ; then
     theval=$1
     if [ "x$theval" == "x" ] ; then
        return 1
     else
        if [ "x`echo $theval | egrep -v '^[0-9]+$'`" != "x" ] ; then
           return 1
        else
           return 0
        fi
     fi
  else
     return 1
  fi
}

checkspaceavail() {
    if [ $# -ne 1 ] ; then
       echo 0
       return 1
    fi
    checkdir=$1
    dirdepth=100
    thedirname=`df -k $checkdir | grep -v -i Filesystem`
    if [ ! -d $checkdir ] ; then
       rdir=$checkdir
       k=0
       while : ; do
	      [ -d $rdir ] && break
	      [ "$rdir" == "/" -o $rdir == "." ] && { echo -n Dot_or_slash $rdir ; break ; } ;
              rdir=`dirname $rdir`
	      k=`expr $k + 1`
	      [ $k -gt $dirdepth ] && { echo -n Too_deep ; break ; } ;
       done
       echo $rdir | grep -q "^/"
       [ $? -eq 0 ] || { echo -n dir_does_not_start_with_slash ; } ;
       thedirname=`df -k $rdir | grep -v -i Filesystem` ;
    fi
    # if it is automount, give up and use /
    echo $thedirname | grep -q automount
    [ $? -eq 0 ] && thedirname=`df -k / | grep -v -i Filesystem`
    echo ":"$thedirname | awk '{print $(NF-2)}'
}

##### Common aptinstall aptremove

# Stolen from cmsos
cmssoft_cmsos() {
### FILE cmsos
if [ "$BUILD_ARCH" != "" ]; then
    echo "$BUILD_ARCH"
elif [ `uname` = Linux ]; then
  if [ -f /etc/SuSE-release ]; then
    echo suse`grep -i '^version' < /etc/SuSE-release | tr -dc '[0-9]'`
  elif grep -q Scientific /etc/redhat-release 2>/dev/null; then
    slc_version=`grep Scientific /etc/redhat-release | sed 's/.*[rR]elease \([0-9]*\)\..*/\1/'`
    if [ `uname -i` == i386 ]; then
      echo slc${slc_version}_ia32
    else
      echo slc${slc_version}_amd64
    fi
  elif grep -q "Red Hat Enterprise" /etc/redhat-release 2>/dev/null; then
      slc_version=`grep Enterprise /etc/redhat-release | sed 's/.*[rR]elease \([0-9]*\).*/\1/'`
      if [ `uname -i` == i386 ]; then
        echo slc${slc_version}_ia32
      else
        echo slc${slc_version}_amd64
      fi
  elif grep -q Scientific /etc/rocks-release 2>/dev/null; then
      slc_version=`grep DISTRIB_RELEASE rocks-release | sed 's/DISTRIB_RELEASE="\([0-9]*\).*/\1/'`
        echo slc${slc_version}_ia32
  elif grep -q PU_IAS /etc/redhat-release 2>/dev/null; then
       if [ `uname -i` == i386 ]; then
           echo slc4_ia32
       else
           echo slc4_amd64
       fi
  else
    archos= archosv=
    for f in debian_version slackware-version fedora-release \
	     redhat-release altlinux-release gentoo-release \
	     cobalt-release mandrake-release conectiva-release; do
      if [ -f /etc/$f ]; then
	archos=`echo $f | sed 's/[-_].*//'`
	archosv=`tr -dc '[0-9]' < /etc/$f`
	break
      fi
    done
    [ X$archos = Xredhat ] && archos=rh
    if [ -z "$archos" -o -z "$archosv" ]; then
      echo linux`uname -r | cut -d. -f1,2 | tr -d .`
    else
      echo $archos$archosv
    fi
  fi
elif [ `uname` = Darwin ]; then
  if [ "`uname -m`" == "i386" ]
  then
	cputype=ia32
  else
	cputype=ppc32
  fi
  echo osx`sw_vers -productVersion | cut -d. -f1,2 | tr -dc [0-9]`_$cputype
elif [ `uname | cut -d_ -f1` = CYGWIN ]; then
  echo win32_ia32
else
  echo unsupported
fi
return 0
}

cmssoft_cmsarch() {
osarch=`cmssoft_cmsos`
compilerv=gcc323
# We need to assume 1 compiler per platform. 
# There is no other way around this.
if [ ! "$SCRAM_ARCH" ]
then
    case $osarch in
        slc3_ia32) compilerv=gcc323;;
        slc3_amd64) compilerv=gcc344;;
        slc4_ia32) compilerv=gcc345;;
        slc4_amd64) compilerv=gcc345;;
        osx104_ia32) compilerv=gcc401;;
        osx104_pcc32) compilerv=gcc400;;
    esac
    echo ${osarch}_${compilerv}
else
    echo $SCRAM_ARCH
fi
return 0
}

checkappfs() {
    appdir=`dirname $prefix`
    [ "x$osg_app" != "x" -a "x$VO_CMS_SW_DIR" != "x" ] && appdir=$VO_CMS_SW_DIR
    # Check if df -k works
    df -k >& /dev/null &
    theproc=$!
    i=0
    while : ; do
       i=`expr $i + 1`
       [ $i -gt 30 ] && { echo error in df -k ; kill -KILL $theproc ; return 1 ; } ;
       ps auxwww | grep $theproc | grep -q "df -[k]"
       [ $? -eq 0 ] || break
       sleep 1
    done
    # end of Check if df -k works
    dirdepth=100
    i=0
    for dir in $appdir ; do
        i=`expr $i + 1`
        echo -n ${i}:DIR_listing_${dir}
        thedirname=`df -k $dir | grep -v -i Filesystem`
        if [ ! -d $dir ] ; then
	   rdir=$dir
	   k=0
	   while : ; do
	      [ -d $rdir ] && break
	      [ "$rdir" == "/" -o $rdir == "." ] && { echo -n Dot_or_slash $rdir ; break ; } ;
              rdir=`dirname $rdir`
	      k=`expr $k + 1`
	      [ $k -gt $dirdepth ] && { echo -n Too_deep ; break ; } ;
	   done
	   echo $rdir | grep -q "^/"
	   [ $? -eq 0 ] || { echo -n dir_does_not_start_with_slash ; } ;
	   thedirname=`df -k $rdir | grep -v -i Filesystem` ;
	fi
        # if it is automount, give up and use /
        echo $thedirname | grep -q automount
        [ $? -eq 0 ] && thedirname=`df -k / | grep -v -i Filesystem`
        echo ":"$thedirname
    done
}

checkappfs_mtab() {
    themountpoint=$1 # `dirname $prefix` # $APPDIR
    if [ "x$osg_app" != "x" ] ; then
       themountpoint=$osg_app
    fi
    [ "x$osg_app" != "x" -a "x$VO_CMS_SW_DIR" != "x" ] && themountpoint=$VO_CMS_SW_DIR
    echo DEBUG themount point $themountpoint
    ik=0
    while [ $ik -lt 100 ] ; do
       ik=$(expr $ik + 1)
       echo DEBUG AAA $themountpoint
       [ "x$themountpoint" == "x/" ] && break
       grep -q " $themountpoint " /etc/mtab
       [ $? -eq 0 ] && break
       themountpoint=$(dirname $themountpoint)
    done
    echo $themountpoint
    return 0
}

# Extract scripts attached
cmssoft_execute_script() {
  # $1 script to extract
  # $2 this script
  # $3 the full script path where the script $1 is going to be extracted
  echo $1 $2 $3
  status_cmssoft_execute_script=0
  if [ $3 ] ; then
     perl -n -e 'print if /^####### BEGIN $1/ .. /^####### ENDIN $1/' < $2 | grep -v "$1" > $3
     if [ $? -ne 0 ] ; then
        echo ERROR cmssoft_execute_script failed to extract $1
        status_cmssoft_execute_script=1
     fi
     chmod +x $3 2>&1
     $3 ${project_version} $ARCH $prefix/cms 2>&1
     if [ $? -ne 0 ] ; then
        echo ERROR cmssoft_execute_script failed to execute $3
        status_cmssoft_execute_script=1
     fi
  else
     echo ERROR there was no argument $3
     return 1
  fi
  rm $3
  return $status_cmssoft_execute_script
}

##### Common aptinstall aptremove
aptremove_64_apt_get_remove() {
   #opt_apt_conf=" -c=$prefix/cms/${ARCH}/external/apt/${apt_version}/etc/apt.conf "
   arch2use=slc5_amd64_gcc462 # ${arch2use}
   if [ "x${ARCH}" == "x$arch2use" ] ; then
      echo ERROR ${SCRAM_ARCH} is $arch2use
      return 1
   fi
   if [ ! -d $prefix/cms ] ; then
      echo ERROR $prefix/cms not found
      return 1
   fi
   if [ "x$apt_version" == "x" ] ; then
      echo ERROR apt_version is empty
      return 1
   fi
   apt_version_64=`ls $prefix/cms/${arch2use}/external/apt/*/bin/apt-get | sed 's#/# #g' | awk '{print $(NF-2)}' | sort -u`
   nw=`echo $apt_version | wc -w`
   if [ $nw -gt 1 ] ; then
      apt_version=`echo $apt_version | awk '{print $NF}'`
   fi

   if [ -f $prefix/cms/${arch2use}/external/apt/${apt_version_64}/bin/apt-get ] ; then
      echo INFO apt-get version apt_version_64 found $apt_version_64
   else
      echo ERROR apt-get version not found apt_version_64 is $apt_version_64 
      echo "Forensic required " 1>&2
      return 1
   fi

   apt_get_binary=`which apt-get`
   # 64-bit apt-get if x86_64
   uname -a | grep -q x86_64
   if [ $? -eq 0 ] ; then
      echo INFO aptremove_64_apt_get_remove apt_version $apt_version_64
      apt_get_binary=$prefix/cms/${arch2use}/external/apt/${apt_version_64}/bin/apt-get
      apt_get_conf=$prefix/cms/${arch2use}/external/apt/${apt_version_64}/etc/apt.conf
      if [ -f $prefix/cms/${arch2use}/external/apt/${apt_version_64}/etc/profile.d/init.sh ] ; then # dependencies-setup.sh ] ; then
         . $prefix/cms/${arch2use}/external/apt/${apt_version_64}/etc/profile.d/init.sh # dependencies-setup.sh
      else
         echo ERROR this $prefix/cms/${arch2use}/external/apt/${apt_version_64}/etc/profile.d/init.sh # dependencies-setup.sh does not exist
         return 1
      fi
      export LD_LIBRARY_PATH=$prefix/cms/${arch2use}/external/apt/${apt_version_64}/lib:$LD_LIBRARY_PATH
      echo DEBUG check ldd apt-get for x86_64
      ldd $apt_get_binary
   fi
   if [ ! -x $apt_get_binary ] ; then
      echo ERROR apt_get_binary is not an executable `ls -al $apt_get_binary`
      return 1
   fi
   #apt_get_binary="$apt_get_binary $opt_apt_conf"
   echo INFO apt_get_binary $apt_get_binary
   # 64-bit apt-get if x86_64
   #fi # if [ "x${SCRAM_ARCH}" != "xslc4_amd64_gcc345" ] ; then
   echo INFO copying ARCH $SCRAM_ARCH/var/lib/rpm for apt-get install
   backup_rpm_db=$prefix/cms/${arch2use}/var/lib/rpm.${arch2use}.$(date -u +%s)
   cp -pR $prefix/cms/${arch2use}/var/lib/rpm $backup_rpm_db
   if [ ! -d $prefix/cms/${arch2use}/var/lib/rpm.fresh ] ; then
      mv $prefix/cms/${arch2use}/var/lib/rpm $prefix/cms/${arch2use}/var/lib/rpm.fresh
      [ $? -eq 0 ] || { echo ERROR rpm.fresh failed ; return 1 ; } ;
   fi
   if [ -d $prefix/cms/${arch2use}/var/lib/rpm ] ; then
      rm -rf $prefix/cms/${arch2use}/var/lib/rpm 
      #[ $? -eq 0 ] || { echo ERROR rpm.fresh failed ; return 1 ; } ;
   fi
   [ -d $prefix/cms/${arch2use}/var/lib/rpm ] && { echo ERROR $prefix/cms/${arch2use}/var/lib/rpm still exists ; return 1 ; } ;
   cp -pR $prefix/cms/${SCRAM_ARCH}/var/lib/rpm $prefix/cms/${arch2use}/var/lib/rpm

   echo INFO since copied from $SCRAM_ARCH to ${arch2use} rebuilding using rpmdb `which rpmdb`

   rm -f $prefix/cms/${arch2use}/var/lib/rpm/__db.00{1,2,3}
   rpmdb --define "_rpmlock_path $prefix/cms/${arch2use}/var/lib/rpm/lock" --rebuilddb --dbpath $prefix/cms/${arch2use}/var/lib/rpm
   if [ $? -ne 0 ] ; then
      echo ERROR rebuidling rpmdb failed "rpmdb --define ""_rpmlock_path $prefix/cms/${arch2use}/var/lib/rpm/lock" "--rebuilddb --dbpath $prefix/cms/${arch2use}/var/lib/rpm"
      mv $prefix/cms/${arch2use}/var/lib/rpm $prefix/cms/${arch2use}/var/lib/rpm.$SCRAM_ARCH
      mv $prefix/cms/${arch2use}/var/lib/rpm.fresh $prefix/cms/${arch2use}/var/lib/rpm
      return 1
   fi

   echo $FULL_HOSTNAME | grep -q -e "uscms1.fltech-grid3.fit.edu\|ce1.accre.vanderbilt.edu\|antaeus.hpcc.ttu.edu\|osgce64.hepgrid.uerj.br"
   if [ $? -eq 0 ] ; then # IS_LUSTRE -eq 1 ] ; then
         #echo INFO creating softlink /tmp$prefix/cms/${arch2use}/var/lib/rpm/__db.000 $prefix/cms/${arch2use}/var/lib/rpm/__db.000
         #[ -d /tmp$prefix/cms/${arch2use}/var/lib/rpm ] || mkdir -p /tmp$prefix/cms/${arch2use}/var/lib/rpm
         #if [ -d $prefix/cms/${arch2use}/var/lib/rpm -a -d /tmp$prefix/cms/${arch2use}/var/lib/rpm ] ; then
         #   ( touch /tmp$prefix/cms/${arch2use}/var/lib/rpm/__db.000 ;
         #     cd $prefix/cms/${thearch64}/var/lib/rpm ;
         #     if [ ! -L __db.000 ] ; then
         #        [ -f __db.000 ] && { echo INFO removing __db.000 ; rm -f __db.000 ; } ;
         #        ln -s /tmp$prefix/cms/${arch2use}/var/lib/rpm/__db.000 __db.000 ;
         #     fi
         #   )
         #fi
         files="${OSG_APP}/cmssoft/cms/${arch2use}/var/lib/rpm ${OSG_APP}/cmssoft/cms/${arch2use}/var/lib/apt/lists ${OSG_APP}/cmssoft/cms/${arch2use}/var/lib/cache/${arch2use} ${OSG_APP}/cmssoft/cms/${arch2use}/var/lib/rpm"
         for f in $files ; do
             echo INFO checking directory /tmp$f
             if [ ! -d /tmp$f ] ; then
                echo INFO creating the tmp directory: mkdir -p /tmp$f
                mkdir -p /tmp$f
                if [ $? -ne 0 ] ; then
                   echo ERROR mkdir -p /tmp$f failed
                   echo "Forensic required "
                   echo "Forensic required " 1>&2
                   #rm -f ${OSG_APP}/cmssoft/var/cmssoft/.cmssoft_install_circle_locked
                   return 1
                fi
             fi
         done
         echo INFO checking necessary lock files and create them as necessary
         files="${OSG_APP}/cmssoft/cms/${arch2use}/var/lib/rpm/__db.0 ${OSG_APP}/cmssoft/cms/${arch2use}/var/lib/apt/lists/lock ${OSG_APP}/cmssoft/cms/${arch2use}/var/lib/cache/${arch2use}/lock ${OSG_APP}/cmssoft/cms/${arch2use}/var/lib/rpm/lock ${OSG_APP}/cmssoft/cms/${arch2use}/var/lib/rpm/__db.000"
         for f in $files ; do
           echo INFO checking the lock file /tmp$f
           if [ ! -f /tmp$f ] ; then
              echo INFO touch /tmp$f
              touch /tmp$f
              if [ $? -ne 0 ] ; then
                 echo ERROR touch /tmp$f failed
                 echo "Forensic required "
                 echo "Forensic required " 1>&2
                 #rm -f ${OSG_APP}/cmssoft/var/cmssoft/.cmssoft_install_circle_locked
                 return 1
              fi
           fi
           echo INFO Checking any stale link
           [ -f $f ] || { [ -L $f ] && { echo INFO removing the stale link ; ls -al $f ; rm -f $f ; } ; } ;
           echo INFO checking the lock file $f
           if [ ! -L $f ] ; then
              echo INFO rm -f $f
              rm -f $f
              if [ $? -ne 0 ] ; then
                 echo ERROR rm -f $f failed
                 echo "Forensic required "
                 echo "Forensic required " 1>&2
                 #rm -f ${OSG_APP}/cmssoft/var/cmssoft/.cmssoft_install_circle_locked
                 return 1
              fi
              echo INFO ln -s /tmp$f $f
              ln -s /tmp$f $f
              if [ $? -ne 0 ] ; then
                 echo ERROR ln -s /tmp$f $f failed
                 echo "Forensic required "
                 echo "Forensic required " 1>&2
                 #rm -f ${OSG_APP}/cmssoft/var/cmssoft/.cmssoft_install_circle_locked
                 return 1
              fi
           fi
           echo INFO checking $f again
           ls -al $f
           [ $? -eq 0 ] || { echo ERROR ls -al $f failed ; echo "Forensic required " 1>&2 ; return 1 ; } ;
           echo INFO checking /tmp$f
           ls -al /tmp$f
           [ $? -eq 0 ] || { echo ERROR ls -al /tmp$f failed ; echo "Forensic required " 1>&2 ; return 1 ; } ;
         done
   fi # if [ $? -eq 0 ] ; then # if [ $IS_LUSTRE -eq 1 ] ; then
   echo INFO rpmdb rebuild in ${arch2use} checking rpm -qa
   rpm --dbpath $prefix/cms/${arch2use}/var/lib/rpm -qa

   echo INFO Executing "${apt_get_binary} --assume-yes remove $apt_get_project   "
   #${apt_get_binary} remove --assume-yes cms+cmssw+${theproject}   
   echo INFO which rpm-wrapper : `which rpm-wrapper`
   #echo INFO Executing "apt-get -c=$apt_get_conf --assume-yes remove cms+cmssw+${theproject}   "
   echo INFO APT_CONFIG $APT_CONFIG
   #${apt_get_binary} -c=$apt_get_conf --assume-yes remove cms+cmssw+${theproject}   
   echo INFO executing ${apt_get_binary} --assume-yes remove $apt_get_project
   ${apt_get_binary} --assume-yes remove $apt_get_project   
   if [ $? -ne 0 ] ; then
      echo ERROR failed "${apt_get_binary} remove --assume-yes $apt_get_project"
      return 1
   fi

   echo INFO restoring ${arch2use}/var/lib/rpm to $SCRAM_ARCH/var/lib/rpm
   [ -d $prefix/cms/${SCRAM_ARCH}/var/lib/rpm.3 ] && rm -rf $prefix/cms/${SCRAM_ARCH}/var/lib/rpm.3
   [ -d $prefix/cms/${SCRAM_ARCH}/var/lib/rpm.2 ] && mv $prefix/cms/${SCRAM_ARCH}/var/lib/rpm.2 $prefix/cms/${SCRAM_ARCH}/var/lib/rpm.3
   [ -d $prefix/cms/${SCRAM_ARCH}/var/lib/rpm.1 ] && mv $prefix/cms/${SCRAM_ARCH}/var/lib/rpm.1 $prefix/cms/${SCRAM_ARCH}/var/lib/rpm.2
   [ -d $prefix/cms/${SCRAM_ARCH}/var/lib/rpm ] && mv $prefix/cms/${SCRAM_ARCH}/var/lib/rpm $prefix/cms/${SCRAM_ARCH}/var/lib/rpm.1
   
   cp -pR $prefix/cms/${arch2use}/var/lib/rpm $prefix/cms/${SCRAM_ARCH}/var/lib/

   echo INFO getting rid of $SCRAM_ARCH rpm db from $arch2use. If necessary use $backup_rpm_db
   rm -rf $prefix/cms/${arch2use}/var/lib/rpm
   cp -pR $prefix/cms/${arch2use}/var/lib/rpm.fresh $prefix/cms/${arch2use}/var/lib/rpm

   echo INFO restroing $SCRAM_ARCH apt env

   if [ -f $prefix/cms/${SCRAM_ARCH}/external/apt/${apt_version}/etc/profile.d/init.sh ] ; then
      . $prefix/cms/${SCRAM_ARCH}/external/apt/${apt_version}/etc/profile.d/init.sh
   else
      echo ERROR $prefix/cms/${SCRAM_ARCH}/external/apt/${apt_version}/etc/profile.d/init.sh not found
      return 1
   fi
if [ ] ; then
   echo INFO since copied from ${arch2use} to $SCRAM_ARCH rebuilding rpmdb `which rpmdb`
   
   rm -f $prefix/cms/${SCRAM_ARCH}/var/lib/rpm/__db.00{1,2,3}
   rpmdb --define "_rpmlock_path $prefix/cms/${SCRAM_ARCH}/var/lib/rpm/lock" --rebuilddb --dbpath $prefix/cms/${SCRAM_ARCH}/var/lib/rpm
   if [ $? -ne 0 ] ; then
      echo ERROR rebuidling rpmdb failed "rpmdb --define ""_rpmlock_path $prefix/cms/${SCRAM_ARCH}/var/lib/rpm/lock" "--rebuilddb --dbpath $prefix/cms/${SCRAM_ARCH}/var/lib/rpm"
      return 1
   fi
   if [ $IS_LUSTRE -eq 1 ] ; then
         echo INFO creating softlink /var/tmp/cms/${SCRAM_ARCH}/var/lib/rpm/__db.000 $prefix/cms/${SCRAM_ARCH}/var/lib/rpm/__db.000
         if [ -d $prefix/cms/${SCRAM_ARCH}/var/lib/rpm -a -d /var/tmp/cms/${SCRAM_ARCH}/var/lib/rpm ] ; then
            ( touch /var/tmp/cms/${SCRAM_ARCH}/var/lib/rpm/__db.000 ;
              cd $prefix/cms/${SCRAM_ARCH}/var/lib/rpm ;
              if [ ! -L __db.000 ] ; then
                 [ -f __db.000 ] && { echo INFO removing __db.000 ; rm -f __db.000 ; } ;
                 ln -s /var/tmp/cms/${SCRAM_ARCH}/var/lib/rpm/__db.000 __db.000 ;
              fi
            )
         fi
   fi # if [ $IS_LUSTRE -eq 1 ] ; then
   echo INFO rpmdb rebuild in $SCRAM_ARCH checking rpm -qa
   rpm --dbpath $prefix/cms/${SCRAM_ARCH}/var/lib/rpm -qa
fi # if [ ] ; then
   return 0
}
########################### BACK UP ###################################################################
