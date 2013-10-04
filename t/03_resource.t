use strict;
use warnings;
use Dancer2::Core::Request;
use Test::More import => ['!pass'];
use JSON;


# Dancer2::Test had a bug in version previous 1.3059_01 that prevent this test
# from running correctly.
my $dancer_version = eval "\$Dancer2::VERSION";
$dancer_version =~ s/_//g;
plan skip_all => "Dancer2 0.04 is needed for this test (you have $dancer_version)"
  if $dancer_version < 0.04;

# wrapper to keep all Dancer2s happy
sub request {
    my %arg = @_;

    $arg{body} = encode_json($arg{body})
        if ref $arg{body};

    return Dancer2::Core::Request->new(
        %arg,
        content_type => 'application/json',
    );

}

plan tests => 8;

{
    package Webservice;
    use Dancer2;
    use Dancer2::Plugin::REST;
    use Test::More import => ['!pass'];

    set show_errors => 1;
    set serializer => 'JSON';
    set logger => 'console';

    resource user => 
        'get' => \&on_get_user,
        'create' => \&on_create_user,
        'delete' => \&on_delete_user,
        'update' => \&on_update_user;

    my $users = {};
    my $last_id = 0;

    sub on_get_user {
        my $id = params->{'id'};
        { user => $users->{$id} };
    }

    sub on_create_user {
        my $ctx = shift;

        my $id = ++$last_id;
        my $user = JSON::decode_json($ctx->request->body());
        $user->{id} = $id;
        $users->{$id} = $user;

        { user => $users->{$id} };
    }

    sub on_delete_user {
        my $ctx = shift;

        my $id = $ctx->request->params->{'id'};
        my $deleted = $users->{$id};
        delete $users->{$id};
        { user => $deleted };
    }

    sub on_update_user {
        my $ctx = shift;

        my $id = $ctx->request->params->{'id'};
        my $user = $users->{$id};
        return { user => undef } unless defined $user;

        my $user_changed = JSON::decode_json($ctx->request->body());
        $users->{$id} = { %$user, %$user_changed };
        { user => $users->{$id} };
    }

    eval { resource 'failure'; };
    like $@, qr{resource should be given with triggers}, 
        "resource must have at least one action";
}

use Dancer2::Test apps => [ 'Webservice' ];

my $r = dancer_response(GET => '/user/1');
is_deeply decode_json($r->content), {user => undef},
    "user 1 is not defined";

$r = dancer_response( request(
        method => 'POST',
        path => '/user',
        body => { name => 'Alexis' },
));

is_deeply decode_json($r->content), { user => { id => 1, name => "Alexis" } },
    "create user works";

$r = dancer_response(GET => '/user/1');
is_deeply decode_json($r->content), {user => { id => 1, name => 'Alexis'}},
    "user 1 is defined";

$r = dancer_response( request(
        method => 'PUT',
        path => '/user/1',
        body => { name => 'Alexis Sukrieh', nick => 'sukria' },
));

is_deeply decode_json($r->content), {user => { id => 1, name => 'Alexis Sukrieh', nick => 'sukria'}},
    "user 1 is updated";

$r = dancer_response(DELETE => '/user/1');
is_deeply decode_json($r->content), {user => { id => 1, name => 'Alexis Sukrieh', nick => 'sukria'}},
    "user 1 is deleted";

$r = dancer_response(GET => '/user/1');
is_deeply decode_json($r->content), {user => undef},
    "user 1 is not defined";

$r = dancer_response( request(
        method => 'POST',
        path => '/user',
        body => { name => 'Franck Cuny' },
));

is_deeply decode_json($r->content), { user => { id => 2, name => "Franck Cuny" } },
    "id is correctly increased";

