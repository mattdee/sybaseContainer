#!/bin/bash
#
#
   #===================================================================================
   #
   #         FILE: sybaseContainer.sh
   #
   #        USAGE: ./sybaseContainer.sh [start|stop|restart|bash|root|sql|adminsql|status|remove|copyin|copyout|help]
   #
   #  DESCRIPTION: Sybase container management script for Docker or Podman
   #      OPTIONS: See menu or command line arguments
   # REQUIREMENTS: Docker or Podman, internet connection for first image pull
   #       AUTHOR: Matt D
   #      CREATED: 10.12.2026
   #      VERSION: 1.1
   #
   #===================================================================================

# Reference --> https://hub.docker.com/r/datagrip/sybase

#===========================
# Global Variables
#===========================

SYBASE_CONTAINER="${SYBASE_CONTAINER:-mysybase}"
SYBASE_IMAGE="${SYBASE_IMAGE:-datagrip/sybase:16.0}"
SYBASE_PORT="${SYBASE_PORT:-5000}"
SYBASE_CONTAINER_PORT="${SYBASE_CONTAINER_PORT:-5000}"
SYBASE_NETWORK="${SYBASE_NETWORK:-sybasenet}"
SYBASE_SERVER="${SYBASE_SERVER:-MYSYBASE}"
SYBASE_LOGIN="${SYBASE_LOGIN:-matt}"
SYBASE_LOGIN_PASSWORD="${SYBASE_LOGIN_PASSWORD:-guest1234}"
SYBASE_LOGIN_DB="${SYBASE_LOGIN_DB:-testdb}"
SYBASE_ADMIN_USER="${SYBASE_ADMIN_USER:-sa}"
SYBASE_ADMIN_PASSWORD="${SYBASE_ADMIN_PASSWORD:-myPassword}"
CONTAINER_ENGINE="${CONTAINER_ENGINE:-}"
CONTAINER_PORT_MAP="-p ${SYBASE_PORT}:${SYBASE_CONTAINER_PORT}"
MAX_INVALID=3
INVALID_COUNT=0

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#===========================
# Helper Functions
#===========================

logInfo() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

logWarning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

logError() {
    echo -e "${RED}[ERROR]${NC} $1"
}

logSuccess() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

displayMenu() {
    clear
    echo -e "${CYAN}===========================================================================${NC}"
    echo -e "${CYAN}                  Sybase Container Management Script                       ${NC}"
    echo -e "${CYAN}===========================================================================${NC}"

    echo -e "\n${GREEN}Container Engine:${NC}"
    echo "  Active engine: $(getEngineName)"
    echo "  Override with: CONTAINER_ENGINE=docker $0 start"
    echo "                 CONTAINER_ENGINE=podman $0 start"

    echo -e "\n${GREEN}Container Management:${NC}"
    echo "  1) Start Sybase container          8) Show status"
    echo "  2) Stop Sybase container           9) Copy file into container"
    echo "  3) Restart Sybase container        10) Copy file out of container"
    echo "  4) Bash access                     11) Remove Sybase container"
    echo "  5) Root access                     12) Exit script"

    echo -e "\n${GREEN}Database Access:${NC}"
    echo "  6) SQL access                      7) Admin SQL access"

    echo -e "\n${CYAN}===========================================================================${NC}"
    read -p "Please enter your choice [1-12]: " menuChoice
    export menuChoice
}

getEngineName() {
    if [ -n "$CONTAINER_ENGINE" ]; then
        echo "$CONTAINER_ENGINE"
    elif command -v docker > /dev/null 2>&1; then
        echo "docker"
    elif command -v podman > /dev/null 2>&1; then
        echo "podman"
    else
        echo "none"
    fi
}

setContainerEngine() {
    if [ -z "$CONTAINER_ENGINE" ]; then
        CONTAINER_ENGINE="$(getEngineName)"
    fi

    case "$CONTAINER_ENGINE" in
        docker|podman)
            if ! command -v "$CONTAINER_ENGINE" > /dev/null 2>&1; then
                logError "$CONTAINER_ENGINE is not installed or not in PATH."
                exit 1
            fi
            ;;
        *)
            logError "No supported container engine found. Install Docker or Podman."
            logInfo "You can also set CONTAINER_ENGINE=docker or CONTAINER_ENGINE=podman."
            exit 1
            ;;
    esac
}

