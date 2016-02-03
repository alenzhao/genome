package Genome::Test::Factory::Model::ReferenceAlignment;
use Genome::Test::Factory::Model;
@ISA = (Genome::Test::Factory::Model);

use strict;
use warnings;

use Genome;
use Genome::Test::Factory::ProcessingProfile::ReferenceAlignment;
use Genome::Test::Factory::Model::ImportedReferenceSequence;
use Genome::Test::Factory::Build;
use Genome::Test::Factory::Sample;

our @required_params = qw(reference_sequence_build subject_id);

sub generate_obj {
    my $self = shift;

    my $m = Genome::Model::ReferenceAlignment->create(@_);
    return $m;
}

sub create_processing_profile_id {
    my $p = Genome::Test::Factory::ProcessingProfile::ReferenceAlignment->setup_object();
    return $p->id;
}

sub create_reference_sequence_build {
    my $m = Genome::Test::Factory::Model::ImportedReferenceSequence->setup_object;
    my $b = Genome::Test::Factory::Build->setup_object(model_id => $m->id);
    return $b;
}

sub create_subject_id {
    my $subject = Genome::Test::Factory::Sample->setup_object();
    return $subject->id;
}

1;
