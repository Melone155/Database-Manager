#!/bin/bash

if ! command -v dialog &> /dev/null; then
  apt-get update -y
  apt-get install dialog -y
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
      echo "Name: $name"
      echo "Password: $password"
      echo "IP Address: $ip_address"
      if [ -n "$name" ] && [ -n "$password" ] && [ -n "$ip_address" ]; then
        echo "All fields are filled."
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


# Debug-Ausgaben hinzufügen
echo "Running main menu..."
main_menu
echo "Finished running main menu."