checkContainerEngine() {
    setContainerEngine

    engine_status=$("$CONTAINER_ENGINE" ps 2>&1)
    engine_status_code=$?

    if [ "$engine_status_code" -ne 0 ]; then
        if [ "$CONTAINER_ENGINE" = "podman" ]; then
            logWarning "Podman is installed but does not appear to be running."
            logInfo "Attempting to start the Podman machine..."
            podman machine start > /dev/null 2>&1 || {
                logError "Unable to start Podman. Please run 'podman machine start' and try again."
                exit 1
            }
        else
            logError "Docker is installed but does not appear to be running."
            logError "$engine_status"
            exit 1
        fi
    fi
}

createNetwork() {
    checkContainerEngine

    if ! "$CONTAINER_ENGINE" network inspect "$SYBASE_NETWORK" > /dev/null 2>&1; then
        logInfo "Creating ${CONTAINER_ENGINE} network '$SYBASE_NETWORK'..."
        "$CONTAINER_ENGINE" network create -d bridge "$SYBASE_NETWORK" > /dev/null
    fi
}

getContainerId() {
    checkContainerEngine
    "$CONTAINER_ENGINE" ps --filter "name=^/${SYBASE_CONTAINER}$" --format "{{.Names}}" | head -n 1
}

getAnyContainerId() {
    checkContainerEngine
    "$CONTAINER_ENGINE" container ls -a --filter "name=^/${SYBASE_CONTAINER}$" --format "{{.Names}}" | head -n 1
}

countDown() {
    message=${1:-"Please wait..."}
    seconds=${2:-5}

    logInfo "$message"
    for (( i=seconds; i>=1; i-- )); do
        echo -ne "\rStarting in $i seconds..."
        sleep 1
    done
    echo -e "\rReady.                         "
}

badChoice() {
    ((INVALID_COUNT++))

    logWarning "Invalid choice, please try again..."
    logWarning "Attempt $INVALID_COUNT of $MAX_INVALID."

    if [ "$INVALID_COUNT" -ge "$MAX_INVALID" ]; then
        logError "Too many invalid attempts. Exiting the script..."
        exit 1
    fi

    sleep 2
}

doNothing() {
    logWarning "You want to quit...yes?"
    read -p "Enter yes or no: " doWhat
    if [[ $doWhat = yes ]]; then
        logInfo "Bye!"
        exit 0
    fi
}

listPorts() {
    container_id=$(getContainerId)
    if [ -n "$container_id" ]; then
        logInfo "Container ports:"
        "$CONTAINER_ENGINE" port "$container_id"
    else
        logWarning "No running Sybase container found."
    fi
}

showStatus() {
    checkContainerEngine
    container_name=$(getAnyContainerId)

    if [ -z "$container_name" ]; then
        logWarning "Sybase container '$SYBASE_CONTAINER' does not exist."
        return
    fi

    logInfo "Container status:"
    "$CONTAINER_ENGINE" ps -a --filter "name=^/${SYBASE_CONTAINER}$" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    if [ -n "$(getContainerId)" ]; then
        listPorts
    fi
}

#===========================
# Core Functions
#===========================

startSybase() {
    checkContainerEngine
    createNetwork

    sybaseRunning=$(getContainerId)
    sybasePresent=$(getAnyContainerId)

    if [ "$sybaseRunning" = "$SYBASE_CONTAINER" ]; then
        logWarning "Sybase ${CONTAINER_ENGINE} container is already running."
        listPorts
        return
    elif [ "$sybasePresent" = "$SYBASE_CONTAINER" ]; then
        logInfo "Sybase ${CONTAINER_ENGINE} container found, restarting..."
        "$CONTAINER_ENGINE" restart "$sybasePresent"
        countDown "Waiting for Sybase to start" 5
    else
        logInfo "Provisioning new Sybase container with image: $SYBASE_IMAGE"
        "$CONTAINER_ENGINE" run -d -t \
            --network="$SYBASE_NETWORK" \
            $CONTAINER_PORT_MAP \
            --name "$SYBASE_CONTAINER" \
            "$SYBASE_IMAGE"

        if [ $? -ne 0 ]; then
            logError "Failed to start Sybase container."
            return 1
        fi

        logSuccess "Sybase container started successfully."
        countDown "Waiting for Sybase to initialize" 30
    fi

    showStatus
}

