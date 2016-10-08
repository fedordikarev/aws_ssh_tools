#!/bin/sh

source ./aws_ssh_tools.sh

host=ec2-52-57-88-237.eu-central-1.compute.amazonaws.com

x_ssh_connect $host 
if [ $? -ne 0 ]; then
  echo "Failed to connect to $host"; 
  exit 1
fi

###
# Usage: path=$( x_longrun $host "$cmd" )
# and $path will be used in x_longpull to distinguish different jobs
###
path=`x_longrun $host \
 "cd work;
 [ -f nginx-1.11.4/objs/nginx ] && exit 0;
 [ ! -f nginx-1.11.4.tar.gz ] && wget http://nginx.org/download/nginx-1.11.4.tar.gz;
 tar xzf nginx-1.11.4.tar.gz;
 cd nginx-1.11.4;
 ./configure;
 make"`

rc=1
printf "Building: "
while [ $rc -ne 0 ]; do
 x_longpull $host $path
 rc=$?
 [ $rc -ne 0 ] && printf "."
 [ $rc -ne 0 ] && sleep 5
done

x_ssh $host cat $path/output
x_ssh $host cat $path/exitcode

path=`x_longrun $host \
 "cd work;
 [ ! -f nginx-tests.tgz ] && wget -c -N -O nginx-tests.tgz http://hg.nginx.org/nginx-tests/archive/tip.tar.gz;
 [ -d nginx-tests ] || mkdir nginx-tests;
 tar xzf nginx-tests.tgz -C nginx-tests;
 env TEST_NGINX_BINARY=\\\$HOME/work/nginx-1.11.4/objs/nginx prove -j16 nginx-tests/*"`

rc=1
printf "Prove: "
while [ $rc -ne 0 ]; do
 x_longpull $host $path
 rc=$?
 [ $rc -ne 0 ] && printf "."
 [ $rc -ne 0 ] && sleep 5
done

x_ssh $host cat $path/output
x_ssh $host cat $path/exitcode

x_ssh_disconnect $host
