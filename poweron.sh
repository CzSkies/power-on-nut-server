#!/bin/bash

battery=0
ping=0

source poweron.cfg

declare -A D_array
declare -A W_arrey

#logging funciton
myprint(){
   echo $(date +'%F %T'): $@ | tee -a $log;
}

#get charge stat of ups
currentCharge=$(upsc $batname@$batadd 2>&1 | grep 'battery.charge:' | grep -Eo '[0-9]{1,}')


while [ $battery -le 10 ]
do
    if [ $currentCharge -gt $bootCharge ]
    then

        #Wake On Lan loop
        if [ $wol -eq 1 ]
        then
            for i in "${!W_array[@]}"
            do
                while [ $ping -le 10 ] 
                do
                    wake=$(ping -c 3 ${i} | grep from* | wc -l)
                    if [ $wake -eq 3 ]
                    then
                        myprint " $i is awake "
                        ping=11
                    else
                        wakeonlan ${W_array[$i]}
                        sleep 60
                        ((ping++))
                    fi
                done
            done
        fi

        #IDRAC loop
        if [ $IDRAC -eq 1 ]
        then
            for i in "${!D_array[@]}"
            do
                if [[ $(ssh ${D_array[$i]}@$i 'racadm serveraction powerstatus') == *"OFF"* ]]
                then
                    ssh ${D_array[$i]}@$i 'racadm serveraction powerup'
                    sleep 120
                    if [[ $(ssh ${D_array[$i]}@$i 'racadm serveraction powerstatus') == *"ON"* ]]
                    then
                        myprint "The Server has been awoken!"
                    else
                        myprint "$i IDRAC accepted response but server didn't wake"
                    fi
                elif [[ $(ssh ${D_array[$i]}@$i 'racadm serveraction powerstatus') == *"ON"* ]]
                then
                    myprint "Server is awake"
                else
                    dwake=$(ping -c 3 ${D_array[$i]} | grep from* | wc -l)
                    if [ $dwake -eq 3 ]
                    then
                        myprint "$i IDRAC online but unexpect reponse"
                    else
                        myprint "$i IDRAC Offline. Does the server have power?"
                    fi
                fi
            done
        fi
    
    battery=11
    else
    ((battery++))
    sleep 60
    fi
done

if [ $ping = 10 ]
then
    myprint "$i never came online, Check connection."
fi 

if [ $battery = 10 ]
then
    myprint "Battery never got above 10% check battery status"
fi