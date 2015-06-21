# Ebilive

Web camera direct live streaming scripts powered by Apple HTTP Live Streaming(HLS) *and twitter bot* .

![Ebilive-logo](docs/logo.png)


# Required Hardware

- MAX31855 thermocouple sensor
- ADT7410 temperature sensor
- H.264 stream supported Web camera

# Required Software

- Ruby
- ImageMagick
- libmagickcore-dev
- libmagickwand-dev


# Configuration

Copy and edit sample configuration file (config.sample.yml).

## Twitter configuration

| Configuration name |       Description         |
|:------------------:|:--------------------------|
|    consumer_key    | OAuth consumer key        |
|   consumer_secret  | OAuth consumer key secret |
|     access_token   | OAuth access token        |
| access_token_secret| OAuth access token secret |

## Timeline search configuration

| Configuration name |       Description                                               |
|:------------------:|:----------------------------------------------------------------|
|        trigger     | Search words of action trigger (comma separated)                |
|        picture     | Search words of taking a picture action (comma separated)       |
|         video      | Search words of taking a video action (comma separated)         |
|      temperature   | Search words of reporting temperature action (comma separated)  |

## Reply response text configuration

| Configuration name |       Description                                         |
|:------------------:|:----------------------------------------------------------|
|        message     | A response message for replying to the action             |
|      temperature   | A message template for replying to the temperature action |

>    The following strings will be substituted:
>    - #now: Stringified date and time
>    - #temp: Value of air temperature in Celsius
>    - #thermo: Value of water temperature in Celsius
>    - #inter: Value of thermocouple sensor's internal temperature in Celsius


## HTTP Live streaming configuration

| Configuration name |       Description                                     |
|:------------------:|:------------------------------------------------------|
|      video_path    | Absolute path of web camera's video block file        |
|         width      | Value of video width                                  |
|        height      | Value of video height                                 |
|          fps       | Value of video framerate                              |
|        seglen      | Number of stream segment duration in seconds          |
|        delsegs     | Automatic deletion of unneeded segments (true/false)  |
|        numsegs     | Number of segments in playlist                        |
|        live_path   | Absolute path of destination to save segments         |


# How to run

## Preparation
```sh
$ cp config.sample.yml config.yml
$ nano config.yml
$ gem install bundler
$ bundle install
```

## Execution
```sh
$ ruby ebilived.rb
```


# HLS live streaming samples
See [HLS_samples](HLS_samples).

# License

MIT
