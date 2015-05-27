use strict;
use warnings;

BEGIN {
    # make sure we don't record usage because of this test
    require Genome::Config;
    Genome::Config::set_env('log_usage', 0);
};
use above 'Genome::Site::TGI::UsageLog';
use Test::More tests => 2;

subtest 'test assumptions' => sub {
    plan tests => 2;
    is(Genome::Config::get('log_usage'), 0, 'log_usage is off initially');
    Genome::Config::set_env('log_usage', '');
    ok(!Genome::Site::TGI::UsageLog::should_record_usage(), 'should_record_usage is false (since UsageLog was already used)');
};

subtest 'test inner record_usage logic' => sub {
    my @cases = (
        ['gmt'    , 'blade14-3-3.gsc.wustl.edu' , 1],
        ['genome' , 'blade14-3-3.gsc.wustl.edu' , 1],
        ['other'  , 'blade14-3-3.gsc.wustl.edu' , 0],
        ['gmt'    , 'linus264.gsc.wustl.edu'    , 1],
        ['genome' , 'linus264.gsc.wustl.edu'    , 1],
        ['other'  , 'linus264.gsc.wustl.edu'    , 1],
    );
    plan tests => scalar(@cases);
    for my $case (@cases) {
        local $0 = $case->[0];

        my $record_usage = 0;
        no warnings 'redefine';
        local *Genome::Site::TGI::UsageLog::hostname = sub { $case->[1] };
        local *Genome::Site::TGI::UsageLog::should_record_usage = sub { 1 };
        local *Genome::Site::TGI::UsageLog::record_usage = sub { $record_usage++ };
        use warnings 'redefine';

        my $expected_record_usage = $case->[2];
        my $name = $case->[0] . ' + ' . $case->[1];

        Genome::Site::TGI::UsageLog->import();
        is($record_usage, $expected_record_usage, $name);
    }
};
