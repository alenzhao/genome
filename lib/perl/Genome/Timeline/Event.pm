package Genome::Timeline::Event;

use strict;
use warnings;

use Genome;
use Sub::Install ();

class Genome::Timeline::Event {
    is_abstract => 1,
    id_generator => '-uuid',
    data_source => 'Genome::DataSource::GMSchema',
    subclass_description_preprocessor => __PACKAGE__ . '::_preprocess_subclass_description',
};


sub _add {
    my $class = shift;
    my ($name, $reason, $instance) =  @_;

    my %prop_hash = $class->_properties_to_snapshot();

    return $class->create(
        name => $name,
        object => $instance,
        reason => $reason,
        map { $prop_hash{$_} => $instance->$_ } keys %prop_hash,
    );
}

#hash mapping value names on the object (key) to database columns for the event (value)
sub _properties_to_snapshot { die('Please provide a map of properties to be saved!'); }

sub _define_event_constructors {
    my ($class, $into, $values) = @_;
    for my $event_name (@$values) {
        Sub::Install::reinstall_sub({
                into => $into,
                as => $event_name,
                code => sub { shift->_add($event_name, @_); }
        });
    }
}

sub _preprocess_subclass_description {
    my ($class, $desc) = @_;
    my $properties = _object_properties();
    for my $property (keys %$properties) {
        $desc->{has}{$property} = $properties->{$property};
    }
    $desc->{id_by} = [ id => { data_type => 'Text', data_length => 64, }, ];

    return $desc;
}

sub _object_properties {
    return {
        object => {
            is => 'UR::Object',
            id_by => 'object_id',
            id_class_by => 'object_class_name',
        },
        name => {
            is => 'Text',
        },
        object_id => {
            is => 'Text',
        },
        object_class_name => {
            is => 'Text',
        },
        reason => {
            is => 'Text',
        },
    };
}

1;
