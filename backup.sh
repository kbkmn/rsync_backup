# #!/bin/sh

BACKUP_DIRECTORY="/home/backup"
EMAIL_RECIPIENTS="email@example.com"
KEY="$BACKUP_DIRECTORY/.ssh/id_rsa"

pid_file="$BACKUP_DIRECTORY/backup.pid"

backup(){
  project_name=$1
  address=$2
  port=$3

  process_log="$BACKUP_DIRECTORY/process.log"
  > $process_log

  error_log="$BACKUP_DIRECTORY/error.log"
  > $error_log

  destination="$BACKUP_DIRECTORY/data/$project_name"
  mkdir -p "$destination/latest"

  echo "[`date`] $project_name backup started" >> $process_log
  start=$(date +%s)
  start_time=$(date)

  rsync --archive --one-file-system --human-readable --delete -e "ssh -p $port -i $KEY" "$address" --exclude "cache" "$destination/latest" 1>>$process_log 2>$error_log

  echo "[`date`] $project_name backup ended" >> $process_log
  end=$(date +%s)
  end_time=$(date)

  echo "[`date`] RSYNC worked for $((end - start)) seconds" >> $process_log

  backup_name=$(date +%F_%H-%M)

  cp --archive --link "$destination/latest" "$destination/$backup_name"

  cp $process_log "$destination/$backup_name/"

  if [ $(cat $error_log | wc -l | bc ) -gt 0 ]; then
    cp $error_log "$destination/$backup_name/"

    (echo -e "$project_name backup started: $start_time\nRSYNC worked for $((end - start)) seconds\n$project_name backup ended: $end_time"; uuencode $process_log "process.txt"; uuencode $error_log "error.txt") | mail -s "$project_name backup: error" $EMAIL_RECIPIENTS
  else
    (echo -e "$project_name backup started: $start_time\nRSYNC worked for $((end - start)) seconds\n$project_name backup ended: $end_time"; uuencode $process_log "process.txt") | mail -s "$project_name backup: success" $EMAIL_RECIPIENTS
  fi

  rm $process_log
  rm $error_log
}

cleanup(){
  project_name=$1
  destination="$BACKUP_DIRECTORY/data/$project_name"

  find $destination -maxdepth 1 -type d -ctime +90 -exec rm -fr {} \;
}

echo $$ > $pid_file

cat backup.conf | while read project_name address port; do
  cleanup $project_name
  backup $project_name $address $port

  sleep 5m
done

rm $pid_file
