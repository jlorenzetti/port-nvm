# MacPorts Node Version Manager
# Implemented as a POSIX-compliant function
# To use source this file from your bash profile
#
# Implemented by Jacopo Lorenzetti <hello@jacopolorenzetti.com>

portnvm_is_version_active() {
  if [ -z "${1-}" ]; then
    return 1
  fi

  if [ $(port -q installed nodejs$1 | grep "(active)" | wc -l) -gt 0 ]; then
    return 0
  fi
  return 1
}

portnvm_is_version_installed() {
  if [ -z "${1-}" ]; then
    return 1
  fi

  if [ $(port -q installed $(port -q list name:^nodejs$1 | tail -n 1 | awk '{print $1;}') | wc -l) -gt 0 ]; then
    return 0
  fi
  return 1
}

portnvm_is_port_installed() {
  if [ -z "${1-}" ]; then
    return 1
  fi

  if [ $(port -q installed "$1" | wc -l) -gt 0 ]; then
    return 0
  fi
  return 1
}

portnvm_is_version_inactive() {
  if [ -z "${1-}" ]; then
    return 1
  fi

  if [ $(port -q inactive $(port -q list name:^nodejs$1 | tail -n 1 | awk '{print $1;}') | wc -l) -gt 0 ]; then
    return 0
  fi
  return 1
}

portnvm_deactivate_npm() {
  if [ $(port -q installed name:^npm and active | wc -l) -gt 0 ]; then
    echo "Deactivating npm…"
    for ACTIVE_NPM in $(port -q installed name:^npm and active | awk '{print $1;}'); do
      sudo port -q deactivate "${ACTIVE_NPM}" || return 1
    done
  fi
  return 0
}

portnvm_deactivate_all() {
  portnvm_deactivate_npm || return 1

  if [ $(port -q installed name:^nodejs and active | wc -l) -gt 0 ]; then
    for ACTIVE_PORT in $(port -q installed name:^nodejs and active | awk '{print $1;}'); do
      if [ $(port -q installed dependentof:${ACTIVE_PORT} and active | wc -l) -gt 0 ]; then
        echo "Deactivating dependent ports of ${ACTIVE_PORT}…"
        for ACTIVE_DEPENDENT in $(port -q installed dependentof:${ACTIVE_PORT} and active | awk '{print $1;}'); do
          sudo port -q deactivate "${ACTIVE_DEPENDENT}" || return 1
        done
      fi

      echo "Deactivating ${ACTIVE_PORT}…"
      sudo port -q deactivate "${ACTIVE_PORT}" || return 1
    done
  fi
  return 0
}

portnvm_install_latest_npm() {
  if [ -z "${1-}" ]; then
    return 1
  fi

  portnvm_deactivate_npm || return 1

  echo 'Attempting to install the latest working version of npm…'
  if [ $1 -lt 10 ]; then
    NPM_PORT="npm6"
  elif [ $1 -lt 16 ]; then
    if [ $1 -eq 14 ]; then
      NPM_PORT="npm9"
    elif [ $1 -eq 12 ]; then
      NPM_PORT="npm8"
    else
      NPM_PORT="npm7"
    fi
  elif [ $1 -lt 19 ]; then
    if [ $1 -eq 17 ]; then
      NPM_PORT="npm8"
    else
      NPM_PORT="npm9"
    fi
  else
    NPM_PORT="$(port -q list name:^npm | tail -n 1 | awk '{print $1;}')"
  fi

  if portnvm_is_port_installed "${NPM_PORT}"; then
    sudo port activate "${NPM_PORT}" || return 1
  else
    sudo port install "${NPM_PORT}" || return 1
  fi

  return 0
}

if [ "$#" -lt 1 ]; then
  echo "Usage:"
  echo "  port-nvm use [<version>]"
  return
fi

local COMMAND
COMMAND="${1-}"
shift

local VERSION
local NPM_PORT

case $COMMAND in
  "activate")
    local PROVIDED_VERSION

    if [ -n "${1-}" ]; then
      PROVIDED_VERSION="$1"
    else
      echo "Usage:"
      echo "  port-nvm activate [<version>]"
      return 127
    fi
    shift

    VERSION="${PROVIDED_VERSION}"

    if portnvm_is_version_installed "${VERSION}"; then
      if portnvm_is_version_active "${VERSION}"; then
        echo "nodejs${VERSION} is already active."
        return 0
      fi
      if ! portnvm_deactivate_all; then
        return 1
      fi
      echo "Activating nodejs${VERSION}…"
      sudo port activate nodejs"${VERSION}" || return 1
      portnvm_install_latest_npm "${VERSION}"
    else
      if ! portnvm_deactivate_all; then
        return 1
      fi
      echo "Installing nodejs${VERSION}…"
      sudo port install nodejs"${VERSION}" || return 1
      portnvm_install_latest_npm "${VERSION}"
    fi


    echo "Now using nodejs${VERSION} (${NPM_PORT})"
  ;;
  esac
