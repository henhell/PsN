# {{{ include

start include statements
use Carp;
use strict;
use File::Copy 'cp';
use data;
use OSspecific;
use tool::llp;
use tool::cdd::jackknife;
use ext::Statistics::Distributions 'udistr', 'uprob';
use Math::Random;
use Data::Dumper;
end include

# }}} include statements

# {{{ new

start new
{

    for my $accessor ('logfile','raw_results_file','raw_nonp_file'){
	my @new_files=();
	my @old_files = @{$this->$accessor};
	for (my $i=0; $i < scalar(@old_files); $i++){
	    my $name;
	    my $ldir;
	    ( $ldir, $name ) =
		OSspecific::absolute_path( $this ->directory(), $old_files[$i] );
	    push(@new_files,$ldir.$name) ;
	}
	$this->$accessor(\@new_files);
    }	

    # If certain ID:s are ignored, this will interfere with bootstrap. Warn user, exit
    #look for synonym
    my $id_synonym;
    $id_synonym = $this ->models()->[0]-> get_option_value(record_name=>'input',
							   option_name=>'ID');
    #we do not look for <synonym>=ID since PsN won't accept it anyway
    #look for ignore/accept of ID/synonym

    my @check_list=();
    my $ignore_list = $this ->models()->[0]-> get_option_value(record_name=>'data',
							       option_name=>'IGNORE',
							       option_index => 'all');
    push (@check_list,@{$ignore_list});
    my $accept_list = $this ->models()->[0]-> get_option_value(record_name=>'data',
							       option_name=>'ACCEPT',
							       option_index => 'all');
    push (@check_list,@{$accept_list});
    my $warning = "Dangerous IGNORE/ACCEPT statement found in \$DATA.\n".
	"Bootstrap program cannot at present safely handle IGNORE or\n".
	"ACCEPT statements involving the ID column, since individuals are\n".
	"renumbered during resampling. ";
    foreach my $igval (@check_list){
	if (($igval =~ /[^a-zA-Z0-9_]+(ID)[^a-zA-Z0-9_]+/ ) ||
	    ($id_synonym && ($igval =~ /[^a-zA-Z0-9_]+($id_synonym)[^a-zA-Z0-9_]+/ ) )){
	    if ($this->allow_ignore_id()){
		print "\nWarning:\n".
		    $warning."It is recommended to edit the datafile\n".
		    "manually instead, before running the bootstrap.\n\n";
	    } else {
		croak($warning."Please edit the datafile ".
			       "manually instead, before running the bootstrap.\n");
	    }
	}
    }

    #warn if code records with ID/synonym detected
    @check_list=();
    my $record_ref = $this ->models()->[0]-> record(record_name => 'pk' );	
    push (@check_list, @{$this ->models()->[0]-> pk})
	if ( scalar(@{$record_ref}) > 0 );
    
    $record_ref = $this ->models()->[0]-> record(record_name => 'pred' );
    push (@check_list,@{$this ->models()->[0]-> pred})
	if ( scalar(@{$record_ref}) > 0 );
    
    $record_ref = $this ->models()->[0] -> record(record_name => 'error' );
    push (@check_list,@{$this ->models()->[0]-> problems->[0]->errors->[0]->code})
	if ( scalar(@{$record_ref}) > 0 );
	
    foreach my $line (@check_list){
	next if ($line =~ /^\s*;/); #skip comments
	if (($line =~ /(^|[^a-zA-Z0-9_]+)ID([^a-zA-Z0-9_]+|$)/ ) ||
	    ($id_synonym && ($line =~ /(^|[^a-zA-Z0-9_]+)($id_synonym)([^a-zA-Z0-9_]+|$)/ ) )){
	    print "\nWarning:\nID/ID-synonym found in \$PK/\$PRED/\$ERROR.\n".
		"Bootstrap script renumbers individuals, which means that code\n".
		"based on ID-value might not give the expected results.\n\n";
	    last;
	}
    }
    
}
end new

# }}} new


# {{{ modelfit_setup

start modelfit_setup
      {

	$self -> general_setup( model_number => $model_number,
				class        => 'tool::modelfit');
      }
end modelfit_setup

# }}}

# {{{ general_setup

