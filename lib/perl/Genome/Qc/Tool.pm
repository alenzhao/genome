package Genome::Qc::Tool;

use strict;
use warnings;
use Genome;
use List::MoreUtils qw(uniq);

use Module::Pluggable
    search_path => 'Genome::Qc::Tool',
    except => [
        'Genome::Qc::Tool::Picard',
    ],
    sub_name => 'available_tools';

class Genome::Qc::Tool {
    is_abstract => 1,
    has => [
        alignment_result => {
            is => 'Genome::InstrumentData::AlignedBamResult',
        },
        gmt_params => {
            is => 'Hash',
        }
    ],
    has_calculated => [
        bam_file => {
            is => 'Path',
            calculate_from => [qw(alignment_result)],
            calculate => q{return $alignment_result->get_bam_file},
        },
    ],
};

sub cmd_line {
    my $self = shift;
    die $self->error_message("Abstract method run must be overriden by subclass");
}

sub qc_metrics_file {
    my $self = shift;
    my $qc_metrics_file_accessor = $self->qc_metrics_file_accessor;
    my %params = %{$self->gmt_params};
    return $params{$qc_metrics_file_accessor};
}

sub supports_streaming {
    my $self = shift;
    die $self->error_message("Abstract method supports_streaming must be overridden by subclass");
}

sub get_metrics {
    my $self = shift;
    die $self->error_message("Abstract method get_metrics must be overridden by subclass");
}

# Overwrite this in subclass to return the gmt tool parameter name for the output file
sub qc_metrics_file_accessor {
    return undef;
}

sub reference_build {
    my $self = shift;
    return $self->alignment_result->reference_build;
}

sub reference_sequence {
    my $self = shift;
    return $self->reference_build->full_consensus_path('fa');
}

sub sample {
    my $self = shift;

    my @samples = uniq map {$_->sample} $self->alignment_result->instrument_data;
    die "More than one sample" if scalar(@samples) > 1;
    return $samples[0];
}

sub sample_id {
    my $self = shift;
    return $self->sample->id;
}

sub sample_name {
    my $self = shift;
    return $self->sample->name;
}

1;
