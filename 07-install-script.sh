#/bin/bash

USERID=$(id -u)
if [ "$USERID" -ne 0 ]; then
    echo "Please run this script as root or using sudo"
    exit 1
fi

dnf list installed mysql

if [ $? -eq 0 ]; then
    echo "MySQL is already installed"
    exit 0
fi

dnf install mysql-server -y
if [ $? -ne 0 ]; then
    echo "MySQL installation failed"
    exit 1
fi
systemctl enable mysqld
systemctl start mysqld

dnf install git -y
if [ $? -ne 0 ]; then
   then
   echo "Git installation failed" 
    exit 1
   else
    echo "Git installed successfully"
fi
