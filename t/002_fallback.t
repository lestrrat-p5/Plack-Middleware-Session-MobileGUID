use strict;
use Test::More;
use Plack::Test;
use Plack::Session::Store::File;
use Plack::Builder;
use HTTP::Request;
use Plack::Session::State::MobileGUID;

my $session_dir = "t/sessions";
if (! ok -d $session_dir || (mkdir($session_dir) && -d $session_dir), "create $session_dir" ) {
    diag "Failed to create dir $session_dir: $!";
}
while (glob("$session_dir/*")) {
    unlink $_;
}

test_psgi
    app => builder {
        enable 'Session::MobileGUID',
            state => Plack::Session::State::MobileGUID->new(
                check_ip => 0,
                cidr     => Net::CIDR::MobileJP->new( "t/cidr.yaml" ),
            ),
            store => Plack::Session::Store::File->new(
                dir => $session_dir
            )
        ;
        enable_if { ! $_[0]->{'psgix.session'} } 
            'Session::RewriteLinks', session_key => 'sid';
        enable_if { ! $_[0]->{'psgix.session'} } 'Session',
            state => Plack::Session::State->new( session_key => 'sid' ),
            store => Plack::Session::Store::File->new(
                dir => $session_dir
            )
        ;
        sub {
            my $env = shift;
            return [ 200, [ "Content-Type" => "text/html" ],
                [ qq{<a href="/foo">bar</a>} ]
            ];
        }
    },
    client => \&run_tests
;


sub run_tests {
    my $cb = shift;

    my $req = HTTP::Request->new(GET => "http://127.0.0.1");
    $req->push_header( 'User-Agent', 'DoCoMo/1.0/D504i/c10/TJ' );
    $req->push_header( 'X-DCMGUID', 'foobar');

    my $res = $cb->( $req );

    if (! ok $res->is_success) {
        diag $res->as_string;
    } else {
        like $res->content, 
            qr{<a href="/foo\?sid=[a-f0-9]+">bar</a>}, 
            "link is rewritten"
        ;
    }

    
}

done_testing;
