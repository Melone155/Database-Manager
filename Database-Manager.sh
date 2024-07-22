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
        mariadb_setup_input
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
      "Create User")
        clear
        mariadb_create_user
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
local passwordrepeat
local $ip_address

# Funktion für MongoDB-Setup-Eingabe
mongodb_setup_input() {
  while true; do
    INPUT=$(dialog --ascii-lines --title "MongoDB Setup" --form "Create an admin user:" 15 50 0 \
      "Name:" 1 1 "" 1 20 30 0 \
      "Password:" 2 1 "" 2 20 30 0 --insecure \
      "Password repeat:" 3 1 "" 2 20 30 0 --insecure \
      "IP Address:" 4 1 "" 3 20 30 0 \
      3>&1 1>&2 2>&3)

    exitstatus=$?
    echo "mongodb_setup_input exitstatus: $exitstatus"
    echo "mongodb_setup_input input: $INPUT"
    if [ $exitstatus -eq 0 ]; then
      IFS=$'\n' read -r -d '' name password ip_address <<< "$INPUT"
      $name
      $password
      $passwordrepeat
      $ip_address
      if [ -n "$name" ] && [ -n "$password" ] && [ -n "$passwordrepeat"] && [ -n "$ip_address" ]; then
        if [ $password == $passwordrepeat ]; then
          mongodb_install
        else
          dialog --ascii-lines --title "Error" --msgbox "The passwords are not correct Please check your input." 6 40
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

mariadb_create_user(){

# Abrufen der Datenbankliste mit mongosh
databases=$(echo "show dbs" | mongosh --quiet)

# Überprüfen, ob Datenbanken gefunden wurden
if [ -z "$databases" ]; then
  echo "Keine Datenbanken gefunden."
  exit 1
fi

# Konvertieren der Datenbankliste in ein dialog-kompatibles Format
db_array=()
index=1
while read -r db size; do
  db_array+=($index "$db")
  index=$((index + 1))
done <<< "$databases"

# Auswahl der Datenbank mit dialog
db_selection=$(dialog --ascii-lines --title "Wählen Sie eine Datenbank aus" --menu "Verfügbare Datenbanken:" 15 50 10 "${db_array[@]}" 3>&1 1>&2 2>&3)

# Überprüfen des exitstatus von dialog
exitstatus=$?
if [ $exitstatus -ne 0 ]; then
  echo "Auswahl abgebrochen."
  exit 1
fi

# Extrahieren des ausgewählten Datenbanknamens
selected_db=$(echo "$databases" | awk "NR==$db_selection {print \$1}")

# Ausgabe der ausgewählten Datenbank
echo "Sie haben die Datenbank ausgewählt: $selected_db"


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
