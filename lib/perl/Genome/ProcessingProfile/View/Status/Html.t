#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok('Genome::ProcessingProfile::View::Status::Html') or die;

class Genome::Model::Tester { is => 'Genome::ModelDeprecated', };

my $pp = Genome::ProcessingProfile::Tester->create(
    name => 'Tester Test for Testing',
);
ok($pp, "created processing profile") or die;
my $model = Genome::Model->create(
    processing_profile => $pp,
    subject_name => 'human',
    subject_type => 'species_name',
);
ok($model, 'create model') or die;

my $view_obj = $pp->create_view(
    xsl_root => Genome->base_dir . '/xsl',
    rest_variable => '/cgi-bin/rest.cgi',
    toolkit => 'html',
    perspective => 'status',
); 
ok($view_obj, "created a view") or die;
isa_ok($view_obj, 'Genome::ProcessingProfile::View::Status::Html');

my $html = $view_obj->_generate_content();
ok($html, "view returns HTML");

done_testing();
