#!/usr/bin/perl

# find(1) for perl programmers.

# Copyright (c) 2006-2011 Finn Thain
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
use POSIX qw(strftime
             S_IRGRP S_IROTH S_IRUSR S_IRWXG S_IRWXO S_IRWXU
             S_ISBLK S_ISCHR S_ISDIR S_ISFIFO S_ISGID S_ISREG S_ISUID
             S_IWGRP S_IWOTH S_IWUSR);
use Digest::MD5;

use Getopt::Std;
$Getopt::Std::STANDARD_HELP_VERSION = 1;
$::VERSION = '0.17';
sub HELP_MESSAGE() {
  print "Usage: $0 [-0] [-d] [-e <perl>] [-h] [-n] [-s] [-t <perl>] [-v] [-x] pathname...\n";
  print 'Options:
         -- Treat all remaining arguments as pathnames.
         -0 Use a null to seperate pathnames listed in output.
         -d Descend directory tree depth first.
         -e Execute perl snippet for every directory entry. $_ is set to the
            pathname to make the unary file test operators more convenient. The
            basename and dirname are in $base and $dir, search depth is in
            $depth and stat() results are available in $dev, $ino, $mode,
            $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize
            and $blocks. You can call prune() to prevent descent into the
            current directory (except with -d), md5() to get the hex MD5 digest
            of the current file and ls() if you want to list the current entry
            (called by default if you return true).
         -h Follow symlinks.
         -n Show GID and UID numerically (with -v).
         -s Process directory entries in ascending order of basename.
         -t Execute perl snippet before terminating.
         -v Verbose listing, like tar(1).
         -x Prune directories used as mount points.
';
}
our ( $opt_0, $opt_d, $opt_e, $opt_h, $opt_n, $opt_s, $opt_t, $opt_v, $opt_x );
getopts( '0de:hnst:vx' );


our ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
      $atime, $mtime, $ctime, $blksize, $blocks );
my %hlinks;
my $width = 19;
sub ls {
  if( $opt_v ) {
    local $_ = $_;
    local $size = $size;
    local $uid = $uid;
    local $gid = $gid;
    my ( $tmode, $target );
    if( (S_ISREG( $mode ) or -l) and $nlink > 1 ) {
      my $k = "$dev:$ino";
      if( defined $hlinks{ $k } ) {
        $target = " link to $hlinks{ $k }";
        $tmode = 'h';
        $size = 0
      } else {
        $hlinks{ $k } = $_
      }
    }
    if ( !$tmode ) {
      if( -l and !$opt_h ) {
        if( !defined( $target = readlink $_ ) ) {
          print STDERR "$0: readlink: $!: $_\n";
          return
        }
        $tmode = 'l';
        $target = " -> $target";
        $size = 0
      } else {
        $target = '';
        if( -d ) {
          $tmode = 'd';
          $size = '0';
          $_ .= '/' unless substr( $_, -1 ) eq '/';
        } else {
          $size = "$size";
          if( -p ) {
            $tmode = 'p'
          } elsif( -S ) {
            $tmode = 's'
          } elsif( -b ) {
            $tmode = 'b';
            $size = sprintf( '%d,%d', ($rdev & 0xff00) >> 8, $rdev & 0xff )
          } elsif( -c ) {
            $tmode = 'c';
            $size = sprintf( '%d,%d', ($rdev & 0xff00) >> 8, $rdev & 0xff )
          } else {
            $tmode = '-';
          }
        }
      }
    }

    my $xsuid  = 'x';
    my $xsgid  = 'x';
    my $sticky = 'x';
    if( !-l ) {
      $xsuid  = 's' if -u;
      $xsgid  = 's' if -g;
      $sticky = 't' if -k;
    }
    my $suid   = (-u) ? 'S' : '-';
    my $sgid   = (-g) ? 'S' : '-';

    $tmode = $tmode.
           ($mode&0400?'r':'-').($mode&0200?'w':'-').($mode&0100?$xsuid:$suid).
           ($mode&0040?'r':'-').($mode&0020?'w':'-').($mode&0010?$xsgid:$sgid).
           ($mode&0004?'r':'-').($mode&0002?'w':'-').($mode&0001?$sticky:'-');
    if( !$opt_n ) {
      my $u = ( getpwuid( $uid ) )[ 0 ];
      my $g = ( getgrgid( $gid ) )[ 0 ];
      $uid = $u if defined $u;
      $gid = $g if defined $g;
    }
    my $owners = "$uid/$gid";

    my $pad = $width - length( $owners ) - length( $size );
    if( $pad < 1 ) {
      $width += 1 - $pad;
      $pad = 1;
    }

    my $escape = $_.$target;
    study $escape;
    $escape =~ s/\\/\\\\/g;
    $escape =~ s/\n/\\n/g;
    $escape =~ s/\r/\\r/g;
    $escape =~ s/([\x80-\xff])/sprintf('\\%03o',unpack('C',$1))/eg;
    print sprintf "%s %s %s %s\n",
                  $tmode,
                  $owners.( ' ' x $pad ).$size,
                  strftime( '%F %T', localtime $mtime ), $escape
  } elsif( $opt_0 ) {
    print $_."\0"
  } else {
    print $_."\n"
  }
}


sub md5 {
  my $fn = shift;
  $fn = $_ if !defined $fn;
  local *FH;
  open( FH, "<$fn" ) or die "open failed\n";
  binmode FH;
  my $result = Digest::MD5->new->addfile( *FH )->hexdigest;
  close FH;
  $result
}


my $pruned;
sub prune {
  $pruned = !$opt_d
}


my ( $parent_dev, $depth );
sub process {
  my ( $dir, $base ) = @_;
  if( !$opt_h ) {
    ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
      $atime, $mtime, $ctime, $blksize, $blocks ) = ( lstat )[ 0..12 ];
  } else {
    ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
      $atime, $mtime, $ctime, $blksize, $blocks ) = ( stat )[ 0..12 ];
  }
  if( !defined $dev ) {
    print STDERR "$0: (l)stat: $!: $_\n";
    return 1
  }

  if( defined $parent_dev ) {
    $pruned = $opt_x && $dev != $parent_dev
  } else {
    $parent_dev = $dev
  }

  my $ok = 1;
  if( defined $opt_e ) {
    local $_ = $_;
    $ok = eval $opt_e;
    die "$0: eval: $@: $_" if $@ ne ''
  }
  ls if $ok;
  return 0
}


sub descend {
  my $result;
  my ( $dir, $base ) = @_;
  local $_ = $dir.$base;

  if( !$opt_d ) {
    $pruned = 0;
    $result = process( $dir, $base );
    return $result if $pruned;
  }

  if( -d and ( $opt_h or !-l ) ) {
    $depth++;
    local *D;
    opendir( D, $_ ) or print STDERR "$0: opendir: $!: $_\n";
    my @ents = readdir D;
    closedir D;
    foreach my $ent ( $opt_s ? sort @ents : @ents ) {
      descend( $base eq '' ? $_ : "$_/", $ent )
        unless $ent eq '..' or $ent eq '.'
    }
    $depth--;
  }

  $result = process( $dir, $base ) if $opt_d;
  return $result
}


my $exit_status = 0;

my $arg;
foreach $arg ( @ARGV ) {
  $arg =~ m,(.*/)?([^/]*)$,;
  $depth = 0;
  $parent_dev = undef;
  $exit_status = descend( defined $1 ? $1 : '', $2 ) || $exit_status
}

if( defined $opt_t ) {
  eval $opt_t;
  die "$0: END eval: $@" if $@ ne ''
}

exit $exit_status
