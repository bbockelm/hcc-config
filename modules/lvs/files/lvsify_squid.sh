#!/bin/sh

yum -y install arptables_jf

arptables -A IN -d 129.93.239.137 -j DROP
arptables -A OUT -s 129.93.239.137 -j mangle --mangle-ip-s `ifconfig bond0 | sed -n 's/.*inet addr:\([0-9.]\+\)\s.*/\1/p'`
service arptables_jf save
chkconfig --level 2345 arptables_jf on

ifconfig bond0:1 129.93.239.137 netmask 255.255.255.192 broadcast 129.93.239.191 up
