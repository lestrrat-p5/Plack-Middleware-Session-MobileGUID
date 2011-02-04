package Plack::Middleware::Session::RewriteLinks;
use strict;
use parent qw(Plack::Middleware);
use HTML::Parser;
use HTML::Tagset;
use Plack::Util::Accessor qw(
    session_key
    parser
);

sub prepare_app {
    my $self = shift;

    $self->session_key( 'plack_session' ) unless $self->session_key;

    my $start_h = sub {
        my ($self, $tag, $attr, $attrseq, $text) = @_;

        my $links = $HTML::Tagset::linkElements{$tag} || [];
        $links = [$links] unless ref $links;
        foreach my $a ( @$links ) {
            next unless exists $attr->{$a};
            my $link = $attr->{$a};
            my $uri  = URI->new($link);

            my $q = $uri->query_form;
            $uri->query_form( %$q, $self->{session_key}, $self->{env}->{'psgix.session.options'}->{id} );
            $attr->{$a} = $uri;
        }

        $self->{parsed} .= "<$tag";
        foreach my $a ( @$attrseq ) {
            next if $a eq '/';
            $self->{parsed} .= sprintf( qq( %s="%s"), $a, $attr->{$a} );
        }
        $self->{parsed} .= ' /' if $attr->{'/'};
        $self->{parsed} .= '>';
    };
    my $default_h = sub {
        my ($self, $tagname, $attr, $text) = @_;
        $self->{parsed} .= $text;
    };
    my $parser = HTML::Parser->new(
        api_version => 3,
        start_h => [ $start_h, "self,tagname,attr,attrseq,text" ],
        default_h => [ $default_h, "self,tagname,attr,text" ]
    );
    $self->parser($parser);
}

sub call {
    my ($self, $env ) = @_;
    my $res = $self->app->( $env );
    $res = $self->response_cb($res, sub { $_[0] } );

    if (! $env->{'psgix.session'}) {
        return $res;
    }

    my $body = $res->[2];
    my $parser = $self->parser;
    local $parser->{parsed};
    local $parser->{env} = $env;
    local $parser->{session_key} = $self->session_key;
    if ( Scalar::Util::blessed $body ) {
        while ( my $ln = $body->getline ) {
            $parser->parse($ln);
        }
        $parser->eof;
    } else {
        $parser->parse( $_ ) for @$body;
        $parser->eof;
    }
    $res->[2] = [ $parser->{parsed} ];

    return $res;
}

1;