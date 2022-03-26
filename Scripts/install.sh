#!/bin/bash
#########################################################################
# Title:         Grayplex Ansible Install Script                        #
# Author(s):     grayplex                                               #
# URL:           https://github.com/grayplex/Ansible-Deployment         #
# --                                                                    #
#########################################################################
#                   GNU General Public License v3.0                     #
#########################################################################

################################
# Variables
################################

VERBOSE=false
VERBOSE_OPT=""
GP_REPO="https://github.com/grayplex/Ansible-Deployment.git"
GP_PATH="/srv/git/Ansible-Deployment/Scripts"
GP_INSTALL_SCRIPT="$GP_PATH/install.sh"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

################################
# Functions
################################

run_cmd () {
  if $VERBOSE; then
      printf '%s\n' "+ $*" >&2;
      "$@"
  else
      "$@" > /dev/null 2>&1
  fi
}

################################
# Argument Parser
################################

while getopts 'v' f; do
  case $f in
  v)  VERBOSE=true
      VERBOSE_OPT="-v"
  ;;
  esac
done

################################
# Main
################################

# Check for supported Ubuntu Releases
release=$(lsb_release -cs)
 
# Add more releases like (focal|jammy)$
if [[ $release =~ (focal)$ ]]; then
    echo "$release is currently supported."
elif [[ $release =~ (jammy)$ ]]; then
    read -p "$release is currently in testing. Press enter to continue"
else
    echo "$release is currently not supported."
    exit 1
fi

# Check if using valid arch
arch=$(uname -m)

if [[ $arch =~ (x86_64)$ ]]; then
    echo "$arch is currently supported."
else
    echo "$arch is currently not supported."
    exit 1
fi

echo "Installing Grayplex Dependencies."

$VERBOSE || exec &>/dev/null

$VERBOSE && echo "Script Path: $SCRIPT_PATH"

# Update apt cache
run_cmd apt-get update

# Install git
run_cmd apt-get install -y git

# Remove existing repo folder
if [ -d "$GP_PATH" ]; then
    run_cmd rm -rf $GP_PATH;
fi

# Clone GP repo
run_cmd mkdir -p /srv/git
run_cmd git clone --branch master "${GP_REPO}" "$GP_PATH"

# Set chmod +x on script files
run_cmd chmod +x $GP_PATH/*.sh

$VERBOSE && echo "Script Path: $SCRIPT_PATH"
$VERBOSE && echo "Grayplex Install Path: "$GP_INSTALL_SCRIPT

## Create script symlinks in /usr/local/bin
shopt -s nullglob
for i in "$GP_PATH"/*.sh; do
    if [ ! -f "/usr/local/bin/$(basename "${i%.*}")" ]; then
        run_cmd ln -s "${i}" "/usr/local/bin/$(basename "${i%.*}")"
    fi
done
shopt -u nullglob

# Relaunch script from new location
if [ "$SCRIPT_PATH" != "$GP_INSTALL_SCRIPT" ]; then
    bash -H "$GP_INSTALL_SCRIPT" "$@"
    exit $?
fi

# Install Grayplex Dependencies
run_cmd bash -H $GP_PATH/dep.sh $VERBOSE_OPT

# Clone Grayplex Repo
run_cmd bash -H $GP_PATH/repo.sh -b master $VERBOSE_OPT