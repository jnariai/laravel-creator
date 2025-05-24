#!/bin/bash

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

readonly REMOTE_REPO_URL="https://raw.githubusercontent.com/jnariai/laravel-creator/refs/heads/main"
readonly TMP_IMAGE_NAME="laravel-creator"

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
    docker rmi "${TMP_IMAGE_NAME}" >/dev/null 2>&1 || true
    rm -rf tmp-laravel-creator
    echo -e "${GREEN}Cleanup completed.${NC}"
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
    local docker_dev_dir="${project_dir}/docker/development"
    local remote_docker_dev="${REMOTE_REPO_URL}/docker/development"
    local dockerfile_app="${remote_docker_dev}/Dockerfile.app"
    local dockerfile_sqlite="${remote_docker_dev}/Dockerfile.sqlite"
    local entrypoint_script="${remote_docker_dev}/entrypoint.sh"
    local nginx_conf="${remote_docker_dev}/nginx.conf"

    echo -e "${BLUE}Setting up Docker environment...${NC}"

    mkdir -p "$docker_dev_dir"

    echo -e "${BLUE}Copying Docker templates...${NC}"
    curl -sSL "$dockerfile_app" -o "$docker_dev_dir/Dockerfile.app"
    curl -sSL "$dockerfile_sqlite" -o "$docker_dev_dir/Dockerfile.sqlite"
    curl -sSL "$entrypoint_script" -o "$docker_dev_dir/entrypoint.sh"
    curl -sSL "$nginx_conf" -o "$docker_dev_dir/nginx.conf"

    chmod 755 -R "$docker_dev_dir"

    curl -sSL "${remote_docker_dev}/docker-compose.development.yml" -o "$project_dir/docker-compose.development.yml"

    echo -e "${BLUE}Configuring environment for ${domain}...${NC}"

    sed -i 's/{{APP_DOMAIN}}/'$domain'/g' "$docker_dev_dir/nginx.conf"
    sed -i 's/{{APP_DOMAIN}}/'$domain'/g' "$project_dir/docker-compose.development.yml"

    echo -e "${GREEN}Docker environment configured for $domain${NC}"
}

function setup_tmp_laravel_creator() {
    local remote_repo_url="${REMOTE_REPO_URL}/build"
    local tmp_laravel_creator_dir="tmp-laravel-creator"

    mkdir -p tmp-laravel-creator
    curl -sSL "${remote_repo_url}/docker-entrypoint.sh" -o tmp-laravel-creator/docker-entrypoint.sh
    chmod +x tmp-laravel-creator/docker-entrypoint.sh
    curl -sSL "${remote_repo_url}/Dockerfile.laravel-creator" -o tmp-laravel-creator/Dockerfile.laravel-creator

    echo -e "${BLUE}Building temporary Docker image...${NC}"
    docker build -t "${TMP_IMAGE_NAME}" \
        --build-arg ENTRYPOINT_SCRIPT="${tmp_laravel_creator_dir}/docker-entrypoint.sh" \
        -f "${tmp_laravel_creator_dir}/Dockerfile.laravel-creator" .

    USER_ID=$(id -u)
    GROUP_ID=$(id -g)

    echo -e "${YELLOW}Initializing Laravel project... This might take a few minutes.${NC}"
    docker run --rm -it \
        -v "$(pwd):/app" \
        "${TMP_IMAGE_NAME}" bash -c "laravel new ${project_name}"
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

setup_tmp_laravel_creator

cleanup

if [ -d "${project_name}" ]; then
    echo -e "${GREEN}Success! Laravel project '${project_name}' has been created.${NC}"

    find "${project_name}" -type d -exec chmod 755 {} \;
    find "${project_name}" -type f -exec chmod 644 {} \;

    add_hosts_entry "${domain_name}"

    setup_docker_environment "${project_name}" "${domain_name}"

    echo -e "${BLUE}Do you want to run the project right now? (y/n):${NC} \c"
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
