#deletes files found in the /backup directory after they reach an age of +7 days
find /backup/* -mtime +7 -exec rm {} \;
