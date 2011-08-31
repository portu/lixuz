use strict;
use warnings;
use Test::More tests => 2;

BEGIN { use_ok 'Catalyst::Test', 'LIXUZ' }

ok( request(/admin'/')->is_success, 'Request should succeed' );
