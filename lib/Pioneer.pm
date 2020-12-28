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



sub stream_done {
    my @s = @_;
    print STDERR dumper \@s;

    return 1 if  $s[0] =~ /^R\s*/;

    if ($s[0] =~ /^FN\d\d\s*/) {
	# print STDERR 'is a command response';
	return 1
    }

    my ($c) = grep { /GBP(\d+)/ } @s;
    ($c) = ($c =~ /GBP(\d+)/);
    # print STDERR "expecting $c lines\n";
    my $a = scalar grep { /^GEP/ } @s;
    # print STDERR "now at $a lines\n";
    # print $c, $a, ((0 + $c) == $a);
    return ($a >= (0 + $c))
}


my $free = 1;
my $queue = [];

sub enqueue {
    my $self = shift;
    my $val  = shift;
    my $p = Mojo::Promise->new;
    my $t = localtime;

    # print STDERR "IN QUEUE\n";
    # print STDERR "$val\n";

    push @{$queue}, [ $p, $val, $t ];

    # print STDERR dumper $queue;

    return $p;
}


sub execute {
    my $self = shift;
    my ($cmd, $promise) = @_;

    my (@r);

    $free = 0;

    my $id = Mojo::IOLoop->client({ address => '192.168.1.204', port => 23, timeout => 13 }
              => sub ($loop, $err, $stream) {
                  return $promise->reject('could not open stream') unless $stream;

                  $stream->on(error => sub ($stream, $err) {
				  $stream->stop;
                                  $stream->close_gracefully;
				  $free = 1;
                                  $promise->reject($err);
                              });

                  $stream->on(read => sub ($stream, $bytes) {
				  # print STDERR $bytes;

                                  $bytes =~ s/\r\n$//;
                                  push @r, split /\r\n/, $bytes;
				  # print STDERR dumper \@r;
                                  # stream done is a function that checks that 
                                  # the appropriate number of lines got sent back

                                  if (stream_done(@r)) {
				      # print STDERR "--------------------- DONE --------------------------\n";
                                      $promise->resolve(\@r);
				      $free = 1;

				      $stream->stop;
                                      $stream->close_gracefully;
                                  };
                              });

                  $stream->on(timeout => sub ($stream) {
				  $stream->stop;
                                  $stream->close_gracefully;
				  $free = 1;

                                  $promise->reject('timeout') if ($err);
                              });

		  # print STDERR "sending $cmd\n";
                  $stream->write($cmd . "\n");
              });
}

sub cmd_p {
    my $self = shift;
    my $cmd = shift;

    # print STDERR "in cmd_p $cmd\n";
    
    return $self->enqueue($cmd)
}

sub get_screen_p {
    my $self = shift;

    return $self->cmd_p('?GAP')
}


Mojo::IOLoop->recurring(1 => sub {
			    # # print STDERR dumper $queue;
			    if ($free && @{$queue}) {
				my ($p, $val, $e) = @{shift @{$queue}};
				Pioneer->execute($val, $p);
			    } else {
				if (@{$queue}) {
				    # print STDERR "not free\n";
				    # $app->log->info('not free')
				}
			    }
			});


1;

__DATA__
