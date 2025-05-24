#!/bin/bash

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

readonly TEMP_IMAGE="laravel-creator"
readonly TEMP_DOCKERFILE="Dockerfile.laravel-creator"
readonly ENTRYPOINT_SCRIPT="entrypoint.sh"

function check_dependency() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${RED}Error: $1 is required but not installed.${NC}"
        exit 1
    fi
}

function print_header() {
    echo -e "${RED} _                              _   ${NC}"
    echo -e "${RED}| |    __ _ _ __ __ ___   _____| |  ${NC}"
    echo -e "${RED}| |   / _\` | '__/ _\` \ \ / / _ \ |  ${NC}"
    echo -e "${RED}| |__| (_| | | | (_| |\ V /  __/ |  ${NC}"
    echo -e "${RED}|_____\__,_|_|  \__,_| \_/ \___|_|  ${NC}"
    echo -e "${RED}                                    ${NC}"
    echo -e "${RED}  ____                _             ${NC}"
    echo -e "${RED} / ___|_ __ ___  __ _| |_ ___  _ __ ${NC}"
    echo -e "${RED}| |   | '__/ _ \/ _\` | __/ _ \| '__|${NC}"
    echo -e "${RED}| |___| | |  __/ (_| | || (_) | |   ${NC}"
    echo -e "${RED} \____|_|  \___|\__,_|\__\___/|_|   ${NC}"
    echo ""
}

function cleanup() {
    echo -e "${BLUE}Cleaning up temporary files...${NC}"
    docker rmi "${TEMP_IMAGE}" >/dev/null 2>&1 || true
}

function handle_error() {
    echo -e "${RED}Error occurred at line $1${NC}"
    cleanup
    exit 1
}

function add_hosts_entry() {
    local domain="$1"
    local hosts_line="127.0.0.1 $domain"
    local hosts_file="/etc/hosts"

    if grep -q "^127\.0\.0\.1[[:space:]]*$domain\$" "$hosts_file"; then
        echo -e "${GREEN}Domain $domain already exists in hosts file.${NC}"
        return 0
    fi

    echo -e "${YELLOW}Adding $domain to hosts file (requires sudo)...${NC}"

    sudo cp "$hosts_file" "$hosts_file.bak.$(date +%Y%m%d%H%M%S)"

    echo "$hosts_line" | sudo tee -a "$hosts_file" >/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully added $domain to hosts file.${NC}"
    else
        echo -e "${RED}Failed to add entry to hosts file.${NC}"
        echo -e "${YELLOW}You may need to manually add the following line to your /etc/hosts file:${NC}"
        echo -e "${YELLOW}$hosts_line${NC}"
    fi
}

function normalize_to_domain() {
    local name="$1"
    echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' _' '-'
}

function setup_docker_environment() {
    local project_dir="$1"
    local domain="$2"
    local docker_template_dir="$(pwd)/docker/development"

    echo -e "${BLUE}Setting up Docker environment...${NC}"

    mkdir -p "$project_dir/docker/development"

    echo -e "${BLUE}Copying Docker templates...${NC}"
    cp -r "$docker_template_dir"/* "$project_dir/docker/development/"

    chmod 755 -R "$project_dir/docker/development"

    cp "$(pwd)/docker-compose.development.yml" "$project_dir/"

    echo -e "${BLUE}Configuring environment for ${domain}...${NC}"

    sed -i 's/{{APP_DOMAIN}}/'$domain'/g' "$project_dir/docker/development/nginx.conf"

    sed -i 's/{{APP_DOMAIN}}/'$domain'/g' "$project_dir/docker-compose.development.yml"

    if [ -f "$project_dir/.env" ]; then
        sed -i 's#APP_URL=http://localhost#APP_URL=http://'$domain'#g' "$project_dir/.env"
    fi

    echo -e "${GREEN}Docker environment configured for $domain${NC}"
}

trap 'handle_error $LINENO' ERR

check_dependency docker
check_dependency docker compose

if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

print_header

echo -e "${BLUE}Enter your project name:${NC} \c"
read user_project_name

if [[ ! $user_project_name =~ ^[[:alnum:]_.-]+$ ]]; then
    echo -e "${RED}Error: The name may only contain letters, numbers, dashes, underscores, and periods.${NC}"
    exit 1
fi

project_name=$(normalize_to_domain "$user_project_name")
domain_name="${project_name}.test"

echo -e "${YELLOW}Creating Laravel project named: ${NC}${project_name}"
echo -e "${YELLOW}Domain will be: ${NC}${domain_name}"
echo -e "${GREEN}Continue? (y/n):${NC} \c"
read confirm

if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo -e "${YELLOW}Operation cancelled.${NC}"
    exit 0
fi

echo -e "${BLUE}Preparing Docker environment...${NC}"

echo -e "${BLUE}Building temporary Docker image...${NC}"
docker build -t "${TEMP_IMAGE}" \
    --build-arg ENTRYPOINT_SCRIPT="${ENTRYPOINT_SCRIPT}" \
    -f "${TEMP_DOCKERFILE}" .

USER_ID=$(id -u)
GROUP_ID=$(id -g)

echo -e "${YELLOW}Initializing Laravel project... This might take a few minutes.${NC}"
docker run --rm -it \
    -v "$(pwd):/app" \
    "${TEMP_IMAGE}" bash -c "laravel new ${project_name}"

echo -e "${BLUE}Cleaning up temporary Docker image...${NC}"
cleanup

if [ -d "${project_name}" ]; then
    echo -e "${GREEN}Success! Laravel project '${project_name}' has been created.${NC}"

    find "${project_name}" -type d -exec chmod 755 {} \;
    find "${project_name}" -type f -exec chmod 644 {} \;

    add_hosts_entry "${domain_name}"

    setup_docker_environment "${project_name}" "${domain_name}"

    echo -e "${GREEN}Do you want to run the project right now? (y/n):${NC} \c"
    read confirm

    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo -e "${GREEN}Project is ready!${NC}"
        echo -e "${GREEN}You can start your project with:${NC}"
        echo -e "  cd ${project_name}"
        echo -e "  docker compose -f docker-compose.development.yml up -d"
        echo -e ""
        echo -e "${GREEN} and access your project at:${NC} http://${domain_name}"
    else
        echo -e "${BLUE}Starting the project...${NC}"
        cd ${project_name}
        docker compose -f docker-compose.development.yml up -d
        echo -e ""
        echo -e "${GREEN}Access your project at:${NC} http://${domain_name}"
    fi
else
    echo -e "${RED}Error: Failed to create the Laravel project.${NC}"
    exit 1
fi
