## Introduction

This is a port of the [kc87fpga core by beokim](https://github.com/beokim/kc854fpga) to the [MiSTer board](https://github.com/MiSTer-devel).

See https://en.wikipedia.org/wiki/KC_85

## The MiSTer Core

The core is in a pretty basic state right now. Its currently hardcoded to KC85/5 configuration with CAOS 4.7.

Tape loading from file and keyboard should work in all turbo modes.

*.KCC and *.TAP files are supported to load software and audio output works too. This can be used to feed software to a real KC8x via its tape input (at 1x turbo). To load programs type LOAD and enter, then select TAP/KCC file from osd.

Joystick is semi-working, is ok in caos menu, mostly fails in games after some time.

Type BASIC at the OS prompt to start the basic interpreter from ROM.

Software modules like M025 are supported too, load contents via osd. The files should be raw eprom/prom dumps with a *.ROM extension. The modules available from VEB Mikroelektronik Mühlhausen (texor, forth, development) work as far as i could test. Segmented ROM modules like Typestar are not supported (yet).

## The Copyright Notice that came with the Sources

Copyright (c) 2015, $ME
All rights reserved.

Redistribution and use in source and synthezised forms, with or without modification, are permitted 
provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions 
   and the following disclaimer.

2. Redistributions in synthezised form must reproduce the above copyright notice, this list of conditions
   and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR 
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
POSSIBILITY OF SUCH DAMAGE.
