#!/bin/zsh
# gitprofile.sh - Script to switch git profile

CONFIG_FILE="$HOME/.gitprofiles.conf"
VERSION="1.0.1"

function init_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat <<EOF > "$CONFIG_FILE"
# Git Profile Config
# Format: profile_name=Full Name|email@example.com|~/.ssh/id_rsa|gitlab.com
EOF
    echo "🆕 Created config file: $CONFIG_FILE"
  fi
}

function show_help() {
  cat <<EOF
📘 gitprofile – Manage multiple Git user profiles with ease

Usage:
  gitprofile <command> [profile_name]

Commands:
  add                   Add a new Git profile
  remove                Remove a Git profile
  list, --list, -l      List all saved profiles
  version               Show script version
  help, --help          Show this help message
  <profile_name>        Switch to the given profile

Examples:
  gitprofile list
  gitprofile add
  gitprofile remove
  gitprofile work
  gitprofile --help
EOF
}

function list_profiles() {
  echo "📋 Available profiles:"
  grep -v '^#' "$CONFIG_FILE" | while IFS='=' read -r key value; do
    [[ -n "$key" ]] && echo "  - $key"
  done
}

function add_profile() {
  echo "➕ Adding a new profile (leave blank to cancel)"

  read "profile_name?Profile name: "
  [[ -z "$profile_name" ]] && echo "❌ Cancelled." && return

  read "full_name?Git user name: "
  [[ -z "$full_name" ]] && echo "❌ Cancelled." && return

  read "email?Git email: "
  [[ -z "$email" ]] && echo "❌ Cancelled." && return

  read "ssh_key?Path to SSH key (e.g. ~/.ssh/id_rsa): "
  [[ -z "$ssh_key" ]] && echo "❌ Cancelled." && return

  read "hostname?SSH host (e.g. gitlab.com): "
  [[ -z "$hostname" ]] && echo "❌ Cancelled." && return

  echo "$profile_name=$full_name|$email|$ssh_key|$hostname" >> "$CONFIG_FILE"
  echo "✅ Profile '$profile_name' added!"
}

function remove_profile() {
  profile=$1
  [[ -z "$profile" ]] && echo "⚠️ Please specify a profile to remove." && return

  if grep -q "^$profile=" "$CONFIG_FILE"; then
    sed -i '' "/^$profile=/d" "$CONFIG_FILE"
    echo "🗑️ Removed profile '$profile'"
  else
    echo "❌ Profile '$profile' not found."
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

  # Make sure git config file exists
  [[ ! -f "$HOME/.gitconfig" ]] && touch "$HOME/.gitconfig"

  git config --global user.name "$name"
  git config --global user.email "$email"
  ssh-add "$ssh_key"

  config_file="${ssh_key%/*}/config"

  if [[ ! -f "$config_file" ]]; then
    cat <<EOF > "$config_file"
Host $hostname
  HostName $hostname
  User git
  IdentityFile $ssh_key
EOF
    echo "🆕 Created SSH config at: $config_file"
  elif [[ -n "$hostname" ]]; then
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

function main() {
  init_config
  command=$1

  case "$command" in
    "" | --list | -l | list) list_profiles ;;
    add) add_profile ;;
    remove) remove_profile "$2" ;;
    version) echo "gitprofile v$VERSION" ;;
    help | --help) show_help ;;
    *) switch_profile "$command" ;;
  esac
}

main "$@"