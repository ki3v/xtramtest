# RAM test ROM for IBM PC/XT and Clones

by David Giller and Adrian Black

See the YouTube video on [Adrian's Digital Basement](https://youtube.com/@adriansdigitalbasement) (direct video link pending release)

![Screenshot](img/screenshot.png)

This is a diagnostic ROM for testing RAM in an IBM PC/XT computer or clone.  It is used by temporarily replacing the BIOS ROM in your machine with this code programmed onto an EPROM chip, which will boot directly into the RAM testing program without requiring functioning RAM or file storage.  It does currnetly require a CGA or MDA adapter both for reporting and for using the video RAM on these cards, allowing testing of every byte of conventional RAM in your system.

The ROM currently performs two types of RAM test:

- The [March-U](https://www.researchgate.net/publication/3349024_March_U_A_test_for_unlinked_memory_faults) algorithm, which is a carefully arranged sequence of sequential reads and writes across the whole memory space looking for faults that result in memory corruption, even where reads/writes to one location cause corruption somewhere else in memory.  This is a common kind of RAM fault that is difficult to detect using simpler testing algorithms.

- Bit pattern and address/data bus exercise testing based on ideas published by [Jack Ganssle](https://www.ganssle.com/testingram.htm).  While just reading and writing bit patterns (the traditional `AA`, `55`, etc. values used by older RAM tests) are of limited value because of the many kinds of RAM faults they don't reliably detect, Ganssle describes in the link above how to aggressively exercise the address and data busses to attempt to expose hardware that may work under simple testing but will fail under heavier load or more challenging sequences of events.

The ROM does not currently test parity RAM or the parity checking circuit. Parity is disabled at all times.

## Using this ROM to test RAM in your PC/XT or clone

Two images are included in the Releases (see the right side of the GitHub project page): `xtramtest.8k` is an 8K binary image for burning into a 2764/2864 or equivalent 64Kbit/8Kbyte E(E)PROM, and `xtramtest.32k` is a 32K image for burning into a 27256/28256 or equivalent 256Kbit/32Kbyte E(E)PROM.  

You may want to remove all other ISA cards (besides the video card) and remove all the other ROM chips from the system before running this ROM, just to eliminate any potential issues.

The Keyboard or any other peripherals are not tested or needed to run this ROM. Currently the speaker is not used either, although beep code support may be added in the future.

There are a few different ways to use this ROM, depending on your hardware. Running the code works generally the same way as the SuperSoft/Landmark Diagnostic and Ruud's Diagnostic ROM for the IBM PC and PC XT. This link on minuszerodegrees.net describes the nuance of getting this running on various IBM machines:

[Supersoft/Landmark Diagnostic ROM's for IBM 5150/5155/5160/5162/5170](https://www.minuszerodegrees.net/supersoft_landmark/Supersoft%20Landmark%20ROM.htm)

This ROM currently only works with IBM MDA (and compatible) cards and IBM CGA (and compatible) cards. It will not work with EGA or VGA (and compatible cards.) This is something that may be added in the future, but EGA/VGA type cards usually require their own BIOS routines to initialize, which usually require working RAM.

### IBM PC 5150

This machine uses 2364 mask ROMs. These sockets are not compatible with 2764/2864 chips and you must use an adapter. Use an adapter that goes from 2764/2864 to the 2364 and use the `xtramtest.8k` binary available under Releases. See this link:

[IBM 5150 motherboard  -  Use of '2364 Adapter'](https://minuszerodegrees.net/5150/motherboard/IBM%205150%20motherboard%20-%20Use%20of%202364%20adapter.htm)

### IBM PC/XT 5160

This machine uses normal ROMs which are compatible with 27C256 (32KB) EPROMs. Download the `xtramtest.32k` Binary and put that onto a 27C256 EPROM and install into U18. See these links for more information:

[Ruud's diagnostic ROM fitted to the 64-256KB version of IBM 5160 motherboard](https://minuszerodegrees.net/ruuds_diagnostic_rom/5160/64-256KB.htm)
[Ruud's Diagnostic ROM fitted to the 256-640KB version of IBM 5160 motherboard](https://minuszerodegrees.net/ruuds_diagnostic_rom/5160/256-640KB.htm)

### PC/XT-class clones

These machines usually use 2764 or sometimes 27128 EPROMs. If it uses a 2764, you can use a 2864 in place of the original BIOS and flash the 8k image onto it. On machines using a 27128, you will need to load the 8k image into the 16k eprom twice before you burn the EPROM.  See also:

[Ruud's diagnostic ROM fitted to PC and XT clones](https://minuszerodegrees.net/ruuds_diagnostic_rom/clones/clones.htm)

The RAM layout may be different on these machines, so make sure to determine if your board differs from what is shown here.

## Memory layout of a typical PC/XT clone motherboard

See also the video linked above for further discussion on how to find the problematic RAM chips on your board.

![Memory Layout](img/memory_layout.png)

## Modifying/Building the ROM

This ROM is assembled using [NASM](https://www.nasm.us).  Tested with version NASM version 2.16.03, but any reasonably modern version should work.

As part of the IBM BIOS image file preparation, a specific checksum is calculated, and this is inconvenient to do in a cross-platform way.  Currently building the ROM is done using Bash and Perl scripts, and should be reasonably easy to do under Linux, Mac, or Windows (with the WSL Linux environment).

Build instructions will be forthcoming, but look in the `tools` directory for the scripts used to build the binaries and test under MAME emulation.

## Acknowledgements and dedication

- This ROM was made possible by starting with [Ruud's Diagnostic ROM](https://www.minuszerodegrees.net/ruuds_diagnostic_rom/clones/clones.htm), by Ruud Baltissen and modem7, at minuszerodegrees.net.  As seen above, we also rely extensivly on their well-researched documentation.

- The compact initialization code is from the [Super PC/Turbo XT BIOS](https://github.com/virtualxt/pcxtbios), which is public domain.

## License

This project is currently licensed under the GNU Public License version 2.  It includes original code copyright (C) David Giller (myself) and also makes use of code that is, as far as I can tell, released to the public domain.
