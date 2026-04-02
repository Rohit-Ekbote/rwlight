#!/bin/bash

set -euo pipefail

# Usage: ./setup.sh

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR" || true
  fi
  echo ""
}

open_in_editor() {
  local file="$1"
  vi "$file"
}

main() {
  setup_dir="$HOME/setup"
  infra_dir="$HOME/flux"
  tf_dir="$HOME/tf"

  trap cleanup EXIT

  cd "$setup_dir"
  local env_target="vars.env"

  echo "Opening the environment file in your default editor..."
  open_in_editor "$env_target"

  set -a
  source "$env_target"
  set +a
  
  while true; do
    echo ""
    echo "Please choose an option:"
    echo "1) install"
    echo "2) update"
    echo "3) cleanup"
    echo "4) bash"
    echo "5) exit"
    read -p "Enter choice [1-5]: " choice

    case $choice in
      1|install)
        echo "Running installation..."

        chmod +x setup-rwdev.sh
        echo "Running setup-rwdev.sh..."
        local retry="false"
        while true; do
          if ./setup-rwdev.sh "$setup_dir" "$infra_dir" "$tf_dir" "$retry"; then
            echo "setup-rwdev.sh completed."
            break
          else
            exit_code=$?
            echo "setup-rwdev.sh failed with exit code $exit_code"
            if [[ "$exit_code" == 1234 ]]; then
              read -pr "Terraform setup failed! Do you want to retry? [y/N]: " tf_retry
              if [[ "${tf_retry}" == "y" || "${tf_retry}" == "Y" ]]; then
                echo "retrying terraform setup..."
                retry="true"
              else
                break
              fi
            else
              break
            fi
          fi
        done

        # Copy the .vault-token back to the workspace directory
        if [[ ! -f ".vault-token" ]]; then
          echo "Error: .vault-token was not created by setup-rwdev.sh" >&2
        fi
        ;;
      2|update)
        echo "Running update..."

        chmod +x update-rwdev.sh
        echo "Running update-rwdev.sh..."
        if ./update-rwdev.sh "$infra_dir" "$tf_dir"; then
          echo "update-rwdev.sh completed."
        else
          echo "update-rwdev.sh FAILED"
        fi
        ;;
      3|cleanup)
        echo "Running cleanup..."

        chmod +x clean-rwdev.sh
        echo "Running clean-rwdev.sh..."
        ./clean-rwdev.sh
        echo "clean-rwdev.sh completed."
        ;;
      4|bash)
        echo "opening shell..."
        exec bash
        ;;
      5|exit)
        echo "Exiting script. Bye!"
        break
        ;;
      *)
        echo "Invalid choice. Please enter 1 (install) or 2 (cleanup)."
        ;;
    esac
  done
}

main "$@"
