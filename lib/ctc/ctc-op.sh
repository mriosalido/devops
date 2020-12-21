#!/bin/bash
set -e

KUBECTL_ARGS="--cache-dir $CTC_DIR/var/$CTC_TARGET/kube/cache"

cmd_check() {
	while true; do
		clear
		echo "Horizontal Pod Autoscaler"
		echo "--------------------------------------------------"
		kubectl $KUBECTL_ARGS get hpa
		echo ""
		echo "Running pods"
		echo "--------------------------------------------------"
		kubectl $KUBECTL_ARGS get pods
		echo ""
		echo "Service"
		echo "--------------------------------------------------"
		kubectl $KUBECTL_ARGS get service		
		sleep 2
	done
}

cmd_start() {
	IP=
	NAME=

	OPTS=$(getopt -o i:n: -n 'parse-options' -- "$@")
	eval set -- "$OPTS"
	while true; do
		case "$1" in
			-n)
				NAME=$2
				shift
				shift
				break
				;;
			-i)
				IP="$2"
				shift
				shift
				break
				;;
			--)
				shift
				break
				;;
		esac
	done
	if [ -z "$NAME" ]; then
		echo "Name not set"
		exit 1
	fi
	if [ -z "$IP" ]; then
		if [ $CTC_TARGET = "production" ]; then
			echo "No ip selected"
			exit 1
		fi
		IP=$(kubectl $KUBECTL_ARGS get service -o json |jq -r '.items[] | select(.metadata.name == "'$NAME'") | .status.loadBalancer.ingress[].ip')
	fi
	echo "Run load http://$IP"
	hey -z 5m http://$IP
}


#
# MAIN
#


main_help() {
	echo "$(basename $0) [COMMAND]"
	echo ""
	echo "Where command is one of:"
	echo ""
	echo "check              Show status"
	echo "start              Start run load"
	echo ""
	exit 1
}

if [ -z "$1" ]; then
	main_help
fi
COMMAND=$1
shift

case "$COMMAND" in
	check)
		cmd_check "$@"
		;;
	start)
		cmd_start "$@"
		;;
esac

exit 0
