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

package LIXUZ::Controller::Admin::Forget;
use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
use Digest::MD5 'md5_base64';
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
use LIXUZ::HelperModules::EMail qw(send_raw_email_to);

# Summary: Forget handler, creates the form and other goodies
sub forget : Path('/admin/forget') Form('/forget')
{
    my ( $self, $c, @args ) = @_;
    my $msg_type = $args[0] || 'no';
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Forget');
    my $i18n = $c->stash->{i18n};
    my $form = $self->formbuilder;
    if ($msg_type eq 1)
    {
        $c->stash->{message} = $i18n->get('An e-mail with a link where you may change your password has been sent. Please check your e-mail.');
    }
    elsif($msg_type eq 2)
    {
	    $c->stash->{message} = $i18n->get('Error: Failed to locate a user with the this email address.');
    }
    elsif($msg_type eq 3)
    {
	    $c->stash->{message} = $i18n->get('Please enter a vaild e-mail address.');
    }
    $c->stash->{template} = 'adm/core/forget.html';
}    
    
sub pstpwd : Path('/admin/pstpwd')
{
    my ( $self, $c ) = @_;
    my $i18n = $c->stash->{i18n};
    my $msg_typ = "no";
    my $form = $self->formbuilder;
    my $post_email = $c->req->param('user_email');
    if(defined($post_email) && length($post_email))
    {
    	my $user_email = $c->model('LIXUZDB::LzUser')->find({email => $c->req->param('user_email')});
	    if (not $user_email)
	    {
	        $msg_typ = 2;
	    }
	    else
	    {
	        my $db_user_name = $user_email->get_column('user_name');
    	    my $db_user_id = $user_email->get_column('user_id');
            my $db_email = $user_email->get_column('email');            
            my $unique_code = md5_base64($db_user_id.'-'.time.'-'.rand(9999999));
            $unique_code =~ s/\//L/g;
    	    while($c->model('LIXUZDB::LzUser')->find({reset_code => $unique_code}))
	        {
		        $unique_code = md5_base64($db_user_id.'-'.time.'-'.rand(9999999));
                $unique_code =~ s/\//L/g;
    	    }    
    	    my $link = $c->uri_for('/admin/forget/change_password/'.$unique_code);	    
            my $subject = $i18n->get_advanced('Forgotten password');
            my $message = $i18n->get_advanced("Dear %(USERNAME),\n\n Please click on following link to change your Lixuz password.\n %(LINK)\n\n--\n Lixuz",{ USERNAME => $db_user_name, LINK => $link});
    	    my $to =$db_email;
    	    my $from = $c->config->{LIXUZ}->{from_email};
    	    my $type = "TEXT";
    	    send_raw_email_to($c,$subject,$message,$to,$from,$type); 
    	    $user_email->set_column('reset_code',$unique_code);
    	    $user_email->update();
    	    $msg_typ = 1;
        }
    }
    else
    {
	    $msg_typ = 3;
    } 
    $c->forward(qw(LIXUZ::Controller::Admin::Forget forget) , [ $msg_typ ]);
}
    
# For change password form
sub change_password : Local Form('change_password')
{	  
    my ( $self, $c, @args ) = @_;
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Change Password');
    my $i18n = $c->stash->{i18n};
    my $form = $self->formbuilder;    
    my $get_reset_code = $args[0] || 'no'; 
    my $msg_type = $args[1] || 'no';
    $c->stash->{reset_code} = $get_reset_code;
    my $obj_reset_code = $c->model('LIXUZDB::LzUser')->find({reset_code => $get_reset_code});
    
    if(not $obj_reset_code)
    {
        $c->stash->{message} = $i18n->get('The password token was invalid.');
    }
    if($msg_type eq 1)
    {
	    $c->stash->{message} = $i18n->get('You need to enter a password.');
    }
    elsif( $msg_type eq 2)
    {
	    $c->stash->{message} = $i18n->get('Your password has been changed. You may now log in with your new password');
    }
    elsif( $msg_type eq 3)
    {
        $c->stash->{message} = $i18n->get('The new passwords do not match');
    }
    $c->stash->{template} = 'adm/core/change_password.html';   
}

sub chngpwd :  Path('/admin/chngpwd')
{
    my ( $self, $c ) = @_;
    my $i18n = $c->stash->{i18n};
    my $form = $self->formbuilder;
    my $pst_new_password = $c->req->param('password');
    my $pst_conf_password = $c->req->param('confpassword');
    my $pst_reset_code = $c->req->param('reset_code');
    my $msg_type = 'no';
    if((defined($pst_new_password) && length($pst_new_password)) && (defined($pst_conf_password) && length($pst_conf_password)))
    {	
    	if ($pst_new_password eq $pst_conf_password)
        {
            my $obj_rest_code = $c->model('LIXUZDB::LzUser')->find({reset_code => $pst_reset_code});
            if (not $obj_rest_code)
            {
                $msg_type = 'no';
            }
            else
            {
		        my $db_reset_code = $obj_rest_code->get_column('reset_code');	    
        		$obj_rest_code->set_password($pst_new_password);
		        $obj_rest_code->set_column('reset_code',undef);
        		$obj_rest_code->update();
		        $msg_type = 2;
            }
        }
        else
        {
           $msg_type = 3;
        }
    }
    else
    {
        $msg_type = 1;
    }
    $c->forward(qw(LIXUZ::Controller::Admin::Forget change_password) , [ $pst_reset_code,$msg_type ]);
}

1;
