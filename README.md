# Timelapse Capture

This script is a simple macOS based utility to create timelapse screen capture
series of any work done on your machine.

It takes a screenshot each `n` seconds to a given folder. The screenshot will be
stored as `png` image, which will be auto optimized using
[pngcrush](https://pmt.sourceforge.io/pngcrush/), to save some space.

## Prerequisites

You need to have [pngcrush](https://pmt.sourceforge.io/pngcrush/) installed and
in your path (You may circumvent that requirement using the `--no-optimization`
flag).

Imagemagick especially the `mogrify` command needs to be present if the
`--resize` flag is used.

The `screencapture` utility is part of the macOS distribution by default.

## Usage

```
timelapse-capture [--resize=<width>x<height>] [--no-optimization] <interval> <target-path>
  <interval> - Interval between screencaptures in seconds
  <target-path> - Path to store screencaptures to

Options:
  --resize=<width>x<height> - Resize the screencapture to the given resolution (eg. 1920x1080)
  --no-optimization - Don't optimize the screen capture for size
```

Keep in mind, that the captures may be quite large, depending on your
display resolution.

## LICENSE

[MIT-License](https://opensource.org/licenses/MIT)
