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
    "MariaDB Install" "" \
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
        mariadb_setup_input
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
    "Create User" "Create new user" \
    "Update User" "Edit rights for existing users" \
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
      "Create User")
        clear
        admin_user_loggin_create_user
        ;;
      "Update User")
        clear
        admin_user_loggin_Update_user
        ;;
    esac
  else
    clear
    echo "No selection made or cancelled."
  fi
}

local $name
local $password
local passwordrepeat
local $ip_address

# Funktion für MongoDB-Setup-Eingabe
mongodb_setup_input() {
  while true; do
    # Dialog für Name und IP-Adresse
    INPUT=$(dialog --ascii-lines --title "MongoDB Setup" --form "Create an admin user:" 15 50 0 \
      "Name:" 1 1 "" 1 20 30 0 \
      "IP Address:" 2 1 "" 2 20 30 0 \
      3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus -eq 0 ]; then
      IFS=$'\n' read -r -d '' name ip_address <<< "$INPUT"
      
      # Dialog für Passwort
      password=$(dialog --ascii-lines --title "MongoDB Setup" --passwordbox "Enter Password:" 10 50 \
        3>&1 1>&2 2>&3)

      passwordrepeat=$(dialog --ascii-lines --title "MongoDB Setup" --passwordbox "Repeat Password:" 10 50 \
        3>&1 1>&2 2>&3)

      if [ -n "$name" ] && [ -n "$password" ] && [ -n "$passwordrepeat" ] && [ -n "$ip_address" ]; then
        if [ "$password" == "$passwordrepeat" ]; then
          mongodb_install
        else
          dialog --ascii-lines --title "Error" --msgbox "The passwords do not match. Please check your input." 6 40
        fi
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
  rm mongodb-mongosh_2.2.10_arm64.deb
  rm mongodb-mongosh_2.2.10_amd64.deb
  rm mongodb-org-server_7.0.12_amd64.deb

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
  roles: [ { role: "root", db: "admin" } ]
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

admin_user_loggin_create_user() {
  name=$(dialog --ascii-lines --title "Admin Login" --inputbox "Please enter the admin user name:" 10 50 \
    3>&1 1>&2 2>&3)

  # Eingabe des Passworts (maskiert)
  password=$(dialog --ascii-lines --title "Admin Login" --passwordbox "Please enter the admin user passwort:" 10 50 \
    3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus -eq 0 ]; then
   #Login succressfull
   list_databases
  else
    echo "Input canceled."
    clear
  fi
}

local $selected_db

list_databases() {
  MONGO_URI="mongodb://$name:$password@localhost:27017/"

  databases=$(mongosh "$MONGO_URI" --quiet --eval "db.adminCommand('listDatabases').databases.map(db => db.name).join('\n')")

  if [ -z "$databases" ]; then
    echo "No databases found."
    exit 1
  fi

  db_array=()
  while IFS= read -r db; do
    db_array+=("$db" "" "off")
  done <<< "$databases"

  echo "db_array: ${db_array[@]}"

  # Dialog zum Auswählen einer Datenbank
  exec 3>&1
  selected_db=$(dialog --ascii-lines --radiolist "Which database should the user be able to access:" 15 50 10 "${db_array[@]}" 2>&1 1>&3)
  exec 3>&-

  if [ $exitstatus -eq 0 ]; then
    clear
    mongodb_create_user_input
  else
    clear
    echo "Selection canceled."
  fi
}

mongodb_create_user_input() {
  while true; do
    # Dialog für Name
    INPUT=$(dialog --ascii-lines --title "Create User" --form "Create a new User:" 15 50 0 \
      "Username:" 1 1 "" 1 20 30 0 \
      3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus -eq 0 ]; then
      IFS=$'\n' read -r username <<< "$INPUT"
      
      # Dialog für Passwort
      passworduser=$(dialog --ascii-lines --title "Create User" --passwordbox "Enter Password:" 10 50 \
        3>&1 1>&2 2>&3)

      passwordrepeat=$(dialog --ascii-lines --title "Create User" --passwordbox "Repeat Password:" 10 50 \
        3>&1 1>&2 2>&3)

      if [ -n "$username" ] && [ -n "$passworduser" ] && [ -n "$passwordrepeat" ]; then
        if [ "$passworduser" == "$passwordrepeat" ]; then
        choose_permission
          break
        else
          dialog --ascii-lines --title "Error" --msgbox "The passwords do not match. Please check your input." 6 40
        fi
      else
        dialog --ascii-lines --title "Error" --msgbox "All fields must be filled." 6 40
      fi
    else
      clear
      break
    fi
  done
}


local permission

choose_permission() {
  OPTION=$(dialog --ascii-lines --title "Choose an Option" --menu "Select an option:" 15 50 2 \
    1 "dbOwner" \
    2 "only Read" \
    3 "read and write" \
    3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus -eq 0 ]; then
    case $OPTION in
      1)
        permission="dbOwner"
        ;;
      2)
        permission="read"
        ;;
      3)
        permission="readWrite"
        ;;
    esac
    create_user
  else
    echo "Selection cancelled."
  fi
}

