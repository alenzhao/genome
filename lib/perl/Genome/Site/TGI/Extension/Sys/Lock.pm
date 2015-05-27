package Genome::Sys::Lock;

use strict;
use warnings;

use Sys::Hostname qw(hostname);

BEGIN {
    unless ($INC{'Genome/Sys/Lock.pm'}) {
        die 'must load Genome::Sys::Lock first';
    }
};


require Genome::Sys::Lock::FileBackend;


Genome::Sys::Lock->add_backend('host',
    Genome::Sys::Lock::FileBackend->new(is_mandatory => 1,
        parent_dir => Genome::Config::get('host_lock_dir')));

Genome::Sys::Lock->add_backend('site',
    Genome::Sys::Lock::FileBackend->new(is_mandatory => 1,
        parent_dir => Genome::Config::get('site_lock_dir')));

my $nessy_server = Genome::Config::get('nessy_server');
if ($nessy_server) {
    require Genome::Sys::Lock::NessyBackend;
    my $is_mandatory = Genome::Config::get('nessy_mandatory') ? 1 : 0;

    my $nessy_host_backend = Genome::Sys::Lock::NessyBackend->new(
        url => $nessy_server,
        is_mandatory => $is_mandatory,
        namespace => hostname(),
    );
    Genome::Sys::Lock->add_backend('host', $nessy_host_backend);

    my $nessy_site_backend = Genome::Sys::Lock::NessyBackend->new(
        url => $nessy_server,
        is_mandatory => $is_mandatory,
    );
    Genome::Sys::Lock->add_backend('site', $nessy_site_backend);

    UR::Observer->register_callback(
        subject_class_name => UR::Context->process->class,
        subject_id => UR::Context->process->id,
        aspect => 'sync_databases',
        callback => sub {
            my ($ctx, $aspect, $sync_db_result) = @_;
            if ($sync_db_result) {
                use vars '@CARP_NOT';
                local @CARP_NOT = (@CARP_NOT, 'UR::Context');
                foreach my $claim ($nessy_site_backend->claims, $nessy_host_backend->claims) {
                    $claim->validate
                        || Carp::croak(sprintf('Claim %s failed to verify during commit', $claim->resource_name));
                }
            }
        }
    );
}

1;
