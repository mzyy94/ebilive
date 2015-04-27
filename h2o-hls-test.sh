#!/bin/sh

# Webcam settings
WEBCAM=/dev/video0
WIDTH=1280
HEIGHT=720
FPS=24

# HttpLiveStreaming settings
SEGLEN=30 # length of one segment in seconds
DELSEGS=true # delete already broadcasted segments
NUMSEGS=6 # segments count

# RAM disk settings
TMPSIZE=128 # RAM disk size in MB

# nginx settings


cleanup () {
  kill -s 0 $(cat h2o.pid) >/dev/null 2>&1 && kill -KILL $(cat h2o.pid)
  rm h2o.pid
  sudo rm -r live/*
  sudo umount live
  sudo rm -r live
}

set -x

mkdir live
sudo mount -t tmpfs -o size=${TMPSIZE}m /dev/shm live
h2o &
trap cleanup INT TERM
vlc -I dummy v4l2://${WEBCAM}:chroma="H264":width=${WIDTH}:height=${HEIGHT}:fps=${FPS} vlc://quit \
  --sout="#standard{access=livehttp{seglen=${SEGLEN},delsegs=${DELSEGS},numsegs=${NUMSEGS}, \
  index=live/index.m3u8,index-url=/live/segment-########.ts},mux=ts{use-key-frames},dst=live/segment-########.ts}"
