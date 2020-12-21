#!/bin/bash
set -e

VIRTUAL_ENV=
CTC_DIR=
GITHUB_CLONE_URL=https://github.com/

SUPPORT_KIND_VERSION=0.9.0
SUPPORT_KOPS_VERSION=1.18.2
SUPPORT_KUBECTL_VERSION=1.20.0
SUPPORT_TERRAFORM_VERSION=0.14.3
SUPPORT_JQ_VERSION=1.6

check_requeriments() {
	echo -n "Checking requirements... "
	if [ ! -d support ]; then
		echo "FAIL: support dir not found. run ctc-bs.sh su"
		exit 1
	fi
	which curl >/dev/null
	if [ $? -ne 0 ]; then
		echo "FAIL: Curl not found"
		exit 1
	fi
	which python3 >/dev/null
	if [ $? -ne 0 ]; then
		echo "FAIL: Python3 not found"
		exit 1
	fi
	python3 -c "import venv" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "FAIL: Python3 -m venv fail"
		exit 1
	fi
	which sed >/dev/null
	if [ $? -ne 0 ]; then
		echo "FAIL: sed not found"
		exit 1
	fi
	which install >/dev/null
	if [ $? -ne 0 ]; then
		echo "FAIL: install not found"
		exit 1
	fi
	which unzip >/dev/null
	if [ $? -ne 0 ]; then
		echo "FAIL: unzip not found"
		exit 1
	fi
	which openssl >/dev/null
	if [ $? -ne 0 ]; then
		echo "FAIL: openssl not found"
		exit 1
	fi
	echo "OK"
}


setvars() {
	VIRTUAL_ENV=$(pwd)/venv
	CTC_DIR=$(pwd)
}


