This Perl script convolves a PNG image into a MIDI sequence for the Novation Launchpad's RG LEDs. If you provide a PNG with a width divisible by 8px and height of 8px, it will produce a MIDI file ready to be imported to Ableton and used as a light-show on your Launchpad.

Each frame must be 8x8 (sorry, the circular buttons' lights are not supported at the moment). This script supports all colors that the Launchpad can represent. It does this by dividing the 8-bit red and green values of each pixel by 64, so sometimes greens in your image editor may not show up the same on the launchpad. Blues are ignored, so if you have any white pixels they will displayed as full-intensity amber on the Launchpad.

Each frame corresponds to one quarter note. I've done some work to reduce flicker between frames, but the entire image refreshes on looping.

**Use:**

perl png2nlp.pl -i _input\_file_ -o _output\_file_

**Required Packages:**

GD
MIDI-Perl
Getopt