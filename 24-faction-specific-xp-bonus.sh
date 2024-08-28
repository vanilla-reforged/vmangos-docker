#!/bin/bash

# Hardcoded values
MARIADB_CONTAINER="vmangos_database"  # Correct MariaDB container name
DOCKER_CONTAINER="vmangos_mangos"  # Correct VMangos Docker container name
CONFIG_FILE="vol/configuration/mangosd.conf"  # Corrected path to mangosd.conf file

# Function to fetch population balance from the MariaDB container
fetch_population_balance() {
    # Run the script inside the MariaDB container to fetch the data
    RESULT=$(docker exec $MARIADB_CONTAINER /export-population-balance.sh 2>&1)

    # Check for errors in executing the script
    if echo "$RESULT" | grep -qi "permission denied"; then
        echo "Error: Permission denied when trying to run the script in the container."
        exit 1
    fi

    if echo "$RESULT" | grep -qi "error"; then
        echo "Error: Something went wrong. Output: $RESULT"
        exit 1
    fi

    # Read the results into variables
    read ALLIANCE_COUNT HORDE_COUNT <<< "$RESULT"

    # Check if the variables are valid integers
    if ! [[ "$ALLIANCE_COUNT" =~ ^[0-9]+$ ]] || ! [[ "$HORDE_COUNT" =~ ^[0-9]+$ ]]; then
        echo "Error fetching population data. Please check your database connection or if there are no online characters. Output: $RESULT"
        exit 1
    fi

    # Determine which faction is underpopulated
    if [ "$ALLIANCE_COUNT" -gt "$HORDE_COUNT" ]; then
        BALANCE_STATUS="Horde"
    elif [ "$HORDE_COUNT" -gt "$ALLIANCE_COUNT" ]; then
        BALANCE_STATUS="Alliance"
    else
        BALANCE_STATUS="Balanced"
    fi

    echo "Alliance: $ALLIANCE_COUNT, Horde: $HORDE_COUNT, Status: $BALANCE_STATUS"
}

# Function to update the configuration file based on the population balance
update_config_file() {
    if [ "$BALANCE_STATUS" == "Alliance" ]; then
        echo "Horde is underpopulated. Updating XP rates for Horde to 2."
        sed -i 's/^Rate\.XP\.Kill\.Horde = .*/Rate.XP.Kill.Horde = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Horde = .*/Rate.XP.Kill.Elite.Horde = 2/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Alliance = .*/Rate.XP.Kill.Alliance = 1/' "$CONFIG_FILE"
        sed -i 's/^Rate\.XP\.Kill\.Elite\.Alliance = .*/Rate.XP.Kill.Elite.Alliance = 1/' "$CONFIG_FILE"
    elif [ "$BALANCE_STATUS" == "Horde" ]; then
        echo "Alliance is underpopulated. Updating XP rates for Alliance to 2."
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
    tmux new-session -d -s vmangos_restart "docker attach $DOCKER_CONTAINER"
    sleep 2  # Wait for the attach to complete

    # Send the server restart command within the tmux session
    tmux send-keys -t vmangos_restart "server restart 900" C-m

    # Wait a moment to ensure the command is processed
    sleep 2

    # Use tmux command to detach the client from the session without killing it
    tmux detach-client -s vmangos_restart

    echo "Server restart command sent with a 900-second delay."
}

# Main execution flow
fetch_population_balance
update_config_file
restart_server
