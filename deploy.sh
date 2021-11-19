#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
AMBER='\033[0;33m'
NC='\033[0m' 

if [[ $1 == 'start' ]]
then
    printf "\n${AMBER}Images available on minikube: ${NC}\n\n"
    # minikube image list
    minikube image ls

    # Start up the articles service 
    printf "\n${AMBER}Starting articles deployment...${NC}\n\n"
    kubectl apply -f ./services/articles/articles-deployment.yaml
    printf "\n${AMBER}Starting articles service...${NC}\n\n"
    kubectl apply -f ./services/articles/articles-service.yaml

    # Start up the envoy proxy 
    printf "\n${AMBER}Starting envoy deployment...${NC}\n\n"
    kubectl apply -f ./services/envoy/envoy-deployment.yaml
    printf "\n${AMBER}Starting envoy service...${NC}\n\n"
    kubectl apply -f ./services/envoy/envoy-service.yaml

    # Output the nodes to the screen
    printf "\n${GREEN}Finished start up.\n\n${NC}"
    printf "${GREEN}Pods:${NC}\n\n"
    kubectl get pods -n development
    printf "\n${GREEN}Services:${NC}\n\n"
    kubectl get services -n development
    printf "\n${GREEN}Endpoint:${NC}\n\n"
    minikube service -n development refme-envoy-proxy --url
elif [[ $1 == 'stop' ]]
then
    # Remove pods and services by their labels
    printf "\n${RED}Stopping deployment...${NC}\n\n"
    kubectl delete deploy refme-articles-service -n development
    kubectl delete services refme-articles-service -n development
    kubectl delete deploy refme-envoy-proxy -n development
    kubectl delete services refme-envoy-proxy -n development

    # Output the result to the screen
    printf "\n${RED}Deleted deployment.\n\n${NC}"
    printf "${GREEN}Pods:${NC}\n\n"
    kubectl get pods -n development
    printf "\n${GREEN}Services:${NC}\n\n"
    kubectl get services -n development
elif [[ $1 == 'status' ]]
then
    # Output the result to the screen
    printf "${GREEN}Pods:${NC}\n\n"
    kubectl get pods -n development
    printf "\n${GREEN}Services:${NC}\n\n"
    kubectl get services -n development
    printf "\n${GREEN}Endpoint:${NC}\n\n"
    minikube service refme-envoy-proxy --url -n development
    printf "\n${GREEN}Logs:${NC}\n\n"
    kubectl logs -f -l app=refme-articles-service -n development
elif [[ $1 == 'restart' ]]
then
    # Stop 
    ./deploy.sh stop $-
    # Start
    ./deploy.sh start $-
elif [[ $1 == 'start-minikube' ]]
then
    # Start minikube with virtualbox
    minikube start --driver=virtualbox
    # Enable addons for ingress
    printf "\n${GREEN}Setup metallb addons...${NC}\n"
    minikube addons enable metallb
    kubectl describe configmap config -n metallb-system
    # Create namespace
    kubectl create -f ./config/namespaces/namespace-dev.json
else
    # Output to the screen that not recongized
    echo "Command not recognized please use one of: [status/build-images/start/stop/restart]"
fi