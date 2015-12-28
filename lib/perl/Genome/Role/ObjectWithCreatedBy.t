#!/usr/bin/env genome-perl
use strict;
use warnings;

use Test::More tests => 4;
use above "Genome";

{
    package Genome::HasCreatedBy;

    class Genome::HasCreatedBy {
        roles => 'Genome::Role::ObjectWithCreatedBy',
        has => [
            dummy_val => { is => 'Text' },
        ],
        data_source => 'Genome::DataSource::GMSchema',
        table_name => 'fake',
        id_generator => '-uuid',
    };
}


my $meta = Genome::HasCreatedBy->__meta__;
is($meta->property('created_by')->column_name, 'created_by', 'created_by property has column name');

my $property_object = Genome::HasCreatedBy->__meta__->properties(property_name => 'created_by');
is($property_object->data_type, 'Text', 'the stapled in property should be of type Text');

my $obj1 = Genome::HasCreatedBy->create(dummy_val => 6);
is(Genome::Sys->username, $obj1->created_by, 'created_by should be automatically set the first time an object is created');

my $obj2 = Genome::HasCreatedBy->create(created_by => 'turkey', dummy_val => 6);
is('turkey', $obj2->created_by, 'the constructor should not overwrite a passed in value');
