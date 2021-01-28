#!/usr/bin/perl

# tree-comm.pl - concurrently descend two directory trees in lexicographic order

# Copyright (c) 2010, 2011, 2013 Finn Thain
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

use Getopt::Std;

use 5.008;
use strict;
use warnings;

$Getopt::Std::STANDARD_HELP_VERSION = 1;
$::VERSION = '0.7';
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

sub spawn {
  my $d = shift;
  local *FH_STDOUT = shift;
  local *FH_CLOSE1 = shift;
  local *FH_CLOSE2 = shift;
  local *FH_CLOSE3 = shift;
  die "$0: does not exist: $d\n" unless -e $d;
  my $pid = fork;
  die "$0: fork: $!\n" unless defined $pid;
  if (!$pid) {
    chdir $d or die "$0: chdir: $!\n";
    open(STDOUT, '>&', FH_STDOUT) or die "$0: open: $!\n";
    close(FH_STDOUT) or warn "$0: close FH_STDOUT: $!\n";
    close(FH_CLOSE1) or warn "$0: close FH_CLOSE1: $!\n";
    close(FH_CLOSE2) or warn "$0: close FH_CLOSE2: $!\n";
    close(FH_CLOSE3) or warn "$0: close FH_CLOSE3: $!\n";
    my @opts = ( '-0', '-s' );
    push(@opts, '-e', $opt_e) if defined $opt_e;
    exec 'find.pl', @opts, '.';
    die "$0: exec: $!\n"
  }
  return $pid
}

die "$0: incorrect usage. Try --help.\n" unless @ARGV == 2;

$^F += 4;
pipe A_READ, A_WRITE;
pipe B_READ, B_WRITE;
my $pid_a = spawn($ARGV[0], *A_WRITE, *A_READ, *B_WRITE, *B_READ);
my $pid_b = spawn($ARGV[1], *B_WRITE, *B_READ, *A_WRITE, *A_READ);
close(A_WRITE) or warn "$0: close A_WRITE: $!\n";
close(B_WRITE) or warn "$0: close B_WRITE: $!\n";

my $afn = fileno(A_READ);
my $bfn = fileno(B_READ);

system qw( comm.pl -0 -p ),
       defined( $opt_c ) ? ( "-c" )           : ( ),
       defined( $opt_1 ) ? ( "-1", "$opt_1" ) : ( ),
       defined( $opt_2 ) ? ( "-2", "$opt_2" ) : ( ),
       defined( $opt_3 ) ? ( "-3", "$opt_3" ) : ( ),
       "/dev/fd/$afn",
       "/dev/fd/$bfn";

die "$0: comm.pl failed\n" if $? >> 8;

close A_READ;
waitpid($pid_a, 0);
die "$0: first find.pl failed\n" if $? >> 8;

close B_READ;
waitpid($pid_b, 0);
die "$0: second find.pl failed\n" if $? >> 8;
