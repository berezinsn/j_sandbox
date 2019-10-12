#!/bin/bash
read -p "Set the variable jenkins-user: " juser
read -sp "Set the variable jenkins-password: " jpass
#Creates folders that will mounted as volumes
if [[ ! -d "./master/data" ]]; then
    mkdir "./master/data"
fi
if [[ ! -d "./master/log" ]]; then
    mkdir "./master/log"
fi
if [[ ! -d "./nexus/data" ]]; then
    mkdir "./nexus/data"
fi    
#read -p "Provide URL where the seed job placed: " SEED_JOBS_URL
rm -rf ./master/data/* ./master/log/* ./nexus/data/*
echo $juser > ./master/data/juser && echo $jpass > ./master/data/jpass
make build && make run
docker logs $(docker ps | grep jenkins_haproxy | awk '{print $1}')
