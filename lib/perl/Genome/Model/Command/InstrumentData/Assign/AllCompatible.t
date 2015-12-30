#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use above 'Genome';
use Genome::Test::Factory::InstrumentData::Solexa;
use Test::More;

use_ok('Genome::Model::Command::InstrumentData::Assign::AllCompatible') or die;

class Genome::Model::Tester { is => 'Genome::ModelDeprecated', };

my $pp = Genome::ProcessingProfile::Tester->create(
    name => 'Tester Test for Testing',
);
ok($pp, "created processing profile") or die;

my @solexa_id = map { Genome::Test::Factory::InstrumentData::Solexa->setup_object() } (1..4);
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

# Fails
my $assign = Genome::Model::Command::InstrumentData::Assign::AllCompatible->create();
ok(!$assign->execute, 'create w/o model fails');

# Success
$assign = Genome::Model::Command::InstrumentData::Assign::AllCompatible->create(
    model => $model,
);
ok($assign, 'create to assign all available instrument data');
$assign->dump_status_messages(1);
ok($assign->execute, 'execute');
my @assigned_inst_data = sort $model->instrument_data;
is_deeply(\@assigned_inst_data, \@solexa_id, 'confirmed assigned inst data');

#Add an ignored InstrumentData, and make sure assign all doesn't grab it.
Genome::InstrumentData::Sanger->create(id => '05.jan00.101amaa');

$assign = Genome::Model::Command::InstrumentData::Assign::AllCompatible->create(
    model => $model,
);
ok($assign, 'create to assign all available instrument data');
$assign->dump_status_messages(1);
ok($assign->execute, 'execute');
@assigned_inst_data = sort $model->instrument_data;
is_deeply(\@assigned_inst_data, \@solexa_id, 'confirmed skip ignored  inst data');

done_testing();
