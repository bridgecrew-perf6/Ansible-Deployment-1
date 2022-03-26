#!/bin/bash
#########################################################################
# Title:         Grayplex: Install Script                               #
# Author(s):     grayplex                                               #
# URL:           https://github.com/grayplex/Ansible-Deployment         #
# --                                                                    #
#########################################################################
#                   GNU General Public License v3.0                     #
#########################################################################

################################
# Privilege Escalation
################################

# Restart script in SUDO
# https://unix.stackexchange.com/a/28793

if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

################################
# Scripts
################################

source /srv/git/Ansible-Deployment/scripts/yaml.sh
create_variables /srv/git/Ansible-Deployment/accounts.yml

################################
# Variables
################################

# Ansible
ANSIBLE_PLAYBOOK_BINARY_PATH="/usr/local/bin/ansible-playbook"

# Grayplex
GRAYPLEX_REPO_PATH="/srv/git/Ansible-Deployment"
GRAYPLEX_PLAYBOOK_PATH="$GRAYPLEX_REPO_PATH/grayplex.yml"
GRAYPLEX_LOGFILE_PATH="$GRAYPLEX_REPO_PATH/grayplex.log"

# GP
GP_REPO_PATH="/srv/git/Ansible-Deployment/Scripts"

################################
# Functions
################################

git_fetch_and_reset () {

    git fetch --quiet >/dev/null
    git clean --quiet -df >/dev/null
    git reset --quiet --hard "@{u}" >/dev/null
    git checkout --quiet master >/dev/null
    git clean --quiet -df >/dev/null
    git reset --quiet --hard "@{u}" >/dev/null
    git submodule update --init --recursive
    chmod 664 "${GRAYPLEX_REPO_PATH}/ansible.cfg"
    # shellcheck disable=SC2154
    chown -R "${user_name}":"${user_name}" "${GRAYPLEX_REPO_PATH}"
}


git_fetch_and_reset_grayplex () {

    git fetch --quiet >/dev/null
    git clean --quiet -df >/dev/null
    git reset --quiet --hard "@{u}" >/dev/null
    git checkout --quiet master >/dev/null
    git clean --quiet -df >/dev/null
    git reset --quiet --hard "@{u}" >/dev/null
    git submodule update --init --recursive
    chmod 775 "${GP_REPO_PATH}/grayplex.sh"
}

run_playbook_grayplex () {

    local arguments=$*

    echo "" > "${GRAYPLEX_LOGFILE_PATH}"

    cd "${GRAYPLEX_REPO_PATH}" || exit

    # shellcheck disable=SC2086
    "${ANSIBLE_PLAYBOOK_BINARY_PATH}" \
        "${GRAYPLEX_PLAYBOOK_PATH}" \
        --become \
        ${arguments}

    cd - >/dev/null || exit

}

install () {

    local arg=("$@")
    echo "${arg[*]}"

    # Remove space after comma
    # shellcheck disable=SC2128,SC2001
    arg_clean=$(sed -e 's/, /,/g' <<< "$arg")

    # Split tags from extra arguments
    # https://stackoverflow.com/a/10520842
    re="^(\S+)\s+(-.*)?$"
    if [[ "$arg_clean" =~ $re ]]; then
        tags_arg="${BASH_REMATCH[1]}"
        extra_arg="${BASH_REMATCH[2]}"
    else
        tags_arg="$arg_clean"
    fi

    # Save tags into 'tags' array
    # shellcheck disable=SC2206
    tags_tmp=(${tags_arg//,/ })

    # Remove duplicate entries from array
    # https://stackoverflow.com/a/31736999
    readarray -t tags < <(printf '%s\n' "${tags_tmp[@]}" | awk '!x[$0]++')

    # Build SB/CM tag arrays
    local tags_grayplex

    for i in "${!tags[@]}"
    do
        #if [[ ${tags[i]} == sandbox-* ]]; then
        #    tags_sandbox="${tags_sandbox}${tags_sandbox:+,}${tags[i]##sandbox-}"
        #
        #else
            tags_grayplex="${tags_grayplex}${tags_grayplex:+,}${tags[i]}"

        #fi
    done

    # GRAYPLEX Ansible Playbook
    if [[ -n "$tags_grayplex" ]]; then

        # Build arguments
        local arguments_grayplex="--tags $tags_grayplex"

        if [[ -n "$extra_arg" ]]; then
            arguments_grayplex="${arguments_grayplex} ${extra_arg}"
        fi

        # Run playbook
        echo ""
        echo "Running GRAYPLEX Tags: ${tags_grayplex//,/,  }"
        echo ""
        run_playbook_grayplex "$arguments_grayplex"
        echo ""

    fi

}

update () {

    if [[ -d "${GRAYPLEX_REPO_PATH}" ]]
    then
        echo -e "Updating GRAYPLEX...\n"

        cd "${GRAYPLEX_REPO_PATH}" || exit

        git_fetch_and_reset

        run_playbook_grayplex "--tags settings" && echo -e '\n'

        echo -e "Update Completed."
    else
        echo -e "GRAYPLEX folder not present."
    fi

}

gp-update () {

    echo -e "Updating sb...\n"

    cd "${GP_REPO_PATH}" || exit

    git_fetch_and_reset_grayplex

    echo -e "Update Completed."

}

gp-list ()  {

    if [[ -d "${GRAYPLEX_REPO_PATH}" ]]
    then
        echo -e "GRAYPLEX tags:\n"

        cd "${GRAYPLEX_REPO_PATH}" || exit

        "${ANSIBLE_PLAYBOOK_BINARY_PATH}" \
            "${GRAYPLEX_PLAYBOOK_PATH}" \
            --become \
            --list-tags --skip-tags "always" 2>&1 | grep "TASK TAGS" | cut -d":" -f2 | awk '{sub(/\[/, "")sub(/\]/, "")}1' | cut -c2-

        echo -e "\n"

        cd - >/dev/null || exit
    else
        echo -e "GRAYPLEX folder not present.\n"
    fi

}

list () {
    gp-list

}

usage () {
    echo "Usage:"
    echo "    gp update              Update GRAYPLEX."
    echo "    gp list                List GRAYPLEX packages."
    echo "    gp install <package>   Install <package>."
}

################################
# Update check
################################

cd "${GP_REPO_PATH}" || exit

git fetch
HEADHASH=$(git rev-parse HEAD)
UPSTREAMHASH=$(git rev-parse "master@{upstream}")

if [ "$HEADHASH" != "$UPSTREAMHASH" ]
then
 echo -e Not up to date with origin. Updating.
 gp-update
 echo -e Relaunching with previous arguments.
 sudo "$0" "$@"
 exit 0
fi

################################
# Argument Parser
################################

# https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/

roles=""  # Default to empty role
#target=""  # Default to empty target

# Parse options
while getopts ":h" opt; do
  case ${opt} in
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
shift $((OPTIND -1))

# Parse commands
subcommand=$1; shift  # Remove 'gp' from the argument list
case "$subcommand" in

  # Parse options to the various sub commands
    list)
        list
        ;;
    update)
        update
        ;;
    install)
        roles=${*}
        install "${roles}"
        ;;
    "") echo "A command is required."
        echo ""
        usage
        exit 1
        ;;
    *)
        echo "Invalid Command: $subcommand"
        echo ""
        usage
        exit 1
        ;;
esac