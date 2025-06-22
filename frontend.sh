#!/bin/bash


USERID=$(id -u) 
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/roboshop-logs" ##Here we are creating the roboshop logs directory
SCRIPT_NAME=$( echo $0 | cut -d "." -f1 ) ##Here we are getting the file name with '$0' and removing the .sh extension 
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"  ##Here we are denoting the logs file name to LOG_FILE Variable..like 14-logs.log
SCRIPT_DIR=$PWD

mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE

# check the user has root priveleges or not
if [ $USERID -ne 0 ]
then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
    exit 1 #give other than 0 upto 127
else
    echo "You are running with root access" | tee -a $LOG_FILE
fi

# validate functions takes input as exit status, what command they tried to install
VALIDATE(){
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}

dnf module disable nginx -y &>>$LOG_FILE
VALIDATE $? "Disabling the nginx"

dnf module enable nginx:1.24 -y &>>$LOG_FILE
VALIDATE $? "Enabling nginx:1.24"

dnf install nginx -y &>>$LOG_FILE
VALIDATE $? "Installing the nginx"

systemctl enable nginx 
systemctl start nginx &>>$LOG_FILE
VALIDATE $? "Starting the ngix"

rm -rf /usr/share/nginx/html/* 

curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>>$LOG_FILE
VALIDATE $? "Downlading the frontend"

cd /usr/share/nginx/html 
unzip /tmp/frontend.zip &>>$LOG_FILE
VALIDATE $? "Unzipping the frontend code"



cp $SCRIPT_DIR/nginx.conf /etc/nginx/nginx.conf

systemctl restart nginx 
VALIDATE $? "Restarting the nginx"

