#!/bin/bash

START_TIME=$(date +%s)
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


dnf install golang -y &>>$LOG_FILE
VALIDATE $? "Installing the GoLang"

id roboshop

if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
    VALIDATE $? "Creating the roboshop system user"
else
    echo -e "Roboshop system user already created....$Y SKIPPING $N" &>>$LOG_FILE
fi

mkdir -p /app
VALIDATE $? "Creating the app directory"

curl -L -o /tmp/dispatch.zip https://roboshop-artifacts.s3.amazonaws.com/dispatch-v3.zip &>>$LOG_FILE 
VALIDATE $? "Downliading the dispatch code"

rm -rf /app/*
cd /app 

unzip /tmp/dispatch.zip &>>$LOG_FILE
VALIDATE $? "Unzipping the dispatch"
 
go mod init dispatch &>>$LOG_FILE
VALIDATE $? "Downloading the $Y mod init $N dependencies..."

go get &>>$LOG_FILE
VALIDATE $? "Downloading the $Y get $N dependencies..."

go build &>>$LOG_FILE
VALIDATE $? "Downloading the $Y go build $N dependencies..."

cp $SCRIPT_DIR/dispatch.service /etc/systemd/system/dispatch.service &>>$LOG_FILE
VALIDATE $? "Copying the dispatch service to systemd"

systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "Daemon reloading"

systemctl enable dispatch &>>$LOG_FILE
VALIDATE $? "Enabling the dispatch"

systemctl start dispatch &>>$LOG_FILE
VALIDATE $? "Starting the dispatch"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME ))
echo -e "Script executed successfully, $Y Time taken: $TOTAL_TIME seconds $N" | tee -a $LOG_FILE
