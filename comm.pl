#!/usr/bin/perl

# comm.pl - compare two files having lines in lexicographic or pathname order

# Copyright (c) 2013 Finn Thain
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


use strict;
use warnings;

use Getopt::Std;
$Getopt::Std::STANDARD_HELP_VERSION = 1;
$::VERSION = '0.1';
sub HELP_MESSAGE() {
  print "Usage: $0 [-0] [-1 <perl>] [-2 <perl>] [-3 <perl>] [-c] [-p] file1 file2\n";
  print 'Options:
            -0 file1 and file2 use null as line separator character.
            -1 Execute perl fragment for every line found only in file1.
            -2 Execute perl fragment for every line found only in file2.
            -3 Execute perl fragment for every line found in both files.
            -c Behave like comm(1) and print entries in three columns.
               For example, passing -c -3 0 will print lines unique to file1 or file2.
            -p Treat lines as pathnames rather than text.
';
}
our ($opt_0, $opt_1, $opt_2, $opt_3, $opt_c, $opt_p);
getopts( '01:2:3:cp' );

use strict;
use warnings;

sub do_eval {
  my $e = shift;
  local $_ = shift;
  eval $e;
  die "$0: eval: $@: $_" if $@ ne ''
}

if ($opt_c) {
  my $num_cols = grep { !defined $_ } $opt_1, $opt_2, $opt_3;
  if ($num_cols) {
    my $col_1 = 'print "$_\n"';
    if (!defined $opt_1) {
      $opt_1 = $col_1
    } elsif (!defined $opt_2) {
      $opt_2 = $col_1
    } elsif (!defined $opt_3) {
      $opt_3 = $col_1
    }
    $num_cols--
  }
  if ($num_cols) {
    my $col_2 = 'print "\t$_\n"';
    if (!defined $opt_2) {
      $opt_2 = $col_2
    } elsif (!defined $opt_3) {
      $opt_3 = $col_2
    }
    $num_cols--
  } 
  if ($num_cols) {
    my $col_3 = 'print "\t\t$_\n"';
    if (!defined $opt_3) {
      $opt_3 = $col_3
    }
  }
}

my $compare = $opt_p ? sub {
                             my $a = shift;
                             $a =~ s,/+,\0,g;
                             chop $a if substr($a, -1, 1) eq chr(0);
                             my $b = shift;
                             $b =~ s,/+,\0,g;
                             chop $b if substr($b, -1, 1) eq chr(0);
                             $a cmp $b
                       }
                     : sub {
                             $_[0] cmp $_[1]
                       };

$/ = $opt_0 ? chr(0) : chr(0x0a);

die "$0: incorrect usage. Try --help.\n" unless @ARGV == 2;

open(A, "<", $ARGV[0]) or die "$0: $ARGV[0]: $!\n";
open(B, "<", $ARGV[1]) or die "$0: $ARGV[1]: $!\n";

my $a = <A>;
chop $a if defined $a;

my $b = <B>;
chop $b if defined $b;

while (defined($a) and defined($b)) {
  my $s = & $compare ($a, $b);
  if ($s == 0) {
    do_eval($opt_3, $a) if defined($opt_3) and $opt_3;

    $a = <A>;
    chop $a if defined $a;

    $b = <B>;
    chop $b if defined $b;
  } elsif ($s > 0) {
    do_eval($opt_2, $b) if defined($opt_2) and $opt_2;

    $b = <B>;
    chop $b if defined $b;
  } else {
    do_eval($opt_1, $a) if defined($opt_1) and $opt_1;

    $a = <A>;
    chop $a if defined $a;
  }
}

if (defined $opt_1) {
  while (defined $a) {
    do_eval($opt_1, $a) if defined($opt_1) and $opt_1;

    $a = <A>;
    chop $a if defined $a;
  }
}

if (defined $opt_2) {
  while (defined $b) {
    do_eval($opt_2, $b) if defined($opt_2) and $opt_2;

    $b = <B>;
    chop $b if defined $b;
  }
}

close A or warn "$0: close file1: $!\n";

close B or warn "$0: close file2: $!\n";
