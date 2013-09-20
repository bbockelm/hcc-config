#!/usr/bin/perl

$out = `/usr/lib64/nagios/plugins/check_mountpoints`;
if($out =~ "not" ) 
        {print "MOUNTS_OK = FALSE\n";}
        else
        {print "MOUNTS_OK = TRUE\n";}
if( -e "/mnt/hadoop/hello_world")
        {
                print "Root Hadoop Mount OK = TRUE\n";
        }
        else
        {
                print "Root Hadoop Mount OK = FALSE\n";
        }

if( -e "/chroot/sl6-v1/root/mnt/hadoop/hello_world")
        {
                print "Chroot Hadoop Mount OK = TRUE\n";
        }
        else
        {
                print "Chroot Hadoop Mount OK = FALSE\n";
        }
#if( -e "/cvmfs/cms.cern.ch/cmsset_default.sh")
#	{
#		print "CVMFS_OK = TRUE\n";
#	}
#	else
#	{
#		print "CVMFS_OK = FALSE\n";
#	}
if( -e "/chroot/sl6-v1/root/cvmfs/cms.cern.ch/cmsset_default.sh")
   {
      print "CHROOT_CVMFS_OK = TRUE\n";
   }
   else
   {
      print "CHROOT_CVMFS_OK = FALSE\n";
   } 

## Now with sssd check

my $ldap_status="SSSD FAILED";

my $exit=system("id uscmsPool1111");
if ($exit == 0){$ldap_status = "LDAP OK";}
print $ldap_status, "\n";               
