#!/usr/bin/env genome-perl
use strict;
use warnings;

use Test::More tests => 4;
use above "Genome";

{
    package Genome::HasTimestamps;

    class Genome::HasTimestamps {
        roles => 'Genome::Role::ObjectWithTimestamps',
        has => [
            dummy_val => { is => 'Text' },
        ],
        id_generator => '-uuid',
        data_source => 'Genome::DataSource::GMSchema',
        table_name => 'fake',
    };
}


my $meta = Genome::HasTimestamps->__meta__;
foreach my $prop_name ( qw( created_at updated_at ) ) {
    is($meta->property($prop_name)->column_name, $prop_name, "$prop_name property has a DB column");
}

my $inherited_obj = Genome::HasTimestamps->create(dummy_val => 6);
ok($inherited_obj->created_at, 'created_at should be automatically set the first time an object is created');
my $old_val = $inherited_obj->updated_at;
sleep(2);
$inherited_obj->dummy_val(2);
ok($old_val ne $inherited_obj->updated_at, 'updated_at should change when the object changes');