create_user(){

  mongosh <<EOF
use $selected_db

db.createUser(
{
  user: "$username",
  pwd: "$passworduser",
  roles: [ { role: "$permission", db: "$selected_db" } ]
}
)
EOF

echo "$username" >> /tmp/mongodb_users.txt

clear
echo "The user $username was Succesfull Create"
}

local selected_user

admin_user_loggin_Update_user() {
  name=$(dialog --ascii-lines --title "Admin Login" --inputbox "Please enter the admin user name:" 10 50 \
    3>&1 1>&2 2>&3)

  # Eingabe des Passworts (maskiert)
  password=$(dialog --ascii-lines --title "Admin Login" --passwordbox "Please enter the admin user passwort:" 10 50 \
    3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus -eq 0 ]; then
   #Login succressfull
   choose_existing_user
  else
    echo "Input canceled."
    clear
  fi
}

local selected_user

choose_existing_user() {
  if [ -f /tmp/mongodb_users.txt ]; then
    mapfile -t users < /tmp/mongodb_users.txt
  else
    echo "No users found."
    users=()
  fi

  user_array=()
  for user in "${users[@]}"; do
    user_array+=("$user" "" "off")
  done

  exec 3>&1
  selected_user=$(dialog --ascii-lines --radiolist "Select a user:" 15 50 10 "${user_array[@]}" 2>&1 1>&3)
  exec 3>&-

  exitstatus=$?
  if [ $exitstatus -eq 0 ]; then
    clear
    list_databases2
  else
    clear
    echo "Selection canceled."
  fi
}

list_databases2() {
  MONGO_URI="mongodb://$name:$password@localhost:27017/"

  databases=$(mongosh "$MONGO_URI" --quiet --eval "db.adminCommand('listDatabases').databases.map(db => db.name).join('\n')")

  if [ -z "$databases" ]; then
    echo "No databases found."
    exit 1
  fi

  db_array=()
  while IFS= read -r db; do
    db_array+=("$db" "" "off")
  done <<< "$databases"

  echo "db_array: ${db_array[@]}"

  # Dialog zum Auswählen einer Datenbank
  exec 3>&1
  selected_db=$(dialog --ascii-lines --radiolist "Which database should the user be able to access:" 15 50 10 "${db_array[@]}" 2>&1 1>&3)
  exec 3>&-

  if [ $exitstatus -eq 0 ]; then
    clear
    choose_permission2
  else
    clear
    echo "Selection canceled."
  fi
}

choose_permission2() {
  OPTION=$(dialog --ascii-lines --title "Choose an Option" --menu "Select an option:" 15 50 2 \
    1 "dbOwner" \
    2 "only Read" \
    3 "read and write" \
    3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus -eq 0 ]; then
    case $OPTION in
      1)
        §="dbOwner"
        ;;
      2)
        permission="read"
        ;;
      3)
        permission="readWrite"
        ;;
    esac
    create_user
  else
    echo "Selection cancelled."
  fi
}

