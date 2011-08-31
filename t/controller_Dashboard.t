use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'LIXUZ' }
BEGIN { use_ok 'LIXUZ::Controller::Admin::Dashboard' }

ok( request(/admin'/dashboard')->is_success, 'Request should succeed' );


