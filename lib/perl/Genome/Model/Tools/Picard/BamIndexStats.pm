package Genome::Model::Tools::Picard::BamIndexStats;

use strict;
use warnings;

use Genome;
use Carp qw(confess);

class Genome::Model::Tools::Picard::BamIndexStats {
    is => 'Genome::Model::Tools::Picard::Base',
    has_input => [
        input_file  => {
            is => 'String',
            doc => 'A BAM file to process.',
            picard_param_name => 'INPUT',
        },
        output_file => {
            is => 'String',
            doc => 'The output file to write stats.',
        },
    ],
};

sub help_brief {
    'Generates BAM index statistics. Input BAM file must have a corresponding index file. ';
}

sub help_detail {
    return <<EOS
    For Picard documentation of this command see:
    http://broadinstitute.github.io/picard/command-line-overview.html#BamIndexStats
EOS
}

sub minimum_version_required { '1.29'; }

sub _jar_name {
    return 'BamIndexStats.jar';
}

sub _java_class {
    return qw(picard sam BamIndexStats);
}

sub _redirects {
    my $self = shift;
    return sprintf '> %s', $self->output_file;
}

sub _shellcmd_extra_params {
    my $self = shift;
    return (
        input_files => [$self->input_file],
        output_files => [$self->output_file],
        skip_if_output_is_present => 0,
        );
}

1;
