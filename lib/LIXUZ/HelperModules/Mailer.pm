package LIXUZ::HelperModules::Mailer;
use Moose;
use JSON qw(encode_json);
use Carp;
use IPC::Open2;
use IO::Socket::UNIX;
use Method::Signatures;
use LIXUZ::HelperModules::Paths qw(lixuzFSPathTo);
use LIXUZ::HelperModules::Version qw(lixuzVersion);

has '_mails' => (
    is => 'ro',
    default => sub { [] },
);

has '_defaultFrom' => (
    is => 'ro',
    builder => '_buildFrom',
    lazy => 1,
);

has '_socket' => (
    is => 'rw',
);

has '_socketConnection' => (
    is => 'rw'
);

has 'streaming' => (
    is => 'ro',
    required => 0,
    default => 0,
);

# Dupe protection enables additional guards against sending duplicates. This is
# only useful for short lived instances that will send a single mail to a lot
# of recipients, and will guard against sending that one e-mail to a single
# recipient more than once. If you will be sending several different e-mails
# through the Mailer instance then this could potentionally result in lost
# mail and should not be used.
#
# The guarding happens within the lixuz-sendmail.pl process itself. If dupes
# are detected then usually the first e-mail added to that recipient will be
# the one that gets sent. That is not guaranteed, however, and if sending
# an e-mail fails (ie. temporary problems with the mail server) then a later
# mail could be sent instead. The only guarantee is one mail per recipient.
has 'dupeProtection' => (
    is => 'ro',
    required => 0,
    default => 0,
);

has 'c' => (
    is => 'rw',
    required => 1,
    weak_ref => 1,
);

method add_mail($settings)
{
    my $recipients  = $settings->{recipients};
    my $subject     = $settings->{subject};
    my $contentText = $settings->{message_text};
    my $contentHtml = $settings->{message_html};
    my $from        = $settings->{from};
    my $systemMail  = $settings->{systemMail};
    my $footer      = $settings->{footer};

    if (!ref($recipients))
    {
        $recipients = [ $recipients ];
    }

    if (scalar @{$recipients} < 1)
    {
        carp('add_mail(): no recipients');
    }
    if (!defined($contentHtml) && !defined($contentText))
    {
        carp('add_mail(): no content');
    }
    if (!defined($subject))
    {
        carp('add_mail(): no subject');
    }
    if(
        defined $self->_config->{email_to_override} &&
        (not $self->_config->{email_to_override} eq 'false') &&
        length $self->_config->{email_to_override})
    {
        if ($contentHtml)
        {
            $contentHtml = 'ORIGINAL TO: '.join(',',@{ $recipients })."<br />\n<br />\n".$contentHtml;
        }
        if ($contentText)
        {
            $contentText = 'ORIGINAL TO: '.join(',',@{ $recipients })."\n\n".$contentText;
        }
        $recipients = [ $self->_config->{email_to_override} ];
    }
    if($systemMail)
    {
        $footer //= $self->_i18n ?
            $self->_i18n->get('This message has been automatically generated by Lixuz')
            : 'This message has been automatically generated by Lixuz';
        if ($contentText)
        {
            $contentText .= "\n\n--\n".$footer."\n".$self->c->uri_for('/admin');
        }
        if ($contentHtml)
        {
            $contentHtml .= "<br />\n<br />\n--\n".$footer."<br />\n".'<a href="'.$self->c->uri_for('/admin').'">'.$self->c->uri_for('/admin').'</a>';
        }
    }
    my $result = {
            distinct_to  => $recipients,
            from         => $from,
            subject      => $subject,
            message_text => $contentText,
            message_html => $contentHtml,
    };
    if ($self->streaming)
    {
        return $self->_stream_out($result);
    }
    else
    {
        push(@{ $self->_mails },$result);
    }
}

method send ()
{
    if ($self->streaming)
    {
        $self->_stream_out({
                END => 1
            });
        return;
    }
    my $from = $self->_defaultFrom;

    my $result = {
        default_from => $from,
        emails => $self->_mails,
    };
    $self->_execute_mailer($result);
}

method _stream_out($data)
{
    my $socket = $self->_socket;
    if ( ! defined $socket)
    {
        $socket = '/tmp/.lixuz-streaming-mailer-socket-'.$$.'-'.int(rand(999999999)).'-'.time.'-'.$<.'-'.$>.'-'.int(rand(999));
        # Incredibly unlikely, but could still happen
        if (-e $socket)
        {
            return $self->_stream_out($data);
        }
        $self->_execute_mailer({
                socket => $socket
            });
        while(! -e $socket)
        {
            sleep(1);
        }
        my $connection = IO::Socket::UNIX->new(
            Peer    => $socket,
            Type    => SOCK_STREAM,
            Timeout => 3
        );
        $self->_socketConnection($connection);
        $self->_socket($socket);
    }
    my $output = $self->_socketConnection;
    print {$output} encode_json($data)."\r\n";
    return;
}

method _execute_mailer($data)
{
    $data->{api}            = 1;
    $data->{version}        = $self->_version;
    $data->{noFork}       //= 0;
    $data->{debug}        //= 0;
    $data->{default_from} //= $self->_defaultFrom;
    $data->{dupeProtection} = $self->dupeProtection;
    my $pid = open2(my $out, my $in, lixuzFSPathTo('/tools/lixuz-sendmail.pl')) or die("Failed to open2 to lixuz-sendmail-pl\n");
    print {$in} encode_json($data);
    close($in);
    close($out) if $out;
    waitpid($pid,0);
}

method _buildFrom(...)
{
    my $from_address = $self->_config->{from_email};
    if(not $from_address)
    {
        $self->c->log->error('from_email is not set in the config, using dummy e-mail');
        $from_address = 'EMAIL_NOT_SET_IN_CONFIG@localhost';
    }
    return $from_address;
}

method _i18n ()
{
    if ($self->c && $self->c->can('stash') && $self->c->stash && $self->c->stash->{i18n})
    {
        return $self->c->stash->{i18n};
    }
    return;
}

method _version
{
    return lixuzVersion($self->c);
}

method _config()
{
    if ($self->c && $self->c->can('config') && $self->c->config && $self->c->config->{LIXUZ})
    {
        return $self->c->config->{LIXUZ};
    }
    return {};
}

__PACKAGE__->meta->make_immutable;
