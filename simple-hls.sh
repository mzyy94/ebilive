#!/bin/sh

# Webcam settings
WEBCAM=/dev/video0
WIDTH=1280
HEIGHT=720
FPS=30

# HttpLiveStreaming settings
SEGLEN=15 # length of one segment in seconds
DELSEGS=true # delete already broadcasted segments
NUMSEGS=10 # segments count
NAME=live
PORT=8080

TMPSIZE=128 # RAM disk size in MB

HTTPDOC="<!DOCTYPE html>
<html>
  <head>
    <title>Live streaming</title>
  </head>
  <body>
    <video width=\"${WIDTH}\" height=\"${HEIGHT}\" autoplay src=\"/${NAME}.m3u8\"></video>
  </body>
</html>
"


cleanup () {
  kill -s 0 ${PID} >/dev/null 2>&1 && kill -KILL ${PID}
  rm index.html
  cd -
  sudo umount ${TMPDIR}
  rm -r ${TMPDIR}
}

TMPDIR=$(mktemp -d)
sudo mount -t tmpfs -o size=${TMPSIZE}m /dev/shm ${TMPDIR}
cd ${TMPDIR}
echo ${HTTPDOC} > index.html
python -m SimpleHTTPServer ${PORT} &
PID=$!
trap cleanup INT TERM
vlc -I dummy v4l2://${WEBCAM}:chroma="H264":width=${WIDTH}:height=${HEIGHT}:fps=${FPS} vlc://quit \
  --sout="#standard{access=livehttp{seglen=${SEGLEN},delsegs=${DELSEGS},numsegs=${NUMSEGS}, \
  index=${NAME}.m3u8,index-url=/${NAME}-########.ts},mux=ts{use-key-frames},dst=${NAME}-########.ts}"
