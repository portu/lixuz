# LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2008-2012
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# LIXUZ::HelperModules::Calendar
#
# This module generates HTML and JS for the calendar widget.
#
# SYNOPSIS:
# use LIXUZ::HelperModules::Calendar qw(create_calendar);
# $c->stash->{yourCalendarStash} = create_calendar($c, 'id tag', { params });
#
# value is optional, the default value of the field.
#
# Then in the view:
# <% $yourCalendarStash |n%>
#
# This does all the magic, generating the HTML, JS and adding needed
# includes.
package LIXUZ::HelperModules::Calendar;
use strict;
use warnings;
use Carp;
use Exporter qw(import);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl);
use POSIX qw(mktime);
our @EXPORT_OK = qw(create_calendar datetime_to_SQL datetime_from_SQL datetime_from_unix datetime_from_SQL_to_unix is_dst);

# TODO: Much more error handling in datetime_(from|to)_* functions

sub datetime_to_SQL
{
	my $string = shift;
	if(not defined $string or not length($string))
	{
		return;
	}
	if(not $string =~ s/^\s*(\S+\s+\S+)\s*$/$1/)
	{
		# FIXME: Handling it like this isn't exactly pretty, should probably silently return in production.
		die("Failed to parse datetime string");
	}
	(my $date = $string) =~ s/\s+\S+$//;
	(my $time = $string) =~ s/^\S+\s+//;
	my ($year, $month, $day, $hour, $minute);
	($year = $date) =~ s/^\d+\.\d+\.//;
	($month = $date) =~ s/^\d+\.(\d+)\..*$/$1/;
	($day = $date) =~ s/\.?\d+\.\d+$//;

	($hour = $time) =~ s/\:\d+$//;
	($minute = $time) =~ s/^\d+\://;

	return($year.'-'.$month.'-'.$day.' '.$hour.':'.$minute.':00');
}

sub datetime_from_SQL
{
	my $string = shift;
	if(not defined $string or not length($string))
	{
		return;
	}
	$string =~ s/:00$//;
	(my $date = $string) =~ s/\s+\S+$//;
	(my $time = $string) =~ s/^\S+\s+//;
	my ($year, $month, $day, $hour, $minute);
	($year = $date) =~ s/-\d+-\d+$//;
	($month = $date) =~ s/^\d+-(\d+)-.*$/$1/;
	($day = $date) =~ s/^\d+-\d+-//;

	($hour = $time) =~ s/(\:\d+)+$//;
	($minute = $time) =~ s/^\d+\:(\d+)(:\d+)*/$1/;
    
    $day = '0'.$day if length($day) == 1;
    $month = '0'.$month if length($month) == 1;
    $hour = '0'.$hour if length($hour) == 1;
    $minute = '0'.$minute if length($minute) == 1;

	return($day.'.'.$month.'.'.$year.' '.$hour.':'.$minute);
}

sub datetime_from_SQL_to_unix
{
	my $string = shift;
	if(not defined $string or not length($string))
	{
		return;
	}
	$string =~ s/:00$//;
	(my $date = $string) =~ s/\s+\S+$//;
	(my $time = $string) =~ s/^\S+\s+//;
	my ($year, $month, $day, $hour, $minute);
	($year = $date) =~ s/-\d+-\d+$//;
	($month = $date) =~ s/^\d+-(\d+)-.*$/$1/;
	($day = $date) =~ s/^\d+-\d+-//;

	($hour = $time) =~ s/(\:\d+)+$//;
	($minute = $time) =~ s/^\d+\:(\d+)(:\d+)*/$1/;
    
    $day = '0'.$day if length($day) == 1;
    $month = '0'.$month if length($month) == 1;
    $hour = '0'.$hour if length($hour) == 1;
    $minute = '0'.$minute if length($minute) == 1;

    $month--;
    $year -= 1900;
    my $unixTime = mktime(0,$minute,$hour,$day,$month,$year,0,0,is_dst());
    return $unixTime;
}


sub datetime_from_unix
{
    my $unixtime = shift;
    $unixtime = $unixtime ? $unixtime : time;
    my ($sec,$minute,$hour,$day,$month,$year,$wday,$yday,$isdst) = localtime($unixtime);
    $year += 1900;
    $month++;
    return($day.'.'.$month.'.'.$year.' '.$hour.':'.$minute);

}

sub get_current_time
{
    my $unixtime = time;
    my ($sec,$minute,$hour,$day,$month,$year,$wday,$yday,$isdst) = localtime($unixtime);
    $year += 1900;
    $month++;
    return ($hour.':'.$minute);

}

# Summary: Create a calendar widget
# Usage: html = create_calendar($c, widget_id, default_value);
# { params } can be undef, or contain zero or more of the following:
# {
# 	value => default value,
# 	form => $form object,
# 	formentry => the entry this calendar has in the $form object - used to
# 			generate validate => code. If it is not present but form is then
# 			the widget_id will be used,
# }
sub create_calendar
{
	my ($c, $id, $params) = @_;
	$params = $params ? $params : {};
	my $value = $params->{value} ? $params->{value} : '';

	# Includes
	add_jsIncl($c,'jscalendar.lib.js');
	add_cssIncl($c,'widgets/jscalendar.css');

	my $html = '<input type="text" size="65" id="'.$id.'" name="'.$id.'" value="'.$value.'"';
    if ($params->{disabled})
    {
        $html .= 'disabled="disabled"';
    }
    $html .= '/>';
	$html .= ' <a href="#" onclick="return false;" id="'.$id.'-triggerButton"><img src="/static/images/calendar.png" style="border:0;" /></a>';
	$html .= "\n<script type='text/javascript'>\n";
    $html .= '$LAB.queue(function () {'."\n";
	$html .= 'Calendar.setup({'."\n";
	$html .= '  inputField  : "'.$id.'",'."\n";
	$html .= '  ifFormat    : "%d.%m.%Y %H:%M",'."\n";
	$html .= '  showsTime   : true,'."\n";
	$html .= '  timeFormat  : 24,'."\n"; # FIXME: We can query this via $i18n 
										# and properly handle it.
	$html .= '  button      : "'.$id.'-triggerButton",'."\n";
	$html .= '  singleClick : true,'."\n";
	$html .= '  step        : 1'."\n";
	$html .= '})'."\n";
    $html .= '});'."\n";
	$html .= '</script>'."\n";

	# Generate validation JS for the form field if it is present
	if ($params->{form})
	{
		$params->{formentry} = $params->{formentry} ? $params->{formentry} : $id;
		$params->{form}->field(
			name => $params->{formentry},
			# Matches DD?.MM?.YYYY HH:MM, with any whitespace fore, aft and 
			# in the middle (middle one required to be at least one).
			validate => '/^\s*\d+\.\d+\.\d\d\d\d\s+\d\d?\:\d\d?\s*$/',
		);
	}
	return $html;
}

# Purpose: Check if daylight savings time is in effect
# Returns: true if in effect, false otherwise
sub is_dst
{
    my @l = localtime();
    return $l[8];
}
1;
