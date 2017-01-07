# Timelapse Capture

This script is a simple macOS based utility to create timelapse screen capture
series of any work done on your machine.

It takes a screenshot each `n` seconds to a given folder. The screenshot will be
stored as `png` image, which will be auto optimized using
[pngcrush](https://pmt.sourceforge.io/pngcrush/), to save some space.

## Prerequisites

You need to have [pngcrush](https://pmt.sourceforge.io/pngcrush/) installed and
in your path. The `screencapture` utility is part of the macOS distribution by
default.

## Usage

```
./timelapse-capture.sh <interval> <target-path>
  <interval> - Interval between screencaptures in seconds
  <target-path> - Path to store screencaptures to
```

Keep in mind, that the captures may be quite large, depending on your
display resolution. On my MBP retina 13" they are about `500kb` each
after optimization.

## LICENSE

[MIT-License](https://opensource.org/licenses/MIT)