stopSybase() {
    checkContainerEngine
    sybaseRunning=$(getContainerId)

    if [ -z "$sybaseRunning" ]; then
        logWarning "No Sybase containers are running."
        return
    fi

    logInfo "Stopping container: $sybaseRunning"
    "$CONTAINER_ENGINE" stop "$sybaseRunning"

    if [ $? -eq 0 ]; then
        logSuccess "Container stopped successfully."
    else
        logError "Failed to stop container."
        return 1
    fi
}

restartSybase() {
    stopSybase
    startSybase
}

removeContainer() {
    checkContainerEngine
    sybasePresent=$(getAnyContainerId)

    if [ -z "$sybasePresent" ]; then
        logWarning "Sybase container '$SYBASE_CONTAINER' does not exist."
        return
    fi

    logInfo "Removing Sybase container: $sybasePresent"
    "$CONTAINER_ENGINE" rm -f "$sybasePresent"

    if [ $? -eq 0 ]; then
        logSuccess "Container removed successfully."
    else
        logError "Failed to remove container."
        return 1
    fi
}

bashAccess() {
    checkContainerEngine
    sybaseImage=$(getContainerId)

    if [ -z "$sybaseImage" ]; then
        logError "Sybase container is not running."
        return 1
    fi

    logInfo "Opening bash shell in container..."
    "$CONTAINER_ENGINE" exec -it "$sybaseImage" /bin/bash
}

rootAccess() {
    checkContainerEngine
    sybaseImage=$(getContainerId)

    if [ -z "$sybaseImage" ]; then
        logError "Sybase container is not running."
        return 1
    fi

    logInfo "Opening root shell in container..."
    "$CONTAINER_ENGINE" exec -it -u 0 "$sybaseImage" /bin/bash
}

escapeSqlString() {
    printf "%s" "$1" | sed "s/'/''/g"
}

validateRequiredValue() {
    name_value="$1"
    name_label="$2"

    if [ -z "$name_value" ]; then
        logError "$name_label cannot be empty."
        return 1
    fi
}

validateSqlIdentifier() {
    name_value="$1"
    name_label="$2"

    validateRequiredValue "$name_value" "$name_label" || return 1

    case "$name_value" in
        *[!a-zA-Z0-9_]*)
            logError "$name_label may only contain letters, numbers, and underscores."
            return 1
            ;;
    esac
}

ensureSqlLogin() {
    sybaseImage="$1"

    validateRequiredValue "$SYBASE_LOGIN" "SYBASE_LOGIN" || return 1
    validateSqlIdentifier "$SYBASE_LOGIN_DB" "SYBASE_LOGIN_DB" || return 1

    login_sql=$(escapeSqlString "$SYBASE_LOGIN")
    password_sql=$(escapeSqlString "$SYBASE_LOGIN_PASSWORD")
    database_sql=$(escapeSqlString "$SYBASE_LOGIN_DB")

    logInfo "Ensuring SQL login '$SYBASE_LOGIN' exists in database '$SYBASE_LOGIN_DB'..."

    provision_sql="
if not exists (select 1 from master..sysdatabases where name = '$database_sql')
begin
    create database $SYBASE_LOGIN_DB
end
go
if not exists (select 1 from master..syslogins where name = '$login_sql')
begin
    exec sp_addlogin '$login_sql', '$password_sql', '$database_sql'
end
go
use $SYBASE_LOGIN_DB
go
if not exists (select 1 from sysusers where name = '$login_sql')
begin
    exec sp_adduser '$login_sql', '$login_sql'
end
go
"

    printf "%s" "$provision_sql" | "$CONTAINER_ENGINE" exec -i \
        -e SYBASE_SERVER="$SYBASE_SERVER" \
        -e SYBASE_ADMIN_USER="$SYBASE_ADMIN_USER" \
        -e SYBASE_ADMIN_PASSWORD="$SYBASE_ADMIN_PASSWORD" \
        "$sybaseImage" \
        /bin/bash -lc '. /opt/sybase/SYBASE.sh >/dev/null 2>&1 || true; isql -S "$SYBASE_SERVER" -U "$SYBASE_ADMIN_USER" -P "$SYBASE_ADMIN_PASSWORD"' > /tmp/sybase_provision.out 2>&1

    if [ $? -ne 0 ]; then
        logError "Failed to provision SQL login '$SYBASE_LOGIN'."
        cat /tmp/sybase_provision.out
        return 1
    fi

    if grep -E "Msg [0-9]+, Level (1[1-9]|[2-9][0-9])" /tmp/sybase_provision.out > /dev/null 2>&1; then
        logError "SQL login provisioning reported an error."
        cat /tmp/sybase_provision.out
        return 1
    fi

    logSuccess "SQL login '$SYBASE_LOGIN' is ready."
}

