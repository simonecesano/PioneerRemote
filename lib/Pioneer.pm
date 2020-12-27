package Pioneer;

use Encode qw/encode decode/;
use Mojo::Base -base;

use Mojo::IOLoop;
use Mojo::Promise;
use Mojo::Util qw/dumper/;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use strict;

use Fcntl qw(:flock);
use Time::HiRes;

# $\ = "\n"; $, = "\t"; $|++;

has lockfile => '.pioneer.lock';

sub stream_done {
    my @s = @_;
    print dumper \@s;

    return 1 if  $s[0] =~ /^R\s*/;
    return 1 if  $s[0] =~ /^FN\d\d\s*/;

    my ($c) = grep { /GBP(\d+)/ } @s;
    ($c) = ($c =~ /GBP(\d+)/);
    my $a = scalar grep { /^GEP/ } @s;
    # print $c, $a, ((0 + $c) == $a);
    return ((0 + $c) == $a)
}

sub get_lock {
    my $self = shift;
    my ($qfn) = $self->lockfile;
    open(my $fh, '+>:raw', $qfn) or do {
	# print STDERR 'could not obtain lock';
	return undef
    };
    # print STDERR 'here';
    if (!flock($fh, LOCK_EX | LOCK_NB)) {
	# print STDERR 'tried to lock';
	return undef if $!{EWOULDBLOCK};
    }
    return $fh;
}

my $lock;

sub enqueue {
    my $self = shift;
    my ($cmd, $promise) = @_;

    $|++;

    # $lock = $self->get_lock;

    # print STDERR $lock;

    # while (!$lock) {
    # 	# print STDERR 'sleeping';
    # 	sleep(1.25);
    # 	$lock = $self->get_lock;
    # }

    my (@r);

    my $id = Mojo::IOLoop->client({ address => '192.168.1.204', port => 23, timeout => 13 }
              => sub ($loop, $err, $stream) {
                  return $promise->reject('could not open stream') unless $stream;

                  $stream->on(error => sub ($stream, $err) {
                                  # flock(DATA, LOCK_UN);
				  $stream->stop;
                                  $stream->close_gracefully;
                                  $promise->reject($err);
                              });

                  $stream->on(read => sub ($stream, $bytes) {
                                  $bytes =~ s/\r\n$//;
                                  push @r, split /\r\n/, $bytes;
                                  # stream done is a function that checks that 
                                  # the appropriate number of lines got sent back
                                  if (stream_done(@r)) {
                                      # flock(DATA, LOCK_UN);
                                      $promise->resolve(\@r);
				      $stream->stop;
                                      $stream->close_gracefully;
                                  };
                              });

                  $stream->on(timeout => sub ($stream) {
                                  # flock(DATA, LOCK_UN);
				  $stream->stop;
                                  $stream->close_gracefully;
                                  $promise->reject('timeout') if ($err);
                              });
                  $stream->write($cmd . "\n");
              });
}

sub cmd_p {
    my $self = shift;
    my $cmd = shift;

    my $promise = Mojo::Promise->new;

    $self->enqueue($cmd, $promise);

    return $promise;
}

sub get_screen_p {
    my $self = shift;

    $self->cmd_p('?GAP')
	->then(sub {
		   return Mojo::Promise->resolve(@_)
	       })
}


1;

__DATA__
