=head1 NAME

Linux::NBD::Client - client (device) side of a network blokc device

=head1 SYNOPSIS

 use Linux::NBD::Client;

=head1 DESCRIPTION

WARNING: I talked to the author of the nbd driver because nbd is so
extremely racy (right now, stopping it often causes oopses, a server
crashing also often oopses etc..).

It turned out that he doesn't care at all and nbd is basically
unmaintained, so YMMV when using this module, especially when writing
servers.

He really should have said that on his nbd pages ;[.

OTOH, it works relatively reliable when you don't stop the servers, so
watch out and keep your fingers crossed.

=head1 METHODS

=over 4

=cut

package Linux::NBD::Client;

$VERSION = 0.21;

use Linux::NBD ();

use Carp qw(croak);
use Errno ();

=item $client = new Linux::NBD::Client [socket => $fh][, device => "/dev/ndx"], ...

Create a new client.

Unless C<device> is given, an unused device node is looked up using the
C<device> method (this might result in an exception!).

The other arguments correspond to calls to methods of the same name.

=item $client->socket([$tcp_socket])

Returns the current socket after setting a new one (if an argument is
supplied). The socket I<MUST> be a tcp socket. Believe, bad things will
happen.

The special argument C<undef> will try to clear the socket, if any was
set.

=item $client->device([$new_device])

Returns the current device node (e.g. C</dev/nd2>) after setting a new one if
an argument is supplied.

If the argument is C<undef> it will search for an unallocated nbd-device
and use it.

=cut

sub new {
   my $class = shift;
   my $self = bless { @_ }, $class;

   $self->device (exists $self->{device} ? $self->{device} : undef);
   exists $self->{socket} and $self->socket($self->{socket});
   
   $self;
}

sub socket {
   my $self = shift;

   if (@_) {
      $self->{socket} = $_[0];

      if (defined $self->{socket}) {
         my $fileno = $_[0] =~ /[^0-9]/ ? fileno $_[0] : $_[0];
         _set_sock fileno $self->{device_fd}, $fileno;
      } else {
         _clear_sock fileno $self->{device_fd};
      }
   }

   $self->{socket};
}

sub device {
   my $self = shift;

   if (@_) {
      my $device = shift;

      if (defined $device) {
         open my $dev, "+<$device" or croak "$device: $!";
         $self->{device} = $device;
         $self->{device_fd} = $dev;
      } else {
        for (0..256) {
           $_ < 256 or croak "unable to find an available nbd device";

           my $path = "/dev/nd$_";
           -e $path or system "mknod", $path, "b", 43, $_;
           open my $dev, "+<$path" or croak "$device: $!";
           _set_sock fileno $dev, -1;
           if ($!{EINVAL}) {
              $self->{device} = $path;
              $self->{device_fd} = $dev;
              last;
           } elsif ($!{EBUSY}) {
              next;
           } else {
              croak "$path: $!";
           }
        }
      }
   }

   $self->{device};
}

=item $client->disconnect

Tries to exit the server by ending a special disconnect message.

=item $client->clear_queue

Clears the request queue, if possible. Should be used before setting a new
socket.

=item $client->set_blocksize($blksize)

Set the device blocksize in bytes (must be >512, <PAGESIZE and a power of
two).

=item $client->set_size($bytes)

Set the device size in bytes.

=item $client->set_blocks($nblocks)

Set the size in blocks.

=cut

sub disconnect {
   my $self = shift;

   _disconnect fileno $self->{device_fd};
}

sub clear_queue {
   my $self = shift;

   _clear_que fileno $self->{device_fd};
}

sub set_blocksize {
   my $self = shift;
              
   _set_blksize fileno $self->{device_fd}, $_[0];
}

sub set_size {
   my $self = shift;
              
   _set_size fileno $self->{device_fd}, $_[0];
}

sub set_blocks {
   my $self = shift;
              
   _set_size_blocks fileno $self->{device_fd}, $_[0];
}

=item $client->run

Enters the service loop (waits for read/write requests on the device and
forwards them over the given socket). Only returns when somebody calls C<disconnect>
or the server is killed.

=item $pid = $client->run_async

Runs the service loop asynchronously and returns the pid of the newly
created service process.

=item $client->kill_async

Kills any running async service. Please note that this also kills the
socket, so you need to re-set the socket after this call.

=cut

sub run {
   my $self = shift;
   _doit fileno $self->{device_fd};
}

sub run_async {
   my $self = shift;

   $self->{pid} = fork;
   defined $self->{pid} or croak "fork: $!";

   $self->{pid} or _doit fileno $self->{device_fd}, 1;

   $self->{pid};
}

sub kill_async {
   my $self = shift;

   if (my $pid = delete $self->{pid}) {
      #_clear_que fileno $self->{device_fd};
      #_disconnect fileno $self->{device_fd};
      #_clear_sock fileno $self->{device_fd};
      # just kill -9 it, seems to be safest (all other ways just oops sooner or later)
      kill 9, $pid;
   }
}

sub DESTROY {
   my $self = shift;

   $self->kill_async;
}

=cut

1;

=back

=head1 AUTHOR

 Marc Lehmann <pcg@goof.com>
 http://www.goof.com/pcg/marc/

=cut

