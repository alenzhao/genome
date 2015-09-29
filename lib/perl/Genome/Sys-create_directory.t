use strict;
use warnings;

use above "Genome";
use Genome::Utility::Test qw(abort run_ok);

use Fcntl ':mode';
use File::Path qw(make_path);
use List::Util qw(first);
use POSIX qw(getgroups);
use Test::Fatal qw(exception);

use Test::More tests => 12;

do {
    my $umask = umask;

    ok(getgrnam(Genome::Config::get('sys_group')), 'sys_group is set to existing group') or abort;

    my $sys_group = first { $_ eq Genome::Config::get('sys_group') } get_group_names();
    ok($sys_group, "user belongs to sys_group ($sys_group)") or abort;

    my $test_group = first { $_ ne $sys_group } get_group_names();
    ok($test_group, "user belongs to some other group besides sys_group ($sys_group)");

    # setup
    my $td_path = File::Temp->newdir();
    ok(-d $td_path, 'made a temp directory to work in') or abort;
    run_ok(['chown', ":$test_group", $td_path], "chown that directory to :$test_group") or abort;
    run_ok(['chmod', 2775, $td_path], 'chmod that directory to have guid sticky') or abort;

    # make sure create_directory overrides umask
    my $cd_path = File::Spec->join($td_path, 'cd');
    Genome::Sys->create_directory($cd_path);
    ok(-d $cd_path, 'made a subdirectory');
    is(gid($cd_path), Genome::Sys::gidgrnam($sys_group), 'created directory has expected gid');

    # verify mkdir, without overrides create_directory has, does not
    my $mkdir_path = File::Spec->join($td_path, 'mkdir');
    mkdir $mkdir_path;
    ok(-d $mkdir_path, 'made a subdirectory');
    is(gid($mkdir_path), Genome::Sys::gidgrnam($test_group), 'created directory has expected gid');
};

# We had builds fail with a permission error on a directory we expected to
# already exist so assumed that mkdir might check permissions before existence
# but since this passes now we think it was probably just an NFS failure.
subtest 'create_directory with intermediate read-only directory' => sub {
    plan tests => 4;

    my @dir = (File::Temp->newdir(), qw(1 2 3));

    my $ro_dir = File::Spec->join(@dir[0..1]);
    mkdir $ro_dir;

    my $rw_dir = File::Spec->join(@dir[0..2]);
    mkdir $rw_dir;

    is(chmod(0555, $ro_dir), 1, 'set read-only permissions on ro_dir');
    is(chmod(0755, $rw_dir), 1, 'set read-write permissions on rw_dir');

    my $final_dir = File::Spec->join(@dir);
    my $exception = exception { Genome::Sys->create_directory($final_dir) };
    ok(!$exception, 'no exception was thrown') or diag $exception;
    ok(-d $final_dir, 'final directory exists');
};

# We had tests fail due to an intermediate directory not being writable:
#   drwxr-sr-x 3 tabbott info 64K 2014-04-28 14:21 /gscmnt/ams1121/info/model_data/ref_build_aligner_index_data
# This test passes without changes though.
subtest 'intermediate directory is group writable' => sub {
    plan tests => 2;

    my $umask = umask 0022;

    do {
        my @dir = (File::Temp->newdir(), qw(intermediate final));
        my $intermediate_dir = File::Spec->join(@dir[0..1]);
        my $final_dir        = File::Spec->join(@dir);
        Genome::Sys->create_directory($final_dir);
        ok(is_group_writable($intermediate_dir), 'create_directory, ignoring umask, should be group writable');
    };

    do {
        my @dir = (File::Temp->newdir(), qw(intermediate final));
        my $intermediate_dir = File::Spec->join(@dir[0..1]);
        my $final_dir        = File::Spec->join(@dir);
        make_path($final_dir);
        ok(!is_group_writable($intermediate_dir), 'make_path, respecting umask, should not be group writable');
    };

    umask $umask;
};

sub is_group_writable {
    my $path = shift;
    my $mode = (stat($path))[2];
    my $perms = S_IMODE($mode);
    my $group_write = ($perms & S_IWGRP) >> 3;
    return $group_write;
}

sub gid {
    my $path = shift;
    return (stat($path))[5];
}

sub get_group_names {
    return map { (getgrgid($_))[0] } getgroups();
}
