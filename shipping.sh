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

echo "Please enter root password to setup"
read -s MYSQL_ROOT_PASSWORD
echo -e "Password entered...$Y PROCEDING FURTHER $N"

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

dnf install maven -y &>>$LOG_FILE
VALIDATE $? "Installing maven and java"

id roboshop
if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
    VALIDATE $? "Creating the roboshop system user...."
else
    echo -e "Roboshop system user already created....$Y SKIPPING $N "
fi

mkdir -p /app 
VALIDATE $? "Creating the app directory"

curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip &>>$LOG_FILE 
VALIDATE $? "Downloading the Shipping"

rm -rf /app/*
cd /app 

unzip /tmp/shipping.zip &>>$LOG_FILE
VALIDATE $? "Unzipping the shipping code"

mvn clean package &>>$LOG_FILE
VALIDATE $? "Packaging the shipping application"

mv target/shipping-1.0.jar shipping.jar &>>$LOG_FILE 
VALIDATE $? "Moving and renaming the jar file"

cp $SCRIPT_DIR/shipping.service /etc/systemd/system/shipping.service

systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "Daemon reloading"

systemctl enable shipping &>>$LOG_FILE
VALIDATE $? "Enabling the shipping"

systemctl start shipping &>>$LOG_FILE
VALIDATE $? "Starting the shipping"

dnf install mysql -y &>>$LOG_FILE
VALIDATE $? "Installing mysql"

mysql -h mysql.arunkumarnelluri.site -u root -p$MYSQL_ROOT_PASSWORD -e 'use cities' &>>$LOG_FILE
if [ $? -ne 0 ]
then
    mysql -h mysql.arunkumarnelluri.site -uroot -pRoboShop@1 < /app/db/schema.sql &>>$LOG_FILE
    mysql -h mysql.arunkumarnelluri.site -uroot -pRoboShop@1 < /app/db/app-user.sql &>>$LOG_FILE
    mysql -h mysql.arunkumarnelluri.site -uroot -pRoboShop@1 < /app/db/master-data.sql &>>$LOG_FILE
    VALIDATE $? "Loading the data into mysql"
else
    echo -e "Data already loaded into MySQL....$Y SKIPPING $N"
fi

systemctl restart shipping
VALIDATE $? "Restarting the shipping"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME ))
echo -e "Script executed successfully, $Y Time taken: $TOTAL_TIME seconds $N" | tee -a $LOG_FILE