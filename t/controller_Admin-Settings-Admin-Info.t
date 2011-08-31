use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'LIXUZ' }
BEGIN { use_ok 'LIXUZ::Controller::Admin::Settings::Admin::Info' }

ok( request('/admin/settings/admin/info')->is_success, 'Request should succeed' );


