#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/.."; #location of includes.pm
use includes; #file with paths to PsN packages

use model::problem::estimation;
use model::problem::table;
use model::problem::problem;
use model;

our $tempdir = create_test_dir('unit_updateinits');
my $modeldir = $includes::testfiledir;

my $est = model::problem::estimation->new(record_arr => ['MAXEV=99 MSFO=msf23', 'ANY=SOUP']);
is ($est->options->[1]->value, 'msf23', "est msf before");

$est->renumber_msfo (numberstring => '44');
is ($est->options->[1]->value, 'msf44', "est msf after");

my $tab = model::problem::table->new(record_arr => ['ID DV MDV NOPRINT ONHEADER NOAPPEND FILE=patab01']);
is ($tab->options->[6]->value, 'patab01', "tab before");

$tab->renumber_file (numberstring => '6');
is ($tab->options->[6]->value, 'patab6', "tab after");

$tab = model::problem::table->new(record_arr => ['ID DV MDV NOPRINT ONHEADER FILE=mytab55.csv NOAPPEND']);
is ($tab->options->[5]->value, 'mytab55.csv', "tab csv before");

$tab->renumber_file (numberstring => '09');
is ($tab->options->[5]->value, 'mytab09.csv', "tab csv after");

$tab = model::problem::table->new(record_arr => ['ID DV MDV NOPRINT','FILE=tab55a.csv']);
is ($tab->options->[4]->value, 'tab55a.csv', "tab num-letter before");

$tab->renumber_file (numberstring => '09');
is ($tab->options->[4]->value, 'tab09a.csv', "tab num-letter after");

my $prob = model::problem::problem->new(record_arr => ['$PROBLEM']);

$prob->add_comment(new_comment => 'added comment');
my $ref = $prob -> _format_record;
my @arr = split("\n",$ref->[0],2);
is ($arr[1],';added comment'."\n",'problem add comment');

$prob = model::problem::problem->new(record_arr => ['$PROBLEM DESCRIPTION']);

$prob->add_comment(new_comment => 'added comment');
my $ref = $prob -> _format_record;
my @arr = split("\n",$ref->[0],2);
is ($arr[1],';added comment'."\n",'problem add comment');


my $model = model->new(filename => "$modeldir/mox1.mod");

my $ref = $model-> get_hash_values_to_labels;

#arr over problems, hash omega sigma theta
is ($ref->[0]->{'theta'}->{'TVCL'},26.1,'TVCL');
is ($ref->[0]->{'theta'}->{'TVV'},100,'TVV');
is ($ref->[0]->{'theta'}->{'TVKA'},4.5,'TVKA');
is ($ref->[0]->{'theta'}->{'LAG'},0.2149,'LAG');
is ($ref->[0]->{'sigma'}->{'SIGMA(1,1)'},0.109,'SIGMA(1,1)');
is (eval($ref->[0]->{'omega'}->{'OMEGA(1,1)'}),eval(0.0750),'OMEGA(1,1)');
is ($ref->[0]->{'omega'}->{'OMEGA(2,1)'},0.0467,'OMEGA(2,1)');
is ($ref->[0]->{'omega'}->{'IIV (CL-V)'},0.0564,'OMEGA(2,2)');
is ($ref->[0]->{'omega'}->{'IIV KA'},2.82,'OMEGA(3,3)');
is ($ref->[0]->{'omega'}->{'IOV CL'},0.0147,'OMEGA(4,4)');
is ($ref->[0]->{'omega'}->{'IOV KA'},0.506,'OMEGA(6,6)');

