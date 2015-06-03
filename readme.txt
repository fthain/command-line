comm.pl
-------

This program works like the standard Un*x comm(1) command, except that
it can handle pathnames correctly. E.g. a/b must sort before a.b

It isn't limited to merely printing particular lines, it can execute
a perl snippet for particular lines.

Usage: ./comm.pl [-0] [-1 <perl>] [-2 <perl>] [-3 <perl>] [-c] [-p] file1 file2
Options:
            -0 file1 and file2 use null as line separator character.
            -1 Execute perl fragment for every line found only in file1.
            -2 Execute perl fragment for every line found only in file2.
            -3 Execute perl fragment for every line found in both files.
            -c Behave like comm(1) and print entries in three columns.
               For example, passing -c -3 0 will print lines unique to file1 or file2.
            -p Treat lines as pathnames rather than text.



find.pl
-------

This program works like the standard Un*x find(1) command, except that
its syntax is sane. Even though it uses perl's eval function, it will
run faster than the standard find command if it avoids having to spawn
a process like mv or cat. Some examples --

# What was changed recently? List . recursively, sorted by age of changes
find.pl -e 'print sprintf q(%015.9f %s), (-M $_), $_.$/; 0' . | sort -rn

# List duplicate files
find.pl -s -e 'my $d; $d = md5 if -f; if (defined $d) { $::seen{$d} = 0 unless defined $::seen{$d} }' .

# To change all names under /tmp/FOO to lowercase:
find.pl -d -e '$b = $base; $b =~ tr/A-Z/a-z/; rename($dir.$base, $dir.$b)' /tmp/FOO

# To concatenate files recursively (the -f is the perl snippet here):
find.pl -0e -f . | xargs -0 cat

# Some systems have perl but not "xargs -0":
find.pl -e 'push(@::x, $_) if -f; 0' -t 'system "cat", @::x' .

# Match names using regexp (more succinct than a series of globs):
find.pl -e '/[.]cc?$/' .

# Shorter syntax than the standard Un*x find command (it's just perl):
find.pl -ve 'prune if $depth == 2; -l' /sys

# More flexible than the standard Un*x find command.
# E.g. to indent subdirectories:
find.pl -e 'print q(  ) x $depth' .

# Count filenames with control characters 
find.pl -e '$::n++ if /[[:cntrl:]]/; 0' -t 'print $::n.$/' /tmp

# List .el files in a directory tree without a corresponding .elc file
find.pl -e 'm([.]el$) and ! -f "${_}c"' .


Usage: ./find.pl [-0] [-d] {-e <perl> | -f <file>} [-h] [-n] [-s] [-t <perl>] [-v] [-x] pathname...
Options:
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



tree-comm.pl
------------

This program is what you get when you combine comm.pl and find.pl: a way
to compare to directory trees and execute a perl snippet for entries that
appear in either or both of those trees.

Usage: ./tree-comm.pl [-1 <perl>] [-2 <perl>] [-3 <perl>] [-c] [-e <perl>] path1 path2
Options:
            -1 Execute perl fragment for every directory entry found only under path1.
            -2 Execute perl fragment for every directory entry found only under path2.
            -3 Execute perl fragment for every directory entry found under both paths.
            -c Behave like comm(1) and print entries in three columns.
               For example, passing -c -3 0 will print entries unique to path1 or path2.
            -e Pass this fragment to find.pl to filter entries in path1 and path2.
               (See find.pl --help for information about the available variables.)
