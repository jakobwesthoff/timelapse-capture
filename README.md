# Timelapse Capture

This script is a simple macOS based utility to create timelapse screen capture
series of any work done on your machine.

It takes a screenshot each `n` seconds to a given folder. The screenshot will be
stored as `png` image, which will be auto optimized using
[pngcrush](https://pmt.sourceforge.io/pngcrush/), to save some space.

## Prerequisites

### Optimization

In order to optimize `png` images you need to have
[pngcrush](https://pmt.sourceforge.io/pngcrush/) installed and
in your path (You may circumvent that requirement using the `--no-optimization`
flag). For optimizing `jpg` images
[jpeg-archive](https://github.com/danielgtaylor/jpeg-archive) is required.

You may install both tools using homebrew:
```
$ brew install pngcrush
$ brew install jpeg-archive
```

### Resizing

Imagemagick especially the `mogrify` command needs to be present if the
`--resize` flag is used.

Installation via homebrew is possible:
```
$ brew install imagemagick
```

### Screencapture

The `screencapture` utility is part of the macOS distribution by default.

## Usage

```
timelapse-capture [--option=<value>, ...] <interval> <target-path>
  <interval> - Interval between screencaptures in seconds
  <target-path> - Path to store screencaptures to

Options:
  --resize=<width>x<height> - Resize the screencapture to the given resolution (eg. 1920x1080)
  --no-optimization - Don't optimize the screen capture for size
  --format=<format> - Capture format (currently supported: png, jpg) (default: png)
```

Keep in mind, that the captures may be quite large, depending on your
display resolution.

## LICENSE

[MIT-License](https://opensource.org/licenses/MIT)