start general_setup
{	
    my $subm_threads = $self->threads();
    my $own_threads = $self ->threads();
    # More threads than models?
    my $num = scalar @{$self ->models()};
    $own_threads = $num if ( $own_threads > $num );

    my $model = $self ->models() -> [$model_number-1];

	# Check which models that hasn't been run and run them This
	# will be performed each step but will only result in running
	# models at the first step, if at all.

	# If more than one process is used, there is a VERY high risk
	# of interaction between the processes when creating
	# directories for model fits. Therefore the directory
	# attribute is given explicitly below.

	# ------------------------  Run original run  -------------------------------

	# {{{ orig run

	unless ( $model -> is_run ) {
	  my %subargs = ();
	  if ( defined $self -> subtool_arguments() ) {
	    %subargs = %{$self -> subtool_arguments()};
	  }

	  if( $self -> nonparametric_etas() or
	      $self -> nonparametric_marginals() ) {
	    $model -> add_nonparametric_code;
	  }
	  

	  my $orig_fit = tool::modelfit ->
	      new( %{common_options::restore_options(@common_options::tool_options)},
		   base_directory	 => $self ->directory(),
		   directory		 => $self ->directory().
		   '/orig_modelfit_dir'.$model_number,
		   models		 => [$model],
		   threads               => $subm_threads,
		   parent_threads        => $own_threads,
		   parent_tool_id        => $self -> tool_id(),
		   logfile	         => undef,
		   raw_results           => undef,
		   prepared_models       => undef,
		   top_tool              => 0,
		   %subargs );
	  
	  ui -> print( category => 'bootstrap',
		       message => 'Executing base model.' );

	  $orig_fit -> run;

	}

	my $output = $model -> outputs -> [0];
	unless ( $output -> have_output ) {
		croak("\nThere is no output from the base model, terminating bootstrap.\n");
	}
	# }}} orig run

	# ------------------------  Print a log-header  -----------------------------

	# {{{ log header

 	my @orig_datas = @{$model -> datas};
 	my @problems   = @{$model -> problems};
 	my @new_models;

	# Print a log-header
	# Lasse 2005-04-21: The minimization_message print will probably not work anymore
	open( LOG, ">>".$self -> logfile()->[$model_number-1] );
	my $ui_text = sprintf("%-5s",'RUN').','.sprintf("%20s",'FILENAME  ').',';
	print LOG sprintf("%-5s",'RUN'),',',sprintf("%20s",'FILENAME  '),',';
	foreach my $param ( 'ofv', 'minimization_message', 'covariance_step_successful' ) {
	  my $orig_ests   = $model -> outputs -> [0] -> $param;
	  # Loop the problems
	  for ( my $j = 0; $j < scalar @{$orig_ests}; $j++ ) {
	    my $name = $param;
	    $name = 'DIC' 
		if (($name eq 'ofv') and 
		    (defined $model -> outputs -> [0]->get_single_value(attribute => 'dic',
									problem_index => $j)));
	    if ( ref( $orig_ests -> [$j][0] ) ne 'ARRAY' ) {
	      my $label = uc($name)."_".($j+1);
	      $ui_text = $ui_text.sprintf("%12s",$label).',';
	      print LOG sprintf("%12s",$label),',';
	    } else {
	      # Loop the parameter numbers (skip sub problem level)
	      for ( my $num = 1; $num <= scalar @{$orig_ests -> [$j][0]}; $num++ ) {
		my $label = uc($name).$num."_".($j+1);
		$ui_text = $ui_text.sprintf("%12s",$label).',';
		print LOG sprintf("%12s",$label),',';
	      }
	    }
	  }
	}
	print LOG "\n";

	# }}} log header

	# ------------------------  Log original run  -------------------------------

	# {{{ Log original run

	# Lasse 2005-04-21: The minimization_message print will probably not work anymore
	open( LOG, ">>".$self -> logfile()->[$model_number-1] );
	$ui_text = sprintf("%5s",'0').','.sprintf("%20s",$model -> filename).',';
	print LOG sprintf("%5s",'0'),',',sprintf("%20s",$model -> filename),',';
	foreach my $param ( 'ofv', 'minimization_message', 'covariance_step_successful' ) {
	  my $orig_ests   = $model -> outputs -> [0] -> $param;
	  # Loop the problems
	  for ( my $j = 0; $j < scalar @{$orig_ests}; $j++ ) {
	    if ( ref( $orig_ests -> [$j][0] ) ne 'ARRAY' ) {
	      $orig_ests -> [$j][0] =~ s/\n//g;
	      $ui_text = $ui_text.sprintf("%12s",$orig_ests -> [$j][0]).',';
	      print LOG sprintf("%12s",$orig_ests -> [$j][0]),',';
	    } else {
	      # Loop the parameter numbers (skip sub problem level)
	      for ( my $num = 0; $num < scalar @{$orig_ests -> [$j][0]}; $num++ ) {
		$ui_text = $ui_text.sprintf("%12f",$orig_ests -> [$j][0][$num]).',';
		print LOG sprintf("%12f",$orig_ests -> [$j][0][$num]),',';
	      }
	    }
	  }
	}
	print LOG "\n";

	# }}} Log original run

 	# TODO: In this loop we loose one dimension (problem) in that
 	# all new models with new data sets are put in the same array,
 	# regardless of which problem the initially belonged to. Fix
 	# this.

	if ( $#orig_datas < 0 ) {
	  carp("No data files to resample from" );
	} elsif ( $#orig_datas > 1 ){
	  print "Warning: bootstrap may not support multiple datasets\n";
	} else {
	  carp("Starting bootstrap sampling" );
	}


	for ( my $i = 1; $i <= scalar @orig_datas; $i++ ) {
	  my $orig_data = $orig_datas[$i-1];
	  my $dataname = $orig_data -> filename; 
	  if ( $self -> drop_dropped() ) {
		  #this can never work if multiple datas
	    my $model_copy = $model -> copy( copy_data => 1,
					     filename => "drop_copy_$i.mod",
					     directory => $self ->directory());

	    $model_copy -> drop_dropped;
	    $model_copy -> _write( write_data => 1 );
	    $model -> datas -> [0] -> flush();
	    $orig_data = $model_copy -> datas -> [0];
	    $model = $model_copy;
		@problems   = @{$model -> problems};

	  }

	  my $stratify_on;
	  if (defined $self->stratify_on ) {
		  my $found=0;
		  # must be string
		  my $counter = 1;
		  foreach my $opt (@{$model->problems->[0]->inputs->[0]->options()}){
			  if ($opt->name() eq $self->stratify_on){
				  $stratify_on = $counter;
				  $found=1;
				  last;
			  }
			  $counter++;
		  }
		  unless ($found){
			  croak("Could not find any column with name ".$self->stratify_on." in \$INPUT of the model, ".
					"set with option -stratify_on");
		  }
	  }
	  
	  my ( @seed, $new_datas, $incl_ids, $incl_keys, $new_mod );

	  my $done = ( -e $self ->directory()."/m$model_number/done.$i" ) ? 1 : 0;
#	  print "stratify_on $stratify_on\n";
	  if ( not $done ) {
	    ui -> print( category => 'bootstrap',
			 message  => "Resampling from $dataname");

	    ( $new_datas, $incl_ids, $incl_keys )
		= $orig_data -> bootstrap( directory   => $self ->directory().'/m'.$model_number,
					   name_stub   => 'bs_pr'.$i,
					   samples     => $self->samples(),
					   subjects    => $self->subjects(),
					   stratify_on => $stratify_on,  #always a number
					   target	     => 'disk');

	    $self->stop_motion_call(tool=>'bootstrap',message => "Created bootstrapped datasets in ".
				    $self ->directory().'m'.$model_number)
		if ($self->stop_motion());

	    for ( my $j = 0; $j < $self->samples(); $j++ ) {
	      my ($model_dir, $filename) = OSspecific::absolute_path( $self ->directory().'/m'.$model_number, 
								      'bs_pr'.$i.'_'.($j+1).'.mod' );
#	      my ($out_dir, $outfilename) = OSspecific::absolute_path( $self ->directory().'/m'.$model_number , 
#								       '/bs_pr'.$i.'_'.$j.'.lst' );
	      my $prob_copy = Storable::dclone($problems[$i-1]); #bug here, is from undropped model


	      $new_mod = model ->
		  new( %{common_options::restore_options(@common_options::model_options)},
		      sde                  => 0,
		      outputs              => undef,
		      datas                => undef,
		      synced               => undef,
		      active_problems      => undef,
		      directory            => $model_dir,
		      filename             => $filename,
		      outputfile           => undef,
		      problems             => [$prob_copy],
		      extra_files          => $model -> extra_files,
		      target               => 'disk',
		      ignore_missing_files => 1 );

	      if( $self -> shrinkage() ) {
		$new_mod -> shrinkage_stats( enabled => 1 );
		$new_mod -> shrinkage_modules( $model -> shrinkage_modules );
#		my @problems = @{$new_mod -> problems};
#		for( my $i = 1; $i <= scalar @problems; $i++ ) {
#		  $problems[ $i-1 ] -> shrinkage_module -> model( $new_mod );
#		}
	      }

	      $new_mod -> datas ( [$new_datas -> [$j]] );

	      if( $self -> nonparametric_etas() or
		  $self -> nonparametric_marginals() ) {
		$new_mod -> add_nonparametric_code;
	      }

	      $new_mod -> update_inits( from_output => $output );
	      $new_mod -> _write;

	      push( @new_models, $new_mod );
	    }
	    $self->stop_motion_call(tool=>'bootstrap',message => "Created one modelfile per dataset in ".
				    $self ->directory().'m'.$model_number)
		if ($self->stop_motion());

	    # Create a checkpoint. Log the samples and individuals.
	    open( DONE, ">".$self ->directory()."/m$model_number/done.$i" ) ;
	    print DONE "Resampling from ",$orig_data -> filename, " performed\n";
	    print DONE $self->samples()." samples\n";
	    while( my ( $strata, $samples ) = each %{$self->subjects()} ) {
	      print DONE "Strata $strata: $samples sample_size\n";
	    }
	    print DONE "Included individuals:\n";
	    @seed = random_get_seed;
	    print DONE "seed: @seed\n";
	    for( my $k = 0; $k < scalar @{$incl_ids}; $k++ ) {
	      print DONE join(',',@{$incl_ids -> [$k]}),"\n";
	    }
	    print DONE "Included keys:\n";
	    for( my $k = 0; $k < scalar @{$incl_keys}; $k++ ) {
	      print DONE join(',',@{$incl_keys -> [$k]}),"\n";
	    }
	    close( DONE );
	    open( INCL, ">".$self ->directory()."included_individuals".$model_number.".csv" ) ;
	    for( my $k = 0; $k < scalar @{$incl_ids}; $k++ ) {
	      print INCL join(',',@{$incl_ids -> [$k]}),"\n";
	    }
	    close( INCL );
	    open( KEYS, ">".$self ->directory()."included_keys".$model_number.".csv" ) ;
	    open( SAMPLEKEYS, ">".$self ->directory()."sample_keys".$model_number.".csv" ) ;
	    my $ninds= ($orig_data -> count_ind());
	    for( my $k = 0; $k < scalar @{$incl_keys}; $k++ ) {
	      my %sample_keys;
	      my $sample_size = scalar @{$incl_keys -> [$k]};
	      for ( my $l = 0; $l < $ninds; $l++ ) {
		$sample_keys{$incl_keys -> [$k][$l]}++;
	      }
	      for ( my $l = 0; $l < $ninds; $l++ ) {
		my $val   = defined $sample_keys{$l} ? $sample_keys{$l} : 0;
		my $extra = ($l == ($ninds-1)) ? "\n" : ',';
		print SAMPLEKEYS $val,$extra;
	      }
	      print KEYS join(',',@{$incl_keys -> [$k]}),"\n";
	    }
	    close( KEYS );
	    close( SAMPLEKEYS );
	  } else {
	    ui -> print( category => 'bootstrap',
			 message  => "Recreating bootstrap from previous run." );

	    # Recreate the datasets and models from a checkpoint
	    my ($stored_filename, $stored_samples, %stored_subjects);
	    my @seed;
	    my ($stored_filename_found, $stored_samples_found, $stored_subjects_found, $stored_seed_found);
	    open( DONE, $self ->directory()."/m$model_number/done.$i" );
	    while( <DONE> ){
	      if( /^Resampling from (.+) performed$/ ){
		$stored_filename = $1;
		$stored_filename_found = 1;
		next;
	      }
	      if( /^(\d+) samples$/ ){
		ui -> print( category => 'bootstrap',
			     message  => "Samples saved: $1" );
		$stored_samples = $1;
		$stored_samples_found = 1;
		next;
	      }
	      if( /^(\d+) subjects$/ ){
		  # Old format (pre 2.2.2)
		$stored_subjects{'default'} = $1;
		$stored_subjects_found = 1;
		next;
	      }
	      if( /^Strata (\w+): (\d+) sample_size$/ ){
		ui -> print( category => 'bootstrap',
			     message  => "Strata $1, samples size: $2" );
		$stored_subjects{$1} = $2;
		$stored_subjects_found = 1;
		next;
	      }
	      if( /^seed: (\d+) (\d+)$/ ){
		@seed = ($1, $2);
		$stored_seed_found = 1;
		next;
	      }

	      if( $stored_filename_found and $stored_samples_found 
		  and $stored_subjects_found and $stored_seed_found ){
		last;
	      }		
	    }
	    close( DONE );
	    unless( $stored_filename_found and $stored_samples_found 
		    and $stored_samples_found and $stored_seed_found ){
			     croak("The bootstrap/m1/done file could not be parsed.");
	    }

	    if ( $stored_samples < $self->samples() ) {
	      croak("The number of samples saved in previous run ($stored_samples) ".
			    "is smaller than the number of samples specified for this run (".
			    $self->samples().")" );
	    }
	    while( my ( $strata, $samples ) = each %{$self->subjects()} ) {
	      if ( $stored_subjects{$strata} != $samples ) {
		croak("The number of individuals sampled i strata $strata ".
			      "in previous run (".
			      $stored_subjects{$strata}.
			      ") does not match the number of individuals specified ".
			      "for this run (".$samples.")" );
	      }
	    }
	    while( my ( $strata, $samples ) = each %stored_subjects ) {
	      if ( $self->subjects()->{$strata} != $samples ) {
		croak("The number of individuals sampled i strata $strata ".
			      "in previous run (". $samples .
			      ") does not match the number of individuals specified ".
			      "for this run (".$self->subjects()->{$strata}.")" );
	      }
	    }

	    # Reinitiate the model objects
	    for ( my $j = 1; $j <= $self->samples(); $j++ ) {
	      my ($model_dir, $filename) = OSspecific::absolute_path( $self ->directory().'/m'.
								      $model_number,
								      'bs_pr'.$i.'_'.$j.'.mod' );
#	      my ($out_dir, $outfilename) = OSspecific::absolute_path( $self ->directory().'/m'.
#								       $model_number,
#								       '/bs_pr'.$i.'_'.$j.'.lst' );
	      $new_mod = model ->
		new( directory   => $model_dir,
		     filename    => $filename,
#		     outputfile  => $outfilename,
		     extra_files => $model -> extra_files,
		     target      => 'disk',
		     ignore_missing_files => 1,
#		     dummy_data => $dummy_data
		     );
#	      $new_mod -> target( 'disk' );
	      push( @new_models, $new_mod );
#	      print "$j\n";
#	      print Dumper $new_mod;
#	      sleep(10);
	    }
	    random_set_seed( @seed );
	    ui -> print( category => 'bootstrap',
			 message  => "Using $stored_samples previously resampled ".
			 "bootstrap sets from $stored_filename" )
	      unless $self -> parent_threads() > 1;
	  }

 	}
 	$self -> prepared_models -> [$model_number-1]{'own'} = \@new_models;

	# ---------------------  Create the sub tools  ------------------------------


 	my $subdir = $class;
 	$subdir =~ s/tool:://;
 	my @subtools = ();
 	@subtools = @{$self -> subtools()} if (defined $self->subtools());
 	shift( @subtools );
 	my %subargs = ();
 	if ( defined $self -> subtool_arguments() ) {
	  %subargs = %{$self -> subtool_arguments()};
	}
	if (($class eq 'tool::modelfit') and not $self->copy_data()){
	  $subargs{'data_path'}='../../m'.$model_number.'/';
	}
    $self->tools([]) unless (defined $self->tools());
    
	push( @{$self -> tools()},
	      $class ->
	      new( %{common_options::restore_options(@common_options::tool_options)},
			   models		 => \@new_models,
			   threads               => $subm_threads,
			   directory             => $self ->directory().'/'.$subdir.'_dir'.$model_number,
			   _raw_results_callback => $self ->
			   _modelfit_raw_results_callback( model_number => $model_number ),
			   subtools              => \@subtools,
			   nmtran_skip_model => 2,
			   parent_threads        => $own_threads,
			   parent_tool_id        => $self -> tool_id(),
			   logfile		 => [$self -> logfile()->[$model_number-1]],
			   raw_results           => undef,
			   prepared_models       => undef,
			   top_tool              => 0,
			   %subargs ) );

	$self->stop_motion_call(tool=>'bootstrap',message => "Created a modelfit object to run all the models in ".
				$self ->directory().'m'.$model_number)
	    if ($self->stop_motion());


      }
end general_setup

# }}}


start llp_setup
      {
	$self -> general_setup( model_number => $model_number,
				class        => 'tool::llp');
      }
end llp_setup


