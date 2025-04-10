#!/bin/zsh
# gitprofile.sh - Script to switch git profile

#!/bin/bash

CONFIG_FILE="$HOME/.gitprofiles.conf"
VERSION="1.0.1"

function init_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat <<EOF > "$CONFIG_FILE"
# Git Profiles
# Format:
#   profile_name=Git User Name|email@example.com|/path/to/ssh_key|git.example.com
# Example:
#   work=Kiet Pham|kietpva0102@gmail.com|~/.ssh/kietpham|github.com
EOF
  echo "📁 Created config file at: $CONFIG_FILE"
  fi
}

function list_profiles() {
  echo "📋 Available profiles:"
  grep -v '^#' "$CONFIG_FILE" | cut -d'=' -f1
}

function add_profile() {
  echo "➕ Adding a new profile (leave blank to cancel):"

  echo -n "Profile name: "; read profile
  [[ -z "$profile" ]] && echo "❌ Cancelled." && return

  echo -n "Display name (Git user.name): "; read name
  echo -n "Email (Git user.email): "; read email
  echo -n "SSH key path: "; read ssh_key
  echo -n "Host (e.g. gitlab.com): "; read hostname

  echo "${profile}=${name}|${email}|${ssh_key}|${hostname}" >> "$CONFIG_FILE"
  echo "✅ Profile '$profile' added."
}

function remove_profile() {
  echo -n "Enter the profile name to remove: "; read profile
  if grep -q "^$profile=" "$CONFIG_FILE"; then
    sed -i.bak "/^$profile=/d" "$CONFIG_FILE"
    echo "🗑️ Profile '$profile' removed."
  else
    echo "⚠️ Profile '$profile' not found."
  fi
}

function switch_profile() {
  profile=$1
  if [[ -z "$profile" ]]; then
    echo "⚠️ Please specify a profile name."
    list_profiles
    return
  fi

  line=$(grep "^$profile=" "$CONFIG_FILE")
  if [[ -z "$line" ]]; then
    echo "❌ Profile '$profile' not found."
    list_profiles
    return
  fi

  IFS='=' read -r _ data <<< "$line"
  IFS='|' read -r name email ssh_key_raw hostname <<< "$data"
  ssh_key="${ssh_key_raw/#\~/$HOME}"

  if [[ ! -f "$ssh_key" ]]; then
    echo "❌ SSH key not found: $ssh_key"
    return 1
  fi

  echo "🔁 Switching to profile '$profile'"
  echo "👤 Name: $name"
  echo "📧 Email: $email"
  echo "🔐 SSH Key: $ssh_key"
  echo "🌐 Host: $hostname"

  git config --global user.name "$name"
  git config --global user.email "$email"
  ssh-add "$ssh_key"

  config_file="${ssh_key%/*}/config"
  if [[ -f "$config_file" && -n "$hostname" ]]; then
    sed -i '' "s|^ *IdentityFile .*|  IdentityFile $ssh_key|" "$config_file"
    sed -i '' "s|^ *Host .*|  Host $hostname|" "$config_file"
    sed -i '' "s|^ *HostName .*|  HostName $hostname|" "$config_file"
    echo "🛠️ SSH config updated: $config_file"
  fi

  if [[ -n "$hostname" ]]; then
    echo "🚀 Testing SSH connection to $hostname..."
    ssh -T "$hostname"
  else
    echo "⚠️ No hostname provided to test SSH connection."
  fi
}

function show_version() {
  echo "gitprofile v$VERSION"
}

function show_help() {
  cat <<EOF
📘 KietPham - gitprofile - Manage multiple Git user profiles with ease

Usage:
  gitprofile <command> [profile_name]

Commands:
  add                   Add a new Git profile
  remove                Remove a Git profile
  version               Show script version
  list, --list, -l      List all saved profiles
  help, --help          Show this help message
  <profile_name>         Switch to the given profile

Examples:
  gitprofile list
  gitprofile add
  gitprofile remove
  gitprofile work
  gitprofile --help
EOF
}

# Main
init_config

case "$1" in
  add) add_profile ;;
  remove|rm) remove_profile ;;
  version|-v) show_version ;;
  list|--list|-l) list_profiles ;;
  help|--help|-h) show_help ;;
  *) switch_profile "$1" ;;
esac