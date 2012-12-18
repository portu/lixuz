use strict;
use warnings;
use 5.010;
use LIXUZ::HelperModules::Scripts qw(getDBIC);

# Add or remove the lz_action entry
sub checkAddOrRemoveACL
{
    my $remove = shift;
    my $dbic = getDBIC();
    my $cview = $dbic->resultset('LzAction')->find_or_create({
            action_path => '/articles/calendarview'
        });
    if ($remove)
    {
        $dbic->resultset('LzRoleAction')->search({
                action_id => $cview->action_id
            })->delete;
        $cview->delete;
    }
    else
    {
        $cview->update;
    }
}

# Add or remove the lz_lixuz_meta setting
sub checkAddOrRemoveSetting
{
    my $remove = shift;
    my $dbic = getDBIC();
    my $cview = $dbic->resultset('LzLixuzMeta')->find_or_create({
            entry => 'calendarview_field',
        });
    if ($remove)
    {
        $cview->delete;
    }
    else
    {
        if ( ! defined $cview->get_column('value'))
        {
            $cview->set_column('value','auto');
        }
        $cview->update;
    }
}

my $triggers = {
    # Triggered on plugin upgrade
    upgrade => sub {
        checkAddOrRemoveACL();
        checkAddOrRemoveSetting();
    },
    # Triggered on plugin install
    install => sub {
        checkAddOrRemoveACL();
        checkAddOrRemoveSetting();
        print "\n".'***'."\n";
        print 'If you have multiple DateTime fields you may need to manually set which field'."\n";
        print 'you want the CalendarView module to use. If so, set the setting'."\n";
        print '"calendarview_field" in lz_lixuz_meta to the ID (default: "auto")'."\n";
        print '***'."\n";
    },
    # Triggered on plugin removal
    removal => sub {
        checkAddOrRemoveACL(1);
        checkAddOrRemoveSetting(1);
    },
    # Triggered on a Lixuz upgrade
    lixuzUpgrade => sub {
    },
    # Triggered during build of the plugin
    build => sub
    {
        # Minify the CSS
        system(qw(java -jar),$ENV{HOME}.'/.local/yuiminify/yuicompressor.jar','content/root/css/articleCalendarView.src.css','-o','content/root/css/articleCalendarView.css');
    },
};