sqlAccess() {
    checkContainerEngine
    sybaseImage=$(getContainerId)

    if [ -z "$sybaseImage" ]; then
        logError "Sybase container is not running."
        return 1
    fi

    ensureSqlLogin "$sybaseImage" || return 1

    logInfo "Opening isql as $SYBASE_LOGIN on database $SYBASE_LOGIN_DB..."
    exec_flags="-it"
    if [ ! -t 0 ]; then
        exec_flags="-i"
    fi

    "$CONTAINER_ENGINE" exec $exec_flags \
        -e SYBASE_SERVER="$SYBASE_SERVER" \
        -e SYBASE_LOGIN="$SYBASE_LOGIN" \
        -e SYBASE_LOGIN_PASSWORD="$SYBASE_LOGIN_PASSWORD" \
        -e SYBASE_LOGIN_DB="$SYBASE_LOGIN_DB" \
        "$sybaseImage" \
        /bin/bash -lc '. /opt/sybase/SYBASE.sh >/dev/null 2>&1 || true; isql -S "$SYBASE_SERVER" -U "$SYBASE_LOGIN" -P "$SYBASE_LOGIN_PASSWORD" -D "$SYBASE_LOGIN_DB"'
}

adminSqlAccess() {
    checkContainerEngine
    sybaseImage=$(getContainerId)

    if [ -z "$sybaseImage" ]; then
        logError "Sybase container is not running."
        return 1
    fi

    logInfo "Opening isql as $SYBASE_ADMIN_USER..."
    exec_flags="-it"
    if [ ! -t 0 ]; then
        exec_flags="-i"
    fi

    "$CONTAINER_ENGINE" exec $exec_flags \
        -e SYBASE_SERVER="$SYBASE_SERVER" \
        -e SYBASE_ADMIN_USER="$SYBASE_ADMIN_USER" \
        -e SYBASE_ADMIN_PASSWORD="$SYBASE_ADMIN_PASSWORD" \
        "$sybaseImage" \
        /bin/bash -lc '. /opt/sybase/SYBASE.sh >/dev/null 2>&1 || true; isql -S "$SYBASE_SERVER" -U "$SYBASE_ADMIN_USER" -P "$SYBASE_ADMIN_PASSWORD"'
}

copyIn() {
    checkContainerEngine
    sybaseRunning=$(getContainerId)

    if [ -z "$sybaseRunning" ]; then
        logError "Sybase container is not running."
        return 1
    fi

    read -p "Please enter the ABSOLUTE PATH to the file you want copied: " thePath
    read -p "Please enter the FILE NAME you want copied: " theFile

    if [ ! -f "$thePath/$theFile" ]; then
        logError "File does not exist: $thePath/$theFile"
        return 1
    fi

    logInfo "Copying file: $thePath/$theFile into container..."
    "$CONTAINER_ENGINE" cp "$thePath/$theFile" "$sybaseRunning:/tmp"

    if [ $? -eq 0 ]; then
        logSuccess "File copied successfully to /tmp/$theFile in the container."
    else
        logError "Failed to copy file into container."
        return 1
    fi
}

copyOut() {
    checkContainerEngine
    sybaseRunning=$(getContainerId)

    if [ -z "$sybaseRunning" ]; then
        logError "Sybase container is not running."
        return 1
    fi

    read -p "Please enter the ABSOLUTE PATH in the CONTAINER to the file you want copied to host: " thePath
    read -p "Please enter the FILE NAME in the CONTAINER you want copied: " theFile

    logInfo "Copying file: $sybaseRunning:$thePath/$theFile to host..."
    "$CONTAINER_ENGINE" cp "$sybaseRunning:$thePath/$theFile" /tmp/

    if [ $? -eq 0 ]; then
        logSuccess "File copied successfully to /tmp/$theFile on your host."
    else
        logError "Failed to copy file from container."
        return 1
    fi
}

