#!/bin/sh

set -eu
export LC_ALL=C

DOCKER=$(command -v docker 2>/dev/null)

IMAGE_REGISTRY=docker.io
IMAGE_NAMESPACE=hectormolinero
IMAGE_PROJECT=pinball
IMAGE_TAG=latest
IMAGE_NAME=${IMAGE_REGISTRY:?}/${IMAGE_NAMESPACE:?}/${IMAGE_PROJECT:?}:${IMAGE_TAG:?}
CONTAINER_NAME=${IMAGE_PROJECT:?}
VOLUME_NAME=${CONTAINER_NAME:?}-data

imageExists() { [ -n "$("${DOCKER:?}" images -q "${1:?}")" ]; }
containerExists() { "${DOCKER:?}" ps -af name="${1:?}" --format '{{.Names}}' | grep -Fxq "${1:?}"; }
containerIsRunning() { "${DOCKER:?}" ps -f name="${1:?}" --format '{{.Names}}' | grep -Fxq "${1:?}"; }

if ! imageExists "${IMAGE_NAME:?}" && ! imageExists "${IMAGE_NAME#docker.io/}"; then
	>&2 printf -- '%s\n' "\"${IMAGE_NAME:?}\" image doesn't exist!"
	exit 1
fi

if containerIsRunning "${CONTAINER_NAME:?}"; then
	printf -- '%s\n' "Stopping \"${CONTAINER_NAME:?}\" container..."
	"${DOCKER:?}" stop "${CONTAINER_NAME:?}" >/dev/null
fi

if containerExists "${CONTAINER_NAME:?}"; then
	printf -- '%s\n' "Removing \"${CONTAINER_NAME:?}\" container..."
	"${DOCKER:?}" rm "${CONTAINER_NAME:?}" >/dev/null
fi

if [ -d '/tmp/.X11-unix' ]; then
	X11_SOCKET_DIRECTORY='/tmp/.X11-unix'

	XAUTHORITY_FILE="/tmp/.Xauthority.docker.${IMAGE_PROJECT:?}"
	touch "${XAUTHORITY_FILE:?}"
	xauth nlist "${DISPLAY:?}" | sed -e 's/^..../ffff/' | xauth -f "${XAUTHORITY_FILE:?}" nmerge -
fi

if [ -n "${XDG_RUNTIME_DIR-}" ] && [ -S "${XDG_RUNTIME_DIR:?}/pulse/native" ]; then
	PULSEAUDIO_SOCKET="${XDG_RUNTIME_DIR:?}/pulse/native"
fi

printf -- '%s\n' "Creating \"${CONTAINER_NAME:?}\" container..."
exec "${DOCKER:?}" run --tty --interactive --rm \
	--name "${CONTAINER_NAME:?}" \
	--hostname "${CONTAINER_NAME:?}" \
	--network none \
	--log-driver none \
	--mount type=volume,src="${VOLUME_NAME:?}",dst='/home/wine/.wine' \
	${X11_SOCKET_DIRECTORY+ \
		--env DISPLAY="${DISPLAY:?}" \
		--mount type=bind,src="${X11_SOCKET_DIRECTORY:?}",dst='/tmp/.X11-unix',ro \
		--env XAUTHORITY='/home/wine/.Xauthority' \
		--mount type=bind,src="${XAUTHORITY_FILE:?}",dst='/home/wine/.Xauthority',ro \
	} \
	${PULSEAUDIO_SOCKET+ \
		--env PULSE_SERVER='/run/user/1000/pulse/native' \
		--mount type=bind,src="${PULSEAUDIO_SOCKET:?}",dst='/run/user/1000/pulse/native',ro \
	} \
	"${IMAGE_NAME:?}" "$@"
