package Pioneer::Socket;

use IO::Socket::IP;
use Mojo::Util qw/dumper/;

use Mojo::Base -base;

use Mojo::Collection;
use Mojo::IOLoop;
use Mojo::Promise;
use Time::Piece;
use Try::Tiny;
use Time::HiRes;
use Encode qw/encode decode/;

use Class::Method::Modifiers;

has 'host';

has 'port';

has 'io';

has 'timeout' => 3;

has 'frequency' => 1;

has 'app';

my $frequency = 1.5;
my $app;

around 'new' => sub {
    my $orig = shift;

    my $ret = $orig->(@_);

    my $io = IO::Socket::IP->new(
				 PeerHost => $ret->host,
				 PeerPort => $ret->port,
				 Type     => SOCK_STREAM,
				) or die "Cannot construct socket - $@";

    # $io->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', $ret->timeout, 0));

    # $app = $ret->app;

    $ret->io($io);

    return $ret;
};


my $queue = Mojo::Collection->new;
my $free = 1;
Mojo::IOLoop->recurring(1 =>
			sub {
			    # print 'here', $free, $queue->size;
			    if ($free && @{$queue}) {
				my ($io, $p, $cmd, $e) = @{shift @{$queue}};
				$free = 0;
				my $res = 
				    ('CODE' eq ref $cmd) ?
				    $cmd->() :
				    $io->cmd($cmd);
				$io->cmd();
				$p->resolve($res);
				$free = 1;
			    } else {
				# print STDERR time;
				if (@{$queue}) {
				}
			    }
			});


sub send { shift->io->send(@_) }

sub recv { shift->io->recv(@_) }

sub read {
    my $self = shift;
    my $length = shift || (15 * 1024);

    my $flags = shift;

    my $buffer;
    $self->recv($buffer, $length);
    return $buffer;
}


sub stream_done {
    my @lines = @_;
    # print STDERR dumper \@lines;

    return 1 if  $lines[0] =~ /^$/;

    return 1 if  $lines[0] =~ /^R\s*/;

    return 1 if ($lines[0] =~ /^FN\d\d\s*/);

    my ($c) = grep { /GBP(\d+)/ } @lines;
    ($c) = ($c =~ /GBP(\d+)/);
    # print STDERR "expecting $c lines\n";
    my $a = scalar grep { /^GEP/ } @lines;
    # print STDERR "now at $a lines\n";
    # print $c, $a, ((0 + $c) == $a);
    return ($a >= (0 + $c))
}


sub done {
    my $i = shift;
    my $c = shift;

    local $_ = $i;

    return 1 if  $_ =~ /^$/;
    return 1 if  $_ =~ /^R/;

    if ($_ =~ /^FN\d\d\s*/) { return 1 }

    $_ = [ split /\r\n/, $_ ]->[-1];

    /GEP(\d\d)/;

    my $d = 0 + $1;
    # print $l, $1, $d, $c;
    # print STDERR dumper [ $i, $_ , $c, $d >= $c ];
    $d >= $c;
}

sub cmd {
    my $self = shift;
    my $cmd  = shift || '';
    my $override = shift;

    return [] unless $override || $self->allowed($cmd);

    my $sent = $self->send("$cmd\n");

    my @lines;

    my $bytes = $self->read();

    $bytes =~ s/\r\n$//;
    push @lines, split /\r\n/, $bytes;

    while (!stream_done(@lines)) {
	my $bytes = $self->read();

	$bytes =~ s/\r\n$//;
	push @lines, split /\r\n/, $bytes;
    }
    # $self->send("\n");
    # print STDERR 'check', $self->read();
    # $self->io;
    if (($lines[0] eq 'R') && ((scalar @lines) > 1)) { shift @lines }

    return [ map { decode('UTF-8', decode('UTF-8', $_) ); } @lines ];
}

sub log {
    my $self = shift;
    if ($self->app) {
	$self->app->log->info(@_)
    } else {
	print @_
    }
}

sub enqueue {
    my $self = shift;
    my $cmd  = shift;

    # return $val;
    my $p = Mojo::Promise->new;
    my $t = localtime;

    push @{$queue}, [ $self, $p, $cmd, $t ];

    # print $queue->size;

    return $p;
}

sub cmd_p {
    my $self = shift;
    my $cmd = shift;
    my $prio = shift;
    return $self->enqueue($cmd, $prio)
}

sub get_screen_p {
    my $self = shift;
    my $p = Mojo::Promise->new;
    Mojo::Promise->all(
		       $self->cmd_p('?F'),
		       $self->cmd_p('?GAP')
		      )
	  ->then(sub {
		     my ($source, $screen) = @_;
		     $source = $source->[0][0];

		     if ($source eq 'FN19' && $screen->[0][-1] =~ /GEP07023/) {
			 $p->resolve($screen->[0]);
		     } elsif ($source eq 'FN19' && $screen->[0][-1] !~ /GEP07023/) {
			 $p->resolve([ 'GBP00' ] );
		     } elsif ($source eq 'FN10') {
			 $p->resolve([ 'GBP00' ] );
		     } else {
			 $p->resolve($screen->[0]);
		     }
		 });
	  return $p;
}

sub _fix_source {
    my $res = shift;
    return join '', reverse unpack 'a2a2', $res;
};

sub source {
    my $self = shift;
    my $source = shift;

    my $current_source = $self->cmd('?F');

    return $current_source unless $source;

    if ($current_source->[0] ne _fix_source($source)) {
	return $self->cmd($source);
    } else {
	return $current_source;
    }
}

sub source_p {
    my $self = shift;
    my $source = shift;

    return $self->enqueue(sub {
			      $self->source($source)
			  });
}

# ----------------------------------------------------------------------------------
# allowed checks here
# ----------------------------------------------------------------------------------

my $checks = {
	      'generic' => sub {
		  my $self = shift;
		  my $cmd  = shift;
		  # do something
		  # check result
		  # allow or reject
		  return 1;
	      },
	      '10FN' => sub {
		  my $self = shift;
		  my $cmd  = shift;
		  # do something
		  my $r = $self->cmd('?F');
		  return $r->[0] ne 'FN10' && $r->[0] ne 'FN19';
		  # check result
		  # allow or reject
	      },
	      '13FN' => sub {
		  my $self = shift;
		  my $cmd  = shift;
		  print 'here';

		  my $r = $self->cmd('?F');
		  return $r->[0] ne 'FN13';
	      },
	      '31PB' => sub {
		  my $self = shift;
		  my $cmd  = shift;

		  my $r = $self->cmd('?GAP');
		  return grep { /GCP0\d{5,5}10/ } @$r;
	      },
	      # play
	      '10PB' => sub { return shift->cmd('?F')->[0] eq 'FN19' },
	      # pause
	      '11PB' => sub { return shift->cmd('?F')->[0] eq 'FN19' },
	      # skip reverse
	      '12PB' => sub { return shift->cmd('?F')->[0] eq 'FN19' },
	      # skip forward
	      '13PB' => sub { return shift->cmd('?F')->[0] eq 'FN19' },
	      # stop
	      '20PB' => sub { return shift->cmd('?F')->[0] eq 'FN19' },
};

# Skip Reverse Key	12PB
# Stop Key	20PB
# Skip Forward Key	13PB
# Pause Key	11PB
# Play Key	10PB

sub allowed {
    my $self = shift;
    my $cmd = shift;

    return 1 unless $cmd;

    return 1 unless $checks->{$cmd};

    return $checks->{$cmd}->($self, $cmd);
}

1;
