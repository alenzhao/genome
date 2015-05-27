package Genome::Utility::ObjectWithCreatedBy;

use strict;
use warnings;

use Genome;

class Genome::Utility::ObjectWithCreatedBy {
    subclass_description_preprocessor => __PACKAGE__ . '::_preprocess_subclass_description',
    is => 'UR::Object',
    is_abstract => 1,
};

UR::Observer->register_callback(subject_class_name => 'Genome::Utility::ObjectWithCreatedBy', aspect => 'create',  callback => \&_populate_created_by);

sub _preprocess_subclass_description {
    my ($class, $desc) = @_;
    $desc->{has}{created_by} = {
        property_name => 'created_by',
        is => 'Text'
    };

    return $desc;
}

sub _populate_created_by {
    my $self = shift;
    unless ($self->created_by) {
        $self->created_by(Genome::Sys->username);
    }
}

1;
