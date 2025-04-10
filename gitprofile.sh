#!/bin/zsh
# gitprofile.sh - Script to switch git profile

typeset -A GIT_PROFILES

# Load profile config from file
CONFIG_FILE="$HOME/.gitprofiles.conf"
if [[ -f "$CONFIG_FILE" ]]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || -z "$value" || "$key" =~ ^# ]] && continue
    GIT_PROFILES[$key]=${value//\"/}
  done < "$CONFIG_FILE"
else
  echo "⚠️  Config file not found at $CONFIG_FILE"
  echo "📄 Please create it with content like:"
  echo 'work="Your Name|email@example.com|~/.ssh/key_path|gitlab.com"'
  exit 1
fi

function gitprofile() {
  local profile_data=${GIT_PROFILES[$1]}
  if [[ -z "$profile_data" ]]; then
    echo "⚠️  Profile '$1' not found."
    echo "📋 List available profiles:"
    for key in ${(k)GIT_PROFILES}; do
      echo "  - $key"
    done
    return 1
  fi

  local name email ssh_key_raw hostname ssh_key
  IFS='|' read name email ssh_key_raw hostname <<< "$profile_data"
  ssh_key="${ssh_key_raw/#\~/$HOME}"

  if [[ ! -f "$ssh_key" ]]; then
    echo "❌ SSH key not found at: $ssh_key"
    return 1
  fi

  echo "🔁 Switching to profile: $1"
  echo "👤 Name: $name"
  echo "📧 Email: $email"
  echo "🔐 SSH key: $ssh_key"
  echo "🌐 Host: $hostname"

  git config --global user.name "$name"
  git config --global user.email "$email"
  ssh-add "$ssh_key"

  local config_file="${ssh_key%/*}/config"
  if [[ -f "$config_file" ]]; then
    sed -i '' "s|^ *IdentityFile .*|  IdentityFile $ssh_key|" "$config_file"
    sed -i '' "s|^ *Host .*|  Host $hostname|" "$config_file"
    sed -i '' "s|^ *HostName .*|  HostName $hostname|" "$config_file"
    echo "🛠️ Updated IdentityFile and HostName in $config_file"
  else
    echo "⚠️ SSH config file not found at $config_file"
  fi

  if [[ -n "$hostname" ]]; then
    echo "🚀 Testing SSH connection to $hostname..."
    ssh -T "$hostname"
  else
    echo "⚠️ No hostname specified to test SSH connection."
  fi
}