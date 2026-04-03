#!/bin/bash

set -euo pipefail

# Usage:
#   ./setup/setup.sh                          # Interactive mode
#   ./setup/setup.sh --subdomain myname-01 install   # Unattended install
#   ./setup/setup.sh --subdomain myname-01 cleanup   # Unattended cleanup
#   ./setup/setup.sh --subdomain myname-01 update    # Unattended update

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR" || true
  fi
  echo ""
}

# Detect project root from script location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

setup_dir="${project_root}/setup"
infra_dir="${project_root}/flux"
tf_dir="${project_root}/tf"

# Parse arguments
SUBDOMAIN_ARG=""
ACTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subdomain)  SUBDOMAIN_ARG="$2"; shift 2 ;;
    --subdomain=*) SUBDOMAIN_ARG="${1#*=}"; shift ;;
    install|update|cleanup|bash)
      ACTION="$1"; shift ;;
    -h|--help|help)
      echo "Usage: ./setup/setup.sh [--subdomain NAME] [install|update|cleanup]"
      echo ""
      echo "Options:"
      echo "  --subdomain NAME   Set the SUBDOMAIN (required for unattended mode)"
      echo ""
      echo "Actions:"
      echo "  install             Install the rwlight platform"
      echo "  update              Update/sync the platform"
      echo "  cleanup             Tear down the platform"
      echo ""
      echo "Without arguments, runs in interactive mode."
      exit 0
      ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

run_install() {
  cd "$setup_dir"
  chmod +x setup-rwdev.sh
  echo "Running setup-rwdev.sh..."
  local retry="false"
  if ./setup-rwdev.sh "$setup_dir" "$infra_dir" "$tf_dir" "$retry"; then
    echo "setup-rwdev.sh completed."
  else
    local exit_code=$?
    echo "setup-rwdev.sh failed with exit code $exit_code"
    if [[ -z "$ACTION" && "$exit_code" == 1234 ]]; then
      read -rp "Terraform setup failed! Do you want to retry? [y/N]: " tf_retry
      if [[ "${tf_retry}" == "y" || "${tf_retry}" == "Y" ]]; then
        echo "retrying terraform setup..."
        ./setup-rwdev.sh "$setup_dir" "$infra_dir" "$tf_dir" "true"
      fi
    fi
  fi

  if [[ ! -f "$setup_dir/.vault-token" ]]; then
    echo "Warning: .vault-token was not created by setup-rwdev.sh" >&2
  fi
}

run_update() {
  cd "$setup_dir"
  chmod +x update-rwdev.sh
  echo "Running update-rwdev.sh..."
  if ./update-rwdev.sh "$infra_dir" "$tf_dir"; then
    echo "update-rwdev.sh completed."
  else
    echo "update-rwdev.sh FAILED"
  fi
}

run_cleanup() {
  cd "$setup_dir"
  chmod +x clean-rwdev.sh
  echo "Running clean-rwdev.sh..."
  ./clean-rwdev.sh
  echo "clean-rwdev.sh completed."
}

main() {
  trap cleanup EXIT

  # Install prerequisites if on Linux (idempotent, skips if already installed)
  if [ "$(uname -s)" = "Linux" ] && [ -f "$setup_dir/install-prerequisites.sh" ]; then
    "$setup_dir/install-prerequisites.sh"
  fi

  cd "$setup_dir"

  # Apply subdomain from CLI arg if provided
  if [[ -n "$SUBDOMAIN_ARG" ]]; then
    sed -i "s/^SUBDOMAIN=.*/SUBDOMAIN=${SUBDOMAIN_ARG}/" vars.env
  fi

  set -a
  source vars.env
  set +a

  # Validate SUBDOMAIN is set
  if [[ -z "${SUBDOMAIN:-}" ]]; then
    echo "ERROR: SUBDOMAIN is not set. Use --subdomain NAME or edit setup/vars.env"
    exit 1
  fi

  # Unattended mode: run the action directly
  if [[ -n "$ACTION" ]]; then
    echo "[rwlight] Subdomain: $SUBDOMAIN | Action: $ACTION"
    case "$ACTION" in
      install)  run_install ;;
      update)   run_update ;;
      cleanup)  run_cleanup ;;
      bash)     exec bash ;;
    esac
    return
  fi

  # Interactive mode
  while true; do
    echo ""
    echo "SUBDOMAIN: ${SUBDOMAIN}"
    echo ""
    echo "Please choose an option:"
    echo "1) install"
    echo "2) update"
    echo "3) cleanup"
    echo "4) bash"
    echo "5) exit"
    read -rp "Enter choice [1-5]: " choice

    case $choice in
      1|install)  run_install ;;
      2|update)   run_update ;;
      3|cleanup)  run_cleanup ;;
      4|bash)     exec bash ;;
      5|exit)     echo "Exiting. Bye!"; break ;;
      *)          echo "Invalid choice." ;;
    esac
  done
}

main
