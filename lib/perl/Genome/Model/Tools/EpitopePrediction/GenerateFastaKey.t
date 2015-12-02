#!/usr/bin/env genome-perl

use strict;
use warnings;

use above 'Genome';
use Test::More;
use Genome::Utility::Test qw(compare_ok);

my $class = 'Genome::Model::Tools::EpitopePrediction::GenerateFastaKey';
my $TEST_DATA_VERSION= 2;
use_ok($class);

my $test_dir = Genome::Utility::Test->data_dir_ok($class, $TEST_DATA_VERSION);
my $input_file = File::Spec->join($test_dir, "snvs_21mer.fa");
my $expected_output = File::Spec->join($test_dir, "output.key");
my $output_dir = Genome::Sys->create_temp_directory;

my $cmd = $class->create(
    input_file => $input_file,
    output_directory => $output_dir,
);

ok($cmd->execute, "Command executed");

compare_ok($cmd->output_file, $expected_output, "Output file is as expected");

done_testing();
