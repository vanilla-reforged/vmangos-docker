#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

#!/bin/bash

# Load environment variables from .env-script
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Install expect if it isn't already installed
sudo apt-get install expect

# Configuration and data files
POPULATION_DATA_FILE="$DOCKER_DIRECTORY/vol/faction-balancer/population_data.csv"  # Use $DOCKER_DIRECTORY for the population data file path
CONFIG_FILE="$DOCKER_DIRECTORY/vol/configuration/mangosd.conf"  # Use $DOCKER_DIRECTORY for the mangosd.conf file path
DAYS_TO_KEEP=7

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
    BALANCE_STATUS="Horde"
elif (( $(echo "$HORDE_PERCENT > 55" | bc -l) )) && (( $(echo "$ALLIANCE_PERCENT < 45" | bc -l) )); then
    BALANCE_STATUS="Alliance"
else
    BALANCE_STATUS="Balanced"
fi

echo "Balance status: $BALANCE_STATUS"

# Function to update the configuration file based on the population balance
update_config_file() {
    if [ "$BALANCE_STATUS" == "Alliance" ]; then
        echo "Horde is underpopulated. Updating XP rates for Horde to 1 and Alliance to 2."
        sed -i 's/^Rate\.XP\.Kill\.Horde = .*/Rate.XP.Kill.Horde = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Horde = .*/Rate.XP.Kill.Elite.Horde = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Alliance = .*/Rate.XP.Kill.Alliance = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Alliance = .*/Rate.XP.Kill.Elite.Alliance = 1/' "$CONFIG_FILE"
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

restart_server() {
    echo "Restarting VMangos server..."

    # Check if the VMangos Docker container is running
    if ! docker ps --format "{{.Names}}" | grep -q "^vmangos-mangos$"; then
        echo "Error: VMangos container 'vmangos-mangos' is not running."
        exit 1
    fi

    # Use expect to attach to the container, send the restart command, and detach
    expect << EOF
    spawn docker attach vmangos-mangos
    expect "#"
    send "server restart 900\r"
    expect "#"
    send "\035"  ;# This sends Ctrl+P
    send "\020"  ;# This sends Ctrl+Q
    expect eof
EOF

    echo "Server restart command sent with a 900-second delay and detached."
}

# Clean up data older than 7 days
echo "Cleaning up old data..."
awk -v date="$SEVEN_DAYS_AGO" -F, '$1 >= date' "$POPULATION_DATA_FILE" > "$DOCKER_DIRECTORY/vol/backup/population_data.csv.tmp" && mv "$DOCKER_DIRECTORY/vol/backup/population_data.csv.tmp" "$POPULATION_DATA_FILE"

# Main execution flow
update_config_file
restart_server
