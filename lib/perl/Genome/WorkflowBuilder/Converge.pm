package Genome::WorkflowBuilder::Converge;

use strict;
use warnings;

use Genome;

class Genome::WorkflowBuilder::Converge {
    is => 'Genome::WorkflowBuilder::Detail::Operation',

    has => [
        input_properties => {
            is => 'Text',
            is_many => 1,
        },
        output_properties => {
            is => 'Text',
            is_many => 1,
        },
    ],
};


sub from_xml_element {
    my ($class, $element) = @_;

    my @input_properties = map {$_->textContent}
        $element->findnodes('.//inputproperty');
    my @output_properties = map {$_->textContent}
        $element->findnodes('.//outputproperty');
    return $class->create(
        name => $element->getAttribute('name'),
        input_properties => \@input_properties,
        output_properties => \@output_properties,
        parallel_by => $element->getAttribute('parallelBy'),
    );
}


sub operation_type_attributes { my %thing; return %thing; }

sub is_input_property {
    my ($self, $name) = @_;

    return Set::Scalar->new($self->input_properties)->contains($name);
}

sub is_output_property {
    my ($self, $name) = @_;

    return Set::Scalar->new($self->output_properties)->contains($name);
}

sub is_many_property {}


sub notify_input_link {
    my ($self, $link) = @_;

    unless ($self->is_input_property($link->destination_property)) {
        $self->add_input_property($link->destination_property);
    }

    return;
}

sub notify_output_link {
    my ($self, $link) = @_;

    unless ($self->is_output_property($link->source_property)) {
        $self->add_output_property($link->source_property);
    }

    return;
}

sub get_ptero_builder_task {
    require Ptero::Builder::Detail::Workflow::Task;

    my $self = shift;

    $self->validate;

    my %params = (
        name => $self->name,
        methods => [
            $self->_get_ptero_converge_method(),
        ],
    );
    if (defined $self->parallel_by) {
        $params{parallel_by} = $self->parallel_by;
    }
    return Ptero::Builder::Detail::Workflow::Task->new(%params);
}

sub _get_ptero_converge_method {
    require Ptero::Builder::Detail::Workflow::Converge;

    my $self = shift;
    my ($output_name) = $self->output_properties;
    return Ptero::Builder::Detail::Workflow::Converge->new(
        name => 'converge',
        parameters => {
            input_names => [$self->input_properties],
            output_name => $output_name,
        },
    );
}

sub _execute_inline {
    my ($self, $inputs) = @_;

    my $output = [];
    for my $input_name ($self->input_properties) {
        my $input = $inputs->{$input_name};
        if (ref($input) eq 'ARRAY') {
            push @$output, @{$input};
        } else {
            push @$output, $input;
        }
    }

    my ($output_name) = $self->output_properties;

    return {
        $output_name => $output,
        result => 1,
    };
}

1;
