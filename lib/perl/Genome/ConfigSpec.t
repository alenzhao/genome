#!/usr/bin/env genome-perl

use strict;
use warnings;

use Genome qw();
use Test::More tests => 6;

use File::Spec qw();
use File::Temp qw();
use Test::Fatal qw(exception);
use YAML::Syck qw();

use_ok('Genome::ConfigSpec');

subtest 'new_from_file: basic' => sub {
    plan tests => 2;

    my %data = (
        validators => [qw(numeric port)],
    );
    my ($input_fh, $input_file, $input_filename) = setup_yaml_file({ %data });

    my $spec = Genome::ConfigSpec->new_from_file($input_file);
    is($spec->key, $input_filename, 'key matches');

    my $got_validator_count = scalar(@{$spec->validators});
    my $exp_validator_count = scalar(@{$data{validators}}) + 1; # + 1 for implied required validator
    is($got_validator_count, $exp_validator_count, q(validators count matches));
};

for my $key (qw(default_value env)) {
    my $has = 'has_' . $key;

    subtest "new_from_file: $key" => sub {
        plan tests => 3;
        subtest "no $key key" => sub {
            plan tests => 2;
            my ($input_fh, $input_file, $input_filename) = setup_yaml_file({});
            my $spec = Genome::ConfigSpec->new_from_file($input_file);
            ok(!$spec->$has, "$has is false");
            is($spec->$key, undef, "$key is undefined")
        };

        subtest qq($key: '') => sub {
            plan tests => 2;
            my ($input_fh, $input_file, $input_filename) = setup_yaml_file({
                $key => '',
            });
            my $spec = Genome::ConfigSpec->new_from_file($input_file);
            ok($spec->$has, "$has is true");
            is($spec->$key, '', "$key is set")
        };

        subtest qq($key: 'foo') => sub {
            plan tests => 2;
            my ($input_fh, $input_file, $input_filename) = setup_yaml_file({
                $key => 'foo',
            });
            my $spec = Genome::ConfigSpec->new_from_file($input_file);
            ok($spec->$has, "$has is true");
            is($spec->$key, 'foo', "$key is set")
        };
    };
}

subtest 'new_from_file: sticky' => sub {
    plan tests => 3;
    {
        my ($input_fh, $input_file, $input_filename) = setup_yaml_file({});
        my $spec = Genome::ConfigSpec->new_from_file($input_file);
        ok(!$spec->sticky, 'no sticky key results in non-sticky spec')
    } {
        my ($input_fh, $input_file, $input_filename) = setup_yaml_file({
            sticky => 0,
        });
        my $spec = Genome::ConfigSpec->new_from_file($input_file);
        ok(!$spec->sticky, 'sticky set to zero results in non-sticky spec')
    } {
        my ($input_fh, $input_file, $input_filename) = setup_yaml_file({
            sticky => 1,
            env => 'FOO',
        });
        my $spec = Genome::ConfigSpec->new_from_file($input_file);
        ok($spec->sticky, 'sticky set to one results in sticky spec')
    }
};

subtest 'new_from_file: non-existant validator' => sub {
    plan tests => 1;

    my %data = (
        env => 'XGENOME_FOO',
        validators => [qw(numeric zzzzzzz)],
        default_value => 1,
    );
    my ($input_fh, $input_file, $input_filename) = setup_yaml_file({ %data });
    my $ex = exception { Genome::ConfigSpec->new_from_file($input_file) };
    like($ex, qr/failed to load validator/, 'failed to load validator');
};

sub setup_yaml_file {
    my $data = shift;

    my $fh = File::Temp->new();
    my $file = $fh->filename;
    my $filename = (File::Spec->splitpath($file))[2];

    $fh->print(YAML::Syck::Dump($data));
    $fh->flush();

    return ($fh, $file, $filename);
}
