#!/bin/bash
set -e

cmd_image_build() {
	echo "Image build"
	cd $CTC_DIR/application/helloworld
	docker build -t mrv-helloworld:0 .
}

cmd_image_push_st() {
	echo "Image push"
	kind load docker-image mrv-helloworld:0
}

cmd_image_push_prod() {
	echo "Image push"
	docker image tag mrv-helloworld:0 $AWS_REGISTRY/mrv-helloworld:0
	docker image push $AWS_REGISTRY/mrv-helloworld:0
}

cmd_image_update() {
	echo "Image update"
	if [ ! -d $CTC_DIR/application/helloworld ]; then
		git clone ${GITHUB_CLONE_URL}mriosalido/devops-app-helloworld.git $CTC_DIR/application/helloworld
	fi
	cd $CTC_DIR/application/helloworld
	git pull
}

#
# MAIN
#

main_help() {
	echo "$(basename $0) [COMMAND]"
	echo ""
	echo "Where command is one of:"
	echo ""
	echo "build           Build image"
	echo "push            Push image"
	echo ""
	exit 1
}

if [ -z "$1" ]; then
	main_help
fi
COMMAND=$1
shift

case "$COMMAND" in
	build)
		cmd_image_update "$@"
		cmd_image_build "$@"
		;;
	push)
		if [ $CTC_TARGET = "production" ]; then
			cmd_image_push_prod "$@"
		else
			cmd_image_push_st "$@"
		fi
		;;
esac

exit 0
