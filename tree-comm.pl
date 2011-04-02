#!/usr/bin/perl

# tree-comm.pl - concurrently descend two directory trees in lexicographic order

# Copyright (c) 2010, 2011 Finn Thain
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
$::VERSION = '0.4';
sub HELP_MESSAGE() {
  print "Usage: $0 [-1 <perl>] [-2 <perl>] [-3 <perl>] [-c] [-e <perl>] path1 path2\n";
  print 'Options:
            -1 Execute perl fragment for every directory entry found only under path1.
            -2 Execute perl fragment for every directory entry found only under path2.
            -3 Execute perl fragment for every directory entry found under both paths.
            -c Behave like comm(1) and print entries in three columns.
               For example, passing -c -3 0 will print entries unique to path1 or path2.
            -e Pass this fragment to find.pl to filter entries in path1 and path2.
               (See find.pl --help for information about the available variables.)
';
}
our ($opt_1, $opt_2, $opt_3, $opt_c, $opt_e);
getopts( '1:2:3:ce:' );

use strict;
use warnings;

sub spawn {
  my $d = shift;
  local *FH = shift;
  die "$0: does not exist: $d\n" unless -e $d;
  my $pid = fork;
  die "$0: fork: $!\n" unless defined $pid;
  if (!$pid) {
    chdir $d or die "$0: chdir: $!\n";
    close STDOUT or die "$0: close: $!\n";
    open STDOUT, ">&FH" or die "$0: open: $!\n";
    close FH;
    my @opts = ( '-0', '-s' );
    push( @opts, '-e', $opt_e ) if defined $opt_e;
    exec 'find.pl', @opts, '.';
    die "$0: exec: $!\n"
  }
  return $pid
}

sub do_eval {
  my $e = shift;
  local $_ = shift;
  eval $e;
  die "$0: eval: $@: $_" if $@ ne ''
}

sub fn_cmp {
  # Can't simply use cmp/eq/gt/lt since we need "y/x" to sort before "y x" etc.
  my @a = split '/', $_[0];
  my @b = split '/', $_[1];
  while (1) {
    my $r = shift(@a) cmp shift(@b);
    return $r if $r;
    if (@a) {
      return 1 unless @b
    } elsif (@b) {
      return -1
    } else {
      return 0
    }
  }
}

die "$0: incorrect usage. Try --help.\n" unless @ARGV == 2;

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

pipe A_READ, A_WRITE;
my $pid_a = spawn($ARGV[0], *A_WRITE);
close A_WRITE;

pipe B_READ, B_WRITE;
my $pid_b = spawn($ARGV[1], *B_WRITE);
close B_WRITE;

$/ = "\0";

my $a = <A_READ>;
chop $a if defined $a;

my $b = <B_READ>;
chop $b if defined $b;

while (defined($a) and defined($b)) {
  my $s = fn_cmp($a, $b);
  if ($s == 0) {
    do_eval($opt_3, $a) if defined $opt_3 and $opt_3;

    $a = <A_READ>;
    chop $a if defined $a;

    $b = <B_READ>;
    chop $b if defined $b;
  } elsif ($s > 0) {
    do_eval($opt_2, $b) if defined $opt_2 and $opt_2;

    $b = <B_READ>;
    chop $b if defined $b;
  } else {
    do_eval($opt_1, $a) if defined $opt_1 and $opt_1;

    $a = <A_READ>;
    chop $a if defined $a;
  }
}

if (defined $opt_1) {
  while (defined $a) {
    do_eval($opt_1, $a) if defined $opt_1 and $opt_1;

    $a = <A_READ>;
    chop $a if defined $a;
  }
}

if (defined $opt_2) {
  while (defined $b) {
    do_eval($opt_2, $b) if defined $opt_2 and $opt_2;

    $b = <B_READ>;
    chop $b if defined $b;
  }
}

close A_READ;
waitpid($pid_a, 0);
die "$0: first find.pl failed\n" if $? >> 8;

close B_READ;
waitpid($pid_b, 0);
die "$0: second find.pl failed\n" if $? >> 8;
