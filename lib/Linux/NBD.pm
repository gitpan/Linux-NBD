=head1 NAME

Linux::NBD - interface to the linux network block device.

=head1 SYNOPSIS

 use Linux::NBD;

=head1 DESCRIPTION

See L<Linux::NBD::Client> and L<Linux::NBD::Server>, or no, better idea:
use the source :)

=head1 FUNCTIONS

=over 4

=cut

package Linux::NBD;

BEGIN {
   $VERSION = 0.1;

   require XSLoader;
   XSLoader::load Linux::NBD, $VERSION;
}

use Socket;

=item ($a, $b) = tcp_socketpair;

Creates a pair of interconnected tcp sockets, which is extremely ugly, so be
happy that this function exists.

=cut

sub tcp_socketpair {
   open my $fh, "</dev/urandom" or die "/dev/urandom: $!";

   # this works by creating a listening socket
   # and connect to it, then exchange a 256 bit random cookie
   # to authentify.
   # the server is created first, and thus cannot be spoofed. i think.
   while () {
      socket my $a, PF_INET, SOCK_STREAM, 0		or die "tcp_socketpair/socket: $!";
      bind $a, sockaddr_in (0, inet_aton "127.0.0.1")	or die "tcp_socketpair/bind $!";
      listen $a, 1					or die "tcp_socketpair/listen $!";
      socket my $b, PF_INET, SOCK_STREAM, 0		or die "tcp_socketpair/socket: $!";
      connect $b, getsockname $a			or die "tcp_socketpair/connect: $!";
      accept $a, $a					or die "tcp_socketpair/accept: $!";

      sysread $fh, (my $rand), 32;
      syswrite $b, $rand				or die "tcp_socketpair/write_cookie: $!";
      sysread $a, (my $cookie), 32			or die "tcp_socketpair/read_cookie: $!";

      return ($a, $b) if $rand eq $cookie;
   }
}

1;

=back

=head1 AUTHOR

 Marc Lehmann <pcg@goof.com>
 http://www.goof.com/pcg/marc/

=cut

