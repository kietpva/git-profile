#!/bin/zsh
# gitprofile.sh - Script to switch git profile

CONFIG_FILE="$HOME/.gitprofiles.conf"
typeset -A GIT_PROFILES

# Create file config if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
  cat <<EOF > "$CONFIG_FILE"
# Git Profiles Configuration
# Format: profile_name=name|email|ssh_key|host

work=Kiet Pham|kietpva0102@gmail.com|~/.ssh/kietpham|github.com
EOF

  echo "📄 Created default config at $CONFIG_FILE"
fi

# Load profiles from config file
while IFS='=' read -r key value; do
  [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
  GIT_PROFILES["$key"]="$value"
done < "$CONFIG_FILE"

function gitprofile() {
  local profile_data="${GIT_PROFILES[$1]}"
  if [[ -z "$profile_data" ]]; then
    echo "⚠️  Profile '$1' not found."
    echo "📋 Available profiles:"
    for key in "${!GIT_PROFILES[@]}"; do
      echo "  - $key"
    done
    return 1
  fi

  local name email ssh_key_raw ssh_key hostname
  IFS='|' read -r name email ssh_key_raw hostname <<< "$profile_data"
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

  # SSH config file auto-update (optional)
  local config_file="${ssh_key%/*}/config"
  if [[ -f "$config_file" ]]; then
    sed -i '' "s|^ *IdentityFile .*|  IdentityFile $ssh_key|" "$config_file"
    sed -i '' "s|^ *Host .*|  Host $hostname|" "$config_file"
    sed -i '' "s|^ *HostName .*|  HostName $hostname|" "$config_file"

    echo "🛠️ Updated IdentityFile and HostName in $config_file"
  else
    echo "⚠️ SSH config file not found at $config_file"
  fi

  # Test SSH (optional)
  if [[ -n "$hostname" ]]; then
    echo "🚀 Testing SSH connection to $hostname..."
    ssh -T "$hostname"
  else
    echo "⚠️ No hostname specified to test SSH connection."
  fi
}