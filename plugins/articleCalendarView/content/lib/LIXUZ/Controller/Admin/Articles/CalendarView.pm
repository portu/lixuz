package LIXUZ::Controller::Admin::Articles::CalendarView;
use 5.010;
use strict;
use warnings;
use Moose;
use DateTime;
use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL_to_unix);
use LIXUZ::HelperModules::RevisionHelpers qw(get_latest_article);
use LIXUZ::HelperModules::Includes qw(add_cssIncl);
BEGIN { extends 'Catalyst::Controller'; }

sub default : Public
{
    my($self,$c) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $mon++;$year += 1900;

    my $reqYear = $c->req->param('year') // $year;
    my $reqMon  = $c->req->param('month') // $mon;
    my $index = $self->performSearch($c,$reqYear,$reqMon);
    $c->stash->{template} = 'adm/articles/calendarview/calendarPage.html';
    $c->stash->{index} = $index;
    $c->stash->{year} = $reqYear;
    $c->stash->{month} = $reqMon;

    add_cssIncl($c,'articleCalendarView.css');
}

sub performSearch
{
    my($self,$c,$year,$month) = @_;
    my $day = DateTime->new( year => $year, month => $month, day => 1 )->add( months => 1 )->subtract( seconds => 1 )->day;

    my $first = $year . '-' . _pad($month) . '-01 00:00';
    my $last  = $year . '-' . _pad($month) . '-' . _pad($day) . ' 23:59';
    my $field_id = $self->_getSearchField($c);

    my $values = $c->model('LIXUZDB::LzFieldValue')->search({
            field_id => $field_id,
            module_name => 'articles',
            dt_value => {
                -between => [ $first, $last ]
            }
        });
    my %articleIndex;
    my %seen;
    while(my $val = $values->next)
    {
        if ($seen{$val->module_id})
        {
            next;
        }
        $seen{$val->module_id} = 1;
        my $article = get_latest_article($c,$val->module_id);
        my $field = $article->getFieldRaw($c,$field_id);
        my $date = datetime_from_SQL_to_unix($field);
        $field =~ s/\s+.+//;
        $articleIndex{$field} //= {};
        $articleIndex{$field}->{$date} //= [];
        push( @{$articleIndex{$field}->{$date}},  $article);
    }
    return \%articleIndex;
}

sub _getSearchField
{
    my ($self,$c) = @_;
    my $cview = $c->model('LIXUZDB::LzLixuzMeta')->find({
            entry => 'calendarview_field',
        });
    if ($cview->value eq 'auto')
    {
        my $fields = $c->model('LIXUZDB::LzField')->search({ field_type => 'datetime' },{
                limit => 1
            });
        if ($fields)
        {
            return $fields->next->field_id;
        }
        return;
    }
    else
    {
        return $cview->value;
    }
}

sub _pad
{
    my $s = shift;
    if ($s < 10)
    {
        $s = '0'.$s;
    }
    return $s;
}

__PACKAGE__->meta->make_immutable;
