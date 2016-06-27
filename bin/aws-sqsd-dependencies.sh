#!/bin/bash
#
RUBY_ROOT="/opt/elasticbeanstalk/lib/ruby"
BUCKET="elasticbeanstalk-env-resources-eu-west-1"

on_error() {
    EXIT_CODE=$?
    if [ "${EXIT_CODE}" != "0" ]
    then
        echo "`basename ${0}`:${1-unknown}: error: \"${2:-No error message specified}\". exit code: ${EXIT_CODE}"
        exit 1
    fi
}

function is_baked
{
	if [[ -f /etc/elasticbeanstalk/baking_manifest/$1 ]]; then
    true
	else
    false
	fi
}

if [ -d "${RUBY_ROOT}" ]
then
    exit 0
fi

ARCHITECTURE=`uname -m`
if [ "${ARCHITECTURE}" == "i686" ]
then
    ARCHITECTURE="i386"
fi
VM_TAR="awseb-ruby-2.2.4-${ARCHITECTURE}-20160315_2014.tar.gz"
S3_URL_BASE="s3-eu-west-1.amazonaws.com"
KEY="eb_sqsd/${VM_TAR}"

if is_baked ${VM_TAR}-manifest; then
    echo $VM_TAR has already been installed. Skipping installation.
else
	curl --retry 10 "https://${BUCKET}.${S3_URL_BASE}/${KEY}" > /tmp/aws-sqsd-ruby.tar.gz
	on_error ${LINENO} "download of https://${BUCKET}.${S3_URL_BASE}/${KEY} failed"
	
	tar zxf /tmp/aws-sqsd-ruby.tar.gz -C /
	on_error ${LINENO} "extracting archive /tmp/aws-sqsd-ruby.tar.gz failed"
	
	rm -f /tmp/aws-sqsd-ruby.tar.gz    
fi
