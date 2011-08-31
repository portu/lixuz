# LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2008-2011
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

# LIXUZ::HelperModules::JSON

# Read before using
# -----------------
# - After calling json_response or json_error catalyst *stops* processing.
# - The keys 'status', 'error' and 'human_error' in the reply is reserved for internal use
#
# Notes on Catalyst forwarding
# ----------------------------
# If you use a JSON module inside of a ->forward()ed action you may run into
# trouble, at least with the test server. This is because Catalyst *appears*
# to only ->detach() the forwarded one properly, the caller/parent that did the
# ->forward() appears to continue to execute, making catalyst hang on some
# syswrite() call that writes to STDOUT. So make sure that the action you
# ->forward to properly returns true if execution is allowed to continue,
# and false if it isn't (using these functions will result in a false return)
# and then do $c->forward('somethingthatcallsJSON') or $c->detach();
package LIXUZ::HelperModules::JSON;

use strict;
use warnings;
use Carp;
use Exporter qw(import);
use constant { true => 1, false => 0 };
our @EXPORT_OK = qw(json_response json_error json_response_raw);

# Summary: Return data in JSON
# Usage: json_response($c,\%Data);
# Note that catalyst stops processing after this has been called.
sub json_response
{
	my $c = shift;
	my $var = shift;
	return _json_send_response($c,$var,false);
}

# Summary: Return data in JSON format, without altering it
# Usage: json_response_raw($c,\@Data or \%Data);
# Note that catalyst stops processing after this has been called.
sub json_response_raw
{
	my $c = shift;
	my $var = shift;
	return _json_output($c,$var,false);
}

# Summary: Return an error in JSON
# Usage: json_error($c,'error text',human_error?, fatal?,extraHash?);
# Note that catalyst stops processing after this has been called.
# Human_error is a string, that can be undef, which describes the error in a human-readable fashion
# fatal is optional and defaults to true, it indicates to the client
# 	if the request was completely fatal, or if it might succeed if retried.
# extraHash is a hashref like the %Data in json_response, it is merged with any other
#   data json_error would return.
sub json_error
{
	my $c = shift;
	my $error = shift;
	my $human_error = shift;
	my $fatal = shift;
    my $extraHash = shift;
    $error = defined $error ? $error : 'UNKNOWN';
    $fatal = (defined $fatal or $fatal) ? 1 : 0;
    my $var = $extraHash ? $extraHash : {};
    $var->{status} = 'ERR',
    $var->{error} = $error;
    $var->{fatal} = $fatal;
	if ($human_error)
	{
		$var->{human_error} = $human_error;
	}
	return _json_output($c,$var);
}

# Summary: Internal function that handles preparing a json_response
# Usage: _json_send_response($c,$data);
sub _json_send_response
{
	my $c = shift;
	my $var = shift;
    my $precoded = shift;
    if(not defined $var)
    {
        $var = {};
    }
    elsif(not ref($var) eq 'HASH')
    {
        my (undef, $filename, $line, undef, undef, undef, undef, undef, undef, undef, undef) = caller(1);
        $c->log->warn('json_response() or json_response() was supplied a nonhash variable (of the type '.ref($var).'), replacing with empty hash and shoving the contents into __responseNonhash. Called from '.$filename.':'.$line);
        $var = {
            __responseNonhash => $var,
        };
    }
	$var->{status} = 'OK';
	return _json_output($c,$var,$precoded);
}

# Summary: Internal function that does the core JSON magic
# Usage: _json_output($c,\%Output);
sub _json_output
{
	my $c = shift;
	my $var = shift;

    if ($c->stash->{multiRequestMode})
    {
        return _json_output_multiRequest($c,$var);
    }

    $c->stash->{json_response} = $var;
    $c->forward('View::JSON');
}

sub _json_output_multiRequest
{
    my $c = shift;
    my $reply = shift;

    if ($reply->{status} eq 'ERR')
    {
        if ($c->req->param('multiReqFail'))
        {
            $c->stash->{'MULTIREQ_SUBFAILURE'} = $reply;
            $c->detach();
            return;
        }
    }

    my $path = $c->stash->{multiRequestCurr};

    $c->stash->{multiRequestResponse}->{$path} = $reply;

    $c->detach();
    return;
}

1;
