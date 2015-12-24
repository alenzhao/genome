#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_NO_REQUIRE_USER_VERIFY} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok("Genome::Model::Build::Command::Abandon") or die;

class Genome::Model::Tester { is => 'Genome::ModelDeprecated', };

my $s = Genome::Sample->create(name => 'TEST-' . __FILE__ . "-$$");
ok($s, "made a test sample");

my $p = Genome::ProcessingProfile::Tester->create(
    name => 'Tester Test for Testing',
);
ok($p, "made a test processing profile");

my $m = Genome::Model::Tester->create(
    processing_profile_id => $p->id,
    subject_class_name => ref($s),
    subject_id => $s->id,
);
ok($m, "made a test model");

my $b1 = $m->add_build();
ok($b1, "made test build 1");

my $exit_code1 = eval { 
    Genome::Model::Build::Command::Abandon->_execute_with_shell_params_and_return_exit_code('--', $b1->id);
};
ok(!$@, "the command did not crash");
is($exit_code1, 0, "command believes it succeeded");

done_testing();
