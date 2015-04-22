#!/bin/sh

# Webcam settings
WEBCAM=/dev/video0
WIDTH=1280
HEIGHT=720
FPS=24

# HttpLiveStreaming settings
SEGLEN=15 # length of one segment in seconds
DELSEGS=true # delete already broadcasted segments
NUMSEGS=10 # segments count

# RAM disk settings
TMPSIZE=128 # RAM disk size in MB

# nginx settings
NGINXDIR=/usr/share/nginx/www


cleanup () {
  sudo rm -r ${NGINXDIR}/*
  sudo umount ${NGINXDIR}
  sudo mv ${TMPDIR}/* ${NGINXDIR}/
  sudo rm -r ${TMPDIR}
}

set -x

TMPDIR=$(mktemp -d)
sudo mv ${NGINXDIR}/* ${TMPDIR}/
sudo mount -t tmpfs -o size=${TMPSIZE}m /dev/shm ${NGINXDIR}
sudo cp -r ${PWD}/www/* ${NGINXDIR}/
mkdir -p ${NGINXDIR}/live
trap cleanup INT TERM
vlc -I dummy v4l2://${WEBCAM}:chroma="H264":width=${WIDTH}:height=${HEIGHT}:fps=${FPS} vlc://quit \
  --sout="#standard{access=livehttp{seglen=${SEGLEN},delsegs=${DELSEGS},numsegs=${NUMSEGS}, \
  index=${NGINXDIR}/live/index.m3u8,index-url=/live/segment-########.ts},mux=ts{use-key-frames},dst=${NGINXDIR}/live/segment-########.ts}"
