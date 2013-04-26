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

# Some notes on usage:
# If you want everything done for you based upon the URL, use ::URLHandler
# You will have to supply a template, if not it won't be able to do anything
# (except use ->message()).
package LIXUZ::HelperModules::TemplateRenderer;
use Carp;
use Moose;
use Module::Load qw(load);
use Try::Tiny;

BEGIN
{
    # Dynamically load all available resolvers
    no warnings;
    foreach my $module (glob($LIXUZ::PATH.'/lib/LIXUZ/HelperModules/TemplateRenderer/Resolver/*.pm'))
    {
        $module =~ s{^.*/([^/]+)\.pm$}{$1};
        load('LIXUZ::HelperModules::TemplateRenderer::Resolver::'.$module);
    }
};

has 'c' => (
    isa => 'Object',
    weak_ref => 1,
    required => 1,
    is => 'ro'
    );

has 'template' => (
    isa => 'Maybe[Object]',
    is => 'rw',
    lazy => 1,
    builder => '_getTemplate',
    );

has 'cache' => (
    isa => 'Bool',
    is => 'ro',
    default => 1,
    );

has '_resolved' => (
    isa => 'Ref',
    required => 0,
    is => 'rw',
    lazy => 1,
    default => sub { {} },
    );

has '_resolvers' => (
    isa => 'HashRef',
    required => 0,
    is => 'ro',
    default => sub { {} },
    );

has '_stateVars' => (
    isa => 'Ref',
    required => 0,
    is => 'rw',
    lazy => 1,
    default => sub { {} },
    );

has '_templateInfo' => (
    isa => 'Maybe[HashRef]',
    is => 'rw',
    builder => '_getTemplateInfo',
    lazy => 1,
    );

has '_cachedData' => (
    isa => 'HashRef',
    is => 'rw',
    builder => '_fetchCachedHash',
    lazy => 1,
    );

# -- Public Methods ---

# Summary: Resolve all dependencies of the current template
sub resolve
{
    my $self = shift;
    if(not defined $self->template)
    {
        my $err = 'Log: resolve() called without a template attribute';
        if ($self->isa('LIXUZ::HelperModules::TemplateRenderer::URLHandler'))
        {
            $err .= ' (in ::URLHandler) for '.$self->c->req->uri->as_string;
        }
        # Don't bother cluttering the error log with requests for /favicon.ico
        if ($self->c->req->uri->path eq '/favicon.ico')
        {
            $err = undef;
        }
        $self->message('Attempted to render page without template','NOTEMPLATE',$err);
    }
    $self->_resolve_deps(
        $self->_templateInfo->{template_deps_parsed}
    );
    if ($self->_templateInfo->{'spots_parsed'} && $self->has_statevar('primaryArticle'))
    {
        $self->_resolve_files(
            {
                article => $self->get_statevar('primaryArticle'),
                spots_parsed => $self->_templateInfo->{'spots_parsed'},
            }
        );
    }
}

# Summary: Render the current template. Needs all deps to be resolved
sub render
{
    my $self = shift;

    foreach my $k (keys %{$self->_resolved})
    {
        $self->c->stash->{$k} = $self->_resolved->{$k};
    }

    $self->c->stash->{template} = 'core/templateHandler.html';
    $self->c->stash->{templateFileMap} = $self->_templateInfo->{includes_map};
    $self->c->stash->{lz_template} = $self->template->file;
    $self->c->stash->{lixuzHeader} = '/core/liveHeader.html';
    # TODO: Replace this, it's mostly compat code for existing code depending on the old
    #   'infolist' stuff used by LiveEntry
    $self->c->stash->{infolist} = {
        spots_parsed => $self->_templateInfo->{spots_parsed},
    };

    $self->c->detach('LIXUZ::View::Mason');
}

# Summary: Resolve all dependencies and then render the template
sub autorender
{
    my $self = shift;
    try
    {
        $self->resolve();
    }
    catch
    {
        if ($_ eq "catalyst_detach\n")
        {
            $self->c->detach;
        }
        $self->c->log->error('Error in template resolver: '.$_);
        $self->error(500,'An error occurred while attempting to serve this page, please try again later','Error in template resolver');
    };
    $self->render();
}

# Summary: Resolve a variable
sub resolve_var
{
    my $self = shift;
    my ($var,$val) = @_;
    if ($self->has_var($var))
    {
        $self->c->log->warn('TemplateRenderer: Variable "'.$var.'" is being resolved for the second time.');
        $self->c->log->warn('       old value: '.$self->_resolved->{$var});
        $self->c->log->warn('       new value: '.$val);
        $self->c->log->warn('Current URL: '.$self->c->req->uri);
    }
    $self->_resolved->{$var} = $val;
    return $val;
}

