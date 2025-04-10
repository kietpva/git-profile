#!/bin/zsh
# Kiet Pham - gitprofile.sh - Script to switch git profile

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
    echo "✅ Config file created at: $CONFIG_FILE"
  fi
}

function show_help() {
  cat <<EOF
📘 Kiet Pham - gitprofile – Manage multiple Git user profiles with ease

Usage:
  gitprofile <command> [profile_name]

Commands:
  add                   Add a new Git profile
  remove                Remove a Git profile
  version               Show script version
  list, --list, -l      List all saved profiles
  help, --help          Show this help message
  <profile_name>        Switch to the given profile

Examples:
  gitprofile example (switch to 'example' profile)
  gitprofile list
  gitprofile add
  gitprofile remove
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

  while true; do
    read -r "profile?🔖 Profile name (e.g. work, personal): "
    [[ -z "$profile" ]] && echo "❌ Cancelled." && return

    if grep -q "^$profile=" "$CONFIG_FILE"; then
      echo "⚠️ Profile '$profile' already exists. Please choose another name."
      continue
    fi

    read -r "name?👤 user.name: "
    [[ -z "$name" ]] && echo "❌ Cancelled." && return

    read -r "email?📧 user.email: "

    # List SSH keys
    echo "🔍 Available SSH keys in ~/.ssh:"
    keys=()
    for f in ~/.ssh/*(N); do
      [[ -f "$f" ]] || continue
      fname=${f:t}
      [[ "$fname" == "config" || "$fname" == "known_hosts" || "$fname" == "known_hosts.old" || "$fname" == *.pub ]] && continue
      keys+=("$fname")
    done

    if (( ${#keys[@]} == 0 )); then
      echo "❌ No SSH keys found in ~/.ssh"
      return
    fi

    for i in {1..${#keys[@]}}; do
      echo "$i) ${keys[$i]}"
    done

    read -r "key_choice?Enter a number to select an SSH key: "
    ssh_key="${keys[$key_choice]}"
    [[ -z "$ssh_key" ]] && echo "❌ Invalid selection." && return
    ssh_key_path="$HOME/.ssh/$ssh_key"
    echo "✅ sshkey '$ssh_key' added."

    # Choose host
    while true; do
      echo "🌐 Select Git host:"
      echo "1) github.com"
      echo "2) gitlab.com"
      echo "3) bitbucket.org"
      echo "4) Other (enter manually)"
      read -r "host_choice?Enter a number: "

      case "$host_choice" in
        1) host="github.com"; break ;;
        2) host="gitlab.com"; break ;;
        3) host="bitbucket.org"; break ;;
        4)
          read -r "host?Enter custom hostname: "
          [[ -z "$host" ]] && echo "❌ Hostname cannot be empty." || break
          ;;
        *) echo "❌ Please try again." ;;
      esac
    done

    echo "$profile=$name|$email|$ssh_key_path|$host" >> "$CONFIG_FILE"
    echo "✅ Profile '$profile' added."
    break
  done
}

function remove_profile() {
  echo "🗑️ Select a profile to remove:"

  profiles=()
  grep -v '^#' "$CONFIG_FILE" | while IFS='=' read -r profile _; do
    profiles+=("$profile")
  done

  if (( ${#profiles[@]} == 0 )); then
    echo "❌ No profiles to remove."
    return
  fi

  for i in {1..${#profiles[@]}}; do
    echo "$i) ${profiles[$i]}"
  done

  read -r "choice?Enter a number to select a profile: "
  selected_profile="${profiles[$choice]}"

  if [[ -z "$selected_profile" ]]; then
    echo "❌ Invalid selection."
    return
  fi

  read -r "confirm?❓ Are you sure you want to delete '$selected_profile'? (y/n): "
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    sed -i '' "/^$selected_profile=/d" "$CONFIG_FILE"
    echo "✅ Removed profile '$selected_profile'"
  else
    echo "❌ Cancelled."
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
  echo "👤 user.nam: $name"
  echo "📧 user.email: $email"
  echo "🔐 SSH Key: $ssh_key"
  echo "🌐 Host: $hostname"

  git config --global user.name "$name"
  git config --global user.email "$email"
  ssh-add "$ssh_key"

  config_file="${ssh_key%/*}/config"

cat <<EOF > "$config_file"
Host $hostname
  HostName $hostname
  User git
  IdentityFile $ssh_key
EOF

  if [[ -f "$config_file" ]]; then
    echo "🔁 SSH config replaced at $config_file"
  else
    echo "📄 Created SSH config at $config_file"
  fi

  if [[ -n "$hostname" ]]; then
    sed -i '' "s|^ *IdentityFile .*|  IdentityFile $ssh_key|" "$config_file" 2>/dev/null || echo "  IdentityFile $ssh_key" >> "$config_file"
    sed -i '' "s|^ *Host .*|  Host $hostname|" "$config_file" 2>/dev/null || echo "  Host $hostname" >> "$config_file"
    sed -i '' "s|^ *HostName .*|  HostName $hostname|" "$config_file" 2>/dev/null || echo "  HostName $hostname" >> "$config_file"
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
  echo "🔖 gitprofile version $VERSION"
}

### Main Logic
init_config

case "$1" in
  add|-a) add_profile ;;
  remove|-rm) remove_profile ;;
  version|-v) show_version ;;
  list|--list|-l) list_profiles ;;
  help|--help|-h) show_help ;;
  "") show_help ;;
  *) switch_profile "$1" ;;
esac