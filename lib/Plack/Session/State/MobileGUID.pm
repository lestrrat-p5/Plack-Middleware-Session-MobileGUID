package Plack::Session::State::MobileGUID;
use strict;
use parent qw(Plack::Session::State);
use Plack::Request;
use HTTP::MobileAgent;
use Net::CIDR::MobileJP;
use Plack::Util::Accessor qw(
    check_ip
    cidr
);

use constant TRACE => 
    exists $ENV{ PLACK_SESSION_STATE_MOBILEAGENT_TRACE } ?
        $ENV{ PLACK_SESSION_STATE_MOBILEAGENT_TRACE } :
        1;
;

sub new {
    my ($class, %args) = @_;

    $args{check_ip} = 1 unless exists $args{check_ip};
    $args{cidr}     = Net::CIDR::MobileJP->new() unless exists $args{cidr};
    my $self = $class->SUPER::new( %args );
    return $self;
}

sub validate_session_id { 1 }
sub get_session_id {
    my ($self, $env) = @_;

    my $hdrs = HTTP::Headers->new(
        map {
            (my $field = $_) =~ s/^HTTPS?_//;
            ( $field => $env->{$_} );
        }
        grep { /^(?:HTTP|CONTENT|COOKIE)/i } keys %$env
    );
    my $agent = HTTP::MobileAgent->new( $hdrs );

    if ( ! $agent->is_docomo && ! $agent->is_softbank && ! $agent->is_ezweb ) {
        if ( TRACE ) {
            warn "Agent $env->{HTTP_USER_AGENT} is not supported";
        }
        return;
    }

    my $id = $agent->user_id();
    if ( ! $id ) {
        if ( TRACE ) {
            my $ip = $env->{REMOTE_ADDR} || 'UNKNOWN';
            warn "Failed to detect mobile id from ( '" . $agent->user_agent . "', '$ip' )";
            return;
        }
    }

    if ( $self->check_ip() ) {
        my $ip = $env->{REMOTE_ADDR};
        if (! $ip) {
            if ( TRACE ) {
                warn "Could not obtain client's remote address";
            }
            return;
        }

        my $carrier = $self->cidr->get_carrier($ip) || '';
        if ( $carrier ne $agent->carrier ) {
            if ( TRACE ) {
                warn "IP address $ip does not match claimed carrier '" . $agent->carrier . "' (expecting $carrier)";
            }
            return;
        }
    }

    # Cache because you're bound to use it in your app
    $env->{'psgix.session.mobile_agent'} = $agent;
    return $id;
}

1;