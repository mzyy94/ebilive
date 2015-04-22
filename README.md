# Ebilive


![Ebilive-logo](docs/logo.png)

Web camera direct live streaming scripts powered by Apple HTTP Live Streaming(HLS).


# Preparation

## Check your web camera

```
$ v4l2-ctl --list-formats
ioctl: VIDIOC_ENUM_FMT
        Index       : 0
        Type        : Video Capture
        Pixel Format: 'YUYV'
        Name        : YUV 4:2:2 (YUYV)

        Index       : 1
        Type        : Video Capture
        Pixel Format: 'MJPG' (compressed)
        Name        : MJPEG

        Index       : 2
        Type        : Video Capture
        Pixel Format: 'H264' (compressed)
        Name        : H.264

```

> NOTE: If there isn't "H264" pixel format, you can't streaming video without transcoding (it means that you need to edit some scripts).

More informations of "H264" pixel format: `v4l2-ctl --list-formats-ext`

Check the web camera works fine with H264 pixel format option.

```
$ v4l2-ctl --try-fmt-video=width=1280,height=720,pixelformat=2
Format Video Capture:
        Width/Height  : 1280/720
        Pixel Format  : 'H264'
        Field         : None
        Bytes per Line: 2560
        Size Image    : 138240
        Colorspace    : SRGB
```

## Install dependencies

- [VLC](http://www.videolan.org/)
- [Python](https://www.python.org/) (optional)
- [Nginx](http://nginx.org/) (optional)



# Common options

Some variables in the script.

## Web camera options

 Variable name |    Description
:-------------:|:----------------------
     WEBCAM    | Device location path
     WIDTH     | Video width in pixels
     HEIGHT    | Video height in pixels
      FPS      | Frame rate per second

## HLS options

 Variable name |    Description
:-------------:|:----------------------
     SEGLEN    | Video length of one segment in seconds
    DELSEGS    | Automatic deletion of unneeded segments (true/false)
    NUMSEGS    | Number of segments in M3U8 playlist
      FPS      | Frame rate per second

## Other options

 Variable name |    Description
:-------------:|:----------------------
    TMPSIZE    | Size of temporary RAM disk in MB



# Run

## Simple streaming test

*Python required*

A test script to check HLS streaming availability.
For personal use, you can get enough experience with this.

```
$ ./simple-hls.sh
```

## Nginx backended basic streaming

*Nginx required*

This is a useful one for basic use when you need a good performance.

```
$ ./nginx-hls.sh
```



# Thanks

- [mangui/flashls](https://github.com/mangui/flashls)



# License

MIT
