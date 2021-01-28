#!/usr/bin/perl

# This hack will convert Mac OS X Stickies notes into standard
# RTF text files in a subdirectory of $HOME.
# This was written without any knowledge of Apple's official Stickies
# file format so YMMV.

# Copyright (c) 2015-2016 Finn Thain
# fthain@telegraphics.com.au

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

use 5.008;
use strict;
use warnings;

$::VERSION = '0.2';

die "Usage: $0 StickiesDatabase\n" unless -f $ARGV[0];

my $temp = qx(mktemp -d ~/StickiesRTF.XXXX);
chop $temp;
die unless -d $temp;

END {
  rmdir $temp if defined $temp;
}

my $count = 0;
open(SD, '<', $ARGV[0]) or die "open StickiesDatabase: $!\n";
$/ = "".chr(0x01);
while (<SD>) {
	chop;
	$count++;
	if (s,.*\0({\\rtf1),$1,) {
		my $fn = sprintf("%s/%04d.rtf", $temp, $count);
		open(STDOUT, '>', $fn) or die "open $fn: $!\n";
		print;
		close STDOUT;
	}
}
close(SD);
