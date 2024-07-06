#!/bin/bash

# Funktion, die das Hauptmenü anzeigt
main_menu() {
  CHOICE=$(dialog --ascii-lines --title "DB Manager" --menu "Please choose your database" 15 50 3 \
  "MongoDB" "" \
  "MariaDB" "" \
  "Oracle" "" \
  3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    case $CHOICE in
      MongoDB)
        clear
        mongodb_menu
        ;;
      MariaDB)
        echo "You chose MariaDB."
        ;;
      Oracle)
        echo "You chose Oracle."
        ;;
    esac
  else
    clear
  fi
}

#  MongoDB-Menü
mongodb_menu() {
  CHOICE=$(dialog --ascii-lines --title "DB Manager (MongoDB)" --menu "Please choose your action" 15 50 5 \
  "Install" "You can install your database if there is none on the system yet" \
  "Update" "Search for and perform an update" \
  "Create User" "Create new user" \
  "Update User" "Edit rights for existing users" \
  "Delete User" "Delete existing users" \
  3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    case $CHOICE in
      "Install")
        echo "You chose Install."
        ;;
      "Update")
        echo "You chose Update."
        ;;
      "Create User")
        echo "You chose Create User."
        ;;
      "Update User")
        echo "You chose Update User."
        ;;
      "Delete User")
        echo "You chose Delete User."
        ;;
    esac
  else
    clear
  fi
}

mongodb_install() {

   local exitstatus

   if systemctl is-active --quiet mongodb; then
    clear
    echo 'Mongodb is already installed'
  elif systemctl is-enabled --quiet mongodb; then
   clear
   echo 'Mongodb is already installed' 
  else
        apt install wget

        . /etc/os-release
        VERSION_ID=${VERSION_ID//\"/} 
        DEBIAN_VERSION=$(echo $VERSION_ID | cut -d'.' -f1)
        if [ "$DEBIAN_VERSION" -ge 12 ]; then

            mkdir DBfiles
            cd DBfiles
            wget https://repo.mongodb.org/apt/debian/dists/bookworm/mongodb-org/7.0/main/binary-amd64/mongodb-org-server_7.0.12_amd64.deb
            dpkg -i mongodb-org-server_7.0.12_amd64

            ARCH=$(uname -m)
            if [ "$ARCH" = "x86_64" ]; then
                wget https://downloads.mongodb.com/compass/mongodb-mongosh_2.2.10_amd64.deb
                dpkg -i mongodb-mongosh_2.2.10_amd64.deb

            elif [ "$ARCH" = "aarch64" ]; then
                 wget https://downloads.mongodb.com/compass/mongodb-mongosh_2.2.10_arm64.deb
                dpkg -i mongodb-mongosh_2.2.10_arm64.deb
        

        elif [ "$DEBIAN_VERSION" -ge 11 ]; then

            mkdir DBfiles
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
        else
            clear
            echo "Debian Version ist älter als 11."
    fi
  fi
}

# Debug-Ausgaben hinzufügen
echo "Running main menu..."
main_menu
echo "Finished running main menu."