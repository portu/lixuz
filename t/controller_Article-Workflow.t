use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'LIXUZ' }
BEGIN { use_ok 'LIXUZ::Controller::Admin::Article::Workflow' }

ok( request(/admin'/article/workflow')->is_success, 'Request should succeed' );


