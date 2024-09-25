#!/bin/bash

docker pull localstack/localstack:latest

pip install localstack

pip install awscli awscli-local
