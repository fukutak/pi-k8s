#!/bin/bash
kubectl apply -f nginx-conf.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
