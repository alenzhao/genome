package Genome::Model::Build::ReferenceSequence::AlignerIndex;

use Genome;
use warnings;
use strict;


class Genome::Model::Build::ReferenceSequence::AlignerIndex {
    is => ['Genome::Model::Build::ReferenceSequence::IndexBase'],
};

sub _working_dir_prefix {
    "aligner-index";
}

sub __display_name__ {
    my $self = shift;
    my @class_name = split("::", $self->class);
    my $class_name = $class_name[-1];
    no warnings;
    return sprintf("%s for build %s with %s, version %s, params='%s'",
        $class_name,
        $self->reference_name,
        $self->aligner_name,
        $self->aligner_version,
        $self->aligner_params || "");
}

sub generate_dependencies_as_needed {
    my $self = shift;
    my $users = shift;

    # if the reference is a compound reference
    if ($self->reference_build->append_to) {
        my %params = (
            aligner_name => $self->aligner_name,
            aligner_params => $self->aligner_params,
            aligner_version => $self->aligner_version,
            users => $users,
        );

        for my $b ($self->reference_build->append_to) { # (append_to is_many)
            $params{reference_build} = $b;
            $self->debug_message("Creating AlignmentIndex for build dependency " . $b->name);
            my $result = Genome::Model::Build::ReferenceSequence::AlignerIndex->get_or_create(%params);
            unless($result) {
                die $self->error_message("Failed to create AlignmentIndex for dependency " . $b->name);

            }
        }
    }

    return 1;
}

sub _prepare_index {
    my $self = shift;
    my $reference_fasta_file = shift;

    unless (symlink($reference_fasta_file, sprintf("%s/all_sequences.fa", $self->temp_staging_directory))) {
        $self->error_message("Couldn't symlink reference fasta into the staging directory");
    }

    my $reference_remap_file = sprintf("%s.remap", $reference_fasta_file);

    if (-e $reference_remap_file) {
        $self->debug_message("Detected $reference_remap_file.remap. Symlinking that as well.");
        unless (symlink($reference_remap_file, sprintf("%s/all_sequences.fa.remap", $self->temp_staging_directory))) {
            $self->error_message("Couldn't symlink reference remap into the staging directory");
        }
    }

    unless ($self->aligner_class_name->prepare_reference_sequence_index($self)) {
        $self->error_message("Failed to prepare reference sequence index.");
        return;
    }

    return $self;
}

sub _resolve_allocation_subdirectory_components {
    my $self = shift;

    return ('ref_build_aligner_index_data',$self->reference_build->model->id,'build'.$self->reference_build->id);
}

1;
