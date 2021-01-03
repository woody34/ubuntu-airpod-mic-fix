#!/bin/bash
# https://askubuntu.com/questions/1231074/ubuntu-20-04-bluetooth-not-working <-- setup blueman
# https://askubuntu.com/questions/831331/failed-to-change-profile-to-headset-head-unit

RANDOM=$(cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | sed -e 's/^0*//' | head --bytes 3)

install_ofono() {
    echo 'Installing ofono'
    sudo apt install ofono
    return $?
}

update_pulse_audio_config() {
    FILE_PATH='/etc/pulse/default.pa'
    FILE_PATH_BACKUP="${FILE_PATH}.$RANDOM"
    OLD_LINE="load-module module-bluetooth-discover"
    NEW_LINE="load-module module-bluetooth-discover headset=ofono"
    ALREADY_UPDATED=$(grep -Fxq "$NEW_LINE" $FILE_PATH)

    if [ -n "$ALREADY_UPDATED" ]
    then
        echo "backing up $FILE_PATH -> $FILE_PATH_BACKUP";
        sudo cp $FILE_PATH $FILE_PATH_BACKUP
        sudo sed -i "s/$OLD_LINE/$NEW_LINE/g" $FILE_PATH
        echo "$FILE_PATH update complete"
        return $?
    else
        echo "pulse audio config previously updated"
        return
    fi
}

add_user_pulse_to_bluetooth_group() {
    echo 'Adding user "pulse" to group "bluetooth"'
    sudo usermod -aG bluetooth pulse
}

update_ofono_config() {
    FILE_PATH='/etc/dbus-1/system.d/ofono.conf'
    FILE_PATH_BACKUP="$FILE_PATH.$RANDOM"
    ALREADY_UPDATED=$(grep "pulse" $FILE_PATH)

    if [ -z "$ALREADY_UPDATED" ]
    then
        echo "backup: $FILE_PATH -> $FILE_PATH_BACKUP";
        sudo cp $FILE_PATH $FILE_PATH_BACKUP
        echo "copying: asset -> $FILE_PATH";
        sudo cp ./assets/ofono.conf $FILE_PATH
        sudo chown root $FILE_PATH
        sudo chmod 644 $FILE_PATH

        # NEW_CONFIG=$(xmlstarlet ed -s '//busconfig' -t elem -n 'policy' \
        #                  -s '/busconfig/policy[last()]' -t attr -n 'user' -v 'pulse' \
        #                  -s '/busconfig/policy[last()]' -t elem -n 'allow' \
        #                  -s '/busconfig/policy[last()]/allow' -t attr -n 'send_destination' -v 'org.ofono' $FILE_PATH)
        # sudo sh -c "echo $'$NEW_CONFIG' > $FILE_PATH"
        # echo "$FILE_PATH update complete"
    else
        echo "ofono config previously updated"
    fi
}

install_phone_sim() {
    INSTALLED="ofono-phonesim -v"

    if [ -z "$INSTALLED" ]
    then
        echo "install: phonesim"
        sudo add-apt-repository ppa:smoser/bluetooth
        sudo apt-get update
        sudo apt-get install ofono-phonesim
        return $?
    else
        echo "phonesim previously installed"
        return
    fi
}

update_phone_sim_config() {
    FILE_PATH='/etc/ofono/phonesim.conf'
    FILE_PATH_BACKUP="$FILE_PATH.$RANDOM"
    ALREADY_UPDATED=$(grep "Driver=phonesim" $FILE_PATH)

    if [ -z "$ALREADY_UPDATED" ]
    then
        echo "backup: $FILE_PATH -> $FILE_PATH_BACKUP";
        sudo cp $FILE_PATH $FILE_PATH_BACKUP
        echo "copying: asset -> $FILE_PATH";
        sudo cp ./assets/phonesim.conf $FILE_PATH
        sudo chown root $FILE_PATH
        sudo chmod 644 $FILE_PATH
        # sudo sh -c "echo [phonesim] >> $FILE_PATH"
        # sudo sh -c "echo Driver=phonesim >> $FILE_PATH"
        # sudo sh -c "echo Address=127.0.0.1 >> $FILE_PATH"
        # sudo sh -c "echo Port=12345 >> $FILE_PATH"
        return $?
    else
        echo "phonesim config previously updated"
        return
    fi
}

restart_ofono_service() {
    sudo sh -c "systemctl restart ofono.service"
    sudo sh -c "systemctl status ofono.service"
}

clone_ofono_repo() {
    sudo sh -c "cd /usr/lib"

    EXISTS=/usr/lib/ofono/
    if [ -f "$EXISTS" ]
    then
        echo "ofono detected"
    else
        echo "cloning ofono"
        sudo git clone git://git.kernel.org/pub/scm/network/ofono/ofono.git
    fi
}

replace_ofono_service() {
    FILE_PATH="/lib/systemd/system/ofono.service"
    echo "backup: ofono service"
    sudo  cp /lib/systemd/system/ofono.service /lib/systemd/system/ofono.service.bak
    echo "replace: ofono service"
    sudo cp ./assets/ofono.service $FILE_PATH
    sudo chown root $FILE_PATH
    sudo chmod 644 $FILE_PATH
    sudo sh -c "systemctl daemon-reload"
    sudo sh -c "systemctl enable ofono-phonesim"
    sudo sh -c "systemctl start ofono-phonesim"
    sudo sh -c "systemctl status ofono-phonesim"
}

create_ofono_modem_service() {
    FILE_PATH="/etc/systemd/system/ofono-modem.service"
    FILE=/etc/systemd/system/ofono-modem.service

    if [ -f "$FILE" ]
    then
        echo "ofono-modem service previous configured"
        sudo systemctl daemon-reload
        sudo systemctl restart ofono-modem
        sudo systemctl status ofono-modem
    else
        echo "creating ofono-modem service"
        sudo cp ./assets/ofono-modem.service $FILE_PATH
        sudo sh -c "systemctl daemon-reload"
        sudo sh -c "systemctl enable ofono-modem"
        sudo sh -c "systemctl start ofono-modem"
        sudo sh -c "systemctl status ofono-modem"
    fi
}

start_phone_sim_service() {
    FILE_PATH="/etc/systemd/system/ofono-phonesim.service"
    FILE=/etc/systemd/system/ofono-phonesim.service

    if [ -f "$FILE" ]
    then
        echo "ofono-phonesim service previous configured"
        sudo systemctl daemon-reload
        sudo systemctl restart ofono-phonesim
        sudo systemctl status ofono-phonesim
    else
        echo "creating ofono-phonesim service"
        sudo cp ./assets/ofono-phonesim.service $FILE_PATH
        sudo sh -c "systemctl daemon-reload"
        sudo sh -c "systemctl enable ofono-phonesim"
        sudo sh -c "systemctl start ofono-phonesim"
        sudo sh -c "systemctl status ofono-phonesim"
    fi
}

restart_pulse_audio() {
    echo "restarting pulseaudio"
    pulseaudio -k
    pulseaudio --start
}

test_phono_sim() {
    echo "testing ofono with phone sim"
    cd /usr/lib/ofono/test
    MODEMS=$(./list-modems)
    if [ -z "$MODEMS" ]
    then
        echo "error: no modems detected"
        return 1
    else
        echo "success: setup ofono and phonesim"
        return 0
    fi
}

install_ofono
update_pulse_audio_config
add_user_pulse_to_bluetooth_group
update_ofono_config
install_phone_sim
update_phone_sim_config
restart_ofono_service
clone_ofono_repo
replace_ofono_service
create_ofono_modem_service
start_phone_sim_service
restart_pulse_audio
test_phono_sim