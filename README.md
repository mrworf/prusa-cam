# Prusa Cam Mini Hack

# Install

First, install the pre-reqs:

```
apt install libcamera-v4l2
```

Make sure this directory is in `/opt/prusa-cam`, next...

Copy `prusa-cam.service` to `/etc/systemd/system/` like so

```
cp prusa-cam.service /etc/systemd/system/
```

# Configuring the script

While you can edit the main file, you can also simply create a `prusa-cam-config` file in the same folder and set the necessary variables.

Benefit of this approach is that any update to the script will not wreck your configuration.

## PRINTER

This is the printer id shown on the prusa connect page when you navigate to it

<SCREENSHOTS TBD>

## TOKEN

The token needed to be able to upload the images

## WIDTH and HEIGHT

The WIDTH and height HEIGHT you want the image to have, must be a supported resolution. By default picks highest resolution supported.

## QUALITY

The compression of the JPEG, ranging from 1 to 100 where 1 is maxium compression and 100 is essentially none. Good balance between quality and size is `65`.

## INTERVAL

How often (in seconds) to upload a still to prusa. A RPi Zero can upload a 1920x1440 with quality of 65 every 10s with around 3-4s to spare. Keep in mind that prusa doesn't refresh too fast either, so 10s is probably sufficient. 

# Starting the service

```
sudo systemctl daemon-reload
sudo systemctl enable prusa-cam.service
sudo systemctl start prusa-cam.service
```

And you're done.
