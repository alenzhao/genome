use strict;
use warnings;

use above 'Genome';
use Genome::Logger;
use Genome::Site::TGI::Extension::Logger;
use Test::More tests => 3;

my $logger = Genome::Logger->logger();

my %outputs = %{$logger->delegate_logger->{outputs}};
my $screen = delete $outputs{screen};
my $syslog = delete $outputs{syslog};

ok($screen, 'got a screen output');
ok($syslog, 'got a syslog output');
is_deeply(\%outputs, {}, 'outputs is otherwise empty');
