#!/bin/bash

/opt/elasticbeanstalk/bin/healthd-track-pidfile --name aws-sqsd --location /var/run/aws-sqsd/default.pid
