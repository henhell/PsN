#!/etc/bin/perl

use strict;
use warnings;
use File::Path 'rmtree';
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../.."; #location of includes.pm
use includes; #file with paths to PsN packages and $path variable definition
use File::Copy 'cp';

our $tempdir = create_test_dir;
our $dir = "$tempdir/Simultaneous_test";
my $model_dir = "$Bin/Simultaneous";
my @needed = <$model_dir/*>;
mkdir($dir);
foreach my $file (@needed){
	cp($file,$dir.'/.');
}
chdir($dir);

my @command_list=(
	[$includes::execute." run81.mod  -model_dir_name","task 1 of 2"],
	[$includes::vpc." run81.mod -tte=RTTE -flip_comments -samples=20 -compress -clean=3 -stratify_on=FLG,DV1,TRET,HR,CONC,CE,AGE,SEX,WT,CRCL"
 ,"task 2 of 2"]
	);
plan tests => scalar(@command_list);

foreach my $ref (@command_list){
	my $command=$ref->[0];
	my $comment=$ref->[1];
	print "Running $comment:\n$command\n";
	my $rc = system($command);
	$rc = $rc >> 8;
	ok ($rc == 0, "$comment ");
}

remove_test_dir;

done_testing();
