#!/usr/bin/perl

# View a patch file using graphical diff tool.

# Copyright (c) 2015-2016 Finn Thain

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

$::VERSION = '0.3';

# input    | resulting state
# ---------+----------------
# whatever | 0
# ---      | 1
# +++      | 2
# @@       | 3
#  context | 4
# -delete  | 5
# +add     | 6

my @pattern    = ( undef,
                   qr/^[-][-][-] /,
                   qr/^[+][+][+] /,
                   qr/^[@][@] [-][0-9,]+ [+][0-9,]+ [@][@]/,
                   qr/^[ ]/,
                   qr/^[-]/,
                   qr/^[+]/, );

my @valid_transitions = ( [ 0, 1,                ],
                          [       2,             ],
                          [          3,          ],
                          [             4, 5, 6, ],
                          [ 0, 1,    3, 4, 5, 6, ],
                          [ 0,          4, 5, 6, ],
                          [ 0,          4,    6, ], );

my $state = 0;

die "Usage: $0 { patch-file | - }\n" unless scalar(@ARGV) == 1;
$ARGV[0] = '/dev/stdin' if $ARGV[0] eq '-';

my $temp = qx(mktemp -d /tmp/patch-viewer.XXXX);
chop $temp;
die "mktemp failed\n" unless -d $temp;

my $a = "$temp/a";
my $b = "$temp/b";

END {
  unlink $a if defined $a;
  unlink $b if defined $b;
  rmdir $temp if defined $temp;
}

open(A, '>', $a) or die "open $a: $!\n";
open(B, '>', $b) or die "open $b: $!\n";

open(P, '<', $ARGV[0]) or die "open $ARGV[0]: $!\n";
while (<P>) {
  my $prev = $state;
  my $next = undef;

  foreach my $i ( @{$valid_transitions[$state]} ) {
    if (!defined $pattern[$i]) {
      $next = 0;
      # keep looking for a match
    } elsif ($_ =~ $pattern[$i]) {
      $next = $i;
      last;
    }
  }
  die "$ARGV[0] line $.: no match in state $state: $_" unless defined $next;
  $state = $next;

  if ($state == 0 || $state == 1 || $state == 2) {
    print A $_;
    print B $_;
  } elsif ($state == 3) {
    my $x = $_;
    s/^([@][@] [-][0-9,]+) [+][0-9,]+( [@][@])/$1$2/;
    print A $_;
    $_ = $x;
    s/^([@][@]) [-][0-9,]+( [+][0-9,]+ [@][@])/$1$2/;
    print B $_;
  } elsif ($state == 4) {
    s,^.,,;
    print A $_;
    print B $_;
  } elsif ($state == 5) {
    s,^.,,;
    print A $_;
  } elsif ($state == 6) {
    s,^.,,;
    print B $_;
  }
}
close(P) or die "close P: $!\n";

close(A) or die "close A: $!\n";
close(B) or die "close B: $!\n";

system qw(meld), $a, $b;
