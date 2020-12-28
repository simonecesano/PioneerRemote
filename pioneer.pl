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

any '/input/*input' => { input => undef } => sub {
    my $c = shift;

    $c->app->log->info('here');

    my $input = $c->stash('input') || $c->param('input') || eval { $c->req->json->{input} };

    $c->app->log->info($input);

    $c->render_later;

    my $fix = sub {
	my $res = shift;
	return join '', reverse unpack 'a2a2', $res;
    };

    $c->pioneer->cmd_p('?F')
	->then(sub {
		   $c->app->log->info(sprintf 'input %s response %s fixed response %s', $input, $_[0][0], $fix->($_[0][0]));
		   if ($input && $input ne $fix->($_[0][0])) {
    		       return $c->pioneer->cmd_p($input)
		   } else {
		       return Mojo::Promise->resolve($_[0]);
		   }
	       })
	->then(sub {
		   $c->render(json => $_[0] );
	       })
	->catch(sub {
		    $c->log->info( "error " . $_[0]);
		    $c->res->code(500);
		    $c->render(json => { error => shift() });
		});


};

post '/command' => sub {
    my $c = shift;
    $c->render_later;

    my $cmd = 
	defined $c->req->json->{item} ? 
	sprintf '%05d%s', $c->req->json->{item}, $c->req->json->{command} :
	$c->req->json->{command};

    $c->app->log->info($cmd);

    $c->pioneer->cmd_p($cmd)
	->then(sub {
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

    # return $c->render(json => [
    # 			"GBP08",
    # 			"GCP0100010\"\"",
    # 			"GDP000010000800015",
    # 			"GEP01102\"Antenne Bayern Live\"",
    # 			"GEP02002\"Radio Popolare 107.6 FM Live\"",
    # 			"GEP03002\"Radio 2 Rai Live\"",
    # 			"GEP04002\"Bayern 1 Live\"",
    # 			"GEP05002\"Bayern 2 Live\"",
    # 			"GEP06002\"Bayern 3 Live\"",
    # 			"GEP07002\"BR-Klassik Live\"",
    # 			"GEP08002\"Deutschlandradio Kultur Live\""
    # 		       ]);
    
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
