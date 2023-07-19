#deletes files found in the /backup directory after they reach an age of +7 days
find ./vol/backup/* -mtime +7 -exec rm {} \;
