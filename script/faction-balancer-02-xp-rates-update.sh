#!/bin/bash

# Logger function for standardized logging
log_message() {
    local level="$1"
    local message="$2"
    local script_name=$(basename "$0")
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$script_name] [$level] $message"
}

# Change to the directory where the script is located
cd "$(dirname "$0")"
log_message "INFO" "Script started"

# Load environment variables from .env-script
log_message "INFO" "Loading environment variables"
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Configuration and data files
POPULATION_DATA_FILE="$DOCKER_DIRECTORY/vol/faction-balancer/population_data.csv"  # Use $DOCKER_DIRECTORY for the population data file path
CONFIG_FILE="$DOCKER_DIRECTORY/vol/configuration/mangosd.conf"  # Use $DOCKER_DIRECTORY for the mangosd.conf file path
DAYS_TO_KEEP=7
log_message "INFO" "Using population data file: $POPULATION_DATA_FILE"
log_message "INFO" "Using config file: $CONFIG_FILE"
log_message "INFO" "Days to keep data: $DAYS_TO_KEEP"

# Function to send message to Discord
send_discord_message() {
  local message=$1
  log_message "INFO" "Sending Discord message: $message"
  if curl -s -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"$message\"}" \
       "$DISCORD_WEBHOOK"; then
    log_message "SUCCESS" "Discord message sent successfully"
  else
    log_message "ERROR" "Failed to send Discord message"
  fi
}

# Calculate the date 7 days ago
SEVEN_DAYS_AGO=$(date -d '7 days ago' '+%Y-%m-%d %H:%M:%S')
log_message "INFO" "Analyzing data from the last 7 days (since $SEVEN_DAYS_AGO)"

# Calculate the average online population for the last 7 days
if [ -f "$POPULATION_DATA_FILE" ]; then
    ALLIANCE_AVG=$(awk -v date="$SEVEN_DAYS_AGO" -F, '$1 >= date { total += $2; count++ } END { if (count > 0) print total / count; else print 0; }' "$POPULATION_DATA_FILE")
    HORDE_AVG=$(awk -v date="$SEVEN_DAYS_AGO" -F, '$1 >= date { total += $3; count++ } END { if (count > 0) print total / count; else print 0; }' "$POPULATION_DATA_FILE")
    log_message "INFO" "Data loaded successfully from population file"
else
    log_message "WARNING" "Population data file not found, using zeros"
    ALLIANCE_AVG=0
    HORDE_AVG=0
fi

log_message "INFO" "Alliance average: $ALLIANCE_AVG, Horde average: $HORDE_AVG"

# Calculate total average population
TOTAL_AVG=$(echo "$ALLIANCE_AVG + $HORDE_AVG" | bc -l)

if (( $(echo "$TOTAL_AVG > 0" | bc -l) )); then
    # Calculate percentages
    ALLIANCE_PERCENT=$(echo "scale=2; ($ALLIANCE_AVG / $TOTAL_AVG) * 100" | bc -l)
    HORDE_PERCENT=$(echo "scale=2; ($HORDE_AVG / $TOTAL_AVG) * 100" | bc -l)
else
    log_message "WARNING" "Total average population is zero, setting equal percentages"
    ALLIANCE_PERCENT=50
    HORDE_PERCENT=50
fi

log_message "INFO" "Alliance percentage: $ALLIANCE_PERCENT%, Horde percentage: $HORDE_PERCENT%"

# Determine if the ratio is worse than 55% to 45%
OVERPOP_STATUS=""
BALANCE_STATUS=""
if (( $(echo "$ALLIANCE_PERCENT > 55" | bc -l) )) && (( $(echo "$HORDE_PERCENT < 45" | bc -l) )); then
    OVERPOP_STATUS="Alliance"
    log_message "INFO" "Population imbalance detected: Alliance overpopulated"
elif (( $(echo "$HORDE_PERCENT > 55" | bc -l) )) && (( $(echo "$ALLIANCE_PERCENT < 45" | bc -l) )); then
    OVERPOP_STATUS="Horde"
    log_message "INFO" "Population imbalance detected: Horde overpopulated"
else
    BALANCE_STATUS="Balanced"
    log_message "INFO" "Population is balanced"
fi

# Function to update the configuration file based on the population balance
update_config_file() {
    local update_message=""
    if [ "$OVERPOP_STATUS" == "Alliance" ]; then
        log_message "INFO" "Updating XP rates: Horde=2, Alliance=1"
        update_message="Horde is underpopulated. Setting Horde XP rate to 2 and Alliance XP rate to 1."
        sed -i 's/^Rate\.XP\.Kill\.Horde = .*/Rate.XP.Kill.Horde = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Horde = .*/Rate.XP.Kill.Elite.Horde = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Alliance = .*/Rate.XP.Kill.Alliance = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Alliance = .*/Rate.XP.Kill.Elite.Alliance = 1/' "$CONFIG_FILE"
    elif [ "$OVERPOP_STATUS" == "Horde" ]; then
        log_message "INFO" "Updating XP rates: Alliance=2, Horde=1"
        update_message="Alliance is underpopulated. Setting Alliance XP rate to 2 and Horde XP rate to 1."
        sed -i 's/^Rate\.XP\.Kill\.Alliance = .*/Rate.XP.Kill.Alliance = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Alliance = .*/Rate.XP.Kill.Elite.Alliance = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Horde = .*/Rate.XP.Kill.Horde = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Horde = .*/Rate.XP.Kill.Elite.Horde = 1/' "$CONFIG_FILE"
    else
        log_message "INFO" "Updating XP rates: Both factions=1"
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
    log_message "INFO" "Initiating server restart (15 minute countdown)"
    if expect <<EOF
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
    then
        log_message "SUCCESS" "Server restart command sent successfully (15 minute countdown)"
    else
        log_message "ERROR" "Failed to send server restart command"
    fi
}

# Clean up data older than 7 days
log_message "INFO" "Cleaning up old population data"
if [ -f "$POPULATION_DATA_FILE" ]; then
    # Create temp directory if it doesn't exist
    mkdir -p "$DOCKER_DIRECTORY/vol/backup"
    awk -v date="$SEVEN_DAYS_AGO" -F, '$1 >= date' "$POPULATION_DATA_FILE" > "$DOCKER_DIRECTORY/vol/backup/population_data.csv.tmp" && mv "$DOCKER_DIRECTORY/vol/backup/population_data.csv.tmp" "$POPULATION_DATA_FILE"
    log_message "SUCCESS" "Old population data cleaned up"
else
    log_message "WARNING" "Population data file not found, skipping cleanup"
fi

# Main execution flow
log_message "INFO" "Updating configuration file based on population balance"
update_config_file
log_message "INFO" "Initiating server restart"
restart_server
log_message "SUCCESS" "Script completed successfully"
