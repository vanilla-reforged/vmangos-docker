#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables from .env-script
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Configuration and data files
POPULATION_DATA_FILE="$DOCKER_DIRECTORY/vol/faction-balancer/population_data.csv"  # Use $DOCKER_DIRECTORY for the population data file path
CONFIG_FILE="$DOCKER_DIRECTORY/vol/configuration/mangosd.conf"  # Use $DOCKER_DIRECTORY for the mangosd.conf file path
DAYS_TO_KEEP=7

# Function to send message to Discord
send_discord_message() {
  local message=$1
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"$message\"}" \
       "$DISCORD_WEBHOOK"
}

# Calculate the date 7 days ago
SEVEN_DAYS_AGO=$(date -d '7 days ago' '+%Y-%m-%d %H:%M:%S')

# Calculate the average online population for the last 7 days
ALLIANCE_AVG=$(awk -v date="$SEVEN_DAYS_AGO" -F, '$1 >= date { total += $2; count++ } END { if (count > 0) print total / count; else print 0; }' "$POPULATION_DATA_FILE")
HORDE_AVG=$(awk -v date="$SEVEN_DAYS_AGO" -F, '$1 >= date { total += $3; count++ } END { if (count > 0) print total / count; else print 0; }' "$POPULATION_DATA_FILE")

echo "Alliance average: $ALLIANCE_AVG, Horde average: $HORDE_AVG"

# Calculate total average population
TOTAL_AVG=$(echo "$ALLIANCE_AVG + $HORDE_AVG" | bc -l)

if (( $(echo "$TOTAL_AVG > 0" | bc -l) )); then
    # Calculate percentages
    ALLIANCE_PERCENT=$(echo "scale=2; ($ALLIANCE_AVG / $TOTAL_AVG) * 100" | bc -l)
    HORDE_PERCENT=$(echo "scale=2; ($HORDE_AVG / $TOTAL_AVG) * 100" | bc -l)
else
    ALLIANCE_PERCENT=0
    HORDE_PERCENT=0
fi

echo "Alliance percentage: $ALLIANCE_PERCENT%, Horde percentage: $HORDE_PERCENT%"

# Determine if the ratio is worse than 55% to 45%
if (( $(echo "$ALLIANCE_PERCENT > 55" | bc -l) )) && (( $(echo "$HORDE_PERCENT < 45" | bc -l) )); then
    OVERPOP_STATUS="Alliance"
elif (( $(echo "$HORDE_PERCENT > 55" | bc -l) )) && (( $(echo "$ALLIANCE_PERCENT < 45" | bc -l) )); then
    OVERPOP_STATUS="Horde"
else
    BALANCE_STATUS="Balanced"
fi

echo "Balance status: $BALANCE_STATUS"

# Function to update the configuration file based on the population balance
update_config_file() {
    local update_message=""
    if [ "$OVERPOP_STATUS" == "Alliance" ]; then
        echo "Horde is underpopulated. Updating XP rates for Horde to 1 and Alliance to 2."
        update_message="Horde is underpopulated. Setting Horde XP rate to 1 and Alliance XP rate to 2."
        sed -i 's/^Rate\.XP\.Kill\.Horde = .*/Rate.XP.Kill.Horde = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Horde = .*/Rate.XP.Kill.Elite.Horde = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Alliance = .*/Rate.XP.Kill.Alliance = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Alliance = .*/Rate.XP.Kill.Elite.Alliance = 1/' "$CONFIG_FILE"
    elif [ "$OVERPOP_STATUS" == "Horde" ]; then
        echo "Alliance is underpopulated. Updating XP rates for Alliance to 2 and Horde to 1."
        update_message="Alliance is underpopulated. Setting Alliance XP rate to 2 and Horde XP rate to 1."
        sed -i 's/^Rate\.XP\.Kill\.Alliance = .*/Rate.XP.Kill.Alliance = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Alliance = .*/Rate.XP.Kill.Elite.Alliance = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Horde = .*/Rate.XP.Kill.Horde = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Horde = .*/Rate.XP.Kill.Elite.Horde = 1/' "$CONFIG_FILE"
    else
        echo "Populations are balanced. Setting XP rates to 1 for both factions."
        update_message="Populations are balanced. Setting both Alliance and Horde XP rates to 1."
        sed -i 's/^Rate\.XP\.Kill\.Horde = .*/Rate.XP.Kill.Horde = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Horde = .*/Rate.XP.Kill.Elite.Horde = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Alliance = .*/Rate.XP.Kill.Alliance = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Alliance = .*/Rate.XP.Kill.Elite.Alliance = 1/' "$CONFIG_FILE"
    fi

    # Send update message to Discord
    send_discord_message "Population balance: Alliance: $ALLIANCE_PERCENT%, Horde: $HORDE_PERCENT%. $update_message"
}

restart_server() {
    echo "[VMaNGOS]: Restarting environment..."
    expect <<EOF
        set timeout -1  ;# Wait indefinitely for the process to finish
        # Start docker attach
        spawn sudo docker attach vmangos-mangos
        # Wait for 2 seconds to ensure the session is fully attached
        sleep 2
        # Send the command to restart the server gracefully
        send "server restart 900\r"
        # Wait for 5 seconds to ensure the command is processed
        sleep 5
        # Simulate Ctrl+P
        send "\x10"
        # Brief delay before simulating Ctrl+Q
        sleep 1
        # Simulate Ctrl+Q
        send "\x11"
        # End the expect script
        expect eof
EOF
}

# Clean up data older than 7 days
echo "Cleaning up old data..."
awk -v date="$SEVEN_DAYS_AGO" -F, '$1 >= date' "$POPULATION_DATA_FILE" > "$DOCKER_DIRECTORY/vol/backup/population_data.csv.tmp" && mv "$DOCKER_DIRECTORY/vol/backup/population_data.csv.tmp" "$POPULATION_DATA_FILE"

# Main execution flow
update_config_file
restart_server