update_mongod_user(){
  mongosh <<EOF
use $selected_db

db.updateUser("$selected_user", {
  roles: [ { role: "$choose_permission2", db: "$selected_db" } ]
})
EOF

echo "$username" >> /tmp/mongodb_users.txt

clear
echo "The user $username was Succesfull Update the Permission"
}






















mariadb_setup_input() {
  while true; do
    INPUT=$(dialog --ascii-lines --title "Mariadb Setup" --form "Create an admin user:" 15 50 0 \
      "Password:" 1 1 "" 1 20 30 0 \
      3>&1 1>&2 2>&3)

    password_exitstatus=$?

    phpmyadmin_choice=$(dialog --ascii-lines --title "Mariadb Setup" --checklist "Install phpMyAdmin:" 10 50 1 \
      1 "phpMyAdmin" off \
      3>&1 1>&2 2>&3)

    phpmyadmin_exitstatus=$?

    if [ $password_exitstatus -eq 0 ] && [ $phpmyadmin_exitstatus -eq 0 ]; then
      password=$(echo "$INPUT" | tr -d '\n')
      phpmyadmin=$(echo "$phpmyadmin_choice" | tr -d '"')
      
      if [ -n "$password" ]; then
        "$password"
        if [ "$phpmyadmin" = "1" ]; then
          mariadb_phpmyadmin
        else
          mariadb_install 
        fi
        break
      else
        dialog --ascii-lines --title "Error" --msgbox "Password field must be filled." 6 40
      fi
    else
      clear
      break
    fi
  done
}

mariadb_install(){
  clear
  apt install mariadb-server -y
  mysql_secure_installation <<EOF
  $password
  Y
  n
  Y
  Y
  Y
  Y
EOF
}

mariadb_phpmyadmin() {
  clear
  apt update
  apt upgrade -y
  apt-get install nano curl unzip ca-certificates apt-transport-https lsb-release gnupg apache2 -y
  wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add - && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
  apt-get update -y
  apt-get install php8.1 php8.1-cli php8.1-common php8.1-curl php8.1-gd php8.1-intl php8.1-mbstring php8.1-mysql php8.1-opcache php8.1-readline php8.1-xml php8.1-xsl php8.1-zip php8.1-bz2 libapache2-mod-php8.1 -y

  mariadb_install

  cd /usr/share && wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip -O phpmyadmin.zip 
  unzip phpmyadmin.zip 
  rm phpmyadmin.zip 
  mv phpMyAdmin-*-all-languages phpmyadmin 
  chmod -R 0755 phpmyadmin

  CONF_FILE="/etc/apache2/conf-available/phpmyadmin.conf"

  if [ ! -f "$CONF_FILE" ]; then
    # Inhalt der Konfigurationsdatei
    CONF_CONTENT="Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
    Options SymLinksIfOwnerMatch
    DirectoryIndex index.php
</Directory>

<Directory /usr/share/phpmyadmin/templates>
    Require all denied
</Directory>
<Directory /usr/share/phpmyadmin/libraries>
    Require all denied
</Directory>
<Directory /usr/share/phpmyadmin/setup/lib>
    Require all denied
</Directory>
"

  # Erstellen der Datei und Einfügen des Inhalts
  echo "$CONF_CONTENT" | sudo tee "$CONF_FILE" > /dev/null
  echo "Konfigurationsdatei $CONF_FILE wurde erstellt."
fi

 a2enconf phpmyadmin 
 systemctl reload apache2 
 mkdir /usr/share/phpmyadmin
 mkdir /usr/share/phpmyadmin/tmp/
 chown -R www-data:www-data /usr/share/phpmyadmin/tmp/

 systemctl reload apache2
}


# Debug-Ausgaben hinzufügen
echo "Running main menu..."
main_menu
