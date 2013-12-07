use strict;
use warnings;

use Test::TCP;
use LWP::UserAgent;

use Test::More tests => 2;
use Dancer2;
use Dancer2::Plugin::REST;

test_tcp(
    server => sub {
        my $port = shift;

        prepare_serializer_for_format;

        get '/:something.:format' => sub {
            { hello => 'world' };
        };
        Dancer2->runner->server->port($port);
        start;
    },
    client => sub {
        my $port = shift;
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get( "http://localhost:$port/foo.json" );
        is $res->code => 200, "success";
        is $res->content => '{"hello":"world"}', "content";
    },
);


