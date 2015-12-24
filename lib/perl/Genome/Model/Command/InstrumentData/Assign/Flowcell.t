#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use strict;
use warnings;

use above 'Genome';
use Genome::Test::Factory::InstrumentData::Solexa;
use Test::More;

use_ok('Genome::Model::Command::InstrumentData::Assign::Flowcell') or die;

class Genome::Model::Tester { is => 'Genome::ModelDeprecated', };

my $pp = Genome::ProcessingProfile::Tester->create(
    name => 'Tester Test for Testing',
);
ok($pp, "created processing profile") or die;

my $flow_cell_id = 'test_flow_cell_id';
my @solexa_id = map { Genome::Test::Factory::InstrumentData::Solexa->setup_object(flow_cell_id => $flow_cell_id) } (1..4);
is(@solexa_id, 4, 'create instrument data') or die;
for(@solexa_id) { $_->sample->source->taxon($solexa_id[0]->taxon); }
@solexa_id = sort @solexa_id;

my $model = Genome::Model->create(
    processing_profile => $pp,
    subject => $solexa_id[0]->taxon,
    user_name => 'apipe',
);
ok($model, 'create model') or die;

no warnings qw/once redefine/;
*Genome::ModelDeprecated::compatible_instrument_data = sub{ return @solexa_id; };
use warnings;
my @compatible_id = sort $model->compatible_instrument_data;
is_deeply(\@solexa_id, \@compatible_id, 'overload compatible instrument data');

my $assign = Genome::Model::Command::InstrumentData::Assign::Flowcell->create(
    model => $model,
    flow_cell_id => $flow_cell_id,
);
ok($assign, 'create to assign instrument data by flow cell');
$assign->dump_status_messages(1);
ok($assign->execute, 'execute');
my @assigned_inst_data = sort $model->instrument_data;
is_deeply(\@assigned_inst_data, \@solexa_id, 'confirmed assigned inst data');

Genome::Test::Factory::InstrumentData::Solexa->setup_object(flow_cell_id => $flow_cell_id . '_other');

$assign = Genome::Model::Command::InstrumentData::Assign::Flowcell->create(
    model => $model,
    flow_cell_id => $flow_cell_id,
);
ok($assign, 'create to assign instrument data by flow cell');
$assign->dump_status_messages(1);
ok($assign->execute, 'execute');
@assigned_inst_data = sort $model->instrument_data;
is_deeply(\@assigned_inst_data, \@solexa_id, 'confirmed skip unrelated inst data');

done_testing();
