#!/bin/bash
#########################################################################
# Title:         Grayplex Repo Cloner Script                            #
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
BRANCH='master'
GRAYPLEX_PATH="/srv/git/Ansible-Deployment"
GRAYPLEX_REPO="https://github.com/grayplex/Ansible-Deployment.git"

################################
# Functions
################################

usage () {
    echo "Usage:"
    echo "    gp_repo -b <branch>    Repo branch to use. Default is 'master'."
    echo "    gp_repo -v             Enable Verbose Mode."
    echo "    gp_repo -h             Display this help message."
}

################################
# Argument Parser
################################

while getopts ':b:vh' f; do
    case $f in
    b)  BRANCH=$OPTARG;;
    v)  VERBOSE=true;;
    h)
        usage
        exit 0
        ;;
    \?)
        echo "Invalid Option: -$OPTARG" 1>&2
        echo ""
        usage
        exit 1
        ;;
    esac
done

################################
# Main
################################

$VERBOSE || exec &>/dev/null

$VERBOSE && echo "git branch selected: $BRANCH"

## Clone Grayplex and pull latest commit
if [ -d "$GRAYPLEX_PATH" ]; then
    if [ -d "$GRAYPLEX_PATH/.git" ]; then
        cd "$GRAYPLEX_PATH" || exit
        git fetch --all --prune
        # shellcheck disable=SC2086
        git checkout -f $BRANCH
        # shellcheck disable=SC2086
        git reset --hard origin/$BRANCH
        git submodule update --init --recursive
        $VERBOSE && echo "git branch: $(git rev-parse --abbrev-ref HEAD)"
    else
        cd "$GRAYPLEX_PATH" || exit
        rm -rf library/
        git init
        git remote add origin "$GRAYPLEX_REPO"
        git fetch --all --prune
        # shellcheck disable=SC2086
        git branch $BRANCH origin/$BRANCH
        # shellcheck disable=SC2086
        git reset --hard origin/$BRANCH
        git submodule update --init --recursive
        $VERBOSE && echo "git branch: $(git rev-parse --abbrev-ref HEAD)"
    fi
else
    # shellcheck disable=SC2086
    git clone -b $BRANCH "$GRAYPLEX_REPO" "$GRAYPLEX_PATH"
    cd "$GRAYPLEX_PATH" || exit
    git submodule update --init --recursive
    $VERBOSE && echo "git branch: $(git rev-parse --abbrev-ref HEAD)"
fi

## Copy settings and config files into Grayplex folder
shopt -s nullglob
for i in "$GRAYPLEX_PATH"/defaults/*.default; do
    if [ ! -f "$GRAYPLEX_PATH/$(basename "${i%.*}")" ]; then
        cp -n "${i}" "$GRAYPLEX_PATH/$(basename "${i%.*}")"
    fi
done
shopt -u nullglob

## Activate Git Hooks
cd "$GRAYPLEX_PATH" || exit
bash "$GRAYPLEX_PATH"/bin/git/init-hooks