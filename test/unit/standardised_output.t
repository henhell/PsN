#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/.."; #location of includes.pm
use includes; #file with paths to PsN packages
use data;

SKIP: {
    eval { require XML::LibXML };
    skip "XML::LibXML not installed" if $@;

    require standardised_output;
    require standardised_output::xml;
    require standardised_output::so;

    sub get_xml
    {
        my $filename = shift;

        my $doc = XML::LibXML->load_xml(location => $filename);
        my $xpc = XML::LibXML::XPathContext->new($doc);
        $xpc->registerNs('x' => 'http://www.pharmml.org/so/0.1/StandardisedOutput');

        return $xpc;
    }

    sub test_number_of_children
    {
        my $xpc = shift;
        my $xpath = shift;
        my $number = shift;
        my $text = shift;

        my @nodes = $xpc->findnodes($xpath);
        is (scalar(@nodes), $number, $text);
    }

    our $tempdir = create_test_dir('unit_standardised_output');
    copy_test_files($tempdir,
        [ "output/special_mod/data_missing.lst", "output/special_mod/missingmodel.lst", "output/special_mod/psnmissingdata.out", "output/special_mod/psnmissingmodel.out", "SO/bootstrap_results.csv", "SO/pheno.lst", "SO/patab", "SO/sdtab" ]);

    chdir $tempdir;

# _get_included_columns
    is_deeply (standardised_output::_get_included_columns(header => { ID => 1, TIME => 2, WT => 3, AMT => 4 }, columns => [ 'WT', 'TIME', 'SNOW' ]),
        [ 'WT', 'TIME' ], "_get_included_columns");

# _get_remaining_columns
    is_deeply (standardised_output::_get_remaining_columns(header => { ID => 1, TIME => 2, WT => 3, AMT => 4 }, columns => [ 'ID', 'WT' ]),
        [ 'TIME', 'AMT' ], "_get_remaining_columns");

# non existing lst file
    my $so = standardised_output->new(lst_files => [ "this_file_is_missing.lst" ]);
    $so->parse;
    my $xpc = get_xml("this_file_is_missing.SO.xml");
    (my $node) = $xpc->findnodes('/x:SO/x:SOBlock/x:TaskInformation/x:Message[@type="ERROR"]');
    ok (defined $node, "missing lst file");
    test_number_of_children($xpc, '/x:SO/x:SOBlock/*', 1, "missing lst file nothing more than TaskInformation");

# non existing multiple lst file
    my $so = standardised_output->new(lst_files => [ "this_file_is_missing.lst", "this_too.lst" ]);
    $so->parse;
    my $xpc = get_xml("this_file_is_missing.SO.xml");
    (my $node1, my $node2) = $xpc->findnodes('/x:SO/x:SOBlock/x:TaskInformation/x:Message[@type="ERROR"]');
    ok (defined $node1, "multiple non existing lst files 1");
    ok (defined $node2, "multiple non existing lst files 2");
    test_number_of_children($xpc, '/x:SO/x:SOBlock', 2, "multiple non existing lst files number of SOBlocks");
    test_number_of_children($xpc, '/x:SO/x:SOBlock/*', 2, "multiple non existing lst files nothing more than TaskInformation");

# missingdata.lst
    my $so = standardised_output->new(lst_files => [ "data_missing.lst" ]);
    $so->parse;
    my $xpc = get_xml("data_missing.SO.xml");
    (my $node) = $xpc->findnodes('/x:SO/x:SOBlock/x:TaskInformation/x:Message[@type="ERROR"]');
    ok (defined $node, "data_missing.lst");
    test_number_of_children($xpc, '/x:SO/x:SOBlock/*', 2, "data_missing.lst nothing more than TaskInformation+RawResults"); 

# missingmodel.lst
    my $so = standardised_output->new(lst_files => [ "missingmodel.lst" ]);
    $so->parse;
    my $xpc = get_xml("missingmodel.SO.xml");
    (my $node) = $xpc->findnodes('/x:SO/x:SOBlock/x:TaskInformation/x:Message[@type="ERROR"]');
    ok (defined $node, "missingmodel.lst");
    test_number_of_children($xpc, '/x:SO/x:SOBlock/*', 2, "missingmodel.lst nothing more than TaskInformation+RawResults"); 

# psnmissingdata.out
    my $so = standardised_output->new(lst_files => [ "psnmissingdata.out" ]);
    $so->parse;
    my $xpc = get_xml("psnmissingdata.SO.xml");
    (my $node) = $xpc->findnodes('/x:SO/x:SOBlock/x:TaskInformation/x:Message[@type="ERROR"]');
    ok (defined $node, "psnmissingdata.out");
    test_number_of_children($xpc, '/x:SO/x:SOBlock/*', 2, "psnmissingdata.out nothing more than TaskInformation");

# psnmissingmodel.out
    my $so = standardised_output->new(lst_files => [ "psnmissingmodel.out" ]);
    $so->parse;
    my $xpc = get_xml("psnmissingmodel.SO.xml");
    (my $node) = $xpc->findnodes('/x:SO/x:SOBlock/x:TaskInformation/x:Message[@type="ERROR"]');
    ok (defined $node, "psnmissingmodel.out");
    test_number_of_children($xpc, '/x:SO/x:SOBlock/*', 2, "psnmissingmodel.out nothing more than TaskInformation");

# bootstrap_results with no lst-files
    my $so = standardised_output->new(bootstrap_results => "bootstrap_results.csv");
    $so->parse;
    my $xpc = get_xml("bootstrap.SO.xml");
    (my $node) = $xpc->findnodes('/x:SO/x:SOBlock/x:Estimation/x:PrecisionPopulationEstimates/x:Bootstrap');
    ok (defined $node, "lone bootstrap");
    test_number_of_children($xpc, '/x:SO/x:SOBlock/x:Estimation/*', 1, "lone bootstrap nothing more than Bootstrap");

# add info message
    my $so = standardised_output->new(lst_files => [ "missingmodel.lst" ], message => "Testing");
    $so->parse;
    my $xpc = get_xml("missingmodel.SO.xml");
    my @nodes = $xpc->findnodes('/x:SO/x:SOBlock/x:TaskInformation/x:Message[@type="INFORMATION"]');
    is (scalar(@nodes), 2, "information message");  # 2 for counting the version message

# set toolname
    my $so = standardised_output->new(lst_files => [ "missingmodel.lst" ], toolname => "MyTool");
    $so->parse;
    my $xpc = get_xml("missingmodel.SO.xml");
    (my $node) = $xpc->findnodes('/x:SO/x:SOBlock/x:TaskInformation/x:Message[@type="ERROR"]/x:Toolname/ct:String');
    is ($node->textContent, "MyTool", "Toolname");

# normal model pheno.lst
    my $so = standardised_output->new(lst_files => [ "pheno.lst" ]);
    $so->parse;
    my $xpc = get_xml("pheno.SO.xml");

    my @nodes = $xpc->findnodes('/x:SO/x:SOBlock/x:Estimation/*');
    my %hash;
    my %results_hash = (
        PopulationEstimates => 1,
        PrecisionPopulationEstimates => 1,
        IndividualEstimates => 1,
        Predictions => 1,
        Residuals => 1,
        Likelihood => 1,
    );

    foreach $node (@nodes) {
        $hash{$node->nodeName} = 1;
    }

    is_deeply(\%hash, \%results_hash, "pheno.lst has all elements under Estimation");

# exclude_elements
    my $so = standardised_output->new(lst_files => [ "pheno.lst" ], exclude_elements => [ 'Estimation/PopulationEstimates', 'Estimation/Likelihood' ] );
    $so->parse;
    my $xpc = get_xml("pheno.SO.xml");

    my @nodes = $xpc->findnodes('/x:SO/x:SOBlock/x:Estimation/*');
    my %hash;
    my %results_hash = (
        PrecisionPopulationEstimates => 1,
        IndividualEstimates => 1,
        Predictions => 1,
        Residuals => 1,
    );

    foreach $node (@nodes) {
        $hash{$node->nodeName} = 1;
    }

    is_deeply(\%hash, \%results_hash, "pheno.lst with exlution has all elements under Estimation");

# only_include_elements
    my $so = standardised_output->new(lst_files => [ "pheno.lst" ], only_include_elements => [ 'Estimation/PopulationEstimates', 'Estimation/Likelihood' ] );
    $so->parse;
    my $xpc = get_xml("pheno.SO.xml");

    my @nodes = $xpc->findnodes('/x:SO/x:SOBlock/x:Estimation/*');
    my %hash;
    my %results_hash = (
        PopulationEstimates => 1,
        Likelihood => 1,
    );

    foreach $node (@nodes) {
        $hash{$node->nodeName} = 1;
    }

    is_deeply(\%hash, \%results_hash, "pheno.lst with only_include_elements has all elements under Estimation");

# no-use_tables
    my $so = standardised_output->new(lst_files => [ "pheno.lst" ], use_tables => 0);
    $so->parse;
    my $xpc = get_xml("pheno.SO.xml");

    my @nodes = $xpc->findnodes('/x:SO/x:SOBlock/x:Estimation/*');
    my %hash;
    my %results_hash = (
        PopulationEstimates => 1,
        PrecisionPopulationEstimates => 1,
        Likelihood => 1,
    );

    foreach $node (@nodes) {
        $hash{$node->nodeName} = 1;
    }

    is_deeply(\%hash, \%results_hash, "pheno.lst with no-use_tables has all elements under Estimation");



# option pharmml
    my $so = standardised_output->new(pharmml => 'test.xml', lst_files => [ "pheno.lst" ]);
    $so->parse;
    my $xpc = get_xml("pheno.SO.xml");
    (my $node) = $xpc->findnodes('/x:SO/x:PharmMLRef[@name]');
    ok (defined $node, "PharmMLRef");

    my $so = standardised_output->new(lst_files => [ "pheno.lst" ]);
    $so->parse;
    my $xpc = get_xml("pheno.SO.xml");
    (my $node) = $xpc->findnodes('/x:SO/x:PharmMLRef[@name]');
    ok (!defined $node, "PharmMLRef");

# Using so.pm
    my $standardised_output = standardised_output->new(lst_files => [ "pheno.lst" ], use_tables => 0);
    $standardised_output->parse;
    my $so = standardised_output::so->new(filename => "pheno.SO.xml");

    is (scalar(@{$so->SOBlock}), 1, "Pheno: number of SOBlocks");
    is ($so->SOBlock->[0]->blkId, 'pheno', "Pheno: name of SOBlock");

    is_deeply($so->SOBlock->[0]->PopulationEstimates->columnId, [ 'CL', 'V', 'IVCL', 'IVV', 'SIGMA_1_1_' ], "Pheno: PopulationEstimates names");
    is_deeply($so->SOBlock->[0]->PopulationEstimates->columnType, [ ('undefined') x 5 ], "Pheno: PopulationEstimates column types");
    is_deeply($so->SOBlock->[0]->PopulationEstimates->valueType, [ ('real') x 5 ], "Pheno: PopulationEstimates value types");
    is_deeply($so->SOBlock->[0]->PopulationEstimates->columns, [ [0.00555], [1.34], [0.247], [0.142], [0.0164] ], "Pheno: PopulationEstimates columns");

    is_deeply($so->SOBlock->[0]->StandardError->columnId, [ 'parameter', 'SE' ], "Pheno: StandardError names");
    is_deeply($so->SOBlock->[0]->StandardError->columnType, [ ('undefined') x 2 ], "Pheno: StandardError column types");
    is_deeply($so->SOBlock->[0]->StandardError->valueType, [ 'string', 'real' ], "Pheno: StandardError value types");
    is_deeply($so->SOBlock->[0]->StandardError->columns, [ [ 'CL', 'V', 'IVCL', 'IVV', 'SIGMA_1_1_' ], [ 0.000395, 0.0799, 0.156, 0.0349, 0.00339 ]  ], "Pheno: StandardError columns");

    is_deeply($so->SOBlock->[0]->RelativeStandardError->columnId, [ 'parameter', 'RSE' ], "Pheno: RelativeStandardError names");
    is_deeply($so->SOBlock->[0]->RelativeStandardError->columnType, [ ('undefined') x 2 ], "Pheno: RelativeStandardError column types");
    is_deeply($so->SOBlock->[0]->RelativeStandardError->valueType, [ 'string', 'real' ], "Pheno: RelativeStandardError value types");
    is_deeply($so->SOBlock->[0]->RelativeStandardError->columns, [ [ 'CL', 'V', 'IVCL', 'IVV', 'SIGMA_1_1_' ], [ 0.07117117117, 0.05962686567, 0.6315789474, 0.2457746479, 0.2067073171 ]  ], "Pheno: RelativeStandardError columns");

    is($so->SOBlock->[0]->Deviance, 742.051, "Pheno: Deviance");

    is(scalar(@{$so->SOBlock->[0]->DataFile}), 1, "Pheno: Number of RawResults files");
    is($so->SOBlock->[0]->DataFile->[0]->{path}, "pheno.lst", "Pheno: Name of lst file");

    is_deeply($so->SOBlock->[0]->CovarianceMatrix->RowNames,  [ 'CL', 'V', 'IVCL', 'IVV', 'SIGMA_1_1_' ], "Pheno: CovarianceMatrix RowNames");
    is_deeply($so->SOBlock->[0]->CovarianceMatrix->ColumnNames,  [ 'CL', 'V', 'IVCL', 'IVV', 'SIGMA_1_1_' ], "Pheno: CovarianceMatrix ColumnNames");
    is_deeply($so->SOBlock->[0]->CovarianceMatrix->MatrixRow, [
        [ 1.56e-07, 4.58e-06, -2.72e-05, 3.56e-06, 7.25e-08 ],
        [ 4.58e-06, 0.00638, -0.00193, 0.00128, 2.13e-05 ],
        [ -2.72e-05, -0.00193, 0.0242, -0.000992, 7.08e-05 ],
        [ 3.56e-06, 0.00128, -0.000992, 0.00122, -5.33e-07 ],
        [ 7.25e-08, 2.13e-05, 7.08e-05, -5.33e-07, 1.15e-05 ] ], "Pheno: CovarianceMattrix MatrixRow");

    is_deeply($so->SOBlock->[0]->CorrelationMatrix->RowNames,  [ 'CL', 'V', 'IVCL', 'IVV', 'SIGMA_1_1_' ], "Pheno: CorrelationMatrix RowNames");
    is_deeply($so->SOBlock->[0]->CorrelationMatrix->ColumnNames,  [ 'CL', 'V', 'IVCL', 'IVV', 'SIGMA_1_1_' ], "Pheno: CorrelationMatrix ColumnNames");
    is_deeply($so->SOBlock->[0]->CorrelationMatrix->MatrixRow, [
          [ 0.000395, 0.145, -0.444, 0.258, 0.0541 ],
          [ 0.145, 0.0799, -0.155, 0.46, 0.0784 ],
          [ -0.444, -0.155, 0.156, -0.183, 0.134 ],
          [ 0.258, 0.46, -0.183, 0.0349, -0.0045 ],
          [ 0.0541, 0.0784, 0.134, -0.0045, 0.00339 ] ], "Pheno CorrelationMatrix MatrixRow");

    unlink "pheno.SO.xml";
    my $standardised_output = standardised_output->new(lst_files => [ "pheno.lst" ], use_tables => 1);
    $standardised_output->parse;
    my $so = standardised_output::so->new(filename => "pheno.SO.xml");

    $so->SOBlock->[0]->create_sdtab(filename => 'sdtab.out');

    my $sdtab_out = data->new(
        filename => 'sdtab.out',
        ignoresign => '@',
        parse_header => 1,
    );

    my $sdtab = data->new(
        filename => 'sdtab',
        ignoresign => '@',
        parse_header => 1,
    );

    foreach my $colname (@{$sdtab_out->header}) {
        my $col = $sdtab->column_to_array(column => $colname); 
        my $col2 = $sdtab_out->column_to_array(column => $colname); 
        is_deeply($col, $col2, "Pheno sdtab $colname");
    }

# pheno.lst without sdtab
    unlink("sdtab");
    my $so = standardised_output->new(lst_files => [ "pheno.lst" ]);
    $so->parse;
    my $xpc = get_xml("pheno.SO.xml");

    my @nodes = $xpc->findnodes('/x:SO/x:SOBlock/x:Estimation/*');
    my %hash;
    my %results_hash = (
        PopulationEstimates => 1,
        PrecisionPopulationEstimates => 1,
        IndividualEstimates => 1,
        Likelihood => 1,
    );

    foreach $node (@nodes) {
        $hash{$node->nodeName} = 1;
    }

    is_deeply(\%hash, \%results_hash, "pheno.lst without sdtab has all elements under Estimation");

# pheno.lst without sdtab and patab
    unlink("patab");
    my $so = standardised_output->new(lst_files => [ "pheno.lst" ]);
    $so->parse;
    my $xpc = get_xml("pheno.SO.xml");

    my @nodes = $xpc->findnodes('/x:SO/x:SOBlock/x:Estimation/*');
    my %hash;
    my %results_hash = (
        PopulationEstimates => 1,
        PrecisionPopulationEstimates => 1,
        Likelihood => 1,
    );

    foreach $node (@nodes) {
        $hash{$node->nodeName} = 1;
    }

    is_deeply(\%hash, \%results_hash, "pheno.lst without sdtab and patab has all elements under Estimation");

    remove_test_dir($tempdir);

}

done_testing();
