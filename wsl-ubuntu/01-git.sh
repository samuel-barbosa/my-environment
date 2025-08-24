#!/bin/bash
set -e
#
# Git Installation Script for Debian/Ubuntu Systems
# 
# This script installs the latest version of Git from the official Git PPA repository
# It automatically detects the system and configures the appropriate repository
#
# Usage: sudo ./01-git.sh
#
# Author: Samuel Barbosa
# License: MIT
# Repository: https://github.com/samuel-barbosa/my-environment
#
# Requirements:
# - Debian-based Linux distribution (Ubuntu, Debian, etc.)
# - Root privileges (sudo)
# - Internet connection
#

# Function to confirm the installed Git version
function this::confirm_version {
   echo "ℹ️ $(git version)"
}

# List of APT packages to install
APT_PACKAGES=(git)

# PPA repository from which packages will be installed
PPA_REPO="git-core/ppa"

# Load core functions
[[ -r `dirname ${0}`/../core/functions.sh ]] && source `dirname ${0}`/../core/functions.sh

# Ensure that the script is running with root privileges
core::requires_root

# Ensure that the script is running on a Debian-based system
core::requires_debian

# Define file paths for repository configuration
KEYRING_FILE="/usr/share/keyrings/${PPA_REPO//\//-}.gpg"
SOURCE_FILE="/etc/apt/sources.list.d/${PPA_REPO//\//-}.list"

# Create a temporary file to capture errors, and set up a trap to remove it on exit
ERROR_FILE=$(mktemp)
trap "rm -f \"${ERROR_FILE}\" \"${SOURCE_FILE}\"" EXIT SIGINT SIGTERM

# Add the PPA repository
if command -v add-apt-repository &>/dev/null; then
   echo "⚙️ Adding the 'ppa:${PPA_REPO}' repository by using the 'add-apt-repository' utility..."
   trap "if [[ \"\$?\" -ne 0 ]]; then cat \"${ERROR_FILE}\"; echo \"❌ An error occurred while adding ppa:${PPA_REPO} repository\" >&2; fi && rm -rf \"${ERROR_FILE}\";" EXIT SIGINT SIGTERM
   add-apt-repository --yes "ppa:${PPA_REPO}" >/dev/null 2>"${ERROR_FILE}"
else
   echo "⚙️ Manually adding the 'ppa:${PPA_REPO}' repository as 'add-apt-repository' utility is not available..."

   # Suppress APT warnings and prompts
   export DEBIAN_FRONTEND=noninteractive
   export DEBCONF_NOWARNINGS=yes

   # Install essential packages required for manual PPA repository addition
   apt-get update >/dev/null
   apt-get --yes --quiet --no-install-recommends --allow-unauthenticated install apt-transport-https ca-certificates lsb-release >/dev/null
   for CMD in curl gpg grep; do
      if ! command -v ${CMD} &>/dev/null; then
         apt-get --yes --quiet --no-install-recommends --allow-unauthenticated install ${CMD} >/dev/null
      fi
   done

   # Determine the corresponding Ubuntu release for PPA compatibility and verify availability
   core::get_ubuntu_release "${PPA_REPO}"
   echo "🚀 Selected '${UBUNTU_RELEASE}' as compatible Ubuntu release for PPA repository ppa:${PPA_REPO}"

   # Check if the PPA repository is available for the selected Ubuntu release
   if [[ "$(curl -w '%{http_code}' -sSLo /dev/null https://ppa.launchpadcontent.net/${PPA_REPO}/ubuntu/dists/${UBUNTU_RELEASE}/)" -ne 200 ]]; then
      echo "❌ PPA repository ppa:${PPA_REPO} is not available for ${UBUNTU_RELEASE}" >&2
      exit 1
   fi

   # Set PPA Repository URL to be added to APT source file
   REPO_URL="https://ppa.launchpadcontent.net/${PPA_REPO}/ubuntu ${UBUNTU_RELEASE} main"

   # Create the APT source file (with no signature verification for now)
   echo "deb [arch=$(dpkg --print-architecture)] ${REPO_URL}" > "${SOURCE_FILE}"

   # Attempt to update and fetch missing GPG keys if needed
   while ! apt-get update >/dev/null 2>"${ERROR_FILE}"; do

      # Extract missing GPG keys
      MISSING_KEYS=$(grep -Po '(NO_PUBKEY|Missing key)\s\w+' "${ERROR_FILE}" | grep -Po '(?<=\s)\w+$' || true)

      # Exit if 'apt update' command fails for reasons other than missing GPG keys
      [[ -z "${MISSING_KEYS}" ]] && { cat "${ERROR_FILE}" && echo "❌ Command 'apt update' failed"; exit 1; }

      # Fetch all missing GPG keys
      for GPG_KEY in ${MISSING_KEYS}; do
         curl --connect-timeout 5 --max-time 15 -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${GPG_KEY}" | gpg --dearmor >> "${KEYRING_FILE}"
         echo "🔑 GPG key ${GPG_KEY} successfully retrieved"
      done

      # Add signature verification to the APT source file
      echo "deb [arch=$(dpkg --print-architecture) signed-by=${KEYRING_FILE}] ${REPO_URL}" > "${SOURCE_FILE}"
   done
   echo "📦 Repository ppa:${PPA_REPO} added successfully"
fi

# Install the required packages
trap "if [[ \"\$?\" -ne 0 ]]; then cat \"${ERROR_FILE}\"; echo \"❌ An error occurred while installing the packages: ${APT_PACKAGES[*]}\" >&2; fi && rm -rf \"${ERROR_FILE}\" \"${SOURCE_FILE}\";" EXIT SIGINT SIGTERM
apt-get --yes --quiet --no-install-recommends --allow-unauthenticated install "${APT_PACKAGES[@]}" >/dev/null 2>"${ERROR_FILE}"
echo "✅ Packages installed successfully: ${APT_PACKAGES[*]}"
this::confirm_version