#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use above 'Genome';
use Genome::Disk::Allocation;
use File::Temp;
use File::Path;
use Filesys::Df;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use_ok('Genome::Disk::Command::Allocation::CreateForExistingData') or die;

test_path_exists_but_not_gscmnt();
test_path_is_gscmnt_but_does_not_exist();
test_path_exists_but_is_link();

test_get_and_validate_group();
test_get_and_validate_volume();

test_nonunique_allocation_path();
test_successful_allocation_create();

done_testing();

################
# Methods for creating test objects
################

sub create_test_command {
    my ($target_path, $volume_prefix, $owner_class_name, $owner_id) = @_;
    $volume_prefix ||= '/gscmnt';
    $owner_class_name ||= 'Genome::Sys::User';
    $owner_id ||= $ENV{USER} . '@genome.wustl.edu';
    return Genome::Disk::Command::Allocation::CreateForExistingData->create(
        target_path => $target_path,
        owner_class_name => $owner_class_name,
        owner_id => $owner_id,
        volume_prefix => $volume_prefix,
    );
}

sub create_test_group {
    my ($group_name, $subdir) = @_;
    die "create_test_group method requires a group_name!" unless $group_name;
    die "create_test_group method requires a subdirectory!" unless $subdir;
    return Genome::Disk::Group->create(
        disk_group_name => $group_name,
        permissions => '755',
        sticky => '1',
        subdirectory => $subdir,
        unix_uid => 0,
        unix_gid => 0,
    );
}

sub create_test_volume {
    my ($mount_path) = @_;
    die "create_test_volume method requires a mount path!" unless $mount_path;
    return Genome::Disk::Volume->create(
        hostname => 'foo',
        physical_path => 'foo/bar',
        mount_path => $mount_path,
        total_kb => Filesys::Df::df($mount_path)->{blocks},
        disk_status => 'active',
        can_allocate => '1',
    );
}

sub create_test_volume_with_group {
    my ($mount_path, $group) = @_;
    die "create_test_volume_with_group method requires a group be provided!" unless $group;
    my $volume = create_test_volume($mount_path);
    die "Could not create test volume with mount path $mount_path" unless $volume;
    my $assignment = Genome::Disk::Assignment->create(
        dv_id => $volume->id,
        dg_id => $group->id,
    );
    return $volume;
}

sub create_test_dir {
    my ($dir_name, $group_name, $create_paths) = @_;
    die 'create_test_path method requires a directory name be provided!' unless $dir_name;
    $group_name ||= 'testing_group';
    $create_paths = 1 unless defined $create_paths;

    my $group = create_test_group($group_name, 'test');
    ok($group, "created test group $group_name");
    is($group->disk_group_name, $group_name, 'group has expected name');
    is($group->subdirectory, 'test', 'group has expected subdirectory');

    my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
    my $volume = create_test_volume_with_group($tmpdir, $group);
    ok($volume, "created test volume with mount path $tmpdir");
    is($volume->disk_group_names, $group->disk_group_name, 'volume is assigned to a disk group');

    my $group_dir = join('/', $volume->mount_path, $group->subdirectory);
    mkdir($group_dir);
    ok(-e $group_dir, "created group directory at $group_dir");

    my $dir = join('/', $volume->mount_path, $group->subdirectory, $dir_name);

    my @files;
    if ($create_paths) {
        File::Path::mkpath($dir);
        ok(-e $dir, "created test allocation path at $dir");

        @files = qw/ a b c /;
        for my $file (@files) {
            my $file_path = join('/', $dir, $file);
            system("touch $file_path");
            ok(-e $file_path, "file created at $file_path");
        }
    }

    return ($dir, $volume, $group, \@files);
}

sub contents_match {
    my ($dir, $files) = @_;
    die "contents_match method must be given a directory!" unless $dir;
    my @contents = grep { $_ ne '.' and $_ ne '..' } glob("$dir/*");
    return is_deeply(\@contents, $files, "directory $dir has expected contents");
}

################
# Test methods
################

