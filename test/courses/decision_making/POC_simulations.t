#!/etc/bin/perl

use strict;
use warnings;
use File::Path 'rmtree';
use Test::More;

use File::Copy 'cp';
use FindBin qw($Bin);
use lib "$Bin/../.."; #location of includes.pm
use includes; #file with paths to PsN packages and $path variable definition

#making sure commands in HO POC_and_dose_finding/Simulations run ok

our $tempdir = create_test_dir;
our $dir = "$tempdir/POC_sim_test";
my $model_dir = "$Bin/HO_POC_simulation_files";
my @needed = <$model_dir/*>;
mkdir($dir);
foreach my $file (@needed) {
	cp($file, $dir . '/.');
}
chdir($dir);

my @command_list=(
	[$includes::execute." run0.mod -model_dir_name","task 1a 1"],
	[$includes::execute." run1.mod -model_dir_name","task 1a 2"],
	[$includes::sumo." run0.lst","task 1b 1"],
	[$includes::sumo." run1.lst","task 1b 2"],
	[$includes::randtest." run1.mod -samples=10 -base_model=run0.mod -random=DOSE -dir=randtest1 ","task 1d"],
	[$includes::vpc." run1.mod -stratify_on=ARM -auto_bin=unique -samples=20 -dir=vpc1","task 2a"],
	[$includes::vpc." run1.mod -stratify_on=ARM  -auto_bin=unique -samples=20 -dir=vpc1CFB -dv=CFB","task 2b"],
	[$includes::bootstrap." run1.mod -samples=20 -dir=boot1 -stratify_on=ARM","task 2c"],
	[$includes::vpc." run1.mod  -auto_bin=unique -stratify_on=ARM -samples=20 -dir=vpc1boot -rawres_in=boot1/raw_results_run1.csv","task 2e"],
	[$includes::vpc." run5.mod  -auto_bin=unique -stratify_on=ARM -samples=20 -dir=vpc5 -rawres_in=boot1/raw_results_run1.csv","task 3a"],
	[$includes::vpc." run5.mod -samples=20 -auto_bin=unique -stratify=ARM -dir=vpc5_NO_PU","task 3b"],
	[$includes::vpc." run5.mod -samples=20 -auto_bin=unique -stratify=ARM -dir=vpc5DD -refstrat=0 -dv=CFB -rawres=boot1/raw_results_run1.csv","task 3d"],
	[$includes::execute." run9.mod -extra_output=fort.50,fort.60 -model_dir_name","task 4b"],
	[$includes::vpc." run9.mod -samples=20 -stratify=ARM -dir=vpc9 -auto_bin=unique","task 4a"]
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
