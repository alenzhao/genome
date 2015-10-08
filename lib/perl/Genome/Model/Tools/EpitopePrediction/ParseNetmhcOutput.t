#!/usr/bin/env genome-perl

use strict;
use warnings;

use above 'Genome';
use Test::More;
use Genome::Utility::Test qw(compare_ok);

my $TEST_DATA_VERSION = 2;
my $class = 'Genome::Model::Tools::EpitopePrediction::ParseNetmhcOutput';
use_ok($class);

my $test_dir = Genome::Utility::Test->data_dir_ok($class, $TEST_DATA_VERSION);
my $key_file = File::Spec->join($test_dir, "key_file.txt");

for my $netmhc_version (qw(3.0 3.4)) {
    my $netmhc_file = File::Spec->join($test_dir, "netmhc_file.$netmhc_version.xls");
    for my $output_type (qw(all top)) {
        test_for_output_type($output_type, $test_dir, $netmhc_file, $netmhc_version, $key_file);
    }
}

sub test_for_output_type {
    my ($output_type, $test_dir, $netmhc_file, $netmhc_version, $key_file) = @_;

    my $expected_output = File::Spec->join($test_dir, "parsed_file.$netmhc_version.$output_type");
    my $output_dir = Genome::Sys->create_temp_directory;

    my $cmd = $class->create(
        netmhc_file => $netmhc_file,
        output_directory => $output_dir,
        key_file => $key_file,
        output_filter => $output_type,
        netmhc_version => $netmhc_version,
    );
    ok($cmd, "Created a command for output type $output_type");

    ok($cmd->execute, "Command executed for output type $output_type");

    compare_ok($cmd->parsed_file, $expected_output, "Output file is as expected for output type $output_type");
}

done_testing();