# Summary: Check if a variable has been resolved
sub has_var
{
    my $self = shift;
    my $var = shift;
    if(defined $self->_resolved->{$var})
    {
        return 1;
    }
    return;
}

# Summary: Remove a resolved variable
# Returns true if the variable existed and was removed, 0 otherwise
sub unresolve_var
{
    my $self = shift;
    my $var = shift;
    if ($self->has_var($var))
    {
        delete($self->_resolved->{$var});
        return 1;
    }
    return 0;
}

# Summary: Retrieve a resolved variable
sub get_var
{
    my $self = shift;
    my $var = shift;
    return $self->_resolved->{$var};
}

# Summary: Set a state variable
sub set_statevar
{
    my $self = shift;
    my $var = shift;
    my $val = shift;
    $self->_stateVars->{$var} = $val;
    return $val;
}

# Summary: Get a state variable
sub get_statevar
{
    my $self = shift;
    my $var = shift;
    return $self->_stateVars->{$var};
}

# Summary: Check if a state variable exists
sub has_statevar
{
    my $self = shift;
    my $var = shift;
    if(defined $self->_stateVars->{$var})
    {
        return 1;
    }
    return;
}

# Summary: Error out
sub error
{
    my $self = shift;
    my($httpVal,$error,$techReason,$debugReason) = @_;
    try
    {
        $self->_error($httpVal,$error,$techReason,$debugReason);
    }
    catch
    {
        if ($_ eq "catalyst_detach\n")
        {
            $self->c->detach;
        }
        else
        {
            $self->c->log->error('_error crashed for URL "'.$self->c->req->uri.'": '.$_);
            $self->c->log->error('Dumping args: '.join(' || ',@_));
            die('_error failed');
        }
    };
}

