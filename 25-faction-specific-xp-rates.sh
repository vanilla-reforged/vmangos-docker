#!/bin/bash

# Configuration and data files
POPULATION_DATA_FILE="./vol/backup/population_data.csv"  # Correct path to population data file
CONFIG_FILE="./vol/configuration/mangosd.conf"  # Correct path to mangosd.conf file
DAYS_TO_KEEP=7

# Calculate the date 7 days ago
SEVEN_DAYS_AGO=$(date -d '7 days ago' '+%Y-%m-%d %H:%M:%S')

# Calculate the average online population for the last 7 days
ALLIANCE_AVG=$(awk -v date="$SEVEN_DAYS_AGO" -F, '$1 >= date { total += $2; count++ } END { if (count > 0) print total / count; else print 0; }' "$POPULATION_DATA_FILE")
HORDE_AVG=$(awk -v date="$SEVEN_DAYS_AGO" -F, '$1 >= date { total += $3; count++ } END { if (count > 0) print total / count; else print 0; }' "$POPULATION_DATA_FILE")

echo "Alliance average: $ALLIANCE_AVG, Horde average: $HORDE_AVG"

# Determine which faction is underpopulated
if (( $(echo "$ALLIANCE_AVG > $HORDE_AVG" | bc -l) )); then
    BALANCE_STATUS="Horde"
elif (( $(echo "$HORDE_AVG > $ALLIANCE_AVG" | bc -l) )); then
    BALANCE_STATUS="Alliance"
else
    BALANCE_STATUS="Balanced"
fi

echo "Balance status: $BALANCE_STATUS"

# Function to update the configuration file based on the population balance
update_config_file() {
    if [ "$BALANCE_STATUS" == "Alliance" ]; then
        echo "Horde is underpopulated. Updating XP rates for Horde to 1 and Alliance to 2."
        sed -i 's/^Rate\.XP\.Kill\.Horde = .*/Rate.XP.Kill.Horde = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Horde = .*/Rate.XP.Kill.Elite.Horde = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Alliance = .*/Rate.XP.Kill.Alliance = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Alliance = .*/Rate.XP.Kill.Elite.Alliance = 2/' "$CONFIG_FILE"
    elif [ "$BALANCE_STATUS" == "Horde" ]; then
        echo "Alliance is underpopulated. Updating XP rates for Alliance to 2 and Horde to 1."
        sed -i 's/^Rate\.XP\.Kill\.Alliance = .*/Rate.XP.Kill.Alliance = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Alliance = .*/Rate.XP.Kill.Elite.Alliance = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Horde = .*/Rate.XP.Kill.Horde = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Horde = .*/Rate.XP.Kill.Elite.Horde = 1/' "$CONFIG_FILE"
    else
        echo "Populations are balanced. Setting XP rates to 1 for both factions."
        sed -i 's/^Rate\.XP\.Kill\.Horde = .*/Rate.XP.Kill.Horde = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Horde = .*/Rate.XP.Kill.Elite.Horde = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Alliance = .*/Rate.XP.Kill.Alliance = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Alliance = .*/Rate.XP.Kill.Elite.Alliance = 1/' "$CONFIG_FILE"
    fi
}

# Function to restart VMangos server using tmux and docker attach
restart_server() {
    echo "Restarting VMangos server using tmux..."

    # Create a tmux session, attach to the Docker container, send the restart command
    tmux new-session -d -s vmangos_restart "docker attach vmangos-mangos"
    sleep 2  # Wait for the attach to complete

    # Send the server restart command within the tmux session
    tmux send-keys -t vmangos_restart "server restart 900" C-m

    # Wait a moment to ensure the command is processed
    sleep 2

    # Use tmux command to detach the client from the session without killing it
    tmux detach-client -s vmangos_restart

    echo "Server restart command sent with a 900-second delay."
}

# Clean up data older than 7 days
echo "Cleaning up old data..."
awk -v date="$SEVEN_DAYS_AGO" -F, '$1 >= date' "$POPULATION_DATA_FILE" > "./vol/backup/population_data.csv.tmp" && mv "./vol/backup/population_data.csv.tmp" "$POPULATION_DATA_FILE"

# Main execution flow
update_config_file
restart_server
