package Genome::Annotation::BamReadcount::Expert;

use strict;
use warnings FATAL => 'all';
use Genome;
use Genome::WorkflowBuilder::DAG;
use Genome::WorkflowBuilder::Command;

class Genome::Annotation::BamReadcount::Expert {
    is => 'Genome::Annotation::ExpertBase',
};

sub name {
    'bam-readcount';
}

sub dag {
    my $self = shift;

    my $dag = Genome::WorkflowBuilder::DAG->create(
        name => 'BamReadcount',
    );
    my $build_adaptor_op = $self->connected_build_adaptor_operation($dag);

    my $run_op = $self->run_op;
    $dag->add_operation($run_op);
    $run_op->parallel_by('aligned_bam_result');
    $dag->create_link(
        source => $build_adaptor_op,
        source_property => 'bam_results',
        destination => $run_op,
        destination_property => 'aligned_bam_result',
    );
    $self->_link(dag => $dag,
          adaptor => $build_adaptor_op,
          previous => $build_adaptor_op,
          target => $run_op,
    );

    my $annotate_op = $self->annotate_op;
    $dag->add_operation($annotate_op);
    $dag->create_link(
        source => $run_op,
        source_property => 'output_result',
        destination => $annotate_op,
        destination_property => 'readcount_results',
    );
    $self->_link(dag => $dag,
          adaptor => $build_adaptor_op,
          previous => $build_adaptor_op,
          target => $annotate_op,
    );

    $dag->connect_output(
        output_property => 'output_result',
        source => $annotate_op,
        source_property => 'output_result',
    );

    return $dag;
}

sub run_op {
    return Genome::WorkflowBuilder::Command->create(
        name => 'Run bam-readcount',
        command => 'Genome::Annotation::BamReadcount::Run',
    );
}

sub annotate_op {
    return Genome::WorkflowBuilder::Command->create(
        name => 'Annotate vcf with readcounts',
        command => 'Genome::Annotation::BamReadcount::Annotate',
    );
}



1;