sub test_path_exists_but_not_gscmnt {
    my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
    ok(-e $tmpdir, "temp path $tmpdir exists");

    my $cmd = create_test_command($tmpdir);
    ok($cmd, 'created test command');

    my $kb = eval { $cmd->_validate_and_get_size_of_path };
    my $error = $@;
    ok(!$error, "no error when validating existing path");
    ok(defined $kb, "got size in kb returned ($kb), as expected");

    my ($mount, $group_subdir, $allocation_path) = eval { $cmd->_parse_path };
    $error = $@;
    ok($error =~ /Could not determine mount path, group subdirectory, or allocation path/,
        "correct error thrown");
    ok(!defined $mount, "failed to parse mount path, as expected");
    ok(!defined $group_subdir, "failed to parse group subdirectory, as expected");
    ok(!defined $allocation_path, "failed to parse allocation path, as expected");

    return 1;
}

sub test_path_is_gscmnt_but_does_not_exist {
    my $path = '/gscmnt/123/group/foo/bar';
    ok(!-e $path, "path $path does not exist, as intended");

    my $cmd = create_test_command($path);
    ok($cmd, "created test command for non-existent path $path");

    my $kb = eval { $cmd->_validate_and_get_size_of_path };
    my $error = $@;
    ok($error =~ /Path does not exist/, "received expected error when dealing with non-existent path");

    my ($mount, $group_subdir, $allocation_path) = $cmd->_parse_path;
    ok($mount, "parsed mount $mount from " . $cmd->target_path);
    ok($group_subdir, "parsed group subdir $group_subdir from " . $cmd->target_path);
    ok($allocation_path, "parsed allocation path $allocation_path from " . $cmd->target_path);

    return 1;
}

sub test_path_exists_but_is_link {
    my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

    my $path = "$tmpdir/test";
    my $link = "$tmpdir/link";
    mkdir($path);
    symlink($path, $link);

    ok((-d $path and not -l $path), "path $path is a directory and not a link");
    ok((-d $link and -l $link), "path $link is a directory and a link");

    my $cmd = create_test_command($link);
    ok($cmd, "created test command for link $link");

    my $kb = eval { $cmd->_validate_and_get_size_of_path };
    my $error = $@;
    ok($error =~ /Path is a link/, "received expected error when dealing with link");

    unlink($link);
    unlink($path);

    return 1;
}

sub test_get_and_validate_group {
    my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
    my $cmd = create_test_command($tmpdir);
    ok($cmd, "created test command for group validation");

    my @groups;
    my %group_info = (
        'testing_group' => 'test',
        'foo' => 'bar',
    );

    for my $group_name (keys %group_info) {
        my $group = create_test_group($group_name, $group_info{$group_name});
        ok($group, "created test group with name $group_name for group validation test");
        push @groups, $group;
    }

    my $rv = eval { $cmd->_get_and_validate_group('blah', @groups) };
    my $error = $@;
    ok(!$rv, "no return value when no group found, as expected");
    ok($error, "got an error when no group found, as expected");
    ok($error =~ /No groups found with subdirectory that matches blah/, "error message matches expected pattern");

    $rv = eval { $cmd->_get_and_validate_group('test', @groups) };
    $error = $@;
    ok($rv, "got a return value, as expected");
    is(ref($rv), 'Genome::Disk::Group', 'return value is an object of type Genome::Disk::Group');
    is($rv->disk_group_name, 'testing_group', 'got expected group back');
    ok(!$error, 'no error');

    return 1;
}