# Summary: Display a message
sub message
{
    my $self = shift;
    my $message = shift;
    my $messageType = shift;
    my $techMessage = shift;
    my $template = $self->c->model('LIXUZDB::LzTemplate')->search({ type => 'message', is_default => 1 });
    my $fallback = 0;
    if(not $template->count)
    {
        $template = $self->c->model('LIXUZDB::LzTemplate')->search({ type => 'message' });
    }
    if (defined $techMessage)
    {
        if (!($techMessage =~ s/^Log:\s*//))
        {
            $self->c->stash->{lz_message_intMsg} = $techMessage;
        }
        if (! $self->c->stash->{_triedPrimaryMessage})
        {
            $self->c->log->warn('TemplateRenderer: '.$techMessage);
        }
    }
    if(!$template->count || $self->c->stash->{_triedPrimaryMessage})
    {
        my $c = $self->c;
        $c->stash->{lz_message} = $message;
        $c->stash->{lz_message_type} = $messageType;
        $c->stash->{template} = 'adm/core/message-fallback.html';
        $c->stash->{i18n} //= undef;
        $c->detach();
    }
    else
    {
        $self->c->stash->{_triedPrimaryMessage} = 1;
        $template = $template->next();
        $self->refreshTemplate($template);
        if ($fallback)
        {
            $self->c->log->warn('Failed to locate a default message template. Falling back to using the first message template found in the DB ('.$template->template_id.')');
        }
    }
    $self->resolve_var('lz_message',$message);
    $self->resolve_var('lz_message_type',$messageType);
    $self->autorender();
}

# Summary: Clear existing internal state (use with caution)
sub clearstate
{
    my $self = shift;
    $self->_stateVars({});
    $self->_resolved({});
    $self->_cachedData({});
}

# Summary: Refresh template to the supplied one (ie. replace the current with a new one)
sub refreshTemplate
{
    my $self = shift;
    my $template = shift;
    if(not $template)
    {
        $template = $self->_get_template();
    }
    $self->template($template);
    $self->_templateInfo($self->_getTemplateInfo);
}

# Summary: Call the internal data handler for the supplied data
# Usage: $resolver->autoResolveDataRequest(RESOLVER, WANTED, PARAMS);
sub autoResolveDataRequest
{
    my $self   = shift;
    my $source = shift;
    my $fetch  = shift;
    my $params = shift;
    my $resolver = $self->_get_resolver_for($source);
    my $resolved = $resolver->get($fetch,$params);
    if(not defined $resolved)
    {
        return;
    }
    if (!ref($resolved) eq 'HASH')
    {
        die('Resolver for '.$source.' did not return a hashref'."\n");
    }
    foreach my $k (keys %{$resolved})
    {
        $self->resolve_var($k,$resolved->{$k});
    }
    return;
}

# -- Private Methods ---
# These methods should not be considered in any way API stable.

sub _error
{
    my $self = shift;
    my($httpVal,$error,$techReason,$debugReason) = @_;
    $self->clearstate();

    if (not defined $httpVal or $httpVal =~ /\D/)
    {
        $httpVal = 500;
    }

    if (not defined $error or not length($error))
    {
        if ($httpVal == 500)
        {
            $error = '500: Internal server error';
        }
        elsif($httpVal == 404)
        {
            $error = '404: File not found';
        }
        else
        {
            $error = 'Unknown error';
        }
    }
    if ($self->c->debug)
    {
        $techReason .= "\n".$debugReason;
    }

    $self->c->res->status($httpVal);
    $self->message($error, $httpVal,$techReason);
}

sub _getTemplate
{
    # TODO: Implement
    confess('_getTemplate: STUB');
}

sub _getTemplateInfo
{
    my $self = shift;
    if ($self->template)
    {
        # TODO: Add to cache, and fetch from cache if we have one
        return $self->template->get_info($self->c);
    }
}

sub _fetchCachedHash
{
    # TODO: Add proper fetching
    return {};
}

sub _resolve_deps
{
    my $self = shift;
    my $entries = shift;

    foreach my $source (sort keys %{$entries})
    {
        foreach my $fetch (sort keys %{$entries->{$source}})
        {
            foreach my $params (@{$entries->{$source}->{$fetch}})
            {
                $self->autoResolveDataRequest($source,$fetch,$params);
            }
        }
    }
    return 1;
}

sub _resolve_files
{
    my $self = shift;
    my $spots = shift;

    $self->autoResolveDataRequest('Files','fileSpots',$spots);
    return;
}

sub _get_resolver_for
{
    my $self = shift;
    my $type = shift;
    $type =~ s/\W//g;
    $type = ucfirst($type);

    if ($self->_resolvers->{$type})
    {
        return $self->_resolvers->{$type};
    }

    my $resolver;
    my $params = { c => $self->c, renderer => $self };
    if ($type eq 'Article')
    {
        $resolver = LIXUZ::HelperModules::TemplateRenderer::Resolver::Articles->new($params);
    }
    else
    {
        $resolver = eval('return LIXUZ::HelperModules::TemplateRenderer::Resolver::'.$type.'->new($params)');
        if(not $resolver)
        {
            die('Failed to dynamically locate resolver for type '.$type."\ntried: LIXUZ::HelperModules::TemplateRenderer::Resolver::$type\->new( resolver => $self, c => $self->c);\n");
        }
    }
    $self->_resolvers->{$type} = $resolver;
    return $resolver;
}

__PACKAGE__->meta->make_immutable;
1;
__END__
=pod

=head1 DESCRIPTION

This is the Lixuz template renderer. It handles retrieving information about
templates, resolving their information (and intra-template) dependencies and
handing off to Mason for rendering, as well as having some helper methods for
displaying common messages and errors to the user.

In most basic sites, it will not be noticable to the user, everything will be
automatic, and the renderer will be called from I<::URLHandler> which takes
care of parsing a URL and providing the template renderer with the information
it needs to do its job.

In more advanced cases however, you can use the template renderer from your
own controllers. It provides a rather powerful interface to the information
retrieval and rendering system that powers the live bits of Lixuz sites.

=head1 ATTRIBUTES

All of these attribues can be supplied to the constructor
(LIXUZ::HelperModules::TemplateRenderer->new()) in a hash or hashref during
construction time, and several of them are required to be supplied like that.

All of these constructors have accessors that can be used to both set
and get the current value. Ie. ->template() gets the current value, while
->template($var) sets the current value. Note that variables required
during construction time can not be set afterwards.

=over

=item B<c>

This is the catalyst object. Required during construction time.

=item B<cache>

A boolean. If true, caching will be enabled. Not required, defaults to
true. Can not be altered after construction.

=item B<template>

A LzTemplate object. This can be set any time, but if you alter it after
calling the L<resolve()> method, the results will be undefined (and likely
crash-happy). If it is not supplied, the renderer will attempt to automatically
find a suitable template, this is not very reliable when not using
L<::URLHandler> though.

=back

=head1 METHODS

=over

=item I<resolve()>

Resolves all pending dependencies. This methods will not return if it fails.
In that case it will automatically render an error page. It is recommended
to use L<autorender> rather than resolve+render.

=item I<render()>

Renders the current template. Needs all dependencies to already have been
resolved. This method never returns. It is recommended to use L<autorender>
rather than resolve+render.

=item I<autorender()>

Resolves all dependencies and renders the current template. This method never
returns.

=item I<resolve_var($var,$value)>

Resolves a dependency variable. Ie. if a template has a NEEDINFO for a
variable named $article, calling resolve_var('article',$value); will resolve
that variable for use in the template. Note that secondary methods (such
as pagination, or preparing comments) will still be performed, so you
can still take advantage of automated retrieval of that information depending
on what the template wants, you only need to supply the base variable.

If a variable is resolved more than once, the renderer while whine loudly,
but will allow the operation to continue, using the most recently supplied
value.

=item I<has_var($var)>

Returns true if $var has been resolved, false otherwise.

=item I<get_var($var)>

Returns the resolved value of $var if it has been resolved, undef otherwise.

=item I<set_statevar($var)>

Sets a state variable. These are not supplied directly to templates, but alters
the state or behaviour in some way. Much of its functionality is automatic,
but it can at times be useful for developers to use directly.

For instance, you can supply a variable named raw_[saveAs] where [saveAs] is
the as= variable name defined in a template. In the case where [saveAs]
is an article list, you can supply an unpaginated resultset here, and
the rendere will handle all pagination. If you just resolve the variable,
then the renderer will not paginate it automatically. It will still provide
a *pager*, but it will never alter the resolved variable, and thus that will
not be paginated, even though a pager is supplied.

B<Other statevars>

=over

=item I<primaryArticle>

This is a state variable referring to the primary article for the current
URL. This will be used as the article where artid=url. Use this instead
of using resolve_var() to resolve a primary article.

=item I<primaryArticleIsValid>

This is a state variable defining if the renderer should validate the status
of the primary article. If this is true then the renderer will not bother with
checking the status and publish time/expiry time of an article. It will assume
that the caller has already validated it. If this is not set or false, then
it will validate it.

=back

=item I<has_statevar($var)>

Returns true if the state variable $var has been set, false otherwise.

=item I<get_var($var)>

Returns the value of the state variable $var if it has been set , undef
otherwise.

=item I<error($httpError,$error,$techReason)>

This displays an error page to the requesting user.

$httpError is the HTTP error code.

$error is the error text as seen by the user.

$techReason is a technical reason for the error. This is logged, and included
in the markup inside a HTML comment (so it can be viewed using the browsers
view source function).

=item I<message($message,$type,$techMessage)>

This displays a message to the requesting user, which does not have
to be an error.

$message is the message shown to the user.

$messageType is the type of message, so that templates can display custom
messages if they want to. This can be a string or int. If it is an int
then the template should assume it is the http error code.

$techMessage is a technical explanation for the above message. This is
logged. If techMessage does not start with "Log: " it is also included in the
markup inside a HTML comment (so it can be viewed using the browsers view
source function).

=item I<clearstate()>

Clears the internal state of the object. B<Use with caution>. It will not
completely empty the object, so it will not be quite reset to the state
it was during construction time. If you need that, you are better off with
creating a new object.

=item I<autoResolveDataRequest($resolver,$wanted,$params)>

Calls the internal data handler for the supplied data.

$resolver is the resolver to use, this would be the first parameter in
"NeedsInfo" lines, ie. "article" in the example.

$wanted is the kind of data we're requesting, somewhat equivalent to a method
call on a class, ie. "list" in the example.

$params is a hashref of parameters, which is what is provided between the brackets
in template requests.

These two are equivalent:
    $resolver->autoResolveDataRequest('article','list', { catid => 17, limit => 5, as => test });
    NeedsInfo = article_list_[catid=17,limit=5,as=test]

One way to think of the above autoResolveDataRequest call is that you're
telling it to call the "list" method on the resolver class for an "article"
and provide the catid, limit and as parameters.

=item I<refreshTemplate($template)>

You can use this to alter the template after performing some actions, such
as I<resolve()>. It will set the template attribute to the supplied variable,
and it will read information from the new template, replacing whatever
information we already have about the old template.

This is also used internally to enable ->error() to operate on an object
that has already begun resolving things.

=back

=head1 EXAMPLES

    my $handler = LIXUZ::HelperModules::TemplateRenderer->new(
        c => $c,
        template => $template
    );

    $handler->set_statevar('raw_articles',$res);
    $handler->autorender();

This will render using the supplied template, it will use the state variable
'raw_articles' to resolve the articles resultset.
