#!/usr/bin/perl

# Suppress runs of identical lines on stdin.

# Copyright (c) 2017-2021 Finn Thain

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

use strict;
use warnings;
use 5.008;

select STDOUT;
$| = 1;

my $n = 0;
my $last = undef;

sub print_last {
	if ($n == 0) {
		return;
	} elsif ($n == 1) {
		print $last x $n;
	} else {
		print "[Last line repeated $n times.]\n";
	}
}

$SIG{INT} = sub {
	close STDIN;
};

while (<STDIN>) {
	if (defined($last)) {
		if ($_ eq $last) {
			$n++;
			next;
		}
		print_last;
		$n = 0;
	}
	print $_;
	$last = $_;
}
print_last;
