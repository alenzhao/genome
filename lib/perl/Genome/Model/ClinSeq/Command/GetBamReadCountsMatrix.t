#!/usr/bin/env genome-perl

#Written by Malachi Griffith

use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}               = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above "Genome";
use Test::More tests => 6;  #One per 'ok', 'is', etc. statement below
use Genome::Model::ClinSeq::Command::GetBamReadCountsMatrix;
use Data::Dumper;

use_ok('Genome::Model::ClinSeq::Command::GetBamReadCountsMatrix') or die;

#Define the test where expected results are stored
my $expected_output_dir =
    Genome::Config::get('test_inputs') . "/Genome-Model-ClinSeq-Command-GetBamReadCountsMatrix/2015-08-28/";
ok(-e $expected_output_dir, "Found test dir: $expected_output_dir") or die;

#Create a temp dir for results
my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir");

#Get a somatic variation build
my $somvar_build_id1 = '5073b4ac211b4ad498e1ee365b0603d8';
#my $somvar_build_id2 = 126847207;

#Create get-bam-read-counts-matrix command and execute
#genome model clin-seq get-bam-read-counts-matrix --output-dir=/tmp/bam_readcount_matrix/ --somatic-build-ids='126851693,126847207' --somatic-labels='DefaultSomatic_PNC4,StrelkaSomatic_PNC4' --skip-mt=1 --max-positions=250
my $bam_readcounts_cmd = Genome::Model::ClinSeq::Command::GetBamReadCountsMatrix->create(
    output_dir        => $temp_dir,
    somatic_build_ids => "$somvar_build_id1",
    somatic_labels    => "Somatic_SCLC1",
    skip_mt           => 1,
    max_positions     => 250
);
$bam_readcounts_cmd->queue_status_messages(1);
my $r1 = $bam_readcounts_cmd->execute();
is($r1, 1, 'Testing for successful execution.  Expecting 1.  Got: ' . $r1);

#Dump the output of update-analysis to a log file
my @output1  = $bam_readcounts_cmd->status_messages();
my $log_file = $temp_dir . "/BamReadCountsMatrix.log.txt";
my $log      = IO::File->new(">$log_file");
$log->print(join("\n", @output1));
ok(-e $log_file, "Wrote message file from update-analysis to a log file: $log_file");

#The first time we run this we will need to save our initial result to diff against
#Genome::Sys->shellcmd(cmd => "cp -r -L $temp_dir/* $expected_output_dir");

#Perform a diff between the stored results and those generated by this test
my @diff = `diff -r $expected_output_dir $temp_dir`;
my $ok = ok(@diff == 0, "Found only expected number of differences between expected results and test results");
unless ($ok) {
    diag("expected: $expected_output_dir\nactual: $temp_dir\n");
    diag("differences are:");
    diag(@diff);
    my $diff_line_count = scalar(@diff);
    print "\n\nFound $diff_line_count differing lines\n\n";
    Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-bam-readcounts-matrix-result/");
    Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-bam-readcounts-matrix-result");
}
