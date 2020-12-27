#!/usr/bin/env perl
use lib "$FindBin::Bin/lib";
use Mojolicious::Lite;
use Pioneer;
use Mojo::Util qw/dumper/;
use FindBin;


plugin 'CHI' => {
		 Pioneer => {
			     driver => 'Memory',
			     global => 1,
			     expires_in => 2
			    }
		};

app->types->type(vue => 'text/plain');

app->helper(cache => sub { state $cache = {

					  } });

app->helper(pioneer => sub {
		state $p = Pioneer->new;
	    });

get '/' => sub {
    my $c = shift;
    $c->render(template => 'app');
};

post '/command' => sub {
    my $c = shift;

    $c->log->info($c->req->json->{command});

    $c->render_later;

    my $cmd = 
	defined $c->req->json->{item} ? 
	sprintf '%05d%s', $c->req->json->{item}, $c->req->json->{command} :
	$c->req->json->{command};

    $c->pioneer->cmd_p($cmd)
	->then(sub {
		   $c->log->info(dumper \@_);
		   $c->render(json => $_[0] );
	       })
	->catch(sub {
		    $c->log->info( "error " . $_[0]);
		    $c->res->code(500);
		    $c->render(json => { error => shift() });
		});
};

post '/pick/:pick' => sub {
    my $c = shift;
    my $p = Pioneer->new;
    # $p->open('192.168.1.204');

    my $o = $p->pick($c->stash('pick'));
    $c->stash($o);
    $c->render(json => $o);
};

post '/moveto/:index' => sub {
    my $c = shift;
    my $p = Pioneer->new;
    # $p->open('192.168.1.204');

    my $o = $p->go_to_item($c->stash('index'));
    $c->stash($o);
    $c->render(json => $o);
};



get '/screen' => sub {
    my $c = shift;

    my $v = $c->chi('Pioneer')->get('screen');
    return $c->render(json => $v ) if $v;

    $c->render_later;

    $c->pioneer->get_screen_p
	->then(sub {
		   # $c->log->info( dumper $_[0]);
		   my $v = shift;
		   $c->chi('Pioneer')->set('screen', $v);
		   $c->render(json => $v );
	       })
	->catch(sub {
		    $c->log->info( "error " . $_[0]);
		    $c->res->code(500);
		    $c->render(json => { error => shift() });
		});
};

app->start;

__DATA__
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <script src="https://code.jquery.com/jquery-3.5.1.slim.js"
	    integrity="sha256-DrT5NfxfbHvMHux31Lkhxg42LY6of8TaYyK50jnxRnM=" crossorigin="anonymous"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/axios/0.20.0/axios.js"
	    integrity="sha512-nqIFZC8560+CqHgXKez61MI0f9XSTKLkm0zFVm/99Wt0jSTZ7yeeYwbzyl0SGn/s8Mulbdw+ScCG41hmO2+FKw=="
	    crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/vue@2/dist/vue.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/vue-router@3.4.8/dist/vue-router.min.js"></script>    
    <script src="https://cdn.jsdelivr.net/npm/http-vue-loader@1.4.1/src/httpVueLoader.js"></script>
    <title><%= title %></title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <style>
      body { background-color: #111122; color: #dddddd; font-family: courier; font-weight: bold; font-size: 14pt }
    </style>
  </head>
  <body>
    <%= content %>
  </body>
  <script src="/app.js"></script>
</html>
@@ app.html.ep
% layout 'default';
% title 'Welcome';
<div id="app">
  <router-view>
  </router-view>
</div>
