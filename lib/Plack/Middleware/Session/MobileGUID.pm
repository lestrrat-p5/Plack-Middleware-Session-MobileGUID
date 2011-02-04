package Plack::Middleware::Session::MobileGUID;
use strict;
use parent qw(Plack::Middleware::Session);

sub prepare_app {
    my $self = shift;
    $self->state( 'MobileGUID' ) unless $self->state;
    $self->SUPER::prepare_app();
}

sub call {
    my ($self, $env) = @_;

    my $id = $self->state->extract($env);
    my $session = $id ? $self->store->fetch($id) : ();
    # don't generate an ID automatically if $id wasn't there,
    # as we're interested in the user's Globally Unique ID.
    if ($id) {
        if ($session) {
            $env->{'psgix.session'} = $session;
        }
        $env->{'psgix.session.options'} = { id => $id };
    }

    my $res = $self->app->($env);
    $self->response_cb( $res, sub { $self->finalize( $env, $_[0] ) } );
}

sub finalize {
    my ($self, $env, $res) = @_;
    if ( ! $env->{'psgix.session'} ) {
        return;
    }
    $self->SUPER::finalize($env, $res);
}

1;

__END__

=head1 NAME

Plack::Middleware::Session::MobileGUID - Use Mobile Phone GUID As Session Key

=head1 SYNOPSIS

    use Plack::Builder;
    use Plack::Middleware::Session::MobileGUID;
    use Plack::Session::Store::File;

    my $app = sub { ... };
    builder {
        enable 'Session::MobileGUID',
            store => Plack::Session::Store::File->new( ... );
        $app;
    }

=head1 DESCRIPTION

Plack::Middleware::Session::MobileGUID extracts the GUID in from your device
and extracts session data from that key.

To fallback nicely you can do the following:

    builder {
        enable 'Session::MobileGUID';
        enable_if { ! $_[0]->{'psgix.session'} 'Session::RewriteLinks';
        enable_if { ! $_[0]->{'psgix.session'} 'Session';
    };

=cut

