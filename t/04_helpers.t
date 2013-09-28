use strict;
use warnings;
use JSON;
use Test::More import => ['!pass'];

plan tests => 16;

{

    package Webservice;
    use Dancer2;
    use Dancer2::Plugin::REST;

    set serializer => 'JSON';

    resource user => 'get' => \&on_get_user,
      'create'    => \&on_create_user,
      'delete'    => \&on_delete_user,
      'update'    => \&on_update_user;

    my $users   = {};
    my $last_id = 0;

    sub on_get_user {
        my $ctx = shift;

        my $id = $ctx->request->params->{'id'};
        return status_bad_request('id is missing') if !defined $users->{$id};
        status_ok( { user => $users->{$id} } );
    }

    sub on_create_user {
        my $ctx = shift;

        my $id = ++$last_id;
        my $user = JSON::decode_json($ctx->request->body());
        $user->{id} = $id;
        $users->{$id} = $user;

        status_created( { user => $users->{$id} } );
    }

    sub on_delete_user {
        my $ctx = shift;

        my $id = $ctx->request->params->{'id'};
        my $deleted = $users->{$id};
        delete $users->{$id};
        status_accepted( { user => $deleted } );
    }

    sub on_update_user {
        my $ctx = shift;

        my $id = $ctx->request->params->{'id'};
        my $user = $users->{$id};
        return status_not_found("user undef") unless defined $user;

        my $user_changed = JSON::decode_json($ctx->request->body());
        $users->{$id} = { %$user, %$user_changed };
        status_accepted { user => $users->{$id} };
    }

}

use JSON;

use Dancer2::Test apps => [ 'Webservice' ];

my $r = dancer_response( GET => '/user/1', { content_type => 'application/json' } );
is $r->status, 400, 'HTTP code is 400';
is_deeply decode_json($r->content) => { error => "id is missing" }, 'Valid content';

$r = dancer_response( POST => '/user', { body => encode_json( { name =>
                'Alexis' } ),
        content_type => 'application/json' } );
is $r->{status}, 201, 'HTTP code is 201';
is_deeply decode_json( $r->content ), { user => { id => 1, name => "Alexis" } },
  "create user works";

$r = dancer_response( GET => '/user/1' );
is $r->status, 200, 'HTTP code is 200';
is_deeply decode_json($r->content), { user => { id => 1, name => 'Alexis' } },
  "user 1 is defined";

$r = dancer_response(
    PUT => '/user/1',
    {   body => encode_json( {
            nick => 'sukria',
            name => 'Alexis Sukrieh'
        } ),
        content_type => 'application/json',
    }
);
is $r->{status}, 202, 'HTTP code is 202';
is_deeply decode_json($r->content),
  { user => { id => 1, name => 'Alexis Sukrieh', nick => 'sukria' } },
  "user 1 is updated";

$r = dancer_response(
    PUT => '/user/23',
    {   body => encode_json( {
            nick => 'john doe',
            name => 'John Doe'
        } ),
        content_type => 'application/json',
    }
);
is $r->status, 404, 'HTTP code is 404';
is_deeply decode_json($r->content)->{error}, 'user undef', 'valid content';

$r = dancer_response( DELETE => '/user/1' );
is_deeply decode_json($r->content),
  { user => { id => 1, name => 'Alexis Sukrieh', nick => 'sukria' } },
  "user 1 is deleted";
is $r->status, 202, 'HTTP code is 202';


$r = dancer_response( GET => '/user/1' );
is $r->status, 400, 'HTTP code is 400';
is_deeply decode_json($r->content)->{error}, 'id is missing', 'valid response';

$r = dancer_response( POST => '/user', { 
    body => encode_json( { name => 'Franck Cuny' } ),
    content_type => 'application/json',
});

is_deeply decode_json($r->content), { user => { id => 2, name => "Franck Cuny" } },
  "id is correctly increased";
is $r->status, 201, 'HTTP code is 201';

