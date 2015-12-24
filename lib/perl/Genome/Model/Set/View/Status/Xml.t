#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
}

use strict;
use warnings;

use above "Genome"; 
use Test::More;

use_ok('Genome::Model::Set::View::Status::Xml') or die;

class Genome::Model::Tester { is => 'Genome::ModelDeprecated', };

my $pp = Genome::ProcessingProfile::Tester->create(
    name => 'Test Pipeline Test for Testing',
);
ok($pp, "created processing profile") or die;
my @models;
for my $i (1..2) {
    push @models, Genome::Model->create(
        name => $pp->name.'-'.$i,
        processing_profile => $pp,
        subject_name => 'human',
        subject_type => 'species_name',
    ) or die;
}
is(@models, 2, "created 2 models");

my $set = Genome::Model->define_set(processing_profile_id => $pp->id);
ok($set, "defined a model set") or die;
my @members = $set->members;
is_deeply([ sort { $a->id cmp $b->id } @models ], [ sort { $a->id cmp $b->id } @members ], 'set members match models');

my $view_obj = $set->create_view(perspective => 'status', toolkit => 'xml'); 
ok($view_obj, "created a view") or die;
isa_ok($view_obj, 'Genome::Model::Set::View::Status::Xml');

my $xml = $view_obj->_generate_content();
ok($xml, "view returns XML");

done_testing();
