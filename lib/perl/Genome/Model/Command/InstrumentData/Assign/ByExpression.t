#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use above 'Genome';
use Test::More;

use_ok('Genome::Model::Command::InstrumentData::Assign::ByExpression') or die;

class Genome::Model::Tester { is => 'Genome::ModelDeprecated', };

my $pp = Genome::ProcessingProfile::Tester->create(
    name => 'Tester Test for Testing',
);
ok($pp, "created processing profile") or die;

my $model = Genome::Model->create(
    processing_profile => $pp,
    subject_name => 'human',
    subject_type => 'species_name',
    user_name => 'apipe',
);
ok($model, 'create model') or die;

my @sanger_id = map { Genome::InstrumentData::Sanger->create(id => '0'.$_.'jan00.101amaa') } (1..4);
is(@sanger_id, 4, 'create instrument data') or die;

my $assign = Genome::Model::Command::InstrumentData::Assign::ByExpression->create(
    model => $model,
    instrument_data => [$sanger_id[0]],
    force => 1,
);
ok($assign, 'create to assign single instrument data');
$assign->dump_status_messages(1);
ok($assign->execute, 'execute');
my @assigned_inst_data = $model->instrument_data;
is_deeply(\@assigned_inst_data, [ $sanger_id[0], ], 'confirmed assigned inst data');

$assign = Genome::Model::Command::InstrumentData::Assign::ByExpression->create(
    model => $model,
    instrument_data => [ $sanger_id[1], $sanger_id[2], ],
    force => 1,
);
ok($assign, 'create to assign multiple instrument data');
$assign->dump_status_messages(1);
ok($assign->execute, 'execute');
@assigned_inst_data = $model->instrument_data;
is_deeply(\@assigned_inst_data, [ @sanger_id[0..2], ], 'confirmed assigned inst data');

done_testing();
