#!/usr/bin/perl
# Hourly cronjob for Lixuz

exit(0); # Unused for now

# -- INIT --
use strict;
use warnings;
use POSIX qw(nice); nice(19); # Be very nice
use FindBin;
use lib $FindBin::RealBin.'/../lib/';
# Lixuz doesn't like not being in its own dir when initializing
chdir($FindBin::RealBin.'/..');
require LIXUZ;

