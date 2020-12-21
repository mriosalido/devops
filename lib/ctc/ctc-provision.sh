#!/bin/bash
set -e

KUBECTL_ARGS="--cache-dir $CTC_DIR/var/$CTC_TARGET/kube/cache"

cmd_st_up() {
	echo "Create cluster"
	kind create cluster --config $CTC_DIR/lib/devel/kind-cluster.yaml
	echo "--------------"
	echo "Configure metallb"
	kubectl $KUBECTL_ARGS apply -f $CTC_DIR/lib/devel/metallb/namespace.yaml
	kubectl $KUBECTL_ARGS apply -f $CTC_DIR/lib/devel/metallb/metallb.yaml
	kubectl $KUBECTL_ARGS create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
	ADDRESSES=$(docker network inspect kind | jq -r '.[].IPAM.Config[].Subnet'|grep "\."|sed -E 's/^([[:digit:]]*).([[:digit:]]*).([[:digit:]]).*/\1.\2.\3.240-\1.\2.\3.250/')
	cat $CTC_DIR/lib/devel/metallb/configmap.yaml | sed -e "s/@ADDRESSES@/$ADDRESSES/" | kubectl $KUBECTL_ARGS apply -f -
	echo "Configure metrics"
	kubectl $KUBECTL_ARGS apply -f $CTC_DIR/lib/devel/metrics-server/metrics-server-0.4.1.yaml
}

cmd_st_down() {
	echo "Destroy kind"
	kind delete cluster
}

cmd_st_help() {
	echo "$(basename $0) [COMMAND]"
	echo ""
	echo "Where command is one of:"
	echo ""
	echo "up              Create environment"
	echo "down            Destroy environment"
	echo ""
	exit 1
}

cmd_st() {
	if [ -z "$1" ]; then
		cmd_st_help
	fi
	COMMAND=$1
	shift
	
	case "$COMMAND" in
		up)
			cmd_st_up
			;;
		down)
			cmd_st_down
			;;
	esac
}


cmd_prod_help() {
	echo "$(basename $0) [COMMAND]"
	echo ""
	echo "Where command is one of:"
	echo ""
	echo "bs              Bootstrap environment"
	echo "up              Create environment"
	echo "down            Destroy environment"
	echo ""
	exit 1
}

cmd_prod_bs() {
	echo "Bootstrap environemnt"
	echo "Create bucket"
	aws s3api create-bucket --bucket mrv-state-store-devops-net --region eu-west-1
	aws ecr create-repository --repository-name mrv-helloworld --region eu-west-1
}
    
cmd_prod_up() {
	echo "Create cluster"
	kops create -f $CTC_DIR/production/cluster.yaml 
	sleep 2
	kops create secret --name mrv-cluster.k8s.local --state=s3://mrv-state-store-devops-net sshpublickey admin -i ~/.ssh/id_rsa.pub
	sleep 2
	kops update cluster --yes
}

cmd_prod() {
	if [ -z "$1" ]; then
		cmd_prod_help
	fi
	COMMAND=$1
	shift
	
	case "$COMMAND" in
		bs)
			cmd_prod_bs
			;;
		up)
			cmd_prod_up
			;;
		down)
			cmd_prod_down
			;;
	esac
}

#
# MAIN
#

case "$CTC_TARGET" in
	devel)
		cmd_st "$@"
		;;
	production)
		cmd_prod "$@"
		;;
esac

exit 0
