use inc::Module::Install;

name 'Plack-Middleware-Session-MobileGUID';
all_from 'lib/Plack/Middleware/Session/MobileGUID.pm';

requires 'Plack::Middleware::Session';
requires 'HTTP::MobileAgent';
requires 'Net::CIDR::MobileJP';

test_requires 'HTTP::Request';

WriteAll;