start _jackknife_raw_results_callback
      {
	# Use the bootstrap's raw_results file.
	my ($dir,$file) =
	  OSspecific::absolute_path( $self ->directory(),
				     $self -> raw_results_file()->[$model_number-1] );
	my ($dir,$nonp_file) =
	  OSspecific::absolute_path( $self ->directory(),
				     $self -> raw_nonp_file()->[$model_number-1] );
	$subroutine = sub {
	  my $jackknife = shift;
	  my $modelfit  = shift;
	  $modelfit -> raw_results_file( [$dir.$file] );
	  $modelfit -> raw_nonp_file( [$dir.$nonp_file] );
	  $modelfit -> raw_results_append( 1 );
	  my ( @new_header, %param_names );
	  unless (defined $modelfit -> raw_results()){
	      $modelfit -> raw_results([]);
	  }
	  foreach my $row ( @{$modelfit -> raw_results()} ) {
	    unshift( @{$row}, 'jackknife' );
	  }

	  $modelfit -> raw_results_header([]);
	};
	return $subroutine;
      }
end _jackknife_raw_results_callback


start _modelfit_raw_results_callback
      {
	# Use the bootstrap's raw_results file.
	my ($dir,$file) = 
	  OSspecific::absolute_path( $self ->directory(),
				     $self -> raw_results_file()->[$model_number-1] );
	my ($dir,$nonp_file) = 
	  OSspecific::absolute_path( $self ->directory(),
				     $self -> raw_nonp_file()->[$model_number-1] );
	my $orig_mod = $self ->models()->[$model_number-1];
	my $type = $self -> type();
	$subroutine = sub {
	  my $modelfit = shift;
	  my $mh_ref   = shift;
	  my %max_hash = %{$mh_ref};
	  $modelfit -> raw_results_file([$dir.$file] );
	  $modelfit -> raw_nonp_file( [$dir.$nonp_file] );

	  # The prepare_raw_results in the modelfit will fix the
	  # raw_results for each bootstrap sample model, we must add
	  # the result for the original model.

	  my %dummy;

	  my ($raw_results_row, $nonp_rows) = $self -> create_raw_results_rows( max_hash => $mh_ref,
										model => $orig_mod,
										raw_line_structure => \%dummy );

#	  $orig_mod -> outputs -> [0] -> flush; #do not flush, want to keep this to use for delta-ofv
	  
	  unshift( @{$modelfit -> raw_results()}, @{$raw_results_row} );

	  $self->raw_line_structure($modelfit -> raw_line_structure());
	  if ( $type eq 'bca' ) {
	    my $first = 1;
	    foreach my $row ( @{$modelfit -> raw_results()} ) {
	      if ($first){
		unshift( @{$row}, 'original' );
		$first=0;
	      }else{
		unshift( @{$row}, 'bootstrap' );
	      }
	    }
	    unshift( @{$modelfit -> raw_results_header()}, 'method' );

	    foreach my $mod (sort({$a <=> $b} keys %{$self->raw_line_structure()})){
	      foreach my $category (keys %{$self->raw_line_structure() -> {$mod}}){
		next if ($category eq 'line_numbers');
		my ($start,$len) = split(',',$self->raw_line_structure() -> {$mod}->{$category});
		$self->raw_line_structure() -> {$mod}->{$category} = ($start+1).','.$len; #+1 for method
	      }
	      $self->raw_line_structure() -> {$mod}->{'method'} = '0,1';
	    }
	  }
	  $self->raw_line_structure() -> {'0'} = $self->raw_line_structure() -> {'1'};
	  $self->raw_line_structure() -> write( $dir.'raw_results_structure' );

	  $self -> raw_results_header($modelfit -> raw_results_header());

	};
	return $subroutine;
      }
end _modelfit_raw_results_callback

# }}} _modelfit_raw_results_callback

