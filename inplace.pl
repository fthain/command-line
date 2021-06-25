#!/usr/bin/perl

# filter files listed on stdin, replacing each file with its filtered version.

# Copyright (c) 2020-2021 Finn Thain

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


use File::Temp ();
use Getopt::Std;

use strict;
use warnings;

my $i = 0;
my $cmd_start;
while ($i <= $#ARGV) {
	if ($ARGV[$i] eq "--") {
		$i++;
		$cmd_start = $i;
		last;
	}
	$i++;
}
my @command = ();
if (defined($cmd_start)) {
	@command = @ARGV[$cmd_start..$#ARGV];
	@ARGV[$cmd_start..$#ARGV] = ();
}

$Getopt::Std::STANDARD_HELP_VERSION = 1;
$::VERSION = '0.2';
sub HELP_MESSAGE {
  print "Usage: $0 [-0] [-d] -- command ...\n";
  print 'Options:
         -- Take all remaining arguments to be the filter command line.
         -0 Use NUL character as pathname separator for stdin.
	 -d Generate a patch on stdout. Do not modify any files.
';
}

our ($opt_0, $opt_d);
getopts('0d');

die "No filter command specified.\n" unless @command;

$/ = chr(0) if ($opt_0);

while (<STDIN>) {
	chop;

	die "not a regular file: $_\n" unless (-f $_);

	my $fh = File::Temp->new();
	my $x = "".$fh;

	die "not a regular file: $x\n" unless (-f $x);

	my $pid = fork;
	die "fork failed ($!)\n" unless defined($pid);

	if ($pid == 0) { # child
		close(STDIN);
		open(STDIN, q(<), $_) or die "open failed ($!): $_\n";
		close(STDOUT);
		open(STDOUT, q(>), $x) or die "open failed ($!): $x\n";
		exec @command;
		die "exec failed ($!)\n";
	}

	wait();

	my $result = $? >> 8;
	die "child failed ($result): $_\n" if $result;

	if ($::opt_d) {
		die "bad filename: $_\n" if $_ eq q(-);
		system(qw(diff -u --label), $_, qw(--label), $_, qw(--), $_, $x);
	} else {
		system(qw(cp --no-preserve=all --reflink=auto --), $x, $_);
		$result = $? >> 8;
		die "cp failed ($result): $_\n" if $result;
	}
}
