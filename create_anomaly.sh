[root@nbuprimary ~]# cat create_anomaly.sh
#!/bin/bash
# anomalymatic v1.1

# Script needs no arguments. Just needs to be made executable.
#
# Before running the script:
# 1. Create a Standard unix policy named Anomaly_Detection and assign appropriate STU
# 2. Create a Schedule named FULL, do not add any execution window so it can only run manually
# 3. Add the name of your test server as the client
# 4. Specify /data as the only path to backup
# 5. Run the script and wait for it to finish

BASE=/data

# Max files to create per directory
NUMFILES=20000

rm -rf ${BASE}/ransom-files.tar

for count in {1..5}
do

    EPOCH=`date '+%s' && echo $EPOCHSECONDS`
    NEWDIR=${BASE}/${EPOCH}
    mkdir -p ${NEWDIR}

    cd ${NEWDIR}
    echo "`date` Info: Creating ${NUMFILES} files in ${NEWDIR}... (${count}/5)"

    ( seq -w 1 ${NUMFILES} | xargs -n1 -I% sh -c "dd if=/dev/urandom of=file.% bs=$(shuf -i1-10 -n1) count=1024" 2>&1 ) > /dev/null

done

###> Backup ${BASE} 10 times <###

for count in {1..10}
do
   echo "`date` Info: Backup normal files in ${BASE}... (${count}/10)"

   # call bpbackup to backup /data and wait until done

   /usr/openv/netbackup/bin/bpbackup -i -p Anomaly_Detection -s FULL

   sleep 10 # <- delay to give job time to start

   while true
   do
      if [ "`/usr/openv/netbackup/bin/admincmd/bpdbjobs | grep Anomaly_Detection | egrep \"Active|Queued\"`" = "" ]
      then
         break
      fi

      sleep 10
   done

done

###> tar and delete all directories in ${BASE} <###

echo "`date` Info: TAR and delete all directories in ${BASE}..."

( tar cvf ${BASE}/ransom-files.tar ${BASE}/164* 2>&1 ) > /dev/null

rm -rf ${BASE}/164*

cd ${BASE}

###> Backup ${BASE} 10 times <###

for count in {1..10}
do
   echo "`date` Info: Backup ransomed files in ${BASE}... (${count}/10)"

   # call bpbackup to backup /data and wait until done

   /usr/openv/netbackup/bin/bpbackup -i -p Anomaly_Detection -s FULL

   sleep 10 # <- delay to give job time to start

   while true
   do
      if [ "`/usr/openv/netbackup/bin/admincmd/bpdbjobs | grep Anomaly_Detection | egrep \"Active|Queued\"`" = "" ]
      then
         break
      fi

      sleep 10
   done

done

echo "`date` Info: All done, go back to the UI and refresh it"

exit 0