sub test_get_and_validate_volume {
    my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
    my $cmd = create_test_command($tmpdir);

    my $volume = create_test_volume($tmpdir);
    ok($volume, "created test volume with mount path $tmpdir");

    my $rv = eval { $cmd->_get_and_validate_volume('blah') };
    my $error = $@;
    ok(!$rv, 'got no return value when attempting to validate non-existent volume, as expected');
    ok($error, 'got an error validating non-existent volume, as expected');
    ok($error =~ /Found no allocatable and active volume with mount path blah/, 'error message matches expected pattern');

    $rv = eval { $cmd->_get_and_validate_volume($tmpdir) };
    $error = $@;
    ok($rv, 'got a return value when volume found');
    is(ref($rv), 'Genome::Disk::Volume', 'return value is an object of type Genome::Disk::Volume');
    is($rv->mount_path, $tmpdir, 'return value has expected mount path');

    $volume->disk_status('inactive');
    $rv = eval { $cmd->_get_and_validate_volume($tmpdir) };
    $error = $@;
    ok(!$rv, 'got no return value when attempting to validate inactive volume, as expected');
    ok($error, 'got an error validating inactive volume, as expected');
    ok($error =~ /Found no allocatable and active volume with mount path $tmpdir/, 'error message matches expected pattern');

    $volume->disk_status('active');
    $volume->can_allocate(0);
    $rv = eval { $cmd->_get_and_validate_volume($tmpdir) };
    $error = $@;
    ok(!$rv, 'got no return value when attempting to validate unallocatable volume, as expected');
    ok($error, 'got an error validating unallocatable volume, as expected');
    ok($error =~ /Found no allocatable and active volume with mount path $tmpdir/, 'error message matches expected pattern');

    return 1;
}

sub test_nonunique_allocation_path {
    my $allocation_path = 'allocation_test/nonunique_path';
    my ($dir, $volume, $group, $files) = create_test_dir($allocation_path, 'nonunique_allocation_test', 0);
    ok($dir, "have test path at $dir");
    ok($volume, "test volume created");
    ok($group, "test group created");
    push @Genome::Disk::Allocation::APIPE_DISK_GROUPS, $group->disk_group_name;

    my $allocation = Genome::Disk::Allocation->create(
        mount_path => $volume->mount_path,
        disk_group_name => $group->disk_group_name,
        kilobytes_requested => 4,
        owner_id => $ENV{USER} . '@genome.wustl.edu',
        owner_class_name => 'Genome::Sys::User',
        allocation_path => 'allocation_test',
    );
    ok($allocation, 'created test allocation');
    my $id = $allocation->id;

    my $cmd = create_test_command($dir, '/tmp');
    ok($cmd, "created test command with target path $dir");

    my $rv = eval { $cmd->_verify_allocation_path($allocation_path) };
    my $error = $@;
    ok(!$rv, "allocation path verification failed (parent allocation), as expected");
    ok(defined $error, "got an error, as expected");
    ok($error =~ /Parent allocation \($id\) found for $allocation_path/, "error message matches expected pattern");

    $allocation->allocation_path("$allocation_path/test");
    $rv = eval { $cmd->_verify_allocation_path($allocation_path) };
    $error = $@;
    ok(!$rv, "allocation path verification failed (child allocation), as expected");
    ok(defined $error, "got an error, as expected");
    ok($error =~ /Child allocation\(s\) found for $allocation_path/, "error message matches expected pattern");

    $allocation->delete;
    $rv = eval { $cmd->_verify_allocation_path($allocation_path) };
    $error = $@;
    is($rv, 1, "allocation path verification succeeded");
    ok(!$error, "no error from allocation path verification");

    return 1;
}

sub test_successful_allocation_create {
    my ($dir, $volume, $group, $files) = create_test_dir('successful_allocation', 'success_test');
    ok($dir, "have test path at $dir");
    ok($volume, "test volume created");
    ok($group, "test group created");
    push @Genome::Disk::Allocation::APIPE_DISK_GROUPS, $group->disk_group_name;

    my $cmd = create_test_command($dir, '/tmp');
    ok($cmd, "created test command with target path $dir");

    is($cmd->execute, 1, 'execute method returned successfully');

    my $allocation = $cmd->allocation;
    ok($allocation, 'got allocation from command');
    is(ref($allocation), 'Genome::Disk::Allocation', 'return allocation is in fact a Genome::Disk::Allocation object');

    is($allocation->absolute_path, $dir, 'allocation absolute path matches target path');

    ok(contents_match($allocation->absolute_path, [ map { $allocation->absolute_path . '/' . $_ } @$files]), 'contents of allocation directory match expected');

    ok(defined $cmd->temp_allocation_path, 'temp allocation path set by command');
    ok(!-e $cmd->temp_allocation_path, 'temp allocation path does not exist, as expected');

    return 1;
}
