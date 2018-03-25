#!/bin/bash

set -x
set -e

# all hosts

hostList=(test214 test215 test216 test217)

# new user name list
curUser=user
userList=(user1 user2 user3)


# I need to know the number of user and host
userCnt=${#userList[@]}
hostCnt=${#hostList[@]}


for hostIndex in  $hostList
do 
    # login in the remote host as root
    ssh root@$hostIndex

    # check default uid and gid of current user
    set +e
    id user 
    i=$?
    set -e
    if [ $i -ne 0 ]; then
        # default user does not exist, so you need create it first
        groupadd -g 1000  user
    fi
    defaultRegularGID=`id user -g`      # default GID is 1000
    defaultRegularUID=`id user -u`      # default UID is 1000

    index=1
    for username in $userList 
    do 
        # create each user and generate corresponding ssh RSA keys.
        newUID=$(expr $defaultRegularUID + index)
        useradd -d /home/$username -g user -u $newUID -s /bin/bash -m $username
        # setup default password for created username
        # echo "passwd" | passwd $username --stdin    # think about chpasswd 

        #
        set timeout 5
        expect<<-EOF
        spawn passwd $username
        expect "Enter new UNIX password: "
        send "passwd\r"
        expect "Retype new UNIX password: "
        send "passwd\r"
        expect eof 
        EOF

        echo "step 1: create new user $username success."

        # switch to new user and generate ssh RSA keys
        su - $username  # this will set CWD to $HOME

        expect<<-EOF
        spawn ssh-keygen -t rsa
        expect "Enter file in which to save the key (/home/$username/.ssh/id_rsa): "
        send "\r"
        expect "Enter passphrase (empty for no passphrase): "
        send "\r"
        expect "Enter same passphrase again: "
        send "\r"
        expect eof
EOF
        echo "step 2: ssh-keygen operation success for $username."

        # prepare to handle the next one, and increment index
        let index++
    done
done

echo "step 3: setup remote login without password."

for hostIndex in $hostList 
do 
    for username in $userList 
    do 
        expect<<-EOF
        spawn ssh-copy-id $username@$hostIndex
        expect {
            "*(yes/no)? " { send "yes\r"; exp_continue }
            "*password: " { send "passwd\r" }
        }
        expect eof
EOF
    done
done



