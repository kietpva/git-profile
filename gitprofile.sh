#!/bin/zsh
# gitprofile.sh - Script to switch git profile

CONFIG_FILE="$HOME/.gitprofiles.conf"
function ensure_config_exists() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
    echo "# Git profiles config" > "$CONFIG_FILE"
    echo "⚙️ Created $CONFIG_FILE"
  fi
}

function load_profiles() {
  ensure_config_exists
  GIT_PROFILES=()
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    GIT_PROFILES["$key"]="$value"
  done < "$CONFIG_FILE"
}

function list_profiles() {
  load_profiles
  echo "📋 Available profiles:"
  for key in "${!GIT_PROFILES[@]}"; do
    IFS='|' read -r name email ssh host <<< "${GIT_PROFILES[$key]}"
    echo "  🔹 $key => $name <$email> | SSH: $ssh | Host: $host"
  done
}

function switch_profile() {
  load_profiles
  local key="$1"
  local profile="${GIT_PROFILES[$key]}"

  if [[ -z "$profile" ]]; then
    echo "❌ Profile '$key' not found."
    list_profiles
    return 1
  fi

  IFS='|' read -r name email ssh_key_raw host <<< "$profile"
  ssh_key="${ssh_key_raw/#\~/$HOME}"

  if [[ ! -f "$ssh_key" ]]; then
    echo "❌ SSH key not found: $ssh_key"
    return 1
  fi

  echo "🔁 Switching to profile '$key'"
  echo "👤 $name <$email>"
  echo "🔐 SSH: $ssh_key"
  echo "🌐 Host: $host"

  git config --global user.name "$name"
  git config --global user.email "$email"
  ssh-add "$ssh_key"

  local config_file="${ssh_key%/*}/config"
  if [[ -f "$config_file" ]]; then
    sed -i '' "s|^ *IdentityFile .*|  IdentityFile $ssh_key|" "$config_file"
    sed -i '' "s|^ *Host .*|  Host $host|" "$config_file"
    sed -i '' "s|^ *HostName .*|  HostName $host|" "$config_file"
    echo "🛠️ Updated $config_file"
  else
    echo "⚠️ SSH config file not found at $config_file"
  fi

  if [[ -n "$host" ]]; then
    echo "🚀 Testing SSH connection to $host..."
    ssh -T "$host"
  fi
}

function add_profile() {
  ensure_config_exists
  echo "➕ Adding a new profile (leave blank to cancel)"

  read -p "🔑 Profile name (e.g., work): " key
  [[ -z "$key" ]] && echo "❌ Cancelled." && return

  read -p "👤 Name: " name
  [[ -z "$name" ]] && echo "❌ Cancelled." && return

  read -p "📧 Email: " email
  [[ -z "$email" ]] && echo "❌ Cancelled." && return

  read -p "🔐 SSH key path (e.g., ~/.ssh/id_rsa): " ssh_key
  [[ -z "$ssh_key" ]] && echo "❌ Cancelled." && return

  read -p "🌐 Host (e.g., github.com): " host
  [[ -z "$host" ]] && echo "❌ Cancelled." && return

  echo "$key=$name|$email|$ssh_key|$host" >> "$CONFIG_FILE"
  echo "✅ Added profile '$key'"
}

function remove_profile() {
  ensure_config_exists
  local key="$1"
  if grep -q "^$key=" "$CONFIG_FILE"; then
    grep -v "^$key=" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo "🗑️ Removed profile '$key'"
  else
    echo "❌ Profile '$key' not found."
  fi
}

function show_version() {
  echo "gitprofile v1.0.1"
}

# Main handler
case "$1" in
  list)
    list_profiles
    ;;
  add)
    add_profile
    ;;
  remove)
    remove_profile "$2"
    ;;
  version)
    show_version
    ;;
  *)
    if [[ -n "$1" ]]; then
      switch_profile "$1"
    else
      echo "⚙️ Usage:"
      echo "  gitprofile list          # Show all profiles"
      echo "  gitprofile add           # Add new profile"
      echo "  gitprofile remove <key>  # Remove profile"
      echo "  gitprofile <key>         # Switch to profile"
      echo "  gitprofile version       # Show version"
    fi
    ;;
esac