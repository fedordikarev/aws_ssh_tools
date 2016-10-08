#!/bin/sh

XSSHTRIES=5
XSSHSLEEPTIME=5
CHECKSLEEPTIME=20

# Example .ssh/config
# Host *
  # StrictHostKeyChecking no
  # ControlPath ~/.ssh/master-%r@%h:%p
  # ConnectionAttempts 5
  # ConnectTimeout 5
  # TCPKeepAlive no
  # ServerAliveCountMax 9
  # ServerAliveInterval 10
#

SSH="ssh -q -o StrictHostKeyChecking=no -o ControlPath=~/.ssh/master-%r@%h:%p"

# Helpers functions

x_ssh_connect() {
  attempts=0
  rc=255
  while [ \( $attempts -lt $XSSHTRIES \) -a \( $rc -eq 255 \) ]; do
    $SSH -o BatchMode=yes -o ControlMaster=yes -f -N "$@"
    rc=$?
    [ $rc -ne 0 ] && sleep $XSSHSLEEPTIME
    attempts=$(( $attempts + 1 ))
  done
  return $rc
}

x_ssh() { $SSH -o BatchMode=yes "$@"; }
x_ssh_pure() { $SSH -o BatchMode=yes -S none "$@"; }
x_scp() { scp -B "$@"; }

x_try_connect() { $SSH -O check "$@" 2>/dev/null || x_ssh_connect "$@" || return 1; }
x_check_vm() {
  READY=0
  VMLIST=$1

  while [ $READY -eq 0 ]; do
    READY=1
    for vm in $VMLIST; do 
      x_try_connect $vm
      if [ $? -ne 0 ]; then
        READY=0
        echo "Host $vm is not ready yet"
        break
      fi
    done
    [ $READY -ne 1 ] && sleep $CHECKSLEEPTIME
  done
}

x_ssh_disconnect() { $SSH -o BatchMode=yes -O exit "$@"; }

x_longrun() {
  host=$1
  shift

run_locked='#!/bin/sh

lock=$1
exitcode=$2
shift 2

flock -x $lock sh -c "$@"
echo $? > $exitcode'

dettach_run='#!/bin/sh

path=$1
shift

echo "logfile $path/output" > $path/screenrc
screen -m -d -L -c $path/screenrc \
  $path/run_locked.sh $path/run.lock $path/exitcode "$@"
'

  path=$(x_ssh $host mktemp -d longrun.XXXX -p /var/tmp )
  echo "$run_locked" | x_ssh $host "cat - > $path/run_locked.sh"
  echo "$dettach_run" | x_ssh $host "cat - > $path/dettach_run.sh"
  x_ssh $host "chmod u+x $path/run_locked.sh $path/dettach_run.sh"
  x_ssh $host "$path/dettach_run.sh $path \"$@\""
  echo $path
}

x_longpull() {
  host=$1
  path=$2

  x_ssh $host flock -n $path/run.lock true
  return $?
}
