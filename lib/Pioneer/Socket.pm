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

my $queue = Mojo::Collection->new;
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

    $app = $ret->app;

    $ret->io($io);

    return $ret;
};

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
    return 1 if  $_ =~ /^R\s*/;

    if ($_ =~ /^FN\d\d\s*/) { return 1 }

    $_ = [ split /\r\n/, $_ ]->[-1];

    /GEP(\d\d)/;

    my $d = 0 + $1;
    # print $l, $1, $d, $c;
    print STDERR dumper [ $i, $_ , $c, $d >= $c ];
    $d >= $c;
}

sub cmd {
    my $self = shift;
    my $cmd  = shift || '';

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
    return [ map { decode('UTF-8', decode('UTF-8', $_) ); } @lines ];
}

sub log {
    my $self = shift;
    if ($self->app) {
	$self->app->log->info(@_)
    } else {
	print @_ . "\n";
    }
}



sub enqueue {
    my $self = shift;
    my $cmd  = shift;

    print STDERR "in enqueue $cmd";

    # return $val;
    my $p = Mojo::Promise->new;
    my $t = localtime;

    push @{$queue}, [ $self, $p, $cmd, $t ];

    print $queue->size;

    return $p;
}

sub cmd_p {
    my $self = shift;
    my $cmd = shift;
    my $prio = shift;
    print STDERR "in cmd_p $cmd";
    return $self->enqueue($cmd, $prio)
}

sub get_screen_p {
    my $self = shift;
    return $self->cmd_p('?GAP')
}


# sub start {
#     print Mojo::IOLoop->is_running;

my $free = 1;
my $frequency = 1.5;

Mojo::IOLoop->recurring(1 =>
			sub {
			    # print 'here', $free, $queue->size;
			    if ($free && @{$queue}) {
				my ($io, $p, $cmd, $e) = @{shift @{$queue}};
				$free = 0;
				my $res = $io->cmd($cmd);
				$io->cmd();
				$p->resolve($res);
				# print STDERR dumper [ $cmd, $res ];
				sleep 0.3;
				$free = 1;
			    } else {
				if (@{$queue}) {
				}
			    }
			});
#     Mojo::IOLoop->singleton->start unless Mojo::IOLoop->singleton->is_running;
# }

# Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
1;