cmd_support_clean() {
	echo -n "Clean support directory... "
	rm -f support/*
	echo "OK"
}

cmd_support_update() {
	echo "Update support"
	mkdir -p support
	echo -n "JQ... "
	if [ ! -e support/jq ]; then
		curl -o support/jq -s -L https://github.com/stedolan/jq/releases/download/jq-${SUPPORT_JQ_VERSION}/jq-linux64
		echo "downloaded"
	else
		echo "OK"
	fi
	echo -n "Kind... "
	if [ ! -e support/kind ]; then
		curl -o support/kind -s -L https://kind.sigs.k8s.io/dl/v${SUPPORT_KIND_VERSION}/kind-linux-amd64
		echo "downloaded"
	else
		echo "OK"
	fi
	echo -n "Kops... "
	if [ ! -e support/kops ]; then
		curl -o support/kops -s -L https://github.com/kubernetes/kops/releases/download/v${SUPPORT_KOPS_VERSION}/kops-linux-amd64
		echo "downloaded"
	else
		echo "OK"
	fi
	echo -n "Kubectl... "
	if [ ! -e support/kubectl ]; then
		curl -o support/kubectl -s -L https://storage.googleapis.com/kubernetes-release/release/v${SUPPORT_KUBECTL_VERSION}/bin/linux/amd64/kubectl
		echo "downloaded"
	else
		echo "OK"
	fi
	echo -n "Terraform... "
	if [ ! -e support/terraform ]; then
		curl -o support/terraform.zip -s -L https://releases.hashicorp.com/terraform/${SUPPORT_TERRAFORM_VERSION}/terraform_${SUPPORT_TERRAFORM_VERSION}_linux_amd64.zip
		echo "downloaded"
		unzip -qq -d support support/terraform.zip
		rm support/terraform.zip
	else
		echo "OK"
	fi
	echo -n "AWS cli 2... "
	if [ ! -e support/awscliv2.zip ]; then
		curl -o support/awscliv2.zip -L -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
		echo "downloaded"
	else
		echo "OK"
	fi
	echo -n "HEY... "
	if [ ! -e support/hey ]; then
		curl -o support/hey -L -s https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
		echo "downloaded"
	else
		echo "OK"
	fi
}

cmd_support_help() {
	echo "$(basename $0) su|support [OPTIONS]"
	echo ""
	echo "-h        Show help"
	echo "-f        Force update"
	echo ""
	exit 1
}

cmd_support() {
	OPTS=$(getopt -o huf -n 'parse-options' -- "$@")
	eval set -- "$OPTS"

	while true; do
		case "$1" in
			-h)
				cmd_support_help
				shift
				;;
			-f)
				cmd_support_clean
				shift
				break
				;;
			--)
				shift
				break
				;;
		esac
	done

	cmd_support_update
}


cmd_venv_clean() {
	echo -n "Cleaning the venv... "
	rm -rf $VIRTUAL_ENV
	rm -f ctcenv
	echo "OK"
}

cmd_venv_install() {
	echo -n "Installing the venv... "
	if [ -d $VIRTUAL_ENV ]; then
		echo "FAIL: already exists"
		exit 1
	fi
	python3 -m venv $VIRTUAL_ENV
	mkdir -p $VIRTUAL_ENV/tmp $CTC_DIR/var/devel/kube $CTC_DIR/var/pruduction/kube

	for target in production devel; do
		sed -e "s|@VIRTUAL_ENV@|$VIRTUAL_ENV|g" \
			-e "s|@CTC_DIR@|$CTC_DIR|g" \
			-e "s|@CTC_TARGET@|$target|g" \
			-e "s|@GITHUB_CLONE_URL@|$GITHUB_CLONE_URL|g" \
			bootstrap/activate.in > venv/bin/activate.$target
	done
	install bootstrap/bashrc venv/bin/bashrc
	sed -e "s|@VIRTUAL_ENV@|$VIRTUAL_ENV|g" bootstrap/ctcenv.in > ctcenv
	chmod +x ctcenv
	
	install -m 755 support/jq $VIRTUAL_ENV/bin/jq
	install -m 755 support/kind $VIRTUAL_ENV/bin/kind
	install -m 755 support/kops $VIRTUAL_ENV/bin/kops
	install -m 755 support/kubectl $VIRTUAL_ENV/bin/kubectl
	install -m 755 support/terraform $VIRTUAL_ENV/bin/terraform
	unzip -qq -d support support/awscliv2.zip
 	support/aws/install -i $VIRTUAL_ENV -b $VIRTUAL_ENV/bin >/dev/null 2>&1
 	rm -rf support/aws
	install -m 755 support/hey $VIRTUAL_ENV/bin/hey

 	for f in lib/ctc/*; do
		fin=$(basename $f)
		install -m 755 lib/ctc/$fin $VIRTUAL_ENV/bin/$fin
	done
 	echo "OK"
 	echo ""
	echo "to activate venv execute: ./ctcenv [target]"
	echo "target: production or devel. Devel is default"
}

cmd_venv_help() {
	echo "$(basename $0) ve|venv [OPTIONS]"
	echo ""
	echo "-h        Show help"
	echo "-r        Re-install venv"
	echo "-g        Github url"
	echo ""
	exit 1
}

cmd_venv() {
	REINSTALL_VE=0

	OPTS=$(getopt -o hrg: -n 'parse-options' -- "$@")
	eval set -- "$OPTS"

	while true; do
		case "$1" in
			-h)
				cmd_venv_help
				shift
				;;
			-r)
				REINSTALL_VE=1
				shift
				;;
			-g)
				GITHUB_CLONE_URL=$2
				shift
				shift
				;;
			--)
				shift
				break
				;;
		esac
	done
	if [ $REINSTALL_VE -eq 1 ]; then
		cmd_venv_clean
	fi
	cmd_venv_install
}


#
# MAIN
#

main_help() {
	echo "$(basename $0) COMMAND [-h for help]"
	echo ""
	echo "su|support      Update support tools"
	echo "ve|venv         Install environment"
	echo "cl|clean        Clean environment"
	echo ""
	exit 1
}

setvars

if [ -z "$1" ]; then
	main_help
fi
COMMAND=$1
shift

case "$COMMAND" in
	su|support)
		cmd_support "$@"
		;;
	ve|venv)
		check_requeriments
		cmd_venv "$@"
		;;
	cl|clean)
		cmd_venv_clean
		;;
esac

exit 0
