#!/bin/bash

set -xe

/opt/elasticbeanstalk/bin/healthd-track-pidfile --name application --location /var/run/docker.pid