start _dofv_raw_results_callback
{

    my $orig_mod = $self ->models()->[$model_number-1];
    my $orig_ofv;
    if ($orig_mod->is_run){
	#in dofv we only handle one $PROB, but could do array over probs here
	$orig_ofv=$orig_mod->outputs->[0]->get_single_value(attribute => 'ofv');
    }
    my @dofv_samples = @{$self->dofv_samples()};
    unshift (@dofv_samples,'original'); #for original model

    
    $subroutine = sub {
	my $modelfit = shift;
	my $mh_ref   = shift;
	my %max_hash = %{$mh_ref};
	
	# The prepare_raw_results in the modelfit will fix the
	# raw_results for each dofv sample model, we must add
	# the result for the original model.
	
	my %dummy;
	
	my ($raw_results_row, $nonp_rows) = $self -> create_raw_results_rows( max_hash => $mh_ref,
									      model => $orig_mod,
									      raw_line_structure => \%dummy );
	
	$raw_results_row->[0]->[0] = 'input';
	
	unshift( @{$modelfit -> raw_results()}, @{$raw_results_row} );
	
	if ( defined $orig_ofv ) {
	    my ($start,$len) = split(',',$modelfit->raw_line_structure() -> {1}->{'problem'});
	    my $problemindex = $start;
	    ($start,$len) = split(',',$modelfit->raw_line_structure() -> {1}->{'ofv'});
	    my $ofvindex=$start;
	    croak("could not find ofv in raw results header") unless (defined $ofvindex);
	    
	    my $si=0;
	    foreach my $row ( @{$modelfit -> raw_results()} ) {
		my $delta_ofv = $row->[$ofvindex] - $orig_ofv;
		my @oldrow =@{$row};
		$row = [@oldrow[0 .. $problemindex],$dofv_samples[$si],@oldrow[$problemindex+1 .. $ofvindex],$delta_ofv,@oldrow[$ofvindex+1 .. $#oldrow]]; 
		$si++;
	    }
	    
	    my @old_header = @{$modelfit -> raw_results_header()};
	    my $headerindex;
	    my $probheadindex;
	    for (my $k=0; $k<scalar(@old_header);$k++){
		$headerindex = $k if ($old_header[$k] eq 'ofv');
		$probheadindex = $k if ($old_header[$k] eq 'problem');
	    }
	    $modelfit -> raw_results_header(
		[@old_header[0 .. $probheadindex],'bs_data_id',@old_header[$probheadindex+1 .. $headerindex],'deltaofv',@old_header[$headerindex+1 .. $#old_header]]);
	    
	    foreach my $mod (sort({$a <=> $b} keys %{$modelfit->raw_line_structure()})){
		foreach my $category (keys %{$modelfit->raw_line_structure() -> {$mod}}){
		    next if ($category eq 'line_numbers');
		    my ($start,$len) = split(',',$modelfit->raw_line_structure() -> {$mod}->{$category});
		    #we know model comes before ofv
		    if ($start > $ofvindex){
			$modelfit->raw_line_structure() -> {$mod}->{$category} = ($start+2).','.$len; #+2 for bs_sample, ofv
		    }elsif ($start > $problemindex){
			$modelfit->raw_line_structure() -> {$mod}->{$category} = ($start+1).','.$len; #+1 for bs_sample
		    }
		}
		$modelfit->raw_line_structure() -> {$mod}->{'deltaofv'} = ($ofvindex+2).',1'; #+2 to handle bs_sample
		$modelfit->raw_line_structure() -> {$mod}->{'bs_sample'} = ($problemindex+1).',1';
	    }
	}
	$modelfit->raw_line_structure() -> {'input'} = $modelfit->raw_line_structure() -> {'1'}; #input model
	my ($dir,$file) = 
	  OSspecific::absolute_path( $modelfit ->directory(),
				     $modelfit -> raw_results_file()->[$model_number-1] );
	$modelfit->raw_line_structure() -> write( $dir.'raw_results_structure' );
	
	
    };

    return $subroutine;
}
end _dofv_raw_results_callback



start cleanup
{
  #remove datafiles in modelfit_dirX/NM_runX
  #leave in m1

  my $prob=1;
  while (1){
    my $dir = $self ->directory()."modelfit_dir$prob/";
    last unless (-e $dir);
    my $sample=1;
    while (1){
      my $file = $dir."NM_run".$sample."/bs_pr".$prob."_".$sample.".dta"; 
      last unless (-e $file);
      unlink $file;
      $sample++;
    }
    $prob++;
  }

}
end cleanup


# {{{ modelfit_analyze

start modelfit_analyze
      {
#	$self-> cleanup();

	my @params = @{$self -> parameters()};
	my @diagnostic_params = @{$self -> diagnostic_parameters()};
	my ( @print_order, @calculation_order );
	my $jackknife;

	if ( $self -> type() eq 'bca' ) {

	  # --------------------------  BCa method  ---------------------------------
	  
	  # {{{ BCa

	  @calculation_order = @{$self -> bca_calculation_order()};
	  @print_order = @{$self -> bca_print_order()};
	  my $jk_threads = $self ->threads();
#	  print "threads $jk_threads\n";
	  my $done = ( -e $self ->directory()."/jackknife_done.$model_number" ) ? 1 : 0;
	  if ( not $done ) {

	      ui -> print( category => 'bootstrap',
			   message  => "Running a Jackknife for the BCa estimates" );
	      $jackknife =tool::cdd::jackknife ->
		  new( %{common_options::restore_options(@common_options::tool_options)},
		       directory        => undef,
		       models           => [$self -> models -> [$model_number -1]],
		       case_column     => $self -> models -> [$model_number -1]
		       -> datas -> [0] -> idcolumn,
		       _raw_results_callback => $self ->
		       _jackknife_raw_results_callback( model_number => $model_number ),
		       nm_version       => $self -> nm_version(),
		       parent_tool_id   => $self -> tool_id(),
		       threads          => $jk_threads,
		       bca_mode         => 1,
		       shrinkage        => $self -> shrinkage(),
		       nonparametric_marginals => $self -> nonparametric_marginals(),
		       nonparametric_etas => $self -> nonparametric_etas(),
		       adaptive         => $self -> adaptive(),
		       rerun            => $self -> rerun(),
		       verbose          => $self -> verbose(),
		       cross_validate   => 0 );

	    # Create a checkpoint. Log the samples and individuals.
	    open( DONE, ">".$self ->directory()."/jackknife_done.$model_number" ) ;
	    print DONE "Jackknife directory:\n";
	    print DONE $jackknife -> directory,"\n";
	    my @seed = random_get_seed;
	    print DONE "seed: @seed\n";
	    close( DONE );


	  } else {

	    # {{{ Recreate Jackknife

	    open( DONE, $self ->directory()."/jackknife_done.$model_number" );
	    my @rows = <DONE>;
	    close( DONE );
	    my ( $stored_directory ) = $rows[1];
	    chomp( $stored_directory );
	    if ( not -e $stored_directory ) {
	      croak("The Jackknife directory ".$stored_directory.
			    "indicated by ".$self ->directory().
			    "/jackknife_done.$model_number".
			    " from the old bootstrap run in ".
			    $self ->directory()." does not exist" );
	    }
	    my @seed = split(' ',$rows[2]);
	    shift( @seed ); # get rid of 'seed'-word
	    $jackknife = tool::cdd::jackknife ->
			new( %{common_options::restore_options(@common_options::tool_options)},
				 models           => [$self -> models -> [$model_number -1]],
				 case_column     => $self -> models -> [$model_number -1]
				 -> datas -> [0] -> idcolumn,
				 _raw_results_callback => $self ->
				 _jackknife_raw_results_callback( model_number => $model_number ),
				 threads          => $jk_threads,
				 parent_tool_id   => $self -> tool_id(),
				 directory        => $stored_directory,
				 bca_mode         => 1,
				 shrinkage        => $self -> shrinkage(),
				 nm_version       => $self -> nm_version(),
				 nonparametric_marginals => $self -> nonparametric_marginals(),
				 nonparametric_etas => $self -> nonparametric_etas(),
				 adaptive         => $self -> adaptive(),
				 rerun            => $self -> rerun(),
				 verbose          => $self -> verbose(),
				 cross_validate   => 0 );

	    random_set_seed( @seed );
	    ui -> print( category => 'bootstrap',
			 message  => "Restarting BCa Jackknife from ".
			 $stored_directory )
	      unless $self -> parent_threads() > 1;

	    # }}} Recreate Jackknife

	  }

	  $jackknife -> run;
#	  $self -> {'jackknife_results'} = $jackknife -> results();
#	  $self -> {'jackknife_prepared_models'} = $jackknife -> prepared_models();

	  $self -> jackknife_raw_results-> [$model_number-1] =
	    $jackknife -> raw_results;
#	    $self -> {'jackknife'} -> raw_results -> [$model_number-1];
#	  $Data::Dumper::Maxdepth = 0;
#	  print Dumper $self -> {'jackknife_raw_results'};

	  # }}} BCa

	} else {
	    #not bca
	  @calculation_order = @{$self -> calculation_order()};
	  @print_order = @{$self -> print_order()};
	  $self -> bootstrap_raw_results() ->[$model_number-1] =
	    $self -> tools() -> [0] -> raw_results;
#	    $self -> {'tools'} -> [0] -> raw_results -> [$model_number-1];
	}

	my @param_names = @{$self -> models -> [$model_number -1] -> outputs -> [0] -> labels};
	my ( @diagnostic_names, @tmp_names );
	foreach my $param ( @diagnostic_params ) {
	  push( @tmp_names, $param );
	  $tmp_names[$#tmp_names] =~ s/_/\./g;
	}
	for ( my $i = 0; $i <= $#param_names; $i++ ) {
	  #unshift( @{$param_names[$i]}, 'OFV' );
	  push( @{$diagnostic_names[$i]}, @tmp_names );
	}


	if ($self->dofv()){
	    my $model = $self -> models -> [$model_number -1];
	    if (scalar(@{$model->problems()}) >1){
		print "\nbootstrap program does not support option -dofv for models with more than one \$PROBLEM.\n";
		return;
	    }
	    unless (-e $self->raw_results_file()->[$model_number-1]){
		print "\nNo raw results file found, nothing to do for -dofv.\n";
		return;
	    }
	    unless ($model->is_run and (defined $model->outputs->[0]->get_single_value(attribute => 'ofv'))){
		print "\nHave no ofv output from original model, nothing to do for -dofv.\n";
		return;
	    }
	    #skip original model ests, only use samples where est gave ofv (and params, we assume), not jackknife method
	    my $filter;
	    if ( $self -> type() eq 'bca' ) {
		$filter = ['method.eq.bootstrap'];
	    }
	    my $sampled_params_arr = 
		$model -> get_rawres_params(filename => $self->raw_results_file()->[$model_number-1],
					    string_filter => $filter,
					    require_numeric_ofv => 1,
					    offset => 1); 

	    if (scalar(@{$sampled_params_arr})<1){
		print "\nNo bootstrap samples gave ofv value, nothing to do for -dofv.\n";
		return;
	    }

	    my $samples_done=0;
	    my $dofvnum=1;
	    my @modelsarr=();
	    my $dofvmodel;
	    my $dummymodel;
	    my $dummyname='dummy.mod';
	    my @problem_lines=();
	    while ($samples_done < scalar(@{$sampled_params_arr})){
		#copy datafile to run directory m1  and later set local path to datafile in model
		cp($model->datas->[0]->full_name(),$self->directory().'m'.$model_number.'/'.$model->datas->[0]->filename());
		#copy the model
		$dofvmodel = $model ->  copy( filename    => $self -> directory().'m'.$model_number."/dofv_$dofvnum.mod",
					      output_same_directory => 1,
					      copy_data   => 0,
					      copy_output => 0);
		$dofvnum++;

		$dofvmodel->set_maxeval_zero(need_ofv => 1);
		if (($PsN::nm_major_version >= 7) and ($PsN::nm_minor_version >= 3)){
		    if ($self->mceta() > 0){
			$dofvmodel->set_option(problem_numbers => [1],
					       record_name => 'estimation',
					       option_name => 'MCETA',
					       option_value => $self->mceta());
		    }
		}
		foreach my $record ('table','simulation','covariance','scatter'){
		    $dofvmodel -> remove_records (problem_numbers => [1],
						  keep_last => 0,
						  type => $record);
		}


		if (scalar(@problem_lines)<1){
		    #first iteration
		    $dummymodel = $dofvmodel ->  copy( filename    => $self -> directory().'m'.$model_number.'/'.$dummyname,
						       output_same_directory => 1,
						       target => 'mem',
						       copy_data   => 0,
						       copy_output => 0);
		    chdir($self -> directory().'m'.$model_number);
		    $dummymodel->datafiles(problem_numbers => [1],
					   new_names => [$model->datas->[0]->filename()]);
		    chdir($self -> directory());

		    #set $DATA REWIND
		    $dummymodel->add_option(problem_numbers => [1],
					    record_name => 'data',
					    option_name => 'REWIND');
		    
		    #remove most records, keep only $PROB, $INPUT, $DATA, $THETA, $OMEGA, $SIGMA $EST
		    foreach my $record ('table','simulation','pk','pred','error','covariance','scatter','msfi','subroutine',
					'abbreviated','sizes','contr','prior','model','tol','infn','aesinitial',
					'aes','des','mix','nonparametric'){
			$dummymodel -> remove_records (problem_numbers => [1],
						       keep_last => 0,
						       type => $record);
		    }
		    my $linesarray = $dummymodel->problems->[0]->_format_problem;
		    #we cannot use this array directly, must make sure items do not contain line breaks
		    foreach my $line (@{$linesarray}){
			my @arr = split(/\n/,$line);
			push(@problem_lines,@arr);
		    }
		    unlink($self -> directory().'m'.$model_number.'/'.$dummyname);
		    $dummymodel = undef;
		}

		#need to set data object , setting record not enough
		#chdir so can use local data file name
		chdir($self -> directory().'m'.$model_number);
		$dofvmodel->datafiles(problem_numbers => [1],
				      new_names => [$model->datas->[0]->filename()]);

		chdir($self -> directory());

		#update ests for first $PROB in real model
		$dofvmodel -> update_inits(from_hash => $sampled_params_arr->[$samples_done]); 
		push(@{$self->dofv_samples},$sampled_params_arr->[$samples_done]->{'model'});
		$samples_done++;
		my $probnum=2;
		for (my $i=1; $i<200; $i++){
		    last if ($samples_done == scalar(@{$sampled_params_arr}));
		    #add one $PROB per $i, update inits from hash
		    my $sh_mod = model::shrinkage_module -> new ( nomegas => $dofvmodel -> nomegas -> [0],
								  directory => $dofvmodel -> directory(),
								  problem_number => $probnum );

		    push(@{$dofvmodel->problems()},
			 model::problem ->
			 new ( directory                   => $dofvmodel->directory,
			       ignore_missing_files        => 1,
			       ignore_missing_output_files => 1,
			       sde                         => $dofvmodel->sde,
			       omega_before_pk             => $dofvmodel->omega_before_pk,
			       cwres                       => $dofvmodel->cwres,
			       tbs                         => 0,
			       tbs_param                    => 0,
			       prob_arr                    => \@problem_lines,
			       shrinkage_module            => $sh_mod )
			);
		    push(@{$dofvmodel->active_problems()},1);
		    push(@{$dofvmodel->datas()},$dofvmodel->datas()->[0]);
		    $dofvmodel -> _write();
#		    print "probnum $probnum, samples_done $samples_done\n";
		    $dofvmodel->update_inits(from_hash => $sampled_params_arr->[$samples_done],
					     problem_number=> $probnum);
		    push(@{$self->dofv_samples},$sampled_params_arr->[$samples_done]->{'model'});
		    $samples_done++;
		    $probnum++;
		}
		$dofvmodel -> _write();
		push(@modelsarr,$dofvmodel);
	    }
	    my $modelfit = tool::modelfit -> new( 
			%{common_options::restore_options(@common_options::tool_options)},
			top_tool         => 0,
			models           => \@modelsarr,
			base_directory   => $self -> directory,
			directory        => $self -> directory.'compute_dofv_dir'.$model_number, 
			raw_results_file => [$self->directory.'raw_results_dofv.csv'],
			nmtran_skip_model => 2,
			parent_tool_id   => $self -> tool_id,
			_raw_results_callback => $self ->_dofv_raw_results_callback( model_number => $model_number ),
			logfile	         => undef,
			data_path         =>'../../m'.$model_number.'/',
			threads          => $self->threads);
	    $modelfit->run;

	    #if clean >=3 this file has been deleted, but the raw_results is ok thanks to explicit setting
	    #of filename above.
	    if (-e $modelfit->directory.'raw_results_structure'){
		cp ($modelfit->directory.'raw_results_structure',$modelfit->base_directory.'raw_results_structure_dofv');
	    }
	}

      }
end modelfit_analyze

# }}}

# {{{ prepare_results

start prepare_results
      {

	my ( @calculation_order, @print_order, %diag_idx );
	if ( $self -> type() eq 'bca' ) {
	  @calculation_order = @{$self -> bca_calculation_order()};
	  @print_order = @{$self -> bca_print_order()};
	} else {
	  @calculation_order = @{$self -> calculation_order()};
	  @print_order = @{$self -> print_order()};
	}
	if ( $self -> type() eq 'bca' ) {
	  $self -> bca_read_raw_results();
	} else {
	    $self -> read_raw_results();
	    $self->stop_motion_call(tool=>'bootstrap',message => "Read raw results from file")
		if ($self->stop_motion());
	    $self -> bootstrap_raw_results ($self -> raw_results());
	}

	for ( my $i = 0; $i < scalar @{$self -> diagnostic_parameters()}; $i++ ) {
	  my ($start,$length) = 
	      split(',',$self->raw_line_structure()->{'1'}->{$self -> diagnostic_parameters() -> [$i]});
	  $diag_idx{$self -> diagnostic_parameters() -> [$i]} = $start;
	}

	# ---------------------  Get data from raw_results  -------------------------

	# Divide the data into diagnostics and estimates. Included in estimates are
	# the parametric estimates, the standard errors of these, the nonparametric
	# estimates, the shrinkage in eta and the shrinkage in wres
        # The diagnostics end up in {'bootstrap_diagnostics'} and
	# {'jackknife_diagnostics'}. The estimates in bootstrap_estimates and
	# jackknife_estimates.
        # The number of runs that are selected for calculation of the results is
	# saved.

        # {{{ Get the data from the runs

	foreach my $tool ( 'bootstrap', 'jackknife' ) {
	    my $rawres = $tool.'_raw_results';
	    my $diagnostics = $tool.'_diagnostics';
	    my $estimates = $tool.'_estimates';
	  if ( defined $self -> $rawres ) {
	    for ( my $i = 0; $i < scalar @{$self->$rawres}; $i++ ) { # All models

	      # {{{ Get the number of columns with estimates 

	      my $cols_orig = 0;
	      foreach my $param ( 'theta', 'omega', 'sigma' ) {
		my $labels =
		  $self ->models() -> [$i] -> labels( parameter_type => $param );
		# we can't use labels directly since different models may have different
		# labels (still within the same modelfit)
		my $numpar = scalar @{$labels -> [0]} if ( defined $labels and
							   defined $labels -> [0] );
		$cols_orig += ( $numpar*3 ); # est + SE + eigen values
	      }
	      # nonparametric omegas and shrinkage
	      my $nomegas = $self ->models() -> [$i] -> nomegas;
	      my $numpar = $nomegas -> [0];

              # shrinkage omega + wres shrinkage
	      $cols_orig += $numpar + 1; 
#	      $cols_orig += ($numpar*($numpar+1)/2 + $numpar + 1); 
	      
              $cols_orig++; # OFV

	      # }}} Get the number of columns with estimates 

	      # {{{ Loop, choose and set diagnostics and estimates

	      my %return_section;
	      $return_section{'name'} = 'Warnings';
	      my ( $skip_term, $skip_cov, $skip_warn, $skip_bound );
	      my $included = 0;

	      for ( my $j = 0; $j < scalar @{$self->$rawres->[$i]}; $j++ ) { # orig model + prepared_models
		my $columns = scalar @{$self->$rawres->[$i][$j]};

		# -----------------------  Diagnostics  -----------------------------

		for ( my $m=0; $m < scalar @{$self -> diagnostic_parameters()}; $m++ ) { # value
		  $self->$diagnostics->[$i][$j][$m] =
		      $self->$rawres->[$i][$j][$diag_idx{$self -> diagnostic_parameters() -> [$m]}];
#		  print "index is ".$diag_idx{$self -> diagnostic_parameters() -> [$m]}." value is ".
#		      $self->{$tool.'_diagnostics'}->[$i][$j][$m]."\n" if ($j==0);
		}
		my $use_run = 1;
		if ( $self -> skip_minimization_terminated and 
		     ( not defined $self->$rawres->
		       [$i][$j][$diag_idx{'minimization_successful'}]
		       or not $self->$rawres->
		       [$i][$j][$diag_idx{'minimization_successful'}] ) ) {
		  $skip_term++;
		  $use_run = 0;
		} elsif ( $self -> skip_covariance_step_terminated and not
			  $self->$rawres->
			  [$i][$j][$diag_idx{'covariance_step_successful'}] ) {
		  $skip_cov++;
		  $use_run = 0;
		} elsif ( $self -> skip_with_covstep_warnings and
			  $self->$rawres->
			  [$i][$j][$diag_idx{'covariance_step_warnings'}] ) {
		  $skip_warn++;
		  $use_run = 0;
		} elsif ( $self -> skip_estimate_near_boundary and
			  $self->$rawres->
			  [$i][$j][$diag_idx{'estimate_near_boundary'}] ) {
		  $skip_bound++;
		  $use_run = 0;
		} 

		# ------------------------  Estimates  ------------------------------


		if( $use_run ) {
#		  for ( my $m = scalar @{$self -> diagnostic_parameters()} + $skip_mps; $m < $columns; $m++ ) {#value
#		    my $val = $self->$rawres->[$i][$j][$m];
#		    $self->{$tool.'_estimates'}->
#			[$i][$included][$m-(scalar @{$self -> diagnostic_parameters()} + $skip_mps)] = $val;
#		  }
		  
		  my ($start,$l) = split(',',$self->raw_line_structure()->{'1'}->{'ofv'});
		  for (my $m=0; $m< ($columns-$start);$m++){
		    my $val = $self->$rawres->[$i][$j][$start+$m];
		    $self->$estimates->[$i][$included][$m] = $val;
		  }
		  $included++;
		}
	      }

	      if ($included < 1){
		  croak("No runs passed the run exclusion critera. Statistics cannot be calculated by PsN. ".
		      "Open the raw results file and do statistics manually.");
	      }
	      # }}} Loop, choose and set diagnostics and estimates

	      # {{{ push #runs to results
	      my %run_info_return_section;
	      my @run_info_labels=('Date','PsN version','NONMEM version');
	      my @datearr=localtime;
	      my $the_date=($datearr[5]+1900).'-'.($datearr[4]+1).'-'.($datearr[3]);
	      my @run_info_values =($the_date,'v'.$PsN::version,$self->nm_version());
	      $run_info_return_section{'labels'} =[[],\@run_info_labels];
	      $run_info_return_section{'values'} = [\@run_info_values];
#	      push( @{$self -> {'results'}[$i]{'own'}},\%run_info_return_section );

	      if ( defined $skip_term ) {
		push( @{$return_section{'values'}}, "$skip_term runs with miminization ".
		      "terminated were skipped when calculating the $tool results" );
	      }
	      if ( defined $skip_cov ) {
		push( @{$return_section{'values'}}, "$skip_cov runs with aborted ".
		      "covariance steps were skipped when calculating the $tool results" );
	      }
	      if ( defined $skip_warn ) {
		push( @{$return_section{'values'}}, "$skip_warn runs with errors from ".
		      "the covariance step were skipped when calculating the $tool results" );
	      }
	      if ( defined $skip_bound ) {
		push( @{$return_section{'values'}}, "$skip_bound runs with estimates ".
		      "near a boundary were skipped when calculating the $tool results" );
	      }
	      $return_section{'labels'} = [];
	      push( @{$self -> results->[$i]{'own'}},\%return_section );

	      # }}} push #runs to results

	    }
	  }
	}

#	  $Data::Dumper::Maxdepth = 5;
#	  die Dumper $self -> {'bootstrap_diagnostics'};

        # }}} Get the data from the runs

	# ----------------------  Calculate the results  ----------------------------

 	# {{{ Result calculations

	unless (defined $self -> bootstrap_raw_results()){
	  croak("No bootstrap_raw_results array");
	}
	for ( my $i = 0; $i < scalar @{$self -> bootstrap_raw_results()} ; $i++ ) { # All models

#	  my $mps_offset = $self -> {'bca'} ? 4 : 3; # <- this is the offset to
	                                             # diagonstic_parameters,
                                                     # which is one more for
                                                     # the method column added
                                                     # with a bca run.
	  my ($start,$l) = split(',',$self->raw_line_structure()->{'1'}->{'ofv'});

	  my @param_names = @{$self -> raw_results_header()->[$i]}[$start .. (scalar @{$self -> raw_results_header->[$i]} - 1)];
	  my ( @diagnostic_names, @tmp_names );
	  foreach my $param ( @{$self -> diagnostic_parameters()} ) {
	    push( @tmp_names, $param );
	    $tmp_names[$#tmp_names] =~ s/_/\./g;
	  }

	  @diagnostic_names = @tmp_names;
	  foreach my $result_type ( @calculation_order ) {
	    my @names = $result_type eq 'diagnostic_means' ?
		@diagnostic_names : @param_names;
	    my $calc = 'calculate_'.$result_type;
	    $self -> $calc( model_number    => ($i+1),
			    parameter_names => \@names );
	  }
	  foreach my $result_type ( @print_order ) {
	    my $name = $result_type;
	    $name =~ s/_/\./g;
	    my %return_section;
	    $return_section{'name'} = $name;
	    $return_section{'values'} = $self -> result_parameters -> {$result_type} -> [$i];
	    $return_section{'labels'} = $self -> result_parameters -> {$result_type.'_labels'} -> [$i];
	    push( @{$self -> results->[$i]{'own'}},\%return_section );
	  }
	}

	# }}} Result calculations
	$self->stop_motion_call(tool=>'bootstrap',message => "Computed bootstrap results based on raw_results data in memory ")
	    if ($self->stop_motion());

      }
end prepare_results

# }}} prepare_results


# {{{ bca_read_raw_results

start bca_read_raw_results
      {
	$self -> raw_results_header([]);
	for ( my $i = 1; $i <= scalar @{$self->models()}; $i++ ) { # All models
#	  if ( -e $self ->directory().'raw_results'.$i.'.csv' ) {
#	    open( RRES, $self ->directory().'raw_results'.$i.'.csv' );
	  if ( defined $self -> raw_results_file()
	       and -e $self -> raw_results_file()->[$i-1] ) {
	    open( RRES, $self -> raw_results_file()->[$i-1] );

	    my @read_file = <RRES>;
	    close( RRES );
	    my @file;

	    foreach (@read_file){
	      chomp;
	      if (/\"\,\".*/ ){
		s/^\"//;
		s/\"$//;
		my @tmp = split('\"\,\"',$_);
		push (@file,\@tmp);
	      } else {
		my @tmp = split(',',$_);
		push (@file,\@tmp);
	      }
	    }

	    my $header = shift @file;
	    
	    # Get rid of 'method' column
	    my $cols = scalar(@{$header})-1;
	    @{$self -> raw_results_header()->[$i-1]} = @{$header}[1..$cols];
	    $self -> raw_results() -> [$i-1] = \@file;
	    for( my $j = 0; $j <= $#file; $j++ ) {
	      if ( $file[$j][0] eq 'jackknife' ) {
		shift( @{$file[$j]} );
#		$self -> {'jackknife_raw_results'}[$i-1] = \@file;
		push( @{$self -> jackknife_raw_results()->[$i-1]}, $file[$j]);
	      } else {
		shift( @{$file[$j]} );
#		$self -> {'bootstrap_raw_results'}[$i-1] = \@file;
		push( @{$self -> bootstrap_raw_results()->[$i-1]}, $file[$j] );
	      }
	    }
	  }
	}
      }
end bca_read_raw_results

# }}} bca_read_raw_results

# {{{ calculate_diagnostic_means

start calculate_diagnostic_means
      {
	my ( @sum, @diagsum, %diag_idx );
	for ( my $i = 0; $i < scalar @{$self -> diagnostic_parameters()}; $i++ ) {
	  $diag_idx{$self -> diagnostic_parameters() -> [$i]} = $i;
	}

	my $def = 0;
	# Prepared model, skip the first (the original)
	for ( my $k = 1; $k < scalar @{$self -> bootstrap_diagnostics ->
					 [$model_number-1]}; $k++ ) {
	  # Diagnostics
	  if( defined $self -> bootstrap_diagnostics ->
	      [$model_number-1][$k] ) {
	    $def++;
	    for ( my $l = 0; $l < scalar @{$self -> bootstrap_diagnostics ->
					       [$model_number-1][$k]}; $l++ ) {
	      $sum[$l] += $self -> bootstrap_diagnostics ->
		  [$model_number-1][$k][$l];
	    }
	  }
	}

	# divide by the number of bootstrap samples (-1 to get rid of the original
	# model) The [0] in the index is there to indicate the 'model' level. Mostly
	# used for printing
	for ( my $l = 0; $l <= $#sum; $l++ ) {
	  if( $l == $diag_idx{'significant_digits'} ) {
	    $self->result_parameters->{'diagnostic_means'} -> [$model_number-1][0][$l] =
		$sum[$l] / $def;
	  } else {
	    $self->result_parameters->{'diagnostic_means'} -> [$model_number-1][0][$l] =
		$sum[$l] / ( scalar @{$self -> bootstrap_diagnostics ->
					  [$model_number-1]} - 1);
	  }
	}
	$self->result_parameters->{'diagnostic_means_labels'} -> [$model_number-1] =
	  [[],\@parameter_names];
      }
end calculate_diagnostic_means

# }}} calculate_diagnostic_means

# {{{ calculate_means

start calculate_means
      {
	my ( @sum, @diagsum );
	# Prepared model, skip the first (the original)
	for ( my $k = 1; $k < scalar @{$self -> bootstrap_estimates ->
					 [$model_number-1]}; $k++ ) {
	  # Estimates
	  for ( my $l = 0; $l < scalar @{$self -> bootstrap_estimates ->
					   [$model_number-1][$k]}; $l++ ) {
	    $sum[$l] += $self -> bootstrap_estimates ->
	      [$model_number-1][$k][$l];
	  }
	}
	# divide by the number of bootstrap samples (-1 to get rid of the original
	# model) The [0] in the index is there to indicate the 'model' level. Mostly
	# used for printing
	my $samples = scalar @{$self -> bootstrap_estimates ->
				 [$model_number-1]} - 1;
	for ( my $l = 0; $l <= $#sum; $l++ ) {
	  my $mean = $sum[$l] / $samples;
	  $self->result_parameters->{'means'} -> [$model_number-1][0][$l] = $mean;
	  my $bias = $mean - $self ->
	    bootstrap_estimates -> [$model_number-1][0][$l];
	  $self->result_parameters->{'bias'} -> [$model_number-1][0][$l] = $bias;
	  if ( $self->bootstrap_estimates -> [$model_number-1][0][$l] != 0 and
	       $bias/$self->bootstrap_estimates -> [$model_number-1][0][$l]
	       > $self -> large_bias_limit() ) {
	    $self->result_parameters->{'large_bias'} -> [$model_number-1][0][$l] = 1;
	  } else {
	    $self->result_parameters->{'large_bias'} -> [$model_number-1][0][$l] = 0;
	  }
	}
	$self->result_parameters->{'means_labels'} -> [$model_number-1] =
	  [[],\@parameter_names];

	$self->result_parameters->{'bias_labels'} -> [$model_number-1] =
	  [[],\@parameter_names];
      }
end calculate_means

# }}} calculate_means

# {{{ calculate_jackknife_means

start calculate_jackknife_means
      {
	my @sum;
	# Prepared model, skip the first (the original)
	if( defined $self -> jackknife_estimates ){
	  unless (defined $self -> jackknife_estimates->[$model_number-1]){
	    print "Jackknife estimates missing, cannot compute jackknife means.\n";
	    return;
	  }
	  for ( my $k = 1; $k < scalar @{$self -> jackknife_estimates->[$model_number-1]}; $k++ ) {
	    # Estimate
	    unless (defined $self -> jackknife_estimates->[$model_number-1][$k]){
	      print "Jackknife estimates missing for model ".($k+1).
		  ", cannot compute jackknife means.\n";
	      return;
	    }
	    for ( my $l = 0; $l <
		  scalar @{$self -> jackknife_estimates->[$model_number-1][$k]}; $l++ ) {
	      $sum[$l] += $self -> jackknife_estimates->[$model_number-1][$k][$l];
	    }
	  }
	  # divide by the number of jackknife samples (-1 to get rid of the original model)
	  # The [0] in the index is there to indicate the 'model' level. Mostly used for printing
#	  unless (defined $self -> jackknife_estimates->[$model_number-1][0]){
#	    print "Results missing for original model".
#		", cannot compute jackknife means.\n";
#	    return;
#	  }
	  for ( my $l = 0; $l <	scalar @sum; $l++ ) {
#		scalar @{$self -> jackknife_estimates->[$model_number-1][0]}; $l++ ) {
	    if( ( scalar @{$self -> jackknife_estimates->[$model_number-1]} - 1) != 0 ) {
	      $self->result_parameters->{'jackknife_means'} -> [$model_number-1][0][$l] =
		  $sum[$l] / ( scalar @{$self -> jackknife_estimates->[$model_number-1]} - 1);
	    }
	  }
	  $self->result_parameters->{'jackknife_means_labels'} -> [$model_number-1] = [[],\@parameter_names];
	}
      }
end calculate_jackknife_means

# }}} calculate_jackknife_means

# {{{ calculate_medians
start calculate_medians
      {
	my @medians;
	# Loop the parameters
	for ( my $l = 0; $l < scalar @{$self -> bootstrap_estimates->
					 [$model_number-1][0]}; $l++ ) {
	  my @parameter_array;
	  # From 1 to get rid of original model
	  for ( my $k = 1; $k < scalar @{$self -> bootstrap_estimates->
					   [$model_number-1]}; $k++ ) {
	    $parameter_array[$k-1] =
	      $self -> bootstrap_estimates->[$model_number-1][$k][$l];
	  }
	  my @sorted = sort {$a <=> $b} @parameter_array;
	  # median postition is half the ( array length - 1 ).
	  my $median_position = ( $#sorted ) / 2;
	  my ($int_med,$frac_med)   = split(/\./, $median_position );
	  $frac_med = eval("0.".$frac_med);
	  my $median_low  = $sorted[ $int_med ];
	  my $median_high = ( $sorted[ $int_med + 1 ] - $sorted[ $int_med ] ) * $frac_med;
	  $medians[$l] = $median_low + $median_high;
	}
	# The [0] in the index is there to indicate the 'model' level. Mostly used for printing
	$self->result_parameters->{'medians'} -> [$model_number-1][0] = \@medians;
	$self->result_parameters->{'medians_labels'} -> [$model_number-1] = [[],\@parameter_names];
      }
end calculate_medians
# }}} calculate_medians

# {{{ calculate_standard_error_confidence_intervals
start calculate_standard_error_confidence_intervals
      {
	# Sort the limits from the inside out
	my @limits = sort { $b <=> $a } keys %{$self -> confidence_limits()};
	foreach my $limit ( @limits ) {
	  my ( @lower_limits, @upper_limits, @within_ci );
	  # Loop the estimates of the first (original) model
	  for ( my $l = 0; $l < scalar @{$self -> bootstrap_estimates->
					   [$model_number-1][0]}; $l++ ) {
	    my $lower_limit =
	      $self -> bootstrap_estimates->[$model_number-1][0][$l] -
		$self->result_parameters->{'standard_errors'}->[$model_number-1][0][$l] *
		  $self -> confidence_limits ->{$limit};
	    my $upper_limit =
	      $self -> bootstrap_estimates->[$model_number-1][0][$l] +
		$self->result_parameters->{'standard_errors'}->[$model_number-1][0][$l] *
		  $self -> confidence_limits ->{$limit};
	    push( @lower_limits, $lower_limit );
	    push(  @upper_limits, $upper_limit );
	    if ( $self -> se_confidence_intervals_check < $upper_limit and
		 $self -> se_confidence_intervals_check > $lower_limit ) {
	      push( @within_ci , 1 );
	    } else {
	      push( @within_ci , 0 );
	    }
	  }
	  unshift( @{$self->result_parameters->{'standard_error_confidence_intervals'} ->
		       [$model_number-1]}, \@lower_limits );
	  push( @{$self->result_parameters->{'standard_error_confidence_intervals'} ->
		    [$model_number-1]}, \@upper_limits );
	  $self->result_parameters->{'within_se_confidence_intervals'} ->
	    [$model_number-1]{$limit} = \@within_ci;
	  unshift( @{$self->result_parameters->{'standard_error_confidence_intervals_labels'} ->
		       [$model_number-1][0]}, ($limit/2).'%' );
	  push( @{$self->result_parameters->{'standard_error_confidence_intervals_labels'} ->
		    [$model_number-1][0]}, (100-($limit/2)).'%' );
	  push( @{$self->result_parameters->{'within_se_confidence_intervals_labels'} ->
		    [$model_number-1][0]}, $limit.'%' );
	}
	$self->result_parameters->{'standard_error_confidence_intervals_labels'} -> [$model_number-1][1] =
	  \@parameter_names;
	$self->result_parameters->{'within_se_confidence_intervals_labels'} -> [$model_number-1][1] =
	  \@parameter_names;
      }
end calculate_standard_error_confidence_intervals
# }}} calculate_standard_error_confidence_intervals

# {{{ calculate_standard_errors

start calculate_standard_errors
      {
	my @se;
	# Prepared model, skip the first (the original)
	for ( my $k = 1; $k < scalar @{$self -> bootstrap_estimates->[$model_number-1]}; $k++ ) {
	  # Estimate
	  for ( my $l = 0; $l <
		scalar @{$self -> bootstrap_estimates->[$model_number-1][$k]}; $l++ ) {
	    $se[$l] += ( $self -> bootstrap_estimates->[$model_number-1][$k][$l] - 
			 $self->result_parameters->{'means'}->[$model_number-1][0][$l] )**2;
	  }
	}
	# divide by the number of bootstrap samples -1 (-2 to get rid of the original model)
	# The [0] in the index is there to indicate the 'model' level.
	for ( my $l = 0; $l <
	      scalar @{$self -> bootstrap_estimates->[$model_number-1][0]}; $l++ ) {
	  my $div = ( scalar @{$self -> bootstrap_estimates->[$model_number-1]} - 2 );
	  if( defined $div and not $div == 0 ) { 
	    $self->result_parameters->{'standard_errors'} -> [$model_number-1][0][$l] =
		($se[$l] / $div  )**0.5;
	  } else {
	    $self->result_parameters->{'standard_errors'} -> [$model_number-1][0][$l] = undef;
	  }
	}
	$self->result_parameters->{'standard_errors_labels'} -> [$model_number-1] = [[],\@parameter_names];
      }
end calculate_standard_errors

# }}} calculate_standard_errors

# {{{ calculate_bca_confidence_intervals

start calculate_bca_confidence_intervals
      {
	sub c_get_z0 {
	  my $arr_ref  = shift;
	  my $orig_value = shift;
	  my $num_less_than_orig = 0;
	  my $nvalues = 0;
	  my $z0;
	  foreach my $value ( @{$arr_ref} ) {
	    if ( defined $value and $value ne '' ) {
	      $num_less_than_orig++ if ( $value < $orig_value );
	      $nvalues ++;
	    }
	  }

	  unless ( $nvalues == 0 ) {
	    if ( ($num_less_than_orig / $nvalues ) == 0 ) {
	      $z0 = -100;
	    } elsif ( ($num_less_than_orig / $nvalues ) == 1 ) {
	      $z0 = 100;
	    } else {
	      $z0 = udistr( 1 - ($num_less_than_orig / $nvalues ) );
	    }
	  }
#	  return ( $z0, $nvalues );
#	  print sprintf( "%4s:%5.0f,%4s:%15.8g  ",'N:',$num_less_than_orig,'ZO', $z0);
	  return $z0;
	}

	sub c_get_acc {
	  my $arr_ref = shift;
	  my $jk_mean = shift;
	  my $acc_upper = 0;
	  my $acc_lower = 0;
	  my $nvalues = 0;
	  my $acc;
	  foreach my $value ( @{$arr_ref} ){
	    if ( defined $value and $value ne '' ) {
	      $acc_upper = $acc_upper + ($jk_mean-$value)**3;
	      $acc_lower = $acc_lower + ($jk_mean-$value)**2;
	      $nvalues ++;
	    }
	  }
	  $acc_lower = 6*($acc_lower**(3/2));
	  unless ( $acc_lower == 0 ) {
	    $acc = $acc_upper / $acc_lower;
	  } else {
	    $acc = $acc_upper / 0.001;
	  }
#	  return ( $acc, $nvalues );
#	  print sprintf( "%4s:%15.8g%4s%8.5g\n",'ACC', $acc,'JKm', $jk_mean);
	  return $acc;
	}

	sub c_get_alphas {
	  my $old_alphas = shift;
	  my $acc = shift;
	  my $z0 = shift;
	  my $denom;
	  my @new_alphas = ();
	  foreach my $position ( @{$old_alphas} ) {
	    if ( $position == 0 ){
	      $denom = -100;
	    } elsif ( $position == 100 ) {
	      $denom = 100;
	    } else {
	      $denom = $z0 + udistr( 1 - $position/100 );
	    }
	    my $nom     = 1 - $acc * $denom;
	    my $lim = 100*uprob( - ( $z0 + $denom / $nom ) );
	    push( @new_alphas, $lim );
	  }
#	  print "@new_alphas\n";
	  return \@new_alphas;
	}

	my @limits = sort { $a <=> $b } keys %{$self -> confidence_limits};
	# Add the upper limits
	my $limnum = $#limits;
	for ( my $i = $limnum; $i >= 0; $i-- ) {
	  $limits[$i] = $limits[$i]/2;
	  push( @limits, 100-$limits[$i] );
	}
	my ( @bootstrap_array, @jackknife_array, @new_alphas, @z0, @acc );
	# Loop the estimates of the first (original) model
	for ( my $l = 0; $l < scalar @{$self -> bootstrap_estimates->
					 [$model_number-1][0]}; $l++ ) {
	  my ( @unsorted_array1, @unsorted_array2 );
	  # Loop the bootstrap samples from 1 to get rid of original model
	  for ( my $k = 1; $k < scalar @{$self -> bootstrap_estimates->
					   [$model_number-1]}; $k++ ) {
	    $unsorted_array1[$k-1] =
	      $self -> bootstrap_estimates->[$model_number-1][$k][$l];
	  }
	  @{$bootstrap_array[$l]} = sort {$a <=> $b} @unsorted_array1;

	  # Loop the jackknife samples from 1 to get rid of original model
	  for ( my $k = 1; $k < scalar @{$self -> jackknife_estimates->
					   [$model_number-1]}; $k++ ) {
	    $unsorted_array2[$k-1] =
	      $self -> jackknife_estimates->[$model_number-1][$k][$l];
	  }
	  @{$jackknife_array[$l]} = sort {$a <=> $b} @unsorted_array2;
	  $z0[$l]         = c_get_z0     ( $bootstrap_array[$l],
					   $self -> bootstrap_estimates ->
					   [$model_number-1][0][$l] );
	  $acc[$l]        = c_get_acc    ( $jackknife_array[$l],
					   $self->result_parameters->{'jackknife_means'} ->
					   [$model_number-1][0][$l] );
	  $new_alphas[$l] = c_get_alphas ( \@limits, $acc[$l], $z0[$l] );
	}
	# Loop limits
	for ( my $lim_idx = 0; $lim_idx <= $#limits; $lim_idx++ ) {
	  my @percentiles;
	  # Loop parameters
	  for ( my $l = 0; $l <= $#bootstrap_array; $l++ ) {
	    my $limit = $new_alphas[$l][$lim_idx]/100;
	    my $position = ( scalar @{$bootstrap_array[$l]} + 1 ) * $limit;
	    my $percentile;
	    if ( $position < 1 ) {
	      $percentile = undef;
	    } elsif ( $position > scalar @{$bootstrap_array[$l]} ) {
	      $percentile = undef;
	    } else {
	      my ($int_med,$frac_med)   = split(/\./, $position );
	      $frac_med = eval("0.".$frac_med);
	      my $percentile_low  = $bootstrap_array[$l][ $int_med - 1];
	      my $percentile_high = ( $bootstrap_array[$l][ $int_med ] -
				      $bootstrap_array[$l][ $int_med - 1] ) * $frac_med;
	      $percentile = $percentile_low + $percentile_high;
	    }
	    push( @percentiles, $percentile );
	  }
	  push( @{$self->result_parameters->{'bca_confidence_intervals'} -> [$model_number-1]},
		\@percentiles );
	  push( @{$self->result_parameters->{'bca_confidence_intervals_labels'}->[$model_number-1][0]},
		$limits[$lim_idx].'%');
	}
	# Check the intervals
	for ( my $lim_idx = 0; $lim_idx <= $limnum; $lim_idx++ ) {
	  my @within_ci;
	  for ( my $l = 0; $l <= $#bootstrap_array; $l++ ) {
	    my $lower_limit = $self->result_parameters->{'bca_confidence_intervals'} ->
	      [$model_number-1][$lim_idx][$l];
	    my $upper_limit = $self->result_parameters->{'bca_confidence_intervals'} ->
	      [$model_number-1][($limnum*2+1)-$lim_idx][$l];
	    if ( $self -> bca_confidence_intervals_check < $upper_limit and
		 $self -> bca_confidence_intervals_check > $lower_limit ) {
	      push( @within_ci , 1 );
	    } else {
	      push( @within_ci , 0 );
	    }
	  }
	  $self->result_parameters->{'within_bca_confidence_intervals'} ->
	    [$model_number-1]{$limits[$lim_idx]*2} = \@within_ci;
	}
	$self->result_parameters->{'bca_confidence_intervals_labels'} -> [$model_number-1][1] =
	  \@parameter_names;
      }
end calculate_bca_confidence_intervals

# }}} calculate_bca_confidence_intervals

# {{{ calculate_percentile_confidence_intervals

start calculate_percentile_confidence_intervals
      {
	# Sort the limits from the inside out
	my @limits = sort { $b <=> $a } keys %{$self -> confidence_limits};
	foreach my $limit ( @limits ) {
	  my ( @lower_limits, @upper_limits, @within_ci );
	  # Loop the estimates of the first (original) model
	  for ( my $l = 0; $l < scalar @{$self -> bootstrap_estimates->
					   [$model_number-1][0]}; $l++ ) {
	    my @parameter_array;
	    # Loop the bootstrap samples from 1 to get rid of original model
	    for ( my $k = 1; $k < scalar @{$self -> bootstrap_estimates->
					     [$model_number-1]}; $k++ ) {
	      my $val = $self -> bootstrap_estimates->[$model_number-1][$k][$l];
	      # get rid of undefined values (these were probably deleted
	      # when the bootstrap_estimates was created
	      push( @parameter_array, $val ) if( defined $val );
	    }
	    my @sorted = sort {$a <=> $b} @parameter_array;
	    for my $side ( 'lower', 'upper' ) {
	      my $use_limit = $side eq 'lower' ? $limit/200 : 1-($limit/200);
	      # percentile postition is:
	      my $percentile_position = ( $#sorted + 2 ) * $use_limit;
	      my $percentile;
	      if ( $percentile_position < 1 ) {
		$percentile = undef;
	      } elsif ( $percentile_position > $#sorted +1) {
		$percentile = undef;
	      } else {
		my ($int_med,$frac_med)   = split(/\./, $percentile_position );
		$frac_med = eval("0.".$frac_med);
		my $percentile_low  = $sorted[ $int_med - 1];
		my $percentile_high = ( $sorted[ $int_med ] - $sorted[ $int_med - 1] ) * $frac_med;
		$percentile = $percentile_low + $percentile_high;
	      }
	      push( @lower_limits, $percentile ) if ( $side eq 'lower' );
	      push( @upper_limits, $percentile ) if ( $side eq 'upper' );
	    }
	    if ( $self -> percentile_confidence_intervals_check() < $upper_limits[$#upper_limits] and
		 $self -> percentile_confidence_intervals_check() > $lower_limits[$#lower_limits] ) {
	      push( @within_ci , 1 );
	    } else {
	      push( @within_ci , 0 );
	    }
	  }
	  unshift( @{$self->result_parameters->{'percentile_confidence_intervals'} ->
		       [$model_number-1]}, \@lower_limits );
	  push( @{$self->result_parameters->{'percentile_confidence_intervals'} ->
		    [$model_number-1]}, \@upper_limits );
	  unshift( @{$self->result_parameters->{'percentile_confidence_intervals_labels'}->
		       [$model_number-1][0]}, ($limit/2).'%' );
	  push( @{$self->result_parameters->{'percentile_confidence_intervals_labels'}->
		    [$model_number-1][0]},(100-($limit/2)).'%');
	  $self->result_parameters->{'within_percentiles'}->[$model_number-1]{$limit}=\@within_ci;
	}
	$self->result_parameters->{'percentile_confidence_intervals_labels'} ->
	  [$model_number-1][1] = \@parameter_names;
      }
end calculate_percentile_confidence_intervals

# }}} calculate_percentile_confidence_intervals

# {{{ modelfit_post_fork_analyze

start modelfit_post_fork_analyze
end modelfit_post_fork_analyze

# }}}

# {{{ resample

start resample
      {
	my $dataObj = $model -> datas -> [0];
	for( my $i = 1; $i <= $self ->samples(); $i++ ) {
	  my ($bs_dir, $bs_name) = OSspecific::absolute_path( $self ->directory(), "bs$i.dta" );
	  my $new_name = $bs_dir . $bs_name;  
	  my $boot_sample = $dataObj -> resample( subjects => $self -> subjects(),
						  new_name => $new_name,
						  target   => $target );
	  my $newmodel = $model -> copy( filename => "bs$i.mod",
					 target   => $target,
					 ignore_missing_files => 1 );
	  $newmodel -> datafiles( new_names => ["bs$i.dta"] );
	  $newmodel -> datas -> [0] = $boot_sample ;
	  $newmodel -> write;
	  push( @resample_models, $newmodel );
	}
      }
end resample

# }}} resample

# {{{ _sampleTools

start _sampleTools
      {
	foreach my $tool ( @{$self -> tools} ) {
	  my @models = @{$tool -> models};
	  foreach my $model (@models){
	    my $dataObj = $model -> datas -> [0];
	    for( my $i = 1; $i <= $samples; $i++ ) {
	      my $boot_sample = $dataObj -> resample( 'subjects' => $self -> subjects,
						      'new_name' => "bs$i.dta",
						      'target' => $target );
	      my $newmodel;
	      $newmodel = $model -> copy( filename => "bs$i.mod" );
	      $newmodel -> datafiles( new_names => ["bs$i.dta"] );
	      $newmodel -> datas -> [0] = $boot_sample ;
	      $newmodel -> write;
	      if( defined( $tool -> models ) ){
		push( @{$tool -> models}, $newmodel );
	      } else {
		$tool -> models( [ $newmodel ] );
	      }
	    }
	  }
	}
      }
end _sampleTools

# }}} _sampleTools

# {{{ create_matlab_scripts

start create_matlab_scripts
    {
      if( defined $PsN::lib_dir ){
	unless( -e $PsN::lib_dir . '/matlab/histograms.m' and
		-e $PsN::lib_dir . '/matlab/bca.m' ){
	  croak('Bootstrap matlab template scripts are not installed, no matlab scripts will be generated.' );
	  return;
	}

	open( PROF, $PsN::lib_dir . '/matlab/histograms.m' );
	my @file = <PROF>;
	close( PROF );
	my $found_code;
	my $code_area_start=0;
	my $code_area_end=0;


	for(my $i = 0;$i < scalar(@file); $i++) {
	  if( $file[$i] =~ /% ---------- Autogenerated code below ----------/ ){
	    $found_code = 1;
	    $code_area_start = $i;
	  }
	  if( $file[$i] =~ /% ---------- End autogenerated code ----------/ ){
	    unless( $found_code ){
	      croak('Bootstrap matlab template script is malformated, no matlab scripts will be generated' );
	      return;
	    }
	    $code_area_end = $i;
	  }
	}
	
	my @auto_code;
	if( $self -> type() eq 'bca' ){
	  push( @auto_code, "use_bca = 1;				% Was a BCa-type of\n" );
	} else {
	  push( @auto_code, "use_bca = 0;				% Was a BCa-type of\n" );
	}

        push( @auto_code, "                                % bootstrap run?\n" );
	if( ref $self ->samples() eq 'ARRAY' ) {
	  push( @auto_code, "bs_samples = ".$self ->samples()->[0][0].";			% Number of bootstrap samples\n" );
	} else {
	  push( @auto_code, "bs_samples = ".$self ->samples().";			% Number of bootstrap samples\n" );
	}	  
	if( $self -> type() eq 'bca' ){
	  my $ninds = $self -> models -> [0]
	      -> datas -> [0] -> count_ind;
	  push( @auto_code, "jk_samples = $ninds;			% Number of (BCa) jackknife samples\n\n" );
	}
	
	push( @auto_code, "col_names = { 'Significant Digits',\n" );
        push( @auto_code, "	         'Condition Number',\n" );
        push( @auto_code, "	         'OFV',\n" );

	my $nps = $self ->models() -> [0] -> nomegas -> [0];

	my %param_names;
	my( @par_names, @se_names, @np_names, @sh_names );
	foreach my $param ( 'theta','omega','sigma' ) {
	  my $labels = $self ->models() -> [0] -> labels( parameter_type => $param );
	  if ( defined $labels ){
	    foreach my $label ( @{$labels -> [0]} ){
	      push( @par_names, "	         '",$label,"',\n" );
	      push( @se_names, "	         '",'se-'.$label,"',\n" );
	    }
	  }
	}

	for( my $i = 1; $i <= ($nps*($nps+1)/2); $i++ ) {
	  push( @np_names, "	         '",'np-om'.$i,"',\n" );
	}

	for( my $i = 1; $i <= $nps; $i++ ) {
	  push( @sh_names, "	         '",'shrinkage-eta'.$i,"',\n" );
	}

	push( @sh_names, "	         '",'shrinkage-eps',"'\n" );

# NP not used for now

	push( @auto_code,(@par_names, @se_names, @sh_names));
#	push( @auto_code,(@par_names, @se_names, @np_names, @sh_names));
        push( @auto_code, "	      };\n\n" );

	my @np_columns = (0) x ($nps*($nps+1)/2);
	my @sh_columns = (0) x ($nps+1);

	if( $self -> type() eq 'bca' ){
	  push( @auto_code, "fixed_columns = [ 0, 0, 0, " );
	} else {
	  push( @auto_code, "fixed_columns = [ 0, 0, 0, " );
	}
	my ( @fixed_columns, @same_columns, @adjust_axes );
	foreach my $param ( 'theta','omega','sigma' ) {
	  my $fixed = $self ->models() -> [0] -> fixed( parameter_type => $param );

	  if ( defined $fixed ){
	    push( @fixed_columns, @{$fixed -> [0]} );
	    if( $param eq 'theta' ) {
	      push( @same_columns, (0) x scalar( @{$fixed -> [0]} ) );
	    }
	  }
	}

	@adjust_axes = (1) x ( ($#fixed_columns + 1) * 2 +
			       $#sh_columns + 1 );
#			       $#np_columns + $#sh_columns + 2 );

        push( @auto_code , join( ', ' , @fixed_columns).', '.
	      join( ', ' , @fixed_columns).', '.
#	      join( ', ' , @np_columns).', '.
	      join( ', ' , @sh_columns)."];\n\n" );

	if( $self -> type() eq 'bca' ){
	  push( @auto_code, "same_columns  = [ 0, 0, 0, " );
	} else {
	  push( @auto_code, "same_columns  = [ 0, 0, 0, " );
	}
	foreach my $param ( 'omegas','sigmas' ) {
	  my $parameters = $self ->models() -> [0] -> problems -> [0] -> $param;
	  foreach my $parameter ( @{$parameters} ){
	    if( $parameter -> same() ){
	      push( @same_columns, (1) x $parameter -> size() );
	    } else {
	      push( @same_columns, (0) x scalar @{$parameter -> options} );
	    }
	  }
	}
        push( @auto_code , join( ', ' , @same_columns ).', '.
	      join( ', ' , @same_columns).', '.
#	      join( ', ' , @np_columns).', '.
	      join( ', ' , @sh_columns)."];\n\n" );

        push( @auto_code , "adjust_axes   = [ 1, 1, 1, ".join( ', ' , @adjust_axes)."];\n\n" );

#        push( @auto_code , 'npomegas = '.($nps*($nps+1)/2).";\n\n" );
        push( @auto_code , "npomegas = 0;\n\n" );
	

        push( @auto_code, "minimization_successful_col    = 5;	% Column number for the\n" );
        push( @auto_code, "                                                     % minimization sucessful flag\n" );
        push( @auto_code, "covariance_step_successful_col = 6;	% As above for cov-step warnings\n" );
        push( @auto_code, "covariance_step_warnings_col   = 7;	% etc\n" );
        push( @auto_code, "estimate_near_boundary_col     = 8;	% etc\n" );

        push( @auto_code, "not_data_cols = 13;			   % Number of columns in the\n" );
        push( @auto_code, "                                        % beginning that are not\n" );
        push( @auto_code, "                                        % parameter estimates.\n" );

        push( @auto_code, "filename = 'raw_results_matlab.csv';\n" );
	
	splice( @file, $code_area_start, ($code_area_end - $code_area_start), @auto_code );	
	open( OUTFILE, ">", $self ->directory() . "/histograms.m" );
	print OUTFILE "addpath " . $PsN::lib_dir . ";\n";
	print OUTFILE @file ;
	close OUTFILE;

	open( OUTFILE, ">", $self ->directory() . "/raw_results_matlab.csv" );
	for( my $i = 0; $i < scalar ( @{$self -> raw_results -> [0]} ); $i ++ ){
# 	  $self -> raw_results() -> [0] -> [$i][0] =
# 	      $self -> raw_results() -> [0] -> [$i][0] eq 'bootstrap' ?
# 	      1 : $self -> raw_results() -> [0] -> [$i][0];
# 	  $self -> raw_results() -> [0] -> [$i][0] =
# 	      $self -> raw_results() -> [0] -> [$i][0] eq 'jackknife' ?
# 	      2 : $self -> raw_results() -> [0] -> [$i][0];
	  map( $_ = $_ eq 'NA' ? 'NaN' : $_, @{$self -> raw_results() -> [0] -> [$i]} );
	  map( $_ = not( defined $_ ) ? 'NaN' : $_, @{$self -> raw_results() -> [0] -> [$i]} );
	  print OUTFILE join( ',', @{$self -> raw_results() -> [0] -> [$i]} ), "\n";
	}
	close OUTFILE;

      } else {
	croak('matlab_dir not configured, no matlab scripts will be generated.');
	return;
      }
    }
end create_matlab_scripts

# }}}

# {{{ create_R_scripts
start create_R_scripts
    {
      unless( -e $PsN::lib_dir . '/R-scripts/bootstrap.R' ){
	ui -> print( message => 'Bootstrap R-script are not installed, no R-script will be generated.' ,
		     newline =>1);
	return;
      }

      my ($dir,$file) =
	  OSspecific::absolute_path( $self ->directory(),
				     $self -> raw_results_file()->[0] );

      open( FILE, $PsN::lib_dir . '/R-scripts/bootstrap.R');
      my @script = <FILE>;
      close( FILE );
      foreach (@script){
	if (/^bootstrap.data/){
	  s/raw_results1.csv/$file/;
	  last;
	}
      }
      open( OUT, ">", $self ->directory() . "/bootstrap.R" );
      foreach (@script){
	print OUT;
      }
      close (OUT);

      # Execute the script

      if( defined $PsN::config -> {'_'} -> {'R'} ) {
	chdir( $self ->directory() );
	system( $PsN::config -> {'_'} -> {'R'}." CMD BATCH bootstrap.R" );
      }

    }
end create_R_scripts
# }}}
