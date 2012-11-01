#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Command::Services::AssignQueuedInstrumentData') or die;

my $instrument_data;
no warnings;
*Genome::InstrumentDataAttribute::get = sub {
    my ($class, %params) = @_;
    my %attrs = map { $_->id => $_ } $instrument_data->attributes;
    for my $param_key ( keys %params ) {
        my @param_values = ( ref $params{$param_key} ? @{$params{$param_key}} : $params{$param_key} );
        my @unmatched_attrs;
        for my $attr ( values %attrs ) {
            next if grep { $attr->$param_key eq $_ } @param_values;
            push @unmatched_attrs, $attr->id;
        }
        for ( @unmatched_attrs ) { delete $attrs{$_} }
    }
    return values %attrs;
};
use warnings;

# Fail - no sample
my $library = Genome::Library->__define__(name => '__TEST_SAMPLE__-testlib');
ok($library, 'define library');

$instrument_data = Genome::InstrumentData::Solexa->__define__(
    id => '-1234',
    library_id => $library->id,
);
ok($instrument_data, 'defined instrument data');
$instrument_data->add_attribute(
    attribute_label => 'tgi_lims_status',
    attribute_value => 'new',
);
is($instrument_data->attributes(attribute_label => 'tgi_lims_status')->attribute_value, 'new', 'instrument data tgi_lims_status is new');

my $cmd = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
ok($cmd, 'create aqid');
ok($cmd->execute, 'execute');
is($instrument_data->attributes(attribute_label => 'tgi_lims_status')->attribute_value, 'failed', 'instrument data tgi_lims_status is failed');
like($instrument_data->attributes(attribute_label => 'tgi_lims_fail_message')->attribute_value, qr/^Failed to get processing for instrument data id \(\-1234\): Failed to get a sample for instrument data! \-1234/, 'instrument data tgi_lims_fail_message is correct');
is($instrument_data->attributes(attribute_label => 'tgi_lims_fail_count')->attribute_value, 1, 'instrument data tgi_lims_fail_count is 1');

# Fail - no sample source
my $sample = Genome::Sample->__define__(name => '__TEST_SAMPLE__');
ok($sample, 'define sample');
$library->sample_id($sample->id);
$library = Genome::Library->__define__(name => '__TEST_SAMPLE__-testlib', sample => $sample);
ok($library, 'define library');
$instrument_data = Genome::InstrumentData::Solexa->__define__(
    id => '-12345',
    library_id => $library->id,
);
ok($instrument_data, 'defined instrument data');
$instrument_data->add_attribute(
    attribute_label => 'tgi_lims_status',
    attribute_value => 'new',
);
is($instrument_data->attributes(attribute_label => 'tgi_lims_status')->attribute_value, 'new', 'instrument data tgi_lims_status is new');

$cmd = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
ok($cmd, 'create aqid');
ok($cmd->execute, 'execute');
is($instrument_data->attributes(attribute_label => 'tgi_lims_status')->attribute_value, 'failed', 'instrument data tgi_lims_status is failed');
like($instrument_data->attributes(attribute_label => 'tgi_lims_fail_message')->attribute_value, qr/^Failed to get processing for instrument data id \(\-12345\): Failed to get a sample source for instrument data! \-12345/, 'instrument data tgi_lims_fail_message is correct');
is($instrument_data->attributes(attribute_label => 'tgi_lims_fail_count')->attribute_value, 1, 'instrument data tgi_lims_fail_count is 1');

# Fail - no taxon
my $source = Genome::Individual->__define__(name => '__TEST_SOURCE__');
$sample = Genome::Sample->__define__(name => '__TEST_SAMPLE__', source => $source);
ok($sample, 'define sample');
$library->sample_id($sample->id);
$library = Genome::Library->__define__(name => '__TEST_SAMPLE__-testlib', sample => $sample);
ok($library, 'define library');
$instrument_data = Genome::InstrumentData::Solexa->__define__(
    id => '-123456',
    library_id => $library->id,
);
ok($instrument_data, 'defined instrument data');
$instrument_data->add_attribute(
    attribute_label => 'tgi_lims_status',
    attribute_value => 'new',
);
$instrument_data->add_attribute(
    attribute_label => 'tgi_lims_fail_count',
    attribute_value => 2,
);
is($instrument_data->attributes(attribute_label => 'tgi_lims_status')->attribute_value, 'new', 'instrument data tgi_lims_status is new');

my $cmd = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
ok($cmd, 'create aqid');
ok($cmd->execute, 'execute');
is($instrument_data->attributes(attribute_label => 'tgi_lims_status')->attribute_value, 'failed', 'instrument data tgi_lims_status is failed');
like($instrument_data->attributes(attribute_label => 'tgi_lims_fail_message')->attribute_value, qr/^Failed to get processing for instrument data id \(\-123456\): Failed to get a taxon from sample source for instrument data! \-123456/, 'instrument data tgi_lims_fail_message is correct');
is($instrument_data->attributes(attribute_label => 'tgi_lims_fail_count')->attribute_value, 3, 'instrument data tgi_lims_fail_count is 3');

done_testing();
exit;

