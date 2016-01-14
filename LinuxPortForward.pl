#!perl -w
# usage: portforward configfile
# configfile has lines like this:
#18025 mail.messagingengine.com:25
#18110 mail.messagingengine.com:110
#where 18025 is the TCP port on the local machine and 
#  mail.messagingengine.com:25
#is where that port is forwarded to.

# Taken from http://www.perlmonks.org/bare/?node_id=367253

use Socket;
use IO::Socket;
use IO::Select;
use strict;

$| = 1;
my %ports;
my $listen_set =  IO::Select->new();


$SIG{CHLD} = 'IGNORE';

while (<>) {
  chomp;
  my ($localport, $remotehost) = split;
  $ports{$localport} = $remotehost;
  print "config $localport -> $remotehost\n";
  my $socklisten = IO::Socket::INET->new(LocalPort => $localport,
                                   Listen   => 2,
                                   Reuse   => 1,
                                   Proto    => 'tcp')
                         or die "Cannot open sock on $localport: $!\n"
+;
 $listen_set->add($socklisten);
}

my @ready;
print "Parent ready to accept\n";
while (1) {
  @ready = $listen_set->can_read;
  for my $socklisten (@ready) {
    my $socklocal = $socklisten->accept;
    if (defined $socklocal) {
      my ($port, $myaddr) = sockaddr_in(getsockname($socklisten));
      print "accepted on $port\n";
      my $remotehost = $ports{$port};
      if (! defined($remotehost)) {
        print "Internal error on port $port\n";
        die;
      }
      if (fork()) {
        close($socklocal);
      } else {
        close($socklisten);
        my $sockremote = IO::Socket::INET->new(
            Proto     => "tcp",
            PeerAddr  => "$remotehost",
            Timeout   => 30,
         )
         or die "cannot create socketremote($remotehost): $!\n";
         my $buf= ' 'x4096;
         if (fork()) {
           my $sent = 0;
           while (sysread($socklocal,  $buf, 4096)) {
             print $sockremote $buf;
             $sent += length($buf);
           }
           # print "Total bytes sent $sent\n";
         } else {
           my $rcvd = 0;
           while(sysread($sockremote, $buf, 4096)) {
             print $socklocal  $buf;
             $rcvd += length($buf);
           }
           # print "Total bytes rcvd: $rcvd\n";
         }
         exit(0);
      }
    }
  }
}
print "End of parent: $!\n";
__END__