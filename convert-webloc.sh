#!/bin/sh

# Copyright (c) 2016 Finn Thain
# fthain@telegraphics.com.au

# Convert Mac OS .webloc files to Linux .desktop files.
# Pass a directory or file name as first argument.
# Handles JSON, XML and binary webloc files. Reverts changes to timestamps.
# Runs on Mac OS and requires command-line Developer Tools to be installed.
# See also http://hints.macworld.com/article.php?story=20040728185233128

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

export TEMPFILE=$(mktemp)

find -f "$1" -- -type f -name "*.webloc" -print0 |
  perl -0nwe '
    chop;
    my $base = $_;
    $base =~ s,.*/,,;
    $base =~ s,.webloc$,,;
    my $dir = $_;
    $dir =~ s,[^/]*/*$,,;

    my $dir_mtime = (stat $dir)[9];
    my $file_mtime = (stat $_)[9];

    my $url;
    if (-s $_) {
      # file has something in the data fork
      open(W, q(<), $_) or die $!;
      my $data = join(q(), <W>);
      close(W) or die $!;
      if (index($data, q(bplist)) != 0 &&
          index($data, q(?xml )) < 0 &&
          index($data, q({)) != 0) {
        warn qq(Not JSON, XML nor binary plist: $_\n);
        next;
      }

      system( qw(plutil -extract URL binary1), $_ ) == 0 or die qq($? ($!));
      open(STDOUT, q(>), $ENV{TEMPFILE}) or die $!;
      system( qw(plutil -p), $_ ) == 0 or die qq($? ($!));
      open(U, q(<), $ENV{TEMPFILE}) or die $!;
      $url = <U>;
      close(U) or die $!;
      chop $url;
      $url =~ s,^",,;
      $url =~ s,"$,,;
    } else {
      # otherwise it presumably has something in the resource fork
      open(STDOUT, q(>), $ENV{TEMPFILE}) or die $!;
      system( qw(DeRez -e -only), q(url ), $_ ) == 0 or die qq($? ($!));
      open(U, q(<), $ENV{TEMPFILE}) or die $!;
      my $u = <U>;
      close(U) or die $!;
      if (!length($u)) {
        warn qq(No url resource: $_);
        next;
      }

      local $_ = $u;
      s,.*{,,;
      s,}.*,,;
      $url = q();
      foreach my $line (split chr(10), $_) {
        chop;
        $line =~ s,^\t.",,;
        $line =~ s," .*,,;
        $line =~ s, ,,g;
        $line =~ s,([0-9a-f][0-9a-f]),chr(hex($1)),eig;
        $url .= $line;
      }
    }
    unlink($_) or die $!;

    $_ =~ s,webloc$,desktop,;
    open(D, q(>), $_) or die $!;
    print D qq([Desktop Entry]
Encoding=UTF-8
Name=$base
Type=Link
URL=$url
Icon=text-html
);
    close(D) or die $!;
    utime($dir_mtime, $dir_mtime, $dir);
    utime($file_mtime, $file_mtime, $_);
  '

rm "$TEMPFILE"
