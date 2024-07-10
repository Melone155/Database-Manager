#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'

if ! command -v dialog &> /dev/null; then
  apt-get update -y
  apt-get install dialog -y
fi

if ! command -v wget &> /dev/null; then
  apt-get update -y
  apt-get install wget -y
fi

# Funktion, die das Hauptmenü anzeigt
main_menu() {
  CHOICE=$(dialog --ascii-lines --title "DB Manager" --menu "Please choose your database" 15 50 3 \
    "MongoDB" "" \
    "MariaDB" "" \
    "Oracle" "" \
    3>&1 1>&2 2>&3)

  exitstatus=$?
  echo "main_menu exitstatus: $exitstatus"
  echo "main_menu choice: $CHOICE"
  if [ $exitstatus = 0 ]; then
    case $CHOICE in
      MongoDB)
        clear
        mongodb_menu
        ;;
      MariaDB)
        clear
        echo "You chose MariaDB."
        ;;
      Oracle)
        clear
        echo "You chose Oracle."
        ;;
    esac
  else
    clear
    echo "No selection made or cancelled."
  fi
}

# MongoDB-Menü
mongodb_menu() {
  CHOICE=$(dialog --ascii-lines --title "DB Manager (MongoDB)" --menu "Please choose your action" 15 50 5 \
    "Install" "You can install your database if there is none on the system yet" \
    "Update" "Search for and perform an update" \
    "Create User" "Create new user" \
    "Update User" "Edit rights for existing users" \
    "Delete User" "Delete existing users" \
    3>&1 1>&2 2>&3)

  exitstatus=$?
  echo "mongodb_menu exitstatus: $exitstatus"
  echo "mongodb_menu choice: $CHOICE"
  if [ $exitstatus = 0 ]; then
    case $CHOICE in
      "Install")
        clear
        mongodb_setup_input
        ;;
      "Update")
        clear
        echo "You chose Update."
        ;;
      "Create User")
        clear
        echo "You chose Create User."
        ;;
      "Update User")
        clear
        echo "You chose Update User."
        ;;
      "Delete User")
        clear
        echo "You chose Delete User."
        ;;
    esac
  else
    clear
    echo "No selection made or cancelled."
  fi
}

local $name
local $password
local $ip_address

# Funktion für MongoDB-Setup-Eingabe
mongodb_setup_input() {
  while true; do
    INPUT=$(dialog --ascii-lines --title "MongoDB Setup" --form "Create an admin user:" 15 50 0 \
      "Name:" 1 1 "" 1 20 30 0 \
      "Password:" 2 1 "" 2 20 30 0 \
      "IP Address:" 3 1 "" 3 20 30 0 \
      3>&1 1>&2 2>&3)

    exitstatus=$?
    echo "mongodb_setup_input exitstatus: $exitstatus"
    echo "mongodb_setup_input input: $INPUT"
    if [ $exitstatus -eq 0 ]; then
      IFS=$'\n' read -r -d '' name password ip_address <<< "$INPUT"
      $name
      $password
      $ip_address
      if [ -n "$name" ] && [ -n "$password" ] && [ -n "$ip_address" ]; then
        mongodb_install
        break
      else
        dialog --ascii-lines --title "Error" --msgbox "All fields must be filled." 6 40
      fi
    else
      clear
      break
    fi
  done
}

mongodb_install() {
  clear
  local exitstatus

  if systemctl is-active --quiet mongodb; then
    clear
    echo 'Mongodb is already installed'
  elif systemctl is-enabled --quiet mongodb; then
    clear
    echo -e '${Red}Mongodb is already installed'
  else
    apt install wget

    . /etc/os-release
    VERSION_ID=${VERSION_ID//\"/}
    DEBIAN_VERSION=$(echo $VERSION_ID | cut -d'.' -f1)
    if [ "$DEBIAN_VERSION" -ge 12 ]; then
      mkdir -p DBfiles
      cd DBfiles
      wget https://repo.mongodb.org/apt/debian/dists/bookworm/mongodb-org/7.0/main/binary-amd64/mongodb-org-server_7.0.12_amd64.deb
      dpkg -i mongodb-org-server_7.0.12_amd64.deb

      ARCH=$(uname -m)
      if [ "$ARCH" = "x86_64" ]; then
        wget https://downloads.mongodb.com/compass/mongodb-mongosh_2.2.10_amd64.deb
        dpkg -i mongodb-mongosh_2.2.10_amd64.deb
      elif [ "$ARCH" = "aarch64" ]; then
        wget https://downloads.mongodb.com/compass/mongodb-mongosh_2.2.10_arm64.deb
        dpkg -i mongodb-mongosh_2.2.10_arm64.deb
      fi
    elif [ "$DEBIAN_VERSION" -ge 11 ]; then
      mkdir -p DBfiles
      cd DBfiles
      wget https://repo.mongodb.org/apt/debian/dists/bullseye/mongodb-org/7.0/main/binary-amd64/mongodb-org-server_7.0.12_amd64.deb
      dpkg -i mongodb-org-server_7.0.12_amd64.deb

      ARCH=$(uname -m)
      if [ "$ARCH" = "x86_64" ]; then
        wget https://downloads.mongodb.com/compass/mongodb-mongosh_2.2.10_amd64.deb
        dpkg -i mongodb-mongosh_2.2.10_amd64.deb
      elif [ "$ARCH" = "aarch64" ]; then
        wget https://downloads.mongodb.com/compass/mongodb-mongosh_2.2.10_arm64.deb
        dpkg -i mongodb-mongosh_2.2.10_arm64.deb
      fi
    else
      clear
      echo -e "${RED}Debian Version ist älter als 11."
    fi
  fi
  start_mongodb_service
}

start_mongodb_service() {
  systemctl start mongod
  sleep 5
  
  if systemctl is-active --quiet mongod; then
    mongodb_adminuser
  else
    echo "MongoDB service failed to start. Attempting to fix and restart..."
    rm /tmp/mongodb-27017.sock
    systemctl restart mongod
    sleep 5
    
    if systemctl is-active --quiet mongod; then
     mongodb_adminuser
    else
      echo -e "${RED}MongoDB service still failed to start."
    fi
  fi
}

mongodb_adminuser() {

  mongosh <<EOF
use admin

db.createUser(
{
  user: "$name",
  pwd: "$password",
  roles: [ { role: "dbAdmin", db: "admin" } ]
}
)
EOF
clear
update_mongod_config
}

update_mongod_config() {
  local config_file="/etc/mongod.conf"

  # Hinzufügen der IP-Adresse hinter bindIp
  sed -i "/bindIp:/ s/127.0.0.1/127.0.0.1,$ip_address/" "$config_file"

  # Entfernen des Kommentars und Aktivieren der Sicherheit
  sed -i '/#security:/c\security:\n  authorization: "enabled"' "$config_file"
  systemctl restart mongod
  clear
  echo  -e '${GREEN}The Setup was Succesfull MongoDB is Install of on you Server'
}

# Debug-Ausgaben hinzufügen
echo "Running main menu..."
main_menu
echo "Finished running main menu."