#modify hash, then use in update_inits and check that got what is expected
$ref->[0]->{'theta'}->{'TVCL'} = 20;
$ref->[0]->{'theta'}->{'TVV'} = 90;
$ref->[0]->{'theta'}->{'TVKA'} = 5;
$ref->[0]->{'theta'}->{'LAG'} = 0.4;
$ref->[0]->{'sigma'}->{'SIGMA(1,1)'}= 0.2;
$ref->[0]->{'omega'}->{'OMEGA(1,1)'} = 0.4;
$ref->[0]->{'omega'}->{'OMEGA(2,1)'}= 0.01;
$ref->[0]->{'omega'}->{'IIV (CL-V)'} = 0.05;
$ref->[0]->{'omega'}->{'IIV KA'}= 3;
$ref->[0]->{'omega'}->{'IOV CL'}= 0.01;
$ref->[0]->{'omega'}->{'IOV KA'}= 0.5;


$model -> update_inits( from_hash => $ref->[0],
						problem_number => 1,
						ensure_diagonal_dominance => 0,
						ignore_missing_parameters => 0 );

my $updated = $model-> get_hash_values_to_labels;

is(eval($updated->[0]->{'theta'}->{'TVCL'}),eval(20),'updated hash TVCL');
is(eval($updated->[0]->{'theta'}->{'TVV'}),eval(90),'updated hash TVV');
is(eval($updated->[0]->{'theta'}->{'TVKA'}),eval(5),'updated hash TVKA');
is(eval($updated->[0]->{'theta'}->{'LAG'}),eval(0.4),'updated hash LAG');
is(eval($updated->[0]->{'sigma'}->{'SIGMA(1,1)'}),eval(0.2),'updated hash SIGMA');
is(eval($updated->[0]->{'omega'}->{'OMEGA(1,1)'}),eval(0.4),'updated hash OM 1,1');
is(eval($updated->[0]->{'omega'}->{'OMEGA(2,1)'}),eval(0.01),'updated hash Om 2,1');
is(eval($updated->[0]->{'omega'}->{'IIV (CL-V)'}),eval(0.05),'updated hash IIV CL-V');
is(eval($updated->[0]->{'omega'}->{'IIV KA'}),eval(3),'updated hash IIV KA');
is(eval($updated->[0]->{'omega'}->{'IOV CL'}),eval(0.01),'updated hash IOV CL');
is(eval($updated->[0]->{'omega'}->{'IOV KA'}),eval(0.5),'updated hash IOV KA');

copy_test_files($tempdir,["pheno.mod", "pheno.lst",'mox1.lst','mox1.mod']);


my %hash;
$hash{'theta'}->{'THETA1'}=1;
$hash{'theta'}->{'THETA2'}=2;
$hash{'theta'}->{'THETA3'}=3;
$hash{'theta'}->{'THETA4'}=4;
$hash{'omega'}={};
$hash{'sigma'}={};

$model -> update_inits( from_hash => \%hash,
						problem_number => 1,
						match_labels => 0,
						ensure_diagonal_dominance => 0,
						ignore_missing_parameters => 1 );

my $updated = $model-> get_hash_values_to_labels;

is(eval($updated->[0]->{'theta'}->{'TVCL'}),eval(1),'updated hash 2 TVCL');
is(eval($updated->[0]->{'theta'}->{'TVV'}),eval(2),'updated hash 2 TVV');
is(eval($updated->[0]->{'theta'}->{'TVKA'}),eval(3),'updated hash 2 TVKA');
is(eval($updated->[0]->{'theta'}->{'LAG'}),eval(4),'updated hash 2 LAG');


chdir($tempdir);
my @command_line = (
	get_command("update_inits") . " pheno.mod -out=run1.mod",
	get_command("update_inits") . " pheno.mod -out=run2.mod -comment=\"new comment\"",
	get_command("update_inits") . " mox1.mod -out=run3.mod",
	get_command("update") . " mox1.mod -out=run4.mod -add_tags"
);
foreach my $i (0..$#command_line) {
	my $command= $command_line[$i];
	print "Running $command\n";
	my $rc = system($command);
	$rc = $rc >> 8;
	ok ($rc == 0, "$command, should run ok");
}
chdir('..');

remove_test_dir($tempdir);




done_testing();
