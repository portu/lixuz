use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'LIXUZ' }
BEGIN { use_ok 'LIXUZ::Controller::Admin::Newsletter' }

ok( request(/admin'/newsletter')->is_success, 'Request should succeed' );


