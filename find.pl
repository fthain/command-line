#!/usr/bin/perl

# find(1) for perl programmers.

# Copyright (c) 2006-2012 Finn Thain
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
use POSIX qw( strftime
              S_IRGRP S_IROTH S_IRUSR S_IRWXG S_IRWXO S_IRWXU
              S_ISBLK S_ISCHR S_ISDIR S_ISFIFO S_ISGID S_ISREG S_ISUID
              S_IWGRP S_IWOTH S_IWUSR );
use Digest::MD5;


use Getopt::Std;
$Getopt::Std::STANDARD_HELP_VERSION = 1;
$::VERSION = '0.20';
sub HELP_MESSAGE {
  print "Usage: $0 [-0] [-d] {-e <perl> | -f <file>} [-h] [-n] [-s] [-t <perl>] [-v] [-x] pathname...\n";
  print 'Options:
         -- Treat all remaining arguments as pathnames.
         -0 Use a null to seperate pathnames listed in output.
         -d Descend directory tree depth-first.
         -e Execute perl snippet for every directory entry. $_ is set to the
            pathname to make the unary file test operators more convenient. The
            basename and dirname are in $base and $dir, search depth is in
            $depth and stat() results are available in $dev, $ino, $mode,
            $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize
            and $blocks. You can call prune() to prevent descent into the
            current directory (except with -d), md5() to get the hex MD5 digest
            of the current file and ls() to list the current entry (called by
            default if you return true).
         -f Read the perl snippet to execute from the given file. Thus it is
            possible to create an interpreter file with #!/path/to/find.pl -f
         -h Follow symlinks.
         -n Show GID and UID numerically (with -v).
         -s Process directory entries in ascending order of basename.
         -t Execute perl snippet before terminating.
         -v Verbose listing, like tar(1).
         -x Do not descend mount points.
';
}

our ( $opt_0, $opt_d, $opt_e, $opt_f, $opt_h,
      $opt_n, $opt_s, $opt_t, $opt_v, $opt_x );
getopts( '0de:f:hnst:vx' );


our ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
      $atime, $mtime, $ctime, $blksize, $blocks );
my %hlinks;
my $width = 19;
sub ls {
  if ( $opt_v ) {
    local $_ = $_;
    local $size = $size;
    local $uid = $uid;
    local $gid = $gid;
    my ( $tmode, $target );
    if ( ( S_ISREG( $mode ) or -l ) and $nlink > 1 ) {
      my $k = "$dev:$ino";
      if ( defined $hlinks{ $k } ) {
        $target = " link to $hlinks{ $k }";
        $tmode = 'h';
        $size = 0
      } else {
        $hlinks{ $k } = $_
      }
    }
    if ( !$tmode ) {
      if ( -l and !$opt_h ) {
        if ( !defined( $target = readlink $_ ) ) {
          print STDERR "$0: readlink $_: $!\n";
          return
        }
        $tmode = 'l';
        $target = " -> $target";
        $size = 0
      } else {
        $target = '';
        if ( -d ) {
          $tmode = 'd';
          $size = '0';
          $_ .= '/' unless substr( $_, -1 ) eq '/';
        } else {
          $size = "$size";
          if ( -p ) {
            $tmode = 'p'
          } elsif ( -S ) {
            $tmode = 's'
          } elsif ( -b ) {
            $tmode = 'b';
            $size = sprintf( '%d,%d', ($rdev & 0xff00) >> 8, $rdev & 0xff )
          } elsif ( -c ) {
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
    if ( ! -l ) {
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
    if ( !$opt_n ) {
      my $u = ( getpwuid( $uid ) )[ 0 ];
      my $g = ( getgrgid( $gid ) )[ 0 ];
      $uid = $u if defined $u;
      $gid = $g if defined $g;
    }
    my $owners = "$uid/$gid";

    my $pad = $width - length( $owners ) - length( $size );
    if ( $pad < 1 ) {
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
                  strftime( '%Y-%m-%d %H:%M', localtime $mtime ), $escape
  } elsif ( $opt_0 ) {
    print $_."\0"
  } else {
    print $_."\n"
  }
  return
}


sub md5 {
  my $fn = shift;
  $fn = $_ if !defined $fn;
  local *FH;
  open( FH, '<', $fn ) or die "$0: open $fn: $!\n";
  binmode FH;
  my $result = Digest::MD5->new->addfile( *FH )->hexdigest;
  close FH;
  return $result
}


my $pruned;
sub prune {
  die "can't use -d with prune\n" if $opt_d;
  $pruned = 1;
  return
}


my $depth;
sub process {
  my ( $dir, $base ) = @_;

  ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime,
    $ctime, $blksize, $blocks ) = ( $opt_h ? stat : lstat )[ 0..12 ];

  if ( !defined $dev ) {
    print STDERR "$0: (l)stat $_: $!\n";
    return 1
  }

  my $ok = 1;
  if ( defined $opt_e ) {
    local $_ = $_;
    $ok = eval $opt_e;
    if ( $@ ne '' ) {
      chomp $@;
      die "$0: eval: $@\n"
    }
  }
  ls if $ok;
  return 0
}


my $parent_dev;
sub descend {
  my $result;
  my ( $dir, $base ) = @_;
  local $_ = $dir.$base;

  if ( $opt_d ) {
    $parent_dev = ( $opt_h ? stat : lstat )[ 0 ] unless defined $parent_dev
  } else {
    $pruned = 0;

    $result = process( $dir, $base );
    if ( defined $parent_dev ) {
      return $result if $opt_x and $dev != $parent_dev
    } else {
      $parent_dev = $dev
    }
    return $result if $pruned
  }

  if ( ( -d and ( $opt_h or ! -l ) and
       ( ! $opt_x or ( $opt_h ? stat : lstat )[ 0 ] == $parent_dev ) ) ) {
    $depth++;

    local *D;
    my @ents = ();
    if ( opendir( D, $_ ) ) {
      @ents = readdir D;
      closedir D
    } else {
      print STDERR "$0: opendir $_: $!\n"
    }

    foreach my $ent ( $opt_s ? sort @ents : @ents ) {
      next if $ent eq '..' or $ent eq '.';
      descend( $base eq '' ? $_ : "$_/", $ent )
    }

    $depth--
  }

  if ( $opt_d ) {
    $result = process( $dir, $base )
  }
  return $result
}


if ( defined $opt_f ) {
  die "$0: can't use -e with -f\n" if defined $opt_e;
  open( SCRIPT, '<', $opt_f ) or die "$0: open $opt_f: $!\n";
  $opt_e = do { local $/; <SCRIPT> };
  close SCRIPT
}

my $exit_status = 0;

foreach my $arg ( @ARGV ) {
  $arg =~ m,(.*/)?([^/]*)$,;
  $depth = 0;
  $parent_dev = undef;
  $exit_status = descend( defined $1 ? $1 : '', $2 ) || $exit_status
}

if ( defined $opt_t ) {
  eval $opt_t;
  if ( $@ ne '' ) {
    chomp $@;
    die "$0: eval: $@\n"
  }
}

exit $exit_status
