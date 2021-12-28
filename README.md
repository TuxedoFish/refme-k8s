# Kubernetes setup for RefMe services

This is a repository for defining how the Kubernetes cluster should be setup for RefMe

## Locally 

Requirements:
- minikube
- virtualbox
- kubectl

Use the deploy.sh helper script and the command `start-minikube`. Once having done this use the `start` script to run the deployment and service. At this point you should need to run `minikube addons configure metallb` giving it a range of 192.168.59.105 and 192.168.59.120. 

Having done this you can use the following test command to see if the service is up and running:

```
grpcurl -plaintext  -d '{"query_string": "Quantum Mechanics", "page": 1}' 192.168.59.105:8080 articles.ArticlesPageService/GetArticles
```