showHelp() {
    echo -e "${BLUE}===========================================================================${NC}"
    echo -e "${BLUE}                  Sybase Container Management Script                       ${NC}"
    echo -e "${BLUE}===========================================================================${NC}"
    echo
    echo "Usage: $0 [command]"
    echo
    echo "Container Management Commands:"
    echo "  start    - Start or restart Sybase container"
    echo "  stop     - Stop the running Sybase container"
    echo "  restart  - Restart Sybase container"
    echo "  bash     - Bash access to container"
    echo "  root     - Root access to container"
    echo "  sql      - SQL access with the default application user"
    echo "  adminsql - SQL access with the default admin user"
    echo "  status   - Show container status and mapped ports"
    echo "  remove   - Remove the Sybase container"
    echo "  copyin   - Copy a local file into the container /tmp directory"
    echo "  copyout  - Copy a file from the container to host /tmp"
    echo "  help     - Show this help message"
    echo
    echo "Configuration:"
    echo "  CONTAINER_ENGINE=docker|podman  Select engine. Defaults to Docker, then Podman."
    echo "  SYBASE_CONTAINER=mysybase       Container name."
    echo "  SYBASE_IMAGE=datagrip/sybase:16.0 Container image."
    echo "  SYBASE_PORT=5000                Host port."
    echo "  SYBASE_CONTAINER_PORT=5000      Container port."
    echo "  SYBASE_NETWORK=sybasenet        Container network name."
    echo "  SYBASE_SERVER=MYSYBASE          Sybase server name for isql."
    echo "  SYBASE_LOGIN=tester             SQL user for the sql command."
    echo "  SYBASE_LOGIN_PASSWORD=guest1234 SQL password for the sql command."
    echo "  SYBASE_LOGIN_DB=testdb          SQL database for the sql command."
    echo "  SYBASE_ADMIN_USER=sa            SQL admin user for adminsql."
    echo "  SYBASE_ADMIN_PASSWORD=myPassword SQL admin password for adminsql."
    echo
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 sql"
    echo "  $0 adminsql"
    echo "  CONTAINER_ENGINE=podman $0 start"
    echo "  CONTAINER_ENGINE=docker $0 status"
    echo
    echo "If no command is provided, the script will start in interactive menu mode."
    echo -e "${BLUE}===========================================================================${NC}"
}

#===========================
# Main Program
#===========================

case "$1" in
    "start")
        logInfo "Starting container..."
        startSybase
        exit $?
        ;;
    "stop")
        logInfo "Stopping container..."
        stopSybase
        exit $?
        ;;
    "restart")
        logInfo "Restarting container..."
        restartSybase
        exit $?
        ;;
    "bash")
        logInfo "Attempting bash access..."
        bashAccess
        exit $?
        ;;
    "root")
        logInfo "Attempting root access..."
        rootAccess
        exit $?
        ;;
    "sql")
        logInfo "Attempting SQL access..."
        sqlAccess
        exit $?
        ;;
    "adminsql")
        logInfo "Attempting admin SQL access..."
        adminSqlAccess
        exit $?
        ;;
    "status")
        logInfo "Checking container status..."
        showStatus
        exit $?
        ;;
    "remove")
        logInfo "Removing container..."
        removeContainer
        exit $?
        ;;
    "copyin")
        copyIn
        exit $?
        ;;
    "copyout")
        copyOut
        exit $?
        ;;
    "help"|"-h"|"--help")
        showHelp
        exit 0
        ;;
    "")
        logInfo "No args provided. Starting menu interface..."
        ;;
    *)
        logError "Invalid argument: $1"
        logInfo "Run '$0 help' for usage information."
        exit 1
        ;;
esac

while true; do
    displayMenu

    case $menuChoice in
        1)
            startSybase
            ;;
        2)
            stopSybase
            ;;
        3)
            restartSybase
            ;;
        4)
            bashAccess
            ;;
        5)
            rootAccess
            ;;
        6)
            sqlAccess
            ;;
        7)
            adminSqlAccess
            ;;
        8)
            showStatus
            ;;
        9)
            copyIn
            ;;
        10)
            copyOut
            ;;
        11)
            removeContainer
            ;;
        12)
            doNothing
            ;;
        *)
            badChoice
            ;;
    esac

    if [[ $menuChoice =~ ^([1-9]|1[0-2])$ ]]; then
        INVALID_COUNT=0
    fi

    if [[ $menuChoice != 12 && $menuChoice =~ ^([1-9]|1[0-2])$ ]]; then
        echo
        read -p "Press Enter to continue..." dummy
    fi
done
