#!/bin/bash
set -e


cmd_init() {
	echo "Init project"
	PROJECT=$1
	case "$PROJECT" in
		nginx)
			if [ ! -e $CTC_DIR/terraform/nginx ]; then
				echo "Get tf devops-tf-nginx"
				git clone ${GITHUB_CLONE_URL}mriosalido/devops-tf-nginx.git $CTC_DIR/terraform/nginx
			else
				cd $CTC_DIR/terraform/nginx
				git pull
			fi
			;;
		helloworld)
			if [ ! -e $CTC_DIR/terraform/helloworld ]; then
				echo "Get tf devops-tf-helloworld"
				git clone ${GITHUB_CLONE_URL}mriosalido/devops-tf-helloworld.git $CTC_DIR/terraform/helloworld
			else
				cd $CTC_DIR/terraform/helloworld
				git pull
			fi
			;;
		*)
			echo "Project [$PROJECT] not found"
			exit 1
			;;
	esac
}


cmd_apply_help() {
	echo "$(basename $0) [OPTIONS]"
	echo ""
	echo "-h              Show help"
	echo "-p              Project name"
	echo "-c              Clean project"
	echo ""
	exit 1
}

cmd_apply() {
	PROJECT=
	CLEAN=0

	OPTS=$(getopt -o hp:c -n 'parse-options' -- "$@")
	eval set -- "$OPTS"
	while true; do
		case "$1" in
			-h)
				cmd_apply_help
				shift
				;;
			-p)
				PROJECT="$2"
				shift
				shift
				break
				;;
			-c)
				CLEAN=1
				shift
				;;
			--)
				shift
				break
				;;
		esac
	done
	if [ -z "$PROJECT" ]; then
		cmd_apply_help
	fi
	if [ $CLEAN -eq 1 ]; then
		rm -rf $CTC_DIR/terraform/$PROJECT
	fi
	if [ ! -d $CTC_DIR/terraform/$PROJECT ]; then
		cmd_init $PROJECT
	fi
	cd $CTC_DIR/terraform/$PROJECT
	if [ ! -d .terraform.lock.hcl ]; then
		terraform init
	fi
	terraform validate
	terraform apply -auto-approve
}

#
# MAIN
#

main_help() {
	echo "$(basename $0) [COMMAND]"
	echo ""
	echo "Where command is one of:"
	echo ""
	echo "apply           Deploy proyect"
	echo ""
	exit 1
}

if [ -z "$1" ]; then
	main_help
fi
COMMAND=$1
shift

case "$COMMAND" in
	apply)
		cmd_apply "$@"
		;;
esac

exit 0
