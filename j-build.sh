#!/bin/bash
read -p "Set the variable jenkins-user: " juser
read -sp "Set the variable jenkins-password: " jpass
#read -p "Provide URL where the seed job placed: " SEED_JOBS_URL
rm -rf ./master/data/* ./master/log/* ./nexus/data/*
echo $juser > ./master/data/juser && echo $jpass > ./master/data/jpass
make build && make run
docker logs $(docker ps | grep jenkins_haproxy | awk '{print $1}')
