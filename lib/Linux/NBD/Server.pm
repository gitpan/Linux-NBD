=head1 NAME

Linux::NBD::Server - server (data provider) side of a network block device

=head1 SYNOPSIS

 use Linux::NBD::Server;

=head1 DESCRIPTION

You must subclass C<Linux::NBD::Server> to get meaningful results. You
should overwrite C<req_read> and/or C<req_write>. The default
implementations just return EIO.

=head1 METHODS

=over 4

=cut

package Linux::NBD::Server;

$VERSION = 0.21;

use Linux::NBD ();

use Carp qw(croak);
use Errno ();

=item $server = new Linux::NBD::Server socket => $fd, ...;

Create a new server. All arguments are put into a hashref which is blessed
and returned. The only required argument is C<socket> which should be
connected to a C<Linux::NBD::Client>.

=cut

sub new {
   my $class = shift;
   bless { @_ }, ref $class || $class;
}

=item $server->run

Enters a server loop, serving requests. Only returns when the socket is closed
or a disconnect message is received.

If you need non-blocking access your best bet is to use
C<$server->one_request>, but note that it still might block to read the
write data from the socket.

=item $server->one_request

Waits for and handles a single request and returns, returning true if no
further requests will arrive.

=item $server->format_reply ($handle[, $error, [, $data]])

Formats (and returns as a string) a reply message. If the request was a
read request and C<$error> is zero (or missing, both meaning no error),
you should append the read data to it.

If C<$data> is given and C<$error> is zero, it is appended to the string
before it is returned.

=item $server->reply ($handle[, $error[, $data]])

Formats and sends a reply to the server.

=item $server->send ($data)

Writes the given data to the client socket.

=item $server->recv ($bytes)

Reads the specified number of bytes and returns them.

=cut

sub run {
   my $self = shift;

   1 while not _one_request $self, fileno $self->{socket};
}

sub one_request {
   my $self = shift;

   _one_request $self, fileno $self->{socket};
}

sub format_reply {
   shift;
   &_format_reply;
}

sub reply {
   my $self = shift;

   $self->send(&_format_reply);
}

sub send {
   syswrite $_[0]->{socket}, $_[1];
}

sub recv {
   my ($self, $len) = @_;

   my ($buf, $todo);

   sysread $self->{socket}, $buf, $togo, length $buf
         or die "error or eof while receiving from network: $!";
      while $todo = $len - length $buf;

   $buf
}

=item $server->req_read ($handle, $offset, $length)

This callback is called for every read request. It should send
back a reply and the requested number of bytes, e.g.:

  my ($self, $handle, $ofs, $len) = @_;
  $self->reply($handle, 0, "\xff" x $len);

=item $server->req_write ($handle, $offset, $length)

Same as C<req_read>, but you should use C<recv> to read C<$len> bytes from
the socket (even if you intend to return an error, of course).

  my ($self, $handle, $ofs, $len) = @_;
  my $data = $self->recv($len);
  $self->reply($handle);

=cut

sub req_read {
   my ($self, $handle, $ofs, $len) = @_;

   $self->reply ($handle, 1);
}

sub req_write {
   my ($self, $handle, $ofs, $len) = @_;

   $self->recv ($len);
   $self->reply ($handle, 1);
}

1;

=back

=head1 NBD TOOL NEGOTIATION PROTOCOL

Standard NBD tools add a handshake phase before starting to serve/send
requests. The server-side implementation looks like this:

    $size = new Math::BigInt $size;
    my $size_hi = $size->copy->brsft(32)->blsft(32);
    my $size_lo = $size->copy->bsub($size_hi)->numify;
    $size_hi = $size_hi->brsft(32)->numify;

    $s->send ("NBDMAGIC\x00\x00\x42\x02\x81\x86\x12\x53");
    $s->send (pack "NN", $size_hi, $size_lo);
    $s->send ("\x00" x 128);

    # now serve
    my $server = new ServerClass socket => $s;
    $server->run;


=head1 BUGS

Should support AnyEvent or something similar for non-blocking behaviour.

=head1 AUTHOR

 Marc Lehmann <schmorp@schmorp.de>
 http://home.schmorp.de/

=cut

