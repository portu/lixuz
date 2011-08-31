use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'LIXUZ' }
BEGIN { use_ok 'LIXUZ::Controller::Admin::Users::Roles' }

ok( request(/admin'/users/roles')->is_success, 'Request should succeed' );


