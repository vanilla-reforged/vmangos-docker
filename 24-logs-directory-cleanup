#!/bin/bash

# Clean out all contents from vol/logs/mangos older than 3 days, excluding the honor folder
find vol/logs/mangos -mindepth 1 -maxdepth 1 -type d ! -name "honor" -exec find {} -type f -mtime +3 -exec rm -f {} \;

# Clean out all contents from vol/logs/mangos/honor older than 2 weeks
find vol/logs/mangos/honor -type f -mtime +14 -exec rm -f {} \;

# Clean out all contents from vol/logs/realmd older than 1 week
find vol/logs/realmd -type f -mtime +7 -exec rm -f {} \;

echo "Cleanup completed."
