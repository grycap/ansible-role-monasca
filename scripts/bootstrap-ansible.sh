#!/usr/bin/env bash
# Copyright 2014, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# (c) 2014, Kevin Carter <kevin.carter@rackspace.com>

## Shell Opts ----------------------------------------------------------------
set -e -u -x


## Vars ----------------------------------------------------------------------
export HTTP_PROXY=${HTTP_PROXY:-""}
export HTTPS_PROXY=${HTTPS_PROXY:-""}
export ANSIBLE_PACKAGE=${ANSIBLE_PACKAGE:-"ansible==2.2.0.0"}
export DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-"noninteractive"}
# Set the location of the constraints to use for all pip installations
export UPPER_CONSTRAINTS_FILE=${UPPER_CONSTRAINTS_FILE:-"http://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?id=master"}
# virtualenv vars
VIRTUALENV_OPTIONS="--always-copy"

# This script should be executed from the root directory of the cloned repo
cd "$(dirname "${0}")/.."

## Functions -----------------------------------------------------------------
info_block "Checking for required libraries." 2> /dev/null ||
    source scripts/scripts-library.sh

## Main ----------------------------------------------------------------------
info_block "Bootstrapping System with Ansible"

# Store the clone repo root location
export OSA_CLONE_DIR="$(pwd)"

# Create the ssh dir if needed
ssh_key_create

# Determine the distribution which the host is running on
determine_distro

# Install the base packages
case ${DISTRO_ID} in
    centos|rhel)
        yum -y install git python2 curl autoconf gcc-c++ \
          python2-devel gcc libffi-devel nc openssl-devel \
          python-pyasn1 pyOpenSSL python-ndg_httpsclient \
          python-netaddr python-prettytable python-crypto PyYAML \
          python-virtualenv
          VIRTUALENV_OPTIONS=""
        ;;
    ubuntu)
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get -y install \
          git python-all python-dev curl python2.7-dev build-essential \
          libssl-dev libffi-dev netcat python-requests python-openssl python-pyasn1 \
          python-netaddr python-prettytable python-crypto python-yaml \
          python-virtualenv
        ;;
esac

# NOTE(mhayden): Ubuntu 16.04 needs python-ndg-httpsclient for SSL SNI support.
#                This package is not needed in Ubuntu 14.04 and isn't available
#                there as a package.
if [[ "${DISTRO_ID}" == 'ubuntu' ]] && [[ "${DISTRO_VERSION_ID}" == '16.04' ]]; then
  DEBIAN_FRONTEND=noninteractive apt-get -y install python-ndg-httpsclient
fi

# Install pip
get_pip

# Ensure we use the HTTPS/HTTP proxy with pip if it is specified
PIP_OPTS=""
if [ -n "$HTTPS_PROXY" ]; then
  PIP_OPTS="--proxy $HTTPS_PROXY"
elif [ -n "$HTTP_PROXY" ]; then
  PIP_OPTS="--proxy $HTTP_PROXY"
fi

# Create a Virtualenv for the Ansible runtime
PYTHON_EXEC_PATH="$(which python2 || which python)"
virtualenv --clear ${VIRTUALENV_OPTIONS} --system-site-packages --python="${PYTHON_EXEC_PATH}" /opt/ansible-runtime

# The vars used to prepare the Ansible runtime venv
PIP_OPTS+=" --upgrade"
PIP_COMMAND="/opt/ansible-runtime/bin/pip"

# When upgrading there will already be a pip.conf file locking pip down to the
# repo server, in such cases it may be necessary to use --isolated because the
# repo server does not meet the specified requirements.

# Ensure we are running the required versions of pip, wheel and setuptools
${PIP_COMMAND} install ${PIP_OPTS} ${PIP_INSTALL_OPTIONS} || ${PIP_COMMAND} install ${PIP_OPTS} --isolated ${PIP_INSTALL_OPTIONS}

# Set the constraints now that we know we're using the right version of pip
PIP_OPTS+=" --constraint ${UPPER_CONSTRAINTS_FILE}"

# Install the required packages for ansible
$PIP_COMMAND install $PIP_OPTS -r requirements.txt ${ANSIBLE_PACKAGE} || $PIP_COMMAND install --isolated $PIP_OPTS -r requirements.txt ${ANSIBLE_PACKAGE}

# Ensure that Ansible binaries run from the venv
pushd /opt/ansible-runtime/bin
  for ansible_bin in $(ls -1 ansible*); do
      # For any other commands, we want to link directly to the binary
      ln -sf /opt/ansible-runtime/bin/${ansible_bin} /usr/local/bin/${ansible_bin}
  done
popd

echo "System is bootstrapped and ready for use."
