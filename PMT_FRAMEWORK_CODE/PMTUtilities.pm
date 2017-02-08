package PMTUtilities;

use strict;
use Carp;

select STDERR; $| = 1;

use File::Spec;

use overload;

use threads;
use threads::shared;
use Config::Simple;
use Data::Dumper;
use File::Basename qw(basename dirname);
use File::Find;
use File::Spec;
use File::Temp;
use Getopt::Long;
use IO::File;
use IO::Handle;
use IO::Select;
use Net::Curl::Easy qw(:constants);
use POSIX (); ## we do not import anything in order to avoid name clashes with Date::Format;
use Time::Local qw(timelocal);
use XML::Simple;

require Exporter;
our @ISA=qw(Exporter);
our @EXPORT_OK = qw(runSysCmd executeInHelper dprint getCredentials getPMTSysConfig getDBConnectionParameters loadResource getJobDefinitions getFlowRunId isSelf parseURI mergeRecursiveHash expand applyFilterChain glob2Regex evalBoolean icdefined all any isDefined icDefined getFileList serializeTo deserializeFrom h2a partial loadClass getSubRefFromName setInOutValue fileExists);

#our @EXPORT_OK = qw(mergeRecursiveHash runSysCmd sysMoveFile sysCopyFile fileGrep cleanupFiles expand applyFilterChain glob2Regex evalBoolean getFileMTime mergeData all any isDefined partial parseNVPairs parseVList parseRecords getFileList PollingDirReader icdefined);

use constant VALUESPEC => '__valuespec__';
use constant NULL      => '__null__';
# ==========================================================================
#
# Some Variables accessible by other modules ... eg, to specify a logger
#
# ==========================================================================

our $_logger = undef;

my $_logwarned = 0;

# ==========================================================================
#
# Version information
#
# ==========================================================================

#my $VERSION = "1.0.0";
#my $whatversion = "@(#) VERSION 1.0.0";
# ==========================================================================
# 
# Some Directives ...
#
# ==========================================================================

autoflush STDERR 1;

# ==========================================================================
# 
# Declaration of main variables
#
# ==========================================================================

my $DEFAULT_DATE_FORMAT = "%Y-%m-%d %H:%M:%S";

sub dprint {
  my @a = @_;
  if ($ENV{'PMTEXECENV'} and $ENV{'PMTEXECENV'} =~ m/stdout::suppress/i) {
     # do nothing 
  }
  elsif ($ENV{'PMTEXECENV'} and $ENV{'PMTEXECENV'} =~ m/stdout::autoderef/i) {
    use Data::Dumper;
    my @b = map { Dumper($_) or $_;  } @a;
    print STDOUT @;
  }
  else {
    print STDOUT @a;
  }
}


sub setLogger {
  my $logger = shift;
  print STDERR "Setting logger to $logger";
  $_logger = shift;
}

sub _log {
  my %args = @_;
  if (not defined $_logger) {
    if ($_logwarned eq 0) {
      print STDERR  "DXOUtilitiesLog: NOTICE: No Logger is defined; Logging (temporarily) disabled\n";
      $_logwarned = 1;
    }
    if (defined $args{'message'}) {
      print STDERR "DXOUtilitiesLog: ".$args{'message'},"\n";
    }
    if (defined $args{'trace'}) {
      print STDERR "DXOUtilitiesLog: ".$args{'trace'},"\n";
    }
  }
  else {
    # Use the logger;
    my $disablelogging = $args{'_DISABLE_LOGGING_'};
    if (not defined $disablelogging) {
      $disablelogging = 0;
    }
    else {
      $disablelogging = $disablelogging + 0;
    }
    #print STDERR "disablelogging = $disablelogging\n";
    if ($disablelogging == 0) {
      $_logger->log(domain=>"system",@_);
    }
  }
}

# Still need to see where this fits in. File::Touch is available here but we need this for our filters
# and this would need remote file support I guess
sub touch {
  for my $filename (@_) {
    _log(level=>'trace',message=>"Touching $filename");
    if (not -e $filename) {
      my $TMP;
      open($TMP,'>',$filename) or croak {message=>"Failed to create file $filename: $!"};
      close $TMP;
    }
    if (-w $filename) {
      my $rc = utime undef,undef,$filename or croak {message=>"Could not touch file $filename: $!"};
      if ($rc == 0) {
        croak {message=>"Could not touch file $filename"};
      }
    }
    else {
      croak { message=>"Could not touch file $filename: Permission denied"};
    }
  }
  return 0;
}

sub evalBoolean {
	my %args = @_;
	my $val = $args{'value'};
  
  if ($val and ref \$val eq 'SCALAR') {
    if (uc $val eq 'Y') {
      return 1;
    }
    if (uc $val eq 'N') {
      return 0;
    }
    if (uc $val eq 'J') {
    	return 1;
    }
  }
  elsif ($val and ref $val eq 'CODE') {
  	my $v = &$val;
  	return evalBoolean(@_,value=>$v);
  }
  elsif ($val and ref $val eq 'ARRAY') {
  	if (scalar @$val > 0) {
  		return 1;
    }
    return 0;
  } 
  elsif ($val and ref $val eq 'HASH') {
  	my @k = keys %$val;
  	if (scalar @k > 0) {
  		return 1;
    }
    return 0;
  }
  elsif ($val and ref $val eq 'VOID') {
    return 0;
  }
  use Scalar::Util qw(looks_like_number);
  if (looks_like_number($val)) { $val = eval $val; if ($val) { return 1; } else { return 0; } } 
  elsif ($val) {
    return 1;
  }
  else {
    return 0;
  }
}

# ---------------------------------------------------------------------------

sub all {
  my %args = @_;
  my $sequence = $args{'sequence'};
  my $evaluator = $args{'evaluator'};
 
  if (not defined $evaluator) {
    $evaluator = \&evalBoolean;
  }
  
  my $rc = 0;

  if (ref $sequence eq 'CODE') {
    $sequence = &$sequence;
  }

  if (ref $sequence eq 'ARRAY') {
    my $rc = 0;
    for my $el (@$sequence) {
      $rc += &$evaluator(value=>$el);
    }
    if ($rc < scalar $sequence) {
    	return 0;
    }
    return $rc;
  }
  elsif (ref $sequence eq 'HASH') {
    my $rc = 0;
    my @seqkeys = keys %$sequence;
    for my $k (@seqkeys) {
      $rc += &$evaluator(value=>$sequence->{$k});
    }
    if ($rc < scalar @seqkeys) {
    	return 0;
    } 
    return $rc;
  }
}

# ---------------------------------------------------------------------------

sub isDefined {
  my %args = @_;
  my $val = $args{'value'};
	
  if (ref $val eq 'HASH' && exists $val->{'__DYNAMIC__'}) {
    return 0;
  }
  if (defined $val) {
    return 1;
  }
  else {
    return 0;
  }
}

# ---------------------------------------------------------------------------

sub icdefined {
  my @val = @_;
  my $vv = $val[0];
  if (ref $vv eq 'VOID') {
    return undef;
  }
  if (ref $vv eq 'HASH' and exists $vv->{'__DYNAMIC__'}) {
    return undef;
  }
  if (ref $vv eq 'VOID') {
    return undef;
  }
  if (scalar @val == 1) {
    return defined $vv;
  }
  if (@val) {
    return 1;
  }
  return 0;
  #return defined @val;
}

# ---------------------------------------------------------------------------

sub any {
  my %args = @_;
  my $sequence = $args{'sequence'};
  my $evaluator = $args{'evaluator'};
 
  if (not defined $evaluator) {
    $evaluator = \&evalBoolean;
  }
  
  my $rc = 0;

  if (ref $sequence eq 'CODE') {
    $sequence = &$sequence;
  }

  if (ref $sequence eq 'ARRAY') {
    my $rc = 0;
    for my $el (@$sequence) {
      $rc += &$evaluator(value=>$el);
    }
    return $rc;
  }
  elsif (ref $sequence eq 'HASH') {
    my $rc = 0;
    for my $k (keys %$sequence) {
      $rc += &$evaluator(value=>$sequence->{$k});
    }
    return $rc;
  }
}
sub setInOutValue {
  my %args = @_;
  my $rargs = $args{'args'};
  my $name = $args{'name'};
  my $val = $args{'value'};

  use List::MoreUtils qw(firstidx);

  my $ix = firstidx { $_ eq $name } @$rargs;

  # I have to do some trickery here too
  my $vix = firstidx {$_ eq 'value'} @_ + 1;

  if ($ix == -1) {
    croak { message=>"Invalid parameter name for returning value: $name" };
  }

  $ix = $ix+1;
  dprint "setting $name (index $ix) to ",$val,"in thread ",threads->tid(),"\n";

  if (ref $rargs->[$ix] and ref $rargs->[$ix] eq 'inout_value_ref') {
    dprint "i get a inout_value in thread ", threads->tid(),"\n";
    ${$rargs->[$ix]} = $_[$vix];
  }
  else {
    $rargs->[$ix] = $val;
  }
}

sub partial {
  my $funcref = shift;
  my @initparams = ();
  for my $a (@_) {
    if (ref $a and ref $a eq 'inout_value') {
      push @initparams, bless \$a,'inout_value_ref';
    }
    else {
      push @initparams,$a;
    }
  }
  #my @initparams = @_;
  return sub {
    my @allparams = (@initparams,@_) ;
    my $name = undef;
    if (ref $funcref eq 'CODE') {
      # all is fine
    }
    elsif (defined $funcref) {
      $name = $funcref; 
      $funcref = getSubRefFromName(name=>$funcref);
    }
    if (wantarray) {
      my @rc;
      eval {
        @rc = $funcref->(@allparams);
      };
      if ($@) {
        my $e = $@;
        #dprint "ERROR FOUND WHILE EXECUTING wantarray PARTIAL:$e->{'message'}\n";
        croak $e;
      }
      return @rc;
    }
    elsif (defined wantarray) {
      my $rc;
      eval {
        $rc = $funcref->(@allparams);
      };
      if ($@) {
        my $e = $@;
        #dprint "ERROR FOUND WHILE EXECUTING definedwant PARTIAL:$e\n";
        croak $e;
      }
      return $rc;
    }
    else {
      eval {
        $funcref->(@allparams);
      };
      if ($@) {
        my $e = $@;
        #dprint "ERROR FOUND WHILE EXECUTING PARTIAL:$e->{'message'}\n";
        croak $e;
      }
    }
  }
}

sub mergeRecursiveHash {
  my %args = @_;
  my $target = $args{'update'};
  my $source = $args{'src'};

  for my $key (keys %$source) {
    my $node = $source->{$key};
    if (ref $node eq 'HASH') {
      if (icdefined $target->{$key} and ref $target->{$key} eq 'HASH') {
        # do nothing
      }
      else {
        $target->{$key} = {};
      }
      mergeRecursiveHash(update=>$target->{$key},src=>$source->{$key});
    }
    else {
      #print STDERR "Setting $target from $source\n";
      $target->{$key} = $source->{$key};
    }
  }
}


sub mergeData {
  my %args =  @_;
  my $src = $args{'src'};
  my $target = $args{'update'};
  my $keepdefined;
  if (ref $src eq 'HASH' or defined overload::Method($src,'%{}')) {
    # all is well
  }
  else {
    croak { message=>'Invalid src type: Source type should implement HASH interface'};
  }

  if (not exists $args{'keepdefined'}) {
    $keepdefined = 0;
  }
  else {
    $keepdefined = evalBoolean(value=>$args{'keepdefined'});
  }
   
  if (ref $target eq 'HASH' or defined overload::Method($target,'%{}')) {
    _log(@_,level=>"trace",message=>"Target is a HASH");
  }
  for my $key (keys %$src) {
    my $rtype = ref $target;
    if (defined $args{'keep_keys'}) {
      my $check_in_keep = grep(/^$key$/,@{$args{'keep_keys'}});
      if ($check_in_keep eq 0) {
        _log(@_,level=>"debug",message=>"Ommitting key $key");
        next;
      }
    }
    if (ref $target eq 'HASH' or defined overload::Method($target,'%{}')) {
      if ($keepdefined) {
        if (defined $src->{$key}) {
          $target->{$key} = $src->{$key};
        }
      }
      else {  
        $target->{$key} = $src->{$key};
      }
    }
    else {
      my $rtype = ref $target;
      if (not defined $rtype) {
        $rtype = ref \$target;
      }
      croak { message=>"Unsupported target type $rtype"};
    }
  }
  
  return undef;
}


sub deserializeFrom {
  my %args = @_;
  my $source = $args{'io'};
  my $format = $args{'format'};
  my $wait_for = $args{'wait_for'};
  my $handlers = $args{'handlers'};
  my $timeout = $args{'timeout'};
  my $receiver_id = $args{'receiver_id'}; if (not defined $receiver_id) { $receiver_id = 'UNKNOWN'};
  my $ignore_error = $args{'ignore_error'};
  my $force_raw = $args{'force_raw'};
  if (not defined $force_raw) { $force_raw = []; }
  if (not defined $ignore_error) { $ignore_error = 0; }
  if (not defined $handlers) { 
    $handlers = {}; 
    if (1)  {
    }
  }


  my $controller = $args{'__controller__'};
  my $verbose = $args{'verbose'};

  # read calls do not support a timeout parameter, but we can do something with IO::Select calls ...

  my $packed_length;
  my $packed_dlength;
  my $src_format;
  
  #print STDERR "READING from ",$source,"\n"; 
  if ($source->can('connected')) {
    if (not $source->connected()) {
      #print STDERR "$$ CHANNEL is not connected\n";
      croak { message=>"Source IO Handle is not connected",data=>{category=>"connection",reason=>"not_connected",receiver_id=>$receiver_id} };
    }
    else {
      #print STDERR "$$ CHANNEL is connected\n";
    }
  }
  #else { print STDERR "$$ connected not supported\n"; } 
	if ($source->can('opened')) {
    if (not $source->opened()) {
      #print STDERR "$$ CHANNEL seems to closed\n";
      croak { message=>"Source IO Handle is not an opened handle", data=>{category=>"connection",reason=>"closed",receiver_id=>$receiver_id}};
    }
    else {
      #print STDERR "$$ CHANNEL seems be open \n";
    }
  }
  else { print STDERR "$$ opened not supported\n"; }
  if ($source->can('eof')) {
    if ($source->eof()) { 
      #print STDERR "$$ CHANNEL seems to be eof\n";
			croak {message=>"Source IO Handle $source is eof",data=>{category=>"connection",reason=>"eof",receiver_id=>$receiver_id} };
    }
    else {
      #print STDERR "$$ CHANNEL seems to be NOT eof\n";
    }
  }
  else { print STDERR "$$ eof not supported\n"; }
  

  my $wait_for_sub = sub {
    my %args = @_;
    my $wvalue = $args{'wait_for'}; 
    my $type = $args{'type'}; 
    my $directives = $args{'directives'}; 
    my $parsed_data = $args{'parsed_data'}; 
    my $unparsed_data = $args{'unparsed_datae'};

    if (not ref $wvalue or defined overload::Method($wvalue,q{""}) or defined overload::Method($wvalue,'${}')) {
      # test it against $directives {$type)
      my $ltype; if (defined $type) { $ltype = $type;} else { $ltype = $directives=>{'type'}; }
      my $l = 1;
      if ($ltype =~ m/$wvalue/ ) { return 1; } else { return 0; }
    }
    elsif (ref $wvalue eq 'HASH' or defined overload::Method($wvalue,'%{}')) {
    }
    else { # it is a hash
      my @wvalues = @$wvalue;
      my $ltype; if (defined $type) { $ltype = $type;} else { $ltype = $directives=>{'type'}; }
      for my $wv (@$wvalue) {
      	if ($ltype =~ m/$wv/ ) { return 1; } 
      }
      return 0;
    }
  };
  my $p_wait_for_sub;

  if (not defined $wait_for ) { $wait_for = '.*'; }

  if (not ref $wait_for or defined overload::Method($wait_for,q{""}) or defined overload::Method($wait_for, '${}') 
        or ref $wait_for eq 'HASH' or defined overload::Method($wait_for,'%{}') 
        or ref $wait_for eq 'ARRAY' or defined overload::Method($wait_for,'@{}')) 
  {
    $p_wait_for_sub = partial($wait_for_sub,wait_for=>$wait_for);
  }
  elsif (ref $wait_for eq 'CODE' or defined overload::Method($wait_for,'&{}')) {
    $p_wait_for_sub = $wait_for;
  }

  my $do_continue = 1;

  while ($do_continue) {

    my $deliver_this_message = 0;

		read $source, $packed_length, 4;
		read $source, $packed_dlength, 4;
		my $buffer_length = unpack('N',$packed_length);
		my $directive_length = unpack('N',$packed_dlength);
    #print STDERR "$$ Got lengths (buffer/directive): $buffer_length $directive_length from ",$source,"\n";
    if (not $buffer_length and not $directive_length) { print STDERR "$$ No data ? Returning immediately. This usually only appears at the end when one side disconnects or so ...\n"; return undef; }
		my $data_buffer;
		my $directives_buffer;

		read $source,$directives_buffer,$directive_length;
    #if ($verbose) { print STDERR "got directives: $directives_buffer\n";}
		read $source,$data_buffer,$buffer_length;
    #if ($verbose) { print STDERR "got data: $data_buffer\n";}

		use JSON;

		my $directives;
    eval { $directives = from_json($directives_buffer);} ;
    if ($@) { print "Error reading directives buffer $directives_buffer in $$ reading from $source\n" ; 
				croak { message=>"JSON in directives buffer parse error:$@", data=>{data=>$directives_buffer}};
    }

		my $send_method = $directives->{'data_serialization_method'};
		my $c;
		$send_method = uc $send_method;
		if (defined $args{'format_override'}) {
			$send_method = $args{'format_override'};
		}
    else {
    }
    
    my $type = $directives->{'type'};
    if (not $type) { $type = '*'; }
   
    if ( grep (m/$type/i,@$force_raw)) {
      $c = $data_buffer;
    }
		elsif ($send_method =~ m/^JSON$/) {
			eval {
				$c = from_json($data_buffer);
			};
			if ($@) {
				croak { message=>"JSON parse error:$@", data=>{data=>$data_buffer, directives=>$directives}};
			}
		}
		elsif ($send_method eq 'RAW') {
			$c = $data_buffer;
		}
		else {
			$c = $data_buffer;
		}


    #print STDERR "type = $type\n";
    #print STDERR "checking for handlers type ($$): $handlers->{$type}\n";
    # now check if the type corresponds to $wait_for 
    if ($p_wait_for_sub->(type=>$type,directives=>$directives,parsed_data=>$c,unparsed_data=>$data_buffer) and defined wantarray) {
      #print STDERR "I should deliver this message\n";
      $deliver_this_message = 1;
    }
    elsif (defined $handlers->{$type}) {
      #print STDERR "It does have a hlandler:",$handlers->{$type},"\n";
      eval {
        $handlers->{$type}->(directives=>$directives,data=>$c);
      };
      if ($@) {
        use Data::Dumper;
        #print STDERR "An error occurred while calling the handler: ",Dumper($@),"\n";
      }
    }
    elsif ($p_wait_for_sub->(type=>$type,directives=>$directives,parsed_data=>$c,unparsed_data=>$data_buffer) and not defined wantarray) {
      return undef;
    }
    else {
      # silently ignore this message
     
      use Data::Dumper;
      if (1) { 
        #print STDERR "(pid $$) Silently ignoring a message of type $type\n"; 
      } #, handlers = ",Dumper($handlers),"\n"; }
      #my @who_called_me = caller(2);
      #print STDERR "NOHANDLERS $$: handlers are not defined in : @who_called_me\n";
      #}
    }
    
    if ($deliver_this_message) {
		  if (wantarray) { return ($directives,$c); } 
      elsif (defined wantarray) { return $c; } 
      elsif (defined $directives->{'error'} and not $ignore_error) { croak { message=>"Error message received ",data=>{directives=>$directives,message=>$c} }; }
      else { $do_continue = 0; }
    }
  }
}

sub serializeTo {
  my %args = @_;
  my $data = $args{'data'};
  my $target = $args{'io'};
  my $format = $args{'format'};
  my $flush = $args{'flush'};
  my $message_type = $args{'type'};
  my $status = $args{'status'};
  my $error = $args{'error'};
  my $stream = $args{'stream'};
  my $lockvar = $args{'_lockvar_'};
  my $controller = $args{'__controller__'};
  my $channellock_checker = $args{'channellock_checker'};
  my $mqueue = $args{'message_queue'};
  my $directives = $args{'directives'};
  my $writer_id = $args{'writer_id'};
  my $locker = $args{'locker'};
  
  use Time::HiRes qw(time);
  if (not defined $writer_id) { use threads; $writer_id = 'writer:'.threads->tid(); }

  # print STDERR "Waiting for lock\n";
  #lock $lockvar->[0] if defined $lockvar;
  #print STDERR "LockAcquired\n";

  if (not defined $message_type) {
    if (defined $args{'directives'} and defined $args{'directives'}->{'type'}) {
      $message_type = $args{'directives'}->{'type'};
    }
    else {
      croak { message=>"Missing type argument in call to serializeTo"};
    }
  }

  #print STDERR "I should send a message of type $message_type\n";

  if ($target->can('connected')) {
    if (not $target->connected()) {
      croak { message=>"Target IO Handle is not connected" };
    }
  }
  elsif ($target->can('opened')) {
    if (not $target->opened()) {
      croak { message=>"Target IO Handle is not an opened handle" };
    }
  }

  use JSON;
  if (not defined $format)  { $format = 'JSON' ; }
  if (not defined $data) { $data={}; }
  $format='JSON';
  my $ldirectives;
  if (defined $args{'directives'}) { $ldirectives = $args{'directives'}; } else { $ldirectives = {}; }
  $ldirectives->{'data_serialization_method'}=$format;
  if (defined $message_type) { $ldirectives->{'type'} = $message_type; }
  if (icdefined $error) { $ldirectives->{'error'} = $error; }
  if (icdefined $status) { $ldirectives->{'status'} = $status; }
  #$ldirectives->{'status'} = $status;

  my $json_string ;
  if ($args{'json_data'}) { $json_string = $args{'json_data'}; } else { $json_string = to_json($data); $ldirectives->{'size'} = length($json_string); }
  my $jlength = length($json_string);
  my $packed_length = pack('N',$jlength);

  #$ldirectives->{'size'} = $jlength;

  if ($stream) { $ldirectives->{'stream'} = $stream; }
  my $dstring;
  if ($args{'json_directives'}) { $dstring = $args{'json_directives'};} else { $dstring = to_json($ldirectives); }
  my $dlength = length($dstring);
  my $packed_dlength = pack('N',$dlength);
 
  # now I need to find out whether I have to send it or queue it
  if (defined $args{'channellock_checker'}) {
    my $channel_locked;
    if (ref $channellock_checker eq 'CODE') {
      $channel_locked = $channellock_checker->();
    }
    else {
      $channel_locked = $args{'channellock_checker'};
    }

    if ($channel_locked and not $args{'wait_for'}) {
      if (not defined $mqueue) {
        croak {message=>"Channel is locked, and no message queue available"};
      }
      lock $mqueue;
      #print STDERR "$$ Channel is locked, I should quuee this message of type $message_type\n";
      if (not $directives->{'_queued_'}) {
      	$ldirectives->{'_queued_'} = time(); 
        my $qm = to_json({ directives=>$ldirectives,data=>$data});
      	push @$mqueue, $qm;
      }
      else { 
        #print STDERR "Message was allready queued\n",to_json({ directives=>$ldirectives,data=>$data}),"\n"; 
      }
      return;
    }
  }

  {
    #print STDERR "Attempting to acquire lock on target $target in $writer_id for directives $dstring\n";
		#lock $lockvar->[0] if (defined $lockvar);
    #print STDERR "Got lock on target $target in $writer_id for directives $dstring\n";
    my $s;
    if (defined $locker) { $s = $locker->(); }
		print $target $packed_length;
		print $target $packed_dlength;
		print $target $dstring;
		print $target $json_string;

		#print STDERR "$$ over the wire: $dstring $json_string\n";
		
		if (not exists $args{'flush'}) { $flush = 1; }
		if ($flush) {
			$target->flush();
    }
  }

  if (defined $args{'wait_for'}) {
    #print STDERR "$$ wait_for = $args{'wait_for'}\n";
    if (defined $args{'reader'}) { 
      my $rdr = $args{'reader'}; 
      if (wantarray) {
        my @r = $rdr->(wait_for=>$args{'wait_for'});
        return @r;
      }
      elsif (defined wantarray) {
        my $r = $rdr->(wait_for=>$args{'wait_for'});
        return $r;
      }
      else {
        #print STDERR "Invoking reader from sender, with wait_for $args{'wait_for'}\n";
        $rdr->(wait_for=>$args{'wait_for'}); undef;
      }
    }
    else { 
			if (wantarray) {
				my @r = deserializeFrom(io=>$args{'io'},wait_for=>$args{'wait_for'});
				return @r;
			} 
			elsif (defined wantarray) {
				my $r = deserializeFrom(io=>$args{'io'},wait_for=>$args{'wait_for'});
				return $r;
			}
			else {
				deserializeFrom(io=>$args{'io'},wait_for=>$args{'wait_for'});
				undef;
			}
    }
  }
}
sub h2a {
  my %args = @_;
  my $hr = $args{'hash'};

  my @a;
  for my $k (keys %$hr) {
    push @a,($k,$hr->{$k});
  }
  
  if (wantarray) {
    return @a;
  }
  elsif (defined wantarray) {
    return \@a;
  }
}

sub tt {
  my $o = shift;
  dprint "tt got a", tied %{$o},"\n";
}

sub loadClass {
  my %args = @_;
  my $module_name=$args{'module'};
  my $constructor = $args{'constructor'};
  my $p = $args{'args'};
  
  if (not defined $constructor) { $constructor = 'new'; }
  if (not defined $p) { $p = []; };
  if (not ref $p) { $p = [ $p ]; }
  if (ref $p eq 'HASH') { $p = h2a(hash=>$p); }
  
  eval "require $module_name";
  if ($@) {
    croak { message=>"Failed to load class $module_name: $@"};
  }
  my $m = $module_name->$constructor(@$p);
  return $m;
}

sub getSubRefFromName {
  my %args = @_;
  my $ref = $args{'name'};
  my $clr = (caller(1))[0].'::'.(caller(1))[3].'::'.(caller(1))[1].'::'.(caller(1))[2];

  my @sargs = ();
  if ($ref =~ m!\(([^)]*)\)$!) {
    my $a = $1;
    @sargs = eval "($a)";
    $ref =~ s!\(([^)]*)\)$!!
  }
  
  my @names = split(/::/,$ref);
  my $subname = pop @names;
  my $modname = join('::',@names);
  if ($modname eq __PACKAGE__) {
    #special case
    my $fnamesub = \&{$subname};
    if (defined $fnamesub) {
      if (@sargs) { 
        return partial($fnamesub,@sargs);
      }
      return $fnamesub;
    }    
    else {
      croak { message=>"Could not find $subname in module $modname"};
    }    
  }
  else {
    eval "require $modname" or { croak {message=>"Really could not load module: $ref requested by $clr"}};
    eval {import $modname qw();}; # in order not to pollute the namespace
    croak {message=>$@} if $@;
    my $fnamesubref = "${modname}::${subname}";
    my $fnamesub = \&{$fnamesubref};
    if (defined $fnamesub) {
      if (@sargs) {
        return partial($fnamesub,@sargs);
      }
      return $fnamesub;
    }    
    else {
      croak { message=>"Could not find $subname in module $modname"};
    }    
  }
}

my $datetime_patterns = {
  '%Y'=>'\d{4}',
  '%y'=>'\d{2}',
  '%I'=>'\d{1,2}',
  '%M'=>'\d{1,2}',
  '%H'=>'\d{1,2}',
  '%S'=>'\d{1,2}',
  '%m'=>'\d{1,2}',
  '%d'=>'\d{1,2}',
  '%a'=>'\w+',
  '%A'=>'\w+',
  '%b'=>'\w+',
  '%B'=>'\w+'
};

my $parse_months = {
  january=>0,
  february=>1,
  march=>2,
  april=>3,
  may=>4,
  june=>5,
  july=>6,
  august=>7,
  september=>8,
  october=>9,
  november=>10,
  december=>11,
  jan=>0,
  feb=>1,
  mar=>2,
  apr=>3,
  may=>4,
  jun=>5,
  jul=>6,
  aug=>7,
  sep=>8,
  oct=>9,
  nov=>10,
  dec=>11
};

my $datetime_pattern_actions = {
  '%Y'=>sub { my $dt = shift; my $val = shift; 
              $dt->{'year'}=$val;},
  '%y'=>sub { my $dt = shift; my $val = shift; 
              $dt->{'year'}=2000+$val;},
  '%M'=>sub { my $dt = shift; my $val = shift; 
              $dt->{'minute'}=$val;},
  '%H'=>sub { my $dt = shift; my $val = shift; 
              $dt->{'hour'}=$val;},
  '%S'=>sub { my $dt = shift; my $val = shift; 
              $dt->{'second'}=$val;},
  '%m'=>sub { my $dt = shift; my $val = shift; 
              $dt->{'month'}=$val-1;},
  '%d'=>sub { my $dt = shift; my $val = shift; 
              $dt->{'day'}=$val;},
  '%b'=>sub { my $dt = shift; my $val = shift;
              $val = lc $val;
              $dt->{'month'}=$parse_months->{$val};
            },
  '%B'=>sub { my $dt = shift; my $val = shift;
              $val = lc $val;
              $dt->{'month'}=$parse_months->{$val};
            },
  '%a'=>sub {
              # do nothing; that's easy
            },
  '%A'=>sub {}
};

my $PREDEFINED_FILTERCHAINS = {
  CANONFILENAME=>'::basename',
  SFMTdmy=>'::formatDateTime %d%m%y'
};

my $PREDEFINED_FILTERS = {};
my $LOADEDFILTERLIBS={};

sub loadFilterLibs {
  my %args = @_;
  my $toload = $args{'filterlibs'};
  if (ref $toload eq 'ARRAY') {
    # Nothin I guess
  }
  elsif (ref \$toload eq 'SCALAR') {
    $toload = [$toload];
  }
  for my $filterlib (@$toload) {
    if (exists $LOADEDFILTERLIBS->{$filterlib}) {
      _log(level=>"trace",message=>"FilterLib $filterlib allready loaded ... Not doing anything ");
    }
    else {
      _log(level=>"trace",message=>"Loading FilterLib $filterlib",call_level=>1);
      eval "require $filterlib" or croak {message=>"Could not load filterlib $filterlib"};
      eval {import $filterlib;};
      croak {message=>$@} if $@;
      # Look for filterchains
      my $filterlibgetfilterssubref = "${filterlib}::getFilterChains";
      my $filterlibgetfilterssub = \&{$filterlibgetfilterssubref};
      if (defined $filterlibgetfilterssub) {
        eval {
          my $filterlibfilters = &{$filterlibgetfilterssub}();
          for my $filterkey (keys %$filterlibfilters) {
            $PREDEFINED_FILTERCHAINS->{$filterkey} = $filterlibfilters->{$filterkey};
          }
        };
      }

      # Look for filters
      $filterlibgetfilterssubref = "${filterlib}::getFilters";
      $filterlibgetfilterssub = \&{$filterlibgetfilterssubref};
      if (defined $filterlibgetfilterssub) {
        eval {
          my $filterlibfilters = &{$filterlibgetfilterssub}();
          for my $filterkey (keys %$filterlibfilters) {
            $PREDEFINED_FILTERS->{$filterkey} = $filterlibfilters->{$filterkey};
          }
        };
      }
      $LOADEDFILTERLIBS->{$filterlib} = 1;
    }
  }
}

sub filter_singlequote {
  my $val = shift;
  if (not defined $val) {
    return undef;
  }
  if (ref $val eq 'ARRAY') {
    my @rval = ();
    for my $r (@$val) {
      push @rval,"'$r'";
    }
    return \@rval;
  }
  my $rval = "'$val'";
  return $rval;
}

sub filter_dbescape {
  my $val = shift;
  if (not defined $val) {
    return $val;
  }
  $val =~ s/'/"/g;
  return $val;
}

sub filter_formatdatetime {
   my $format = shift;
   my $val = shift;
   if (not defined $val) {
     return $val;
   }
   if (length("$val") == 0) {
     return $val;
   }
   return POSIX::strftime($format,localtime($val));
}

sub filter_echo {
  my $val = shift;
  _log(level=>"info",message=>$val);
  return $val;
}

sub filter_regmatch {
  my $regexp = shift;
  my $val = shift;
  if ($val =~ m/$regexp/) {
    return 1;
  }
  return 0;
}

sub filter_regextr {
  my $regexp = shift;
  my $val = shift;

  if ($val =~ m/$regexp/) {
    if (defined $1) {
      return $1;
    }
  }
  return undef;
}

sub filter_parseDateTime {
  my $format = shift;
  my $val = shift;
  if (not defined $val) {
    return $val;
  }
  my @transformers;
  my $createpatternreplacer = sub {
    my $dtp = $datetime_patterns;
    my $f = shift;
    my $dt = shift;
    my $matchcount = 0;
    my $patternreplacer = sub {
      my $v = shift;
      if (exists $datetime_patterns->{$v}) {
        my $rval = '('.$datetime_patterns->{$v}.')';
        push(@transformers,$datetime_pattern_actions->{$v});
        return $rval;
      }
     return $v;
    };
    $f =~ s/(%.)/&$patternreplacer($1)/gse;
    $f = '^'.$f.'$';
    return $f;
  };
  my $dt = {
    year => 1900,
    month => 0,
    day => 1,
    hour => 0,
    minute => 0,
    second => 0
  }; 

  my $newformat = &$createpatternreplacer($format,$dt);
  
  my @match = $val =~ m/$newformat/;
  if (scalar @match ne scalar @transformers) {
    my $sm = scalar @match;
    my $st = scalar @transformers;
    croak {message=>"Could not parse DateTime value $val using format $format:new format $newformat, number of matches: $sm number of transformers $st"};
  }
  my $mc;
  for ($mc = 0; $mc < scalar @match; $mc++) {
    my $tf = $transformers[$mc];
    &$tf($dt,$match[$mc]);
  }
  my $lt = timelocal($dt->{'second'},$dt->{'minute'},$dt->{'hour'},$dt->{'day'},$dt->{'month'},$dt->{'year'});
  return $lt;
}

sub filter_adddays {
  my $daystoadd = shift;
  my $val = shift;
  my $rval = $val + ($daystoadd * 24 * 3600);
  return $rval; 
}

sub filter_lastdayofmonth {
   my $val = shift;
   #print "val is now $val\n";
   my $da = filter_formatdatetime('%d',$val);
   #print "da is now $da\n";
   $da =~ s/^0+//;

   #print "da is now $da\n";
   my $rval;
   if ($da < 15) {
     $rval=applyFilterChain(value=>$val,filterchain=>'addDays 40|setDays 01|addDays "-1"');
   }
   else {
     $rval=applyFilterChain(value=>$val,filterchain=>'addDays 20|setDays 01|addDays "-1"');
   }
   return $rval;
}

sub filter_setdays {
  my $days_to_set = shift;
  my $val = shift;
  my $formatted = filter_formatdatetime('%Y-%m-%d-%H-%M-%S',$val);
  my @splitted = split(/-/,$formatted);
  $splitted[2] = filter_lpad('0',2,$days_to_set);
  my $rc = filter_parseDateTime('%Y-%m-%d-%H-%M-%S',join('-',@splitted));
  return $rc;
}
sub filter_addmonths {
  my $monthstoadd = shift;
  my $val = shift;
  $monthstoadd = $monthstoadd + 0;
  $val = $val + 0;
  if ($monthstoadd == 0) {
    return $val;
  }
  my $origdayinmonth = filter_formatdatetime('%d',$val);

  if ($monthstoadd > 0) {
    my $fullfmted = filter_formatdatetime('%Y-%m-%d-%H-%M-%S',$val);
    my @a_fullfmted = split(/-/,$fullfmted);
    my $year = $a_fullfmted[0] + 0;
    my $month = $a_fullfmted[1] + 0;
    my $day = $a_fullfmted[2];
    $day =~ s/^0+//;
    $day = $day + 0;
    if ($monthstoadd > 12) {
      while ($monthstoadd > 12) {
        $year = $year + 1;
        $monthstoadd = $monthstoadd - 12;
      }
    }
    if (($month + $monthstoadd) > 12) {
       $year = $year + 1;
       $month = $monthstoadd + $month -12;
    }
    else {
      $month = $month + $monthstoadd;
    }
    #if ($month == 2 and $day > 28) {
    #  $day = 28;
    #}
    $month = filter_lpad('0',2,$month);
    $day = filter_lpad('0',2,$day);
    $a_fullfmted[0] = $year;
    $a_fullfmted[1] = $month;
    #$a_fullfmted[2] = $day;
    $a_fullfmted[2] = '01';
    
    $fullfmted = join('-',@a_fullfmted);
    my $preval = filter_parseDateTime('%Y-%m-%d-%H-%M-%S',$fullfmted);
    $preval = filter_lastdayofmonth($preval);
    my $lastdaypreval = filter_formatdatetime('%d',$preval);
    while ($lastdaypreval < $origdayinmonth) {
      $origdayinmonth = $origdayinmonth - 1;
    }
    $a_fullfmted[2] = $origdayinmonth;
    $fullfmted = join('-',@a_fullfmted);
    return filter_parseDateTime('%Y-%m-%d-%H-%M-%S',$fullfmted);
  }
  if ($monthstoadd < 0) {
    my $fullfmted = filter_formatdatetime('%Y-%m-%d-%H-%M-%S',$val);
    my @a_fullfmted = split(/-/,$fullfmted);
    my $year = $a_fullfmted[0] + 0;
    my $month = $a_fullfmted[1] + 0;
    my $day = $a_fullfmted[2] + 0;
    while ($monthstoadd < -12) {
      $year = $year -1;
      $monthstoadd = $monthstoadd + 12;
    }
    # now do the remaining months:
    if (abs($monthstoadd) > $month) {
      $year = $year -1;
      $month = 12 - (abs($monthstoadd) - $month);
    }
    elsif (abs($monthstoadd) == $month) {
      $year = $year - 1;
      $month = 12;
    }
    else {
       $month = $month + $monthstoadd;
    }
    if ($month == 2 and $day > 28) {
      $day = 28;
    }
    $month = filter_lpad('0',2,$month);
    $day = filter_lpad('0',2,$day);
    $a_fullfmted[0] = $year;
    $a_fullfmted[1] = $month;
    #$a_fullfmted[2] = $day;
    $a_fullfmted[2] = '01';
    
    $fullfmted = join('-',@a_fullfmted);
    my $preval = filter_parseDateTime('%Y-%m-%d-%H-%M-%S',$fullfmted);
    $preval = filter_lastdayofmonth($preval);
    my $lastdaypreval = filter_formatdatetime('%d',$preval);
    while ($lastdaypreval < $origdayinmonth) {
      $origdayinmonth = $origdayinmonth - 1;
    }
    $a_fullfmted[2] = $origdayinmonth;
    $fullfmted = join('-',@a_fullfmted);
    return filter_parseDateTime('%Y-%m-%d-%H-%M-%S',$fullfmted);
  }
}

sub filter_sethour {
  my $hourstoset = shift;
  my $val = shift;
  my $formatted = filter_formatdatetime('%Y-%m-%d-%H-%M-%S',$val);
  my @splitted = split(/-/,$formatted);
  $splitted[3] = filter_lpad('0',2,$hourstoset);
  my $rc = filter_parseDateTime('%Y-%m-%d-%H-%M-%S',join('-',@splitted));
  return $rc;
}

sub filter_glob2regex {
	my $val = shift;
	if (not defined $val) {
		return $val;
	}
	return glob2Regex(globpattern=>$val);
}

sub filter_setminute {
  my $minutestoset = shift;
  my $val = shift;
  my $formatted = filter_formatdatetime('%Y-%m-%d-%H-%M-%S',$val);
  my @splitted = split(/-/,$formatted);
  $splitted[4] = filter_lpad('0',2,$minutestoset);
  my $rc = filter_parseDateTime('%Y-%m-%d-%H-%M-%S',join('-',@splitted));
  return $rc;
}

sub filter_default {
  my $default = shift;
  if ($default eq '_BLANK_') {
    $default = '';
  }
  elsif ($default eq '_WHITESPACE_') {
    $default = ' ';
  }
  elsif ($default =~ m/^_LIST_:\[(.*)\]/) {
    my $lb = $1;
    my @rlist;  
    if ($lb) {
      @rlist = split(/,/,$lb);
    }
    else {
      @rlist = ();
    }
    $default = \@rlist;
  }
  my $val = shift;
  if (not defined $val) {
    return $default;
  }
  return $val;
}

sub filter_add {
  my $toadd = shift;
  my $val = shift;
  my $rval = $toadd + $val;
  return $rval;
}

sub filter_multiply {
  my $tomul = shift;
  my $val = shift;
  my $rval = $tomul * $val;
  return $rval;
}

sub filter_basename {
  my $filename = shift;
  if (not defined $filename) {
    return $filename;
  }
  if (length("$filename") == 0) {
    return $filename;
  }
  return basename($filename);
}


sub filter_dirname {
  my $filename = shift;
  if (not defined $filename) {
    return $filename;
  }
  if (length("$filename") == 0) {
    return $filename;
  }
  return dirname($filename);
}

sub filter_createpath{
  my $dirname; my $name_is_filename;
  if (scalar @_ == 2) {
   $name_is_filename = shift; 
   $dirname = shift;
  # the dirname specified could actually be a full path to a file or simple a directory name
  }
  else {
   $dirname = shift;
  }
  if (not defined $name_is_filename) { $name_is_filename = 0; }
  if (not defined $dirname) {
    return $dirname;
  }
  if (not $dirname) {
    return $dirname;
  }
  if (ref $dirname eq 'ARRAY') {
     my @r = ();
     for my $i (@$dirname) {
        push @r,filter_createpath($i,$name_is_filename);
     }
     return \@r;
  }
  use File::Path qw(make_path);
  use File::Basename qw(basename dirname);
  my $ldirname;
  if ($name_is_filename) { $ldirname = dirname $dirname; } else { $ldirname = $dirname;}
  eval {
  make_path($ldirname);
  };
  if ($@) { croak { message=>"Failed to create path $ldirname: $@" }; }
  
  return $dirname;
}

sub filter_touch {
  my $filename = shift;
  if (not defined $filename) {
    return $filename;
  }
  if (not $filename) {
    return $filename;
  }
  touch $filename;
  return $filename;
   
}

sub filter_bool2YN {
  my $val = shift;
  if ($val) {
    return 'Y';
  }
  else {
    return 'N';
  }
}

sub filter_evalboolean {
  my $val = shift;
  my $rval = evalBoolean(value=>$val);
  return $rval;
}

sub filter_not {
  my $val = shift;
  if ($val == 0) {
  	return 1;
  }
  return 0;
}
  
sub filter_filetimestamp {
  my $filename = shift;
  if (not defined $filename) {
  	return $filename;
  }
  return getFileMTime(filename=>$filename);
}

sub filter_substring {
  my @args = @_;
  my $val = pop;
  if (not defined $val) {
    return $val;
  }
  my @subst = @_;
  my $substr_start = 0;
  my $substr_end = 0;
  if (scalar @subst == 0) {
    return $val;
  }
  if (scalar @subst > 1) {
    $substr_start = $subst[0];
    $substr_end = $subst[1];
  }
  else {
    $substr_end = $subst[0];
  }
  my $rval = substr $val,$substr_start,$substr_end;
  return $rval;
}

sub filter_trim {
  my $val = shift;
  $val =~ s/^\s*//g;
  $val =~ s/\s*$//g;
  return $val;
}

sub filter_lpad {
  my $val = pop;
  my @lpaddef = @_;
  my $padlen = $lpaddef[1];
  my $padchar = $lpaddef[0];
  my $padded = sprintf("%${padchar}${padlen}s",$val);
  return $padded;
}

sub filter_regExpReplace {
  my $value = pop;
  if (not defined $value or not $value) {
     return $value;
  }
  my $matchp = shift;
  my $replacep = shift;

  # Now this can be tricky:
  # if any of $match op or replacep match a specific character, say a /, I cannot use the slash
  if ($matchp =~ m/\// or $replacep =~ /\//) {
    $value =~ s|$matchp|$replacep|;
  }
  else {
    $value =~ s/$matchp/$replacep/;
  }
  return $value;
}

sub filter_rpad {
  my $val = pop;
  if (not defined $val) {
    return $val;
  }
  my @lpaddef = @_;
  my $padlen;
  my $padchar;
  if (scalar @lpaddef > 1) {
    $padlen = $lpaddef[1];
    $padchar = $lpaddef[0];
  }
  else {
    $padlen = $lpaddef[0];
    $padchar = ' ';
  }
  #my $padchar = $lpaddef[0];
  my $padded = sprintf('%*2$s',$val,(-1) * $padlen);
  return $padded;
}


sub filter_uc {
 my $val = shift;
 if (not defined $val) {
   return $val;
 }
 return uc $val;
}

sub filter_lc {
 my $val = shift;
 if (not defined $val) {
   return $val;
 }
 return lc $val;
}

sub filter_bullet {
  my $bullet = shift;
  my $val = shift;

  if (ref $val and ref $val eq 'ARRAY') {
    my @rval = ();
    for my $v (@$val) {
      push(@rval,"${bullet}${v}");
    }
    return \@rval;
  }
  else {
    return "${bullet}${val}";
  }
}

sub filter_join {
  my $joiner = shift;
  $joiner =~ s/_NEWLINE_/\n/g;
  my $val = shift;
  my $rval;
  if (ref $val and ref $val eq 'ARRAY') {
    $rval = join($joiner,@$val);
    return $rval;
  }
  return $val;
}

sub filter_eq {
  my $cmp = shift;
  my $val = shift;
  if ($val eq $cmp) { return 1; } return 0;
}

$PREDEFINED_FILTERS->{'formatDateTime'} = \&filter_formatdatetime;
$PREDEFINED_FILTERS->{'parseDateTime'} = \&filter_parseDateTime;
$PREDEFINED_FILTERS->{'setHour'} = \&filter_sethour;
$PREDEFINED_FILTERS->{'setMinutes'} = \&filter_setminute;
$PREDEFINED_FILTERS->{'basename'} = \&filter_basename;
$PREDEFINED_FILTERS->{'dirname'} = \&filter_dirname;
$PREDEFINED_FILTERS->{'default'} = \&filter_default;
$PREDEFINED_FILTERS->{'bool2YN'} = \&filter_bool2YN;
$PREDEFINED_FILTERS->{'filetimestamp'} = \&filter_filetimestamp;
$PREDEFINED_FILTERS->{'evalBoolean'} = \&filter_evalboolean;
$PREDEFINED_FILTERS->{'not'} = \&filter_not;
$PREDEFINED_FILTERS->{'addDays'} = \&filter_adddays;
$PREDEFINED_FILTERS->{'substring'} = \&filter_substring;
$PREDEFINED_FILTERS->{'trim'} = \&filter_substring;
$PREDEFINED_FILTERS->{'add'} = \&filter_add;
$PREDEFINED_FILTERS->{'lpad'} = \&filter_lpad;
$PREDEFINED_FILTERS->{'rpad'} = \&filter_rpad;
$PREDEFINED_FILTERS->{'uc'} = \&filter_uc;
$PREDEFINED_FILTERS->{'lc'} = \&filter_lc;
$PREDEFINED_FILTERS->{'echo'} = \&filter_echo;
$PREDEFINED_FILTERS->{'addMonths'} = \&filter_addmonths;
$PREDEFINED_FILTERS->{'singleQuote'} = \&filter_singlequote;
$PREDEFINED_FILTERS->{'glob2Regex'} = \&filter_glob2regex;
$PREDEFINED_FILTERS->{'regExtract'} = \&filter_regextr;
$PREDEFINED_FILTERS->{'regMatch'} = \&filter_regmatch;
$PREDEFINED_FILTERS->{'setDays'} = \&filter_setdays;
$PREDEFINED_FILTERS->{'dbEscape'} = \&filter_dbescape;
$PREDEFINED_FILTERS->{'touch'} = \&filter_touch;
$PREDEFINED_FILTERS->{'regReplace'} = \&filter_regExpReplace;
$PREDEFINED_FILTERS->{'join'} = \&filter_join;
$PREDEFINED_FILTERS->{'bullet'} = \&filter_bullet;
$PREDEFINED_FILTERS->{'multiply'} = \&filter_multiply;
$PREDEFINED_FILTERS->{'lastDayOfMonth'} = \&filter_lastdayofmonth;
$PREDEFINED_FILTERS->{'createPath'} = \&filter_createpath;
$PREDEFINED_FILTERS->{'eq'} = \&filter_eq;

# --------------------------------------------------------------------------
#
# Implementation of Template Engine Core Functionality
# Consider this as a 'private' function
#
# --------------------------------------------------------------------------

sub getContextEvaluator {
  my %args = @_;
  my $maindisablelogging = $args{'_DISABLE_LOGGING_'};
  if (not defined $maindisablelogging) {
    $maindisablelogging=0;
  }
  #print STDERR "disableligging=$maindisablelogging\n";
  
  my @evalcontexts = @{$args{'evalcontext'}};
  my @origcontexts = @{$args{'evalcontext'}};
  my $filterchains = $args{'filterchains'};
  my $nokeysplit = $args{'nokeysplit'};
  my $local_filters = $args{'filters'};
  use Cwd; my $cd = getcwd();
  push(@evalcontexts,{_CWD_=>$cd,_PROCESSID_=>$$,_START_TM_=>$^T,_NOW_=>time()});
  my $evalu;
  eval {
    $evalu = sub  {
    my %args = @_;

    my @ocontexts = @origcontexts;
    my @contexts = @evalcontexts;
    my $string_to_expand = $args{'src'};
    my $recursive = $args{'recursive'};
    my $disablelogging=$maindisablelogging;
    #print STDERR "ce: disablelogging: $disablelogging\n";
    delete $args{'src'};
    delete $args{'recursive'};

    my $filterspec =  undef;
    my $optionals = {};
    my $orig_string_to_expand = $string_to_expand;
    $string_to_expand =~ s/^\s+//g;
    $string_to_expand =~ s/\s+$//g;
    # check for filter specifications
    if ($string_to_expand =~ m/([^|]+)\|(.*)$/) {
      $string_to_expand = filter_trim($1);
      $filterspec = filter_trim($2);
      # Experience during testing has revealed that it is a good idea to tidy up the filters before proceeding
      # Additionally, this is the place where we introduce the implementation of the standard filters
      my @rebuiltfilter = ();
      my @splitfilterspec = split(/\|/,$filterspec);
      for my $filtercomp (@splitfilterspec) {
        $filtercomp = filter_trim($filtercomp);
        if ($filtercomp =~ m/^::@/) {
          # This does the same as above, syntax with STDFILTER, but allows for a more conscise syntax
          # allowing one to say ::@FILTERNAME instead of ::STDFILTER FILTERNAME 
          my $filterchainname = $filtercomp;
          $filterchainname =~ s/^::@//;
          if (exists $filterchains->{$filterchainname}) {
            if (defined $filterchains->{$filterchainname}) {
              push(@rebuiltfilter,split(/\|/,$filterchains->{$filterchainname}));
            }
          }
          else {
            croak {message=>"Filterchain $filterchainname is unknown"};
          }
        }
        elsif ($filtercomp =~ m/:@/){
          # Search for it in the eval contexts ... 
          my $filterchainname = $filtercomp;
          $filterchainname =~ s/^:@//;
          my $filterchaindef;
          for my $ctx (@evalcontexts) {
            if (defined $ctx->{$filterchainname} and not defined $filterchaindef) {
              $filterchaindef = $ctx->{$filterchainname};
            }
          }
          if (defined $filterchaindef) {
            push(@rebuiltfilter,split(/\|/,$filterchaindef));
          }
          else {
            croak { message=>"Filterchainname $filterchainname cannot be resolved in the provided context"};
          }
        }
        else {
          push(@rebuiltfilter,$filtercomp);
        }
      }
      $filterspec = join('|',@rebuiltfilter);
    }
    if ($string_to_expand =~ m/^\?/) {
      $string_to_expand =~ s/^\?//;
      $optionals->{$string_to_expand} = undef;
    }

    #if ($string_to_expand =~ m/^LITERAL::((.(?!LITERAL::))+?)::/) {
    if ($string_to_expand =~ m/^LITERAL::((.(?!LITERAL::))+?)::/) {
      my $lit = $1;
      push (@contexts,{__LITERAL__=>$1});
      $string_to_expand = '__LITERAL__';
    }
    
    my $expandedstring = undef;
    my @lcontexts = reverse @contexts;
    my $it;
    my @filterchain = ();
    my $filters = {};
    my $filterkeys_to_search_for = {};
    my $filterkeycounter = 0;
    my $chain_directives = {CONTINUEONERROR=>0};
    if (defined $filterspec) {
      $filterspec=~ s/\s*$//g;
      $filterspec=~ s/\s*$//g;
      if(length ($filterspec)) {
        if ($filterspec =~ m/^\[([^\]]*)\]\s*\|/) {
         my $found_directives = $1;
          #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Found directives in $filterspec");
          $filterspec =~ s/^\[([^\]]*)\]\s*\|//;
          #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Working with filterspec $filterspec");
          $found_directives =~ s/\s*$//g;
          $found_directives =~ s/^\s*//g;
          #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Found directives: $found_directives");
          if (length($found_directives)) {
            my @splitdirectives = split(/,/,$found_directives);
            for my $direct (@splitdirectives) {
              $direct = uc $direct;
              if (exists $chain_directives->{$direct}) {
                 #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Setting directive $direct");
                 $chain_directives->{$direct} = 1;
              }
            }
          };
        }
        else {
          #_log(_DISABLE_LOGGING_,$disablelogging,trace=>"Did not find directives in filterspec $filterspec");
        }
      }
    }
    if (defined $filterspec) {
      my @prefilterchain = split/\|/,$filterspec;
      for my $filter (@prefilterchain) {
        #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Trying to resolve filter $filter");
        $filter=~ s/\s*$//g;
        $filter=~ s/^\s*//g;
        my @filtersplitcommand = split /\ /,$filter;
        my $command = shift @filtersplitcommand;
        #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Checking for command $command");
        my $commanddirective = undef;
        if ($command =~ m/\//) {
          my @splitcmd = split(/\//,$command);
          $command = $splitcmd[0];
         $commanddirective=$splitcmd[1];
        }
        if ($command =~ m/^::/ or not $command =~ m/^:/ ) {
          $command =~ s/^:://;
          my $directive;
          if ($command =~ /\//) {
            my @splitcommand = split(/\//,$command);
            $command = $splitcommand[0];
            $directive = $splitcommand[1];
         }
         if (defined $local_filters->{$command}) {
            
            my $cargs = join(' ',@filtersplitcommand);
             #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Arguments to command: $cargs");
             my @filterparameters;
             my $runval = 0;
             my $endval = 0;
             my $concatval ='';
             for my $sval (@filtersplitcommand) {
               if ($sval =~ m/^"/ and $runval eq 0) {
                 $runval = 1;
                 $sval =~ s/^"//;
               }
               if ($sval =~ m/"$/ and $runval eq 1) {
                 $sval =~ s/"$//;  
                 $endval = 1;
               }
               if ($runval eq 1) {
                 $concatval .= $sval;
                 if ($endval eq 1) {
                   push @filterparameters,$concatval;
                   $concatval = '';
                   $runval = 0;
                   $endval = 0;
                 }
                 else {
                   $concatval .= ' ';
                 }
               }
               else {
                 push @filterparameters,$sval;
               }
            }
             
            if (defined $commanddirective) {
              my $thewrapped = partial($local_filters->{$command},@filterparameters);
              if ($commanddirective eq 'STOPIFSET') {
               #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"I should apply commanddirective $commanddirective");
                my $stopwrapper = sub {
                 my $inval = shift;
                  #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Using stopwrapper on $inval");
                  my $outval = &$thewrapped($inval);
                  #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Got $outval vs $inval");
		   # we need to consider a special case here, if only to avoid warnings ...
		   # if STOPIFSET is used with default
		   if (not icdefined $inval and icdefined $outval) {
                     croak { message=>'_STOP_',result=>$outval };
		   }
                   elsif ($inval eq $outval) {
                     return $inval;
                   }
                   else {
                    #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Throwing stop message");
                     croak { message=>'_STOP_',result=>$outval };
                   }
                 };
                #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Made stopwrapper");
                 push @filterchain,$stopwrapper;
               }
               else {
                #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Unknown commanddirective: $commanddirective. Ignoring it");
                 push @filterchain,$thewrapped;
               }
            }
            else {
              my $sc = scalar @filterparameters;
              #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Adding command $command with $sc params: @filterparameters");
              push @filterchain,partial($local_filters->{$command},@filterparameters);
            }
            if (defined $command and $command =~ m/^default$/) {
               $optionals->{$string_to_expand} = undef;
             }
          } 
          else {
             #### this is an error condition
             croak { message=>"Unknown command $command while processing fileterchain for $orig_string_to_expand"};
         }
        }
        elsif ($command =~ m/^:/) {
         $command =~ s/^://;
          # create a temporary reference to for the new anonymous 
          my $filterkey_index = "$filterkeycounter";
           $filterkeycounter++;
           push @filterchain,$filterkey_index;
           $filterkeys_to_search_for->{$filterkey_index} = {command=>$command,args=>\@filtersplitcommand,coderef=>undef};
         }
         else { 
           # could be used to allow standard Perl functions
           # but we dont allow for that functionality, for security and other reasons
           croak { message=>"Invalid command spec: $command while parsing $filter ($string_to_expand)"};
         }
       }
     }

     foreach $it (@lcontexts) {
       my $ctxk;
       if (defined $it) {  
         #if ($string_to_expand =~ m/^([^\[]+)\[([^\]]+)\]/ or $string_to_expand =~ m/\//) {
         if ($string_to_expand =~ m/^[^\[]+\[[^\]]+\]/ or $string_to_expand =~ m/\//) {
           my $key; 
           my @keycomponents = ();
           my @indexes;
           my $index;
           if ($nokeysplit) {
             $key = $string_to_expand;
             @indexes = ();
             $index = undef;
           }
           else {
						 if ($string_to_expand =~ m/^([^\[]+)\[([^\]]+)\]/) {
							 my $localkey = $1;
							 push(@keycomponents, split(/\//,$localkey));
							 my $helper_string_to_expand = $string_to_expand;
							 #print STDERR "helper string is now $helper_string_to_expand\n";
							 while ($helper_string_to_expand =~ m/^([^\[]+)\[([^\]]+)\]/) {
								 push @indexes,$2;
								 $helper_string_to_expand =~ s/^([^\[]+)\[[^\]]+\](.*)/$1$2/;
								 #print STDERR "helper string is now $helper_string_to_expand\n";
							 }
						 }
						 else {
							 push(@keycomponents, split(/\//,$string_to_expand));
						 }
		
						 $key = shift @keycomponents;
						 @indexes = (@keycomponents,@indexes);
						 $index = shift @indexes;
           }
     
           #my $subsearch = undef;
           #if (ref $it eq 'HASH' or defined overload::Method($it,'%{}')) {
           #  if (exists $it->{$key}) {
           #    my $testsub = $it->{$key};
           #    if (defined $testsub and (ref $testsub eq 'HASH' or ref $testsub eq 'ARRAY')) {
           #      $subsearch = $it->{$key};
           #    }
           #  }
           #}
           
           my @fakeindex;
           if ($nokeysplit) {
             @fakeindex = ($key);
           }
           else {
            @fakeindex = ($key,$index,@indexes);
           }
           my $testval = $it->{\@fakeindex};
           if (icdefined $testval) {
             my $tval = $testval;
             if (ref $tval eq 'CODE') {
               $expandedstring = &$tval;
             }
             else {
               $expandedstring = $tval;
             }
             if (defined $expandedstring) {
               $expandedstring =~ s/^\s+//;
               $expandedstring =~ s/^\s+$//;
               if ($expandedstring =~ m/^\{\{.*\}\}$/ and $recursive) {
                 $expandedstring = expand(src=>$expandedstring,evalcontext=>\@ocontexts,nokeysplit=>$nokeysplit);
               }
             }
           }
           #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Trying to expand an array-like value, key=$key, index=$index");
           elsif (icdefined $it->{$key}) {
             my $subsearch = $it->{$key};
             if (ref $subsearch eq 'HASH' or defined overload::Method($subsearch,'%{}')) {
               #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Subsearching a HASH for key $index");
               if (icdefined $subsearch->{$index}) {
                 #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Key $index found and defined in hash $subsearch->{$index}");
                 my $tval = $subsearch->{$index};
                 if (ref $tval eq 'CODE') {
                   $expandedstring = &$tval;
                 }
                 elsif (ref \$tval eq 'SCALAR') {
                   #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Setting expandedstring to $tval");
                   $expandedstring = $tval;
                 }
                 else {
                   my $rtype = ref $tval;
                   if (not defined $rtype) {
                     $rtype = ref \&tval;
                   }
                   #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Unsuppered type $rtype for index $index");
                 }
               }
               else {
                 #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Key $index not found in searched hash");
               }
             }
             elsif (ref $subsearch eq 'ARRAY') {
               my $ll = scalar @$subsearch;
               my $cstr = "Subsearching array of $ll long";
               #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>$cstr);
               if ($index =~ m/^[0-9]+$/) {
                 if ($index < scalar @$subsearch) {
                   my $tval = $subsearch->[$index];
                   if (ref $tval eq 'CODE') {
                      $expandedstring =&$tval;
                   }
                   elsif (ref \$tval eq 'SCALAR') {
                     $expandedstring = $tval;
                   }
                   else {
                     my $rtype = ref \$tval;
                     #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Don't know how to deal with $rtype. Discarding it alltogether");
                   }
                 } 
                 else {
                   #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"$index is larger than array being searched. Discarding");
                 }
               }
               else {
                 # this is not a valid index
                 #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"$index is not a valid index for an array. Discarding it");
               }
             }
           }
         } # end of this string_to_expand contains []...

         elsif (ref $it eq 'HASH' or defined overload::Method($it,'%{}')) {
           if (exists $it->{$string_to_expand}) {
             my $tval = $it->{$string_to_expand};
             if (ref \$tval eq 'SCALAR') {
               $expandedstring = $tval;
             }
             elsif (ref $tval eq 'CODE') {
               $expandedstring = &$tval;
             }
             else {
               my $rtype = ref $tval;
               #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Found unsupported type: $rtype. Discarding");
             }
           }
           else {
             my @ks = keys %$it;
             #print "Did not find single key $string_to_expand in $it: @ks\n";
           }
         }

         # Are there any filters we should be looking for
         for my $fk (keys %$filterkeys_to_search_for) {
           my $look = $filterkeys_to_search_for->{$fk}->{'command'};
           #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Looking for filterkey $look in current context");
           if (defined $it->{$filterkeys_to_search_for->{$fk}->{'command'}}) {
             my $testsub = $it->{$filterkeys_to_search_for->{$fk}->{'command'}};
             if (ref $testsub eq 'CODE') {
                $filterkeys_to_search_for->{$fk}->{'coderef'} = $it->{$filterkeys_to_search_for->{$fk}->{'command'}};
             }
           }
           else {
             ## Nothing to see here, move on ...;
           }
         } # end of searching for filterkeys
       } # the current item in the context is defined,
       else {
         #print STDERR "The current item in the list of contexts is not defined\n";
       } # not defined
       
     } # end of looping over contexts

     if (not defined $expandedstring) {
       if (not exists $optionals->{$string_to_expand}) {
         croak {message=>"$string_to_expand does not exist in the provided contexts"};
       }
     }
     ## check if need to apply any filters:
     ## First check if there any filters we could not resolve, that would be an error condition
     for my $sk (keys %$filterkeys_to_search_for) {
       if (not defined $filterkeys_to_search_for->{$sk}->{'coderef'}) {
          croak {message=>"Could not resolve ".$filterkeys_to_search_for->{$sk}->{'command'}};
        }
      }
     
      if (scalar @filterchain gt 0) {
        my $continue_flag = 1;
        my $filtercount = 0;
       
        # say here what directives are in effect
        while ($filtercount < scalar @filterchain && $continue_flag eq 1) {
          my $locfilter = $filterchain[$filtercount];
          if (ref $locfilter eq 'CODE') {
            if ($chain_directives->{'CONTINUEONERROR'}) {
              my $tmpexp;
              eval {
                $tmpexp = &$locfilter($expandedstring);
              };
              if ($@) {
                if ($@->{'message'} eq '_STOP_') {
                  $expandedstring = $@->{'result'};
                  $continue_flag = 0;
                }
                else {
                  #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Filter returned error: $@->{message} but it is ignored due to CONTINUEONERROR directive");
                }
              }
              else {
                $expandedstring = $tmpexp;
              }
            }
            else {
              my $tmpexp;
              eval {
                $tmpexp = &$locfilter($expandedstring);
              };
              if ($@) {
                if (ref $@ eq 'HASH') {
                if ($@->{'message'} eq '_STOP_') {
                  #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Got STOP signal in filterchain");
                  $continue_flag = 0;
                  $expandedstring = $@->{'result'};
                }
                else {
                  croak $@;
                }
                }
                else {
                  croak { message=>$@};
                }
              }
              else {
                $expandedstring = $tmpexp;
              }
            }
          }
          elsif (ref \$locfilter eq 'SCALAR') {
            my $foundsub = $filterkeys_to_search_for->{$locfilter}->{'coderef'};
            my $origargs = $filterkeys_to_search_for->{$locfilter}->{'args'};
            if ($chain_directives->{'CONTINUEONERROR'}) {
              my $tmpexp;
              eval {
                $tmpexp = &$foundsub(@$origargs,$expandedstring);
              };
              if ($@) {
                #_log(_DISABLE_LOGGING_=>$disablelogging,trace=>"Filter returned error: $@->{message} but it is ignored due to CONTINUEONERROR directive");
              }
              else {
                $expandedstring = $tmpexp;
              }
            }
            else {
              $expandedstring = &$foundsub(@$origargs,$expandedstring);
            }
          }
          $filtercount++;
        }
      }
      if (not defined $expandedstring) {
        if (exists $optionals->{$string_to_expand}) {
          $expandedstring = '';
        }
        else {
          croak {message=>"$string_to_expand does not exist in the provided contexts"};
        }
      }
      return $expandedstring;
    };
  };
  if ($@) { 
    croak { message=>"Error building evaluator: $@"};
  }
  else {
    return $evalu;
  }
}

# --------------------------------------------------------------------------
#
# Template Engine API
#
# --------------------------------------------------------------------------
sub expand {
  my %args = @_;
  my $src;
  my $target;
  my $evaluator;
  my $nokeysplit = $args{'nokeysplit'};

  my $recursive = 1;
  if (exists $args{'recursive'} and evalBoolean(value=>$args{'recursive'}) == 0) {
    $recursive = 0;
  }
  
  my $toexpand;
  if (defined $args{'infile'}) {
    my $ifilename = $args{'infile'};
    if (ref $ifilename eq 'CODE') {
      $ifilename = &$ifilename;
    }
    my $IFILE;
    open($IFILE,'<',$ifilename);
    local($/) = undef;
    $toexpand=<$IFILE>;
    close $IFILE;
  }
  elsif (defined $args{'src'}) {
    $toexpand = $args{'src'};
    if (ref $toexpand eq 'CODE') {
      $toexpand = &$toexpand;
    }
  }
  if (not defined $toexpand) {
    croak {message=>"Could not determine src to expand"};
  }

  # now check if we should run in resolve mode
  my $resolve_mode = 0;
  if ($toexpand =~ m/^{!(.*)!}$/) {
    $resolve_mode = 1;
    $toexpand = $1;
  }
  my $result = $toexpand;

  # Check for FILTERLIB declarations
  my $filterchains = {};
  for my $filterchainkey (keys %$PREDEFINED_FILTERCHAINS) {
    $filterchains->{$filterchainkey} = $PREDEFINED_FILTERCHAINS->{$filterchainkey};
  }
  my $filters = {};
  for my $filterkey (keys %$PREDEFINED_FILTERS) {
    $filters->{$filterkey} = $PREDEFINED_FILTERS->{$filterkey};
  }

  my @allfilterlibs = ();
  my @infilefilterlibdecls = $result=~/<<FILTERLIB:([^>>]+)>>/;
  if (scalar @infilefilterlibdecls) {
    for my $filterlibs (@infilefilterlibdecls) {
      $result =~s/<<FILTERLIB:$filterlibs>>\s*\n?//;
      my @splitfilterlib = split(/,/,$filterlibs);
      push @allfilterlibs,@splitfilterlib;
    }
  }
  if (defined $args{'filterlib'} and ref $args{'filterlib'} eq 'ARRAY') {
    push @allfilterlibs,@{$args{'filterlib'}};
  }
  elsif (defined $args{'filterlib'}) {
  	push @allfilterlibs,$args{'filterlib'};
  }

  for my $filterlib (@allfilterlibs) {
    eval "require $filterlib" or croak {message=>"Could not load filterlib $filterlib"};
    eval {import $filterlib;};
    croak {message=>$@} if $@;
    # Look for filterchains
    my $filterlibgetfilterssubref = "${filterlib}::getFilterChains";
    my $filterlibgetfilterssub = \&{$filterlibgetfilterssubref};
    if (defined $filterlibgetfilterssub) {
      eval {
        my $filterlibfilters = &{$filterlibgetfilterssub}();
        for my $filterkey (keys %$filterlibfilters) {
          $filterchains->{$filterkey} = $filterlibfilters->{$filterkey};
        }
      };
    }

    # Look for filters
    $filterlibgetfilterssubref = "${filterlib}::getFilters";
    $filterlibgetfilterssub = \&{$filterlibgetfilterssubref};
    if (defined $filterlibgetfilterssub) {
      eval {
        my $filterlibfilters = &{$filterlibgetfilterssub}();
        for my $filterkey (keys %$filterlibfilters) {
          $filters->{$filterkey} = $filterlibfilters->{$filterkey};
        }
      };
    }
  }

  if (defined $args{'filterchains'}) {
    my $lfilterchains = $args{'filterchains'};
    for my $key (keys %$lfilterchains) {
      $filterchains->{$key} = $lfilterchains->{$key};
    }
  }
  if (defined $args{'filters'}) {
    my $lfilters = $args{'filters'};
    for my $key (keys %$lfilters) {
      $filters->{$key} = $lfilters->{$key};
    }
  }
  
  # Now check for sections ...
  my @sections = $result =~ m/<<SECTION:([^>>]+)>>(.*)<<\/SECTION:\1>>/gs;
  my %sectionsh;
  if (scalar @sections) {
    #_log(@_,trace=>"I found sections in the input");
    %sectionsh = @sections;
  }
  else {
    %sectionsh = ();
  }
  if (scalar keys %sectionsh ge 1) {
    if (scalar keys %sectionsh > 1) {
      if (not defined $args{'section'}) {
        croak {message=>"Template contains multiple sections; please specify a section to expand"};
      }
      else {
        my $sectp = $args{'section'};
        if (ref \$sectp eq 'SCALAR') {
        	$sectp = [$sectp];
        }
        my $tmpresult = '';
        #_log(trace=>"Looking for section $sectp");
        for my $s (@$sectp) {
          if (exists $sectionsh{$s}) {
            $tmpresult .= $sectionsh{$s};
          }
          else {
            croak {message=>"Template does not contain the mentioned section"};
          }
        }
        $result = $tmpresult;
      }
    }
    elsif (scalar keys %sectionsh eq 1 and defined) {
      my $dummy = 7;
    }
  }
  else {
    my $dummy = 7;
  }
  
  if (defined $args{'evaluator'}) {
    $evaluator = $args{'evaluator'};
    if (ref $evaluator eq 'CODE') {
      $evaluator = &$evaluator;
    }
  }
  elsif (defined $args{'evalcontext'}) {
    my $ctx = $args{'evalcontext'};
    if (ref $ctx eq 'ARRAY') {
      $evaluator = getContextEvaluator(filters=>$filters,nokeysplit=>$nokeysplit,filterchains=>$filterchains,_DISABLE_LOGGING_=>$args{'_DISABLE_LOGGING_'},evalcontext=>$ctx);
    }
    elsif (ref $ctx eq 'HASH' or defined overload::Method($ctx,'%{}')) {
      $evaluator = getContextEvaluator(filters=>$filters,nokeysplit=>$nokeysplit,filterchains=>$filterchains,_DISABLE_LOGGING_=>$args{'_DISABLE_LOGGING_'},evalcontext=>[$ctx]);
    }
    elsif (ref $ctx eq 'CODE') {
      $ctx = &$ctx;
      if (ref $ctx eq 'ARRAY') {
        $evaluator = getContextEvaluator(filters=>$filters,nokeysplit=>$nokeysplit,filterchains=>$filterchains,_DISABLE_LOGGING_=>$args{'_DISABLE_LOGGING_'},evalcontext=>$ctx);
      }
      elsif (ref $ctx eq 'HASH' or defined overload::Method($ctx,'%{}')) {
        $evaluator = getContextEvaluator(filters=>$filters,nokeysplit=>$nokeysplit,filterchains=>$filterchains,_DISABLE_LOGGING_=>$args{'_DISABLE_LOGGING_'},evalcontext=>[$ctx]);
      }
    }    
  }
  else {
    $evaluator = getContextEvaluator(filters=>$filters,nokeysplit=>$nokeysplit,filterchains=>$filterchains,_DISABLE_LOGGING_=>$args{'_DISABLE_LOGGING_'},evalcontext=>[]);
  }

  #_log(trace=>"Attempting to expand: $result");
  #print STDERR "Attempting to expand $result\n";
  eval {
    ## And this, ladies and gentlemen, is where the actual expansion takes place.
    ## And it is the $evaluator in the $regex below that does the actual work.
    ## The loop allows to work recursively

    # The commented lines below do greedy matching, which doesn't always work
    #while ($result =~ m/\{\{([^{]+)\}\}/) {
    #  $result =~ s/\{\{([^{]+)\}\}/&$evaluator(src=>$1)/gse;
    #}

    # this does non-greedy matching
    if ($recursive) {
      while ($result =~ m/\{\{((.(?!\{\{))+?)\}\}/) {
        #print STDERR "Attempting to expand: $1 in $result\n";
        $result =~ s/\{\{((.(?!\{\{))+?)\}\}/&$evaluator(src=>$1,recursive=>1)/gse;
        #print STDERR "   ---> result = $result\n";
      }
    }
    else {
      $result =~ s/\{\{((.(?!\{\{))+?)\}\}/&$evaluator(src=>$1,recursive=>0)/gse;
    }
  };
  if ($@) {
    if (ref $@ eq 'HASH') {
      croak $@;
    }
    elsif ( ref \$@ eq 'SCALAR') {
      croak { message=>$@ };
    }
  }

  ## Now look for savepoints
  my @savepoints = $result =~ m/<<SAVE:([^>>]+)>>(.*?)<<\/SAVE:?\1?>>/gs;
  if (scalar @savepoints) {
    my $toupdate;
    my %temp_toupdate = @savepoints;
    if (defined $args{'update'}) {
      #_log(@_,trace=>"Parameter update in call to expand is specified and is not defined. I will use it to save data from the result of the expansion");
      $toupdate = $args{'update'};
    }
    else {
      if (exists $args{'update'}) {
        #_log(@_,trace=>"Parameter update in call to expand is specified but is not defined. Is this intentional ?");
      }
      $toupdate = {}; # which will be thrown away 
    }
    for my $savepoint (keys %temp_toupdate) {
      $toupdate->{$savepoint} = $temp_toupdate{$savepoint};
      $result =~ s/<<SAVE:$savepoint>>(.*?)<<\/SAVE([^>>]*)>>/$1/g;
    }
  }

  #_log(trace=>"Expanded result: $result");
  if (defined $args{'outfile'}) {
    my $ofilename = $args{'outfile'};
    if (ref $ofilename eq 'CODE') {
      $ofilename = &$ofilename;
    }
    my $OFILE;
    open($OFILE,'>',$ofilename);
    print $OFILE $result;
    close $OFILE;
  } 

  if ($resolve_mode) {
    my $ctx = $args{'evalcontext'};
    if (ref $ctx eq 'ARRAY') {
      # all is well
    }
    elsif (ref $ctx eq 'HASH' or defined overload::Method($ctx,'%{}')) {
      $ctx = [$ctx];
    }
    elsif (ref $ctx eq 'CODE') {
      $ctx = &$ctx;
      if (ref $ctx eq 'ARRAY') {
        # all is well 
      }
      elsif (ref $ctx eq 'HASH' or defined overload::Method($ctx,'%{}')) {
        $ctx = [$ctx];
      }
    }    
    my $endresult = undef;
    for my $c (@$ctx) {
      my $v = $c->{$result};
      if (icdefined $v) {  # It does exist
        return $v; 
      }   
    }
    return undef;
  }
  else {
  	return $result if defined wantarray;
  }
}


sub applyFilterChain {
  my %args = @_;
  my $filterchain = $args{'filterchain'};
  my $value = $args{'value'};
  if (ref $value eq 'HASH' or defined overload::Method($value,'%{}')) {
    my $newhash;
    if (defined $args{'update'}) {
      if (ref $args{'update'} eq 'HASH' or defined overload::Method($args{'update'},'%{}')) {
        $newhash = $args{'update'};
      }
      else {
        croak { message=> "Invalid update type: Type to be updated must be a reference to a type implementing HASH interface"};
      }
    }
    else {
      $newhash = {};
    }
    for my $k (keys %$value) {
      my $filteredvalue = applyFilterChain(@_,value=>$value->{$k});
      $newhash->{$k} = $filteredvalue;
    }
    return $newhash;
  }
  elsif (ref $value eq 'ARRAY' or defined overload::Method($value,'@{}')) {
    my $newarr=[];
    for my $v (@$value) {
      my $nv = applyFilterChain(@_,value=>$value->[$v]);
      push(@$newarr,$nv);
    }
    if (defined $args{'update'}) {
      if (ref $args{'update'} eq 'ARRAY' or defined overload::Method($args{'update'},'@{}')) {
        my $toupdate = $args{'update'}; 
        for (my $cntr = 0; $cntr lt scalar @$newarr; $cntr++) {
          $toupdate->[$cntr] = $newarr->[$cntr];
        }
      }
      else {
        croak { message=> "Invalid update type: Type to be updated must be a reference to a type implementing ARRAY interface"};
      }
    }
    return $newarr;
  }
  elsif (ref $value eq 'CODE') {
    my $newval = &$value;
    my $lrc = applyFilterChain(@_,value=>$newval);
    return $lrc;
  }
  elsif (ref \$value eq 'SCALAR') {
    my $filterlibs = $args{'filterlibs'};
    my $srcstring = '';
    if (defined $filterlibs) {
      $srcstring = '<<FILTERLIB:'.join(',',@{$filterlibs}).'>>\n';
    }
    $srcstring .= "{{?_VALUE_|$filterchain}}";
    my $lrc=expand(src=>$srcstring,evalcontext=>{_VALUE_=>$value},_DISABLE_LOGGING_=>$args{'_DISABLE_LOGGING_'});
    return $lrc;
  }
  else {
    my $rtype = ref $value;
    if (not defined $rtype) {
      $rtype = ref \$value;
    }
    croak { message=>"Unrecognized type: %rtype"};
  }
}

sub getFileList_ssh {
  my %args = @_;
  use Data::Dumper;
  print STDERR "GETFILELIST_SSH called with params: ",Dumper(\%args),"\n";
  my $filepattern;
  my $dir = $args{'directory'};
  my $parsed_uri = parseURI(uri=>$dir,resolve_credentials=>1);

  if (defined $args{'filepattern'}) {
    $filepattern = $args{'filepattern'};
  }
  elsif (defined $args{'globpattern'}) {
    $filepattern = glob2Regex(globpattern=>$args{'globpattern'});
  }
  else {
    $filepattern = '.*';
  }
  my $fileprefix;
  if (defined $args{'prefix'}) {
    $fileprefix = $args{'prefix'};
  }
  else {
    $fileprefix = undef;
  }
  my $basename;
  if (not exists $args{'basename'}) {
    $basename = 0;
  }
  else {
    $basename = evalBoolean(value=>$args{'basename'});
  }
  use Net::OpenSSH;
  my $ssh_options = {};
	if (defined $parsed_uri->{'username'}) {
		$ssh_options->{'user'} = $parsed_uri->{'username'};
	}
	if (defined $parsed_uri->{'password'}) {
		$ssh_options->{'password'} = $parsed_uri->{'password'};
	}
	if (defined $parsed_uri->{'private_key'}) {
	  $ssh_options->{'key_path'} = $parsed_uri->{'private_key'};
	}
  my $ssh = Net::OpenSSH->new($parsed_uri->{'host'},%$ssh_options);
  my $sftp = $ssh->sftp();
  use Fcntl ':mode';
  my $ls = $sftp->ls($parsed_uri->{'path'} or '/');
  my @readfiles = @$ls;
  @readfiles = grep { S_ISREG($_->{a}->perm)} @readfiles;
  use Data::Dumper;
  print "Net::OpenSSH got ",Dumper(\@readfiles),"\n";

  if (defined $args{'filter'}) {
  	my $filter;
    $filter = $args{'filter'};
    # we now have to build a hash containing directory, filename, and stats
     my @nlist = map { { 
                         filename=>$_->{'filename'},
                         directory=>$dir,
                          stats=>{
                                   size=>$_->{'a'}->{'size'},
                                   atime=>$_->{'a'}->{'atime'},
                                   mtime=>$_->{'a'}->{'mtime'}
                                 }  
                       } } @readfiles;
    #print STDERR "Build nlist: ",Dumper(\@nlist),"\n";
       
  	@nlist = $filter->(data=>\@nlist);
    #print STDERR "Got nlist from filter: ",Dumper(\@nlist),"\n";
    @readfiles = @nlist;
  }
  print STDERR "after filter readfiles = ",Dumper(\@readfiles),"\n";
 #print STDERR "Got readfiles before passing to filter: ",Dumper(\@readfiles),"\n";
  if (defined $fileprefix) {
    my $pattern = "$filepattern";
    $pattern =~ s/\$$//;
    $pattern =~ s/^\^//;
    $pattern = "$fileprefix$filepattern";
    _log(level=>"trace",message=>"Using filename pattern: $pattern");
    
    @readfiles = grep { $_->{'filename'} =~ m/^$pattern$/} @readfiles;
  }
  else {
    my $pattern = $filepattern;
    print STDERR "Filtering files by filepattern $filepattern\n";
    my $negmatch = 0;
    if ($pattern =~ m/^!/) {
      $negmatch = 1;
      $pattern =~ s/^!//;
    }
    $pattern =~ s/\$$//;
    $pattern =~ s/^\^//;
    if ($negmatch) {
      @readfiles = grep { $_->{'filename'} !~ m/^$pattern$/} @readfiles;
    }
    else {
      @readfiles = grep { $_->{'filename'} =~ m/^$pattern$/} @readfiles;
    }
  }

  #print STDERR "after local pattern filter readfiles = ",Dumper(\@readfiles),"\n";

  if (defined $args{'maxage'}) {
    my $maxage = $args{'maxage'};
    _log(message=>"filtering on age: maxage = $maxage",level=>"debug");
    # by default we take maxage in days  ... but we need it in seconds ...
    if ($maxage =~ m/^\d+$/) {
      $maxage = $maxage * 86400;
    }
    elsif ($maxage =~ m/d$/) {
      $maxage =~ s/d$//;
      $maxage = $maxage * 86400;
    }
    elsif ($maxage =~ m/s$/) {
      $maxage =~ s/s$//;
      $maxage = $maxage + 0;
    }
    elsif ($maxage =~ m/m$/) {  
      $maxage =~ s/m$//;
      $maxage = $maxage * 60;
    }
    elsif ($maxage =~ m/h$/) { 
      $maxage =~ s/h$//;
      $maxage = $maxage * 3600;
    }
    my $mintimestamp = time() - $maxage;
    print STDERR "Looking for files with timestamp > ",applyFilterChain(value=>$mintimestamp,filterchain=>'formatDateTime %Y%m%d:%H:%M:%S'),"\n";
    print "PREAGEFILTER for $mintimestamp",Dumper(\@readfiles),"\n";
    @readfiles = grep { $_->{'stats'}->{'mtime'} ge $mintimestamp  } @readfiles;
    print "POSTAGEFILETER $mintimestamp ",Dumper(\@readfiles),"\n";
  }
  else {
   #_log(message=>"not filtering on maxage",level=>"debug" );
  }

  if (defined $args{'minage'}) {
    my $minage = $args{'minage'};
    _log(message=>"filtering on age: minage = $minage",level=>"debug");
    # by default we take maxage in days  ... but we need it in seconds ...
    if ($minage =~ m/^\d+$/) {
      $minage = $minage * 86400;
    }
    elsif ($minage =~ m/d$/) {
      $minage =~ s/d$//;
      $minage = $minage * 86400;
    }
    elsif ($minage =~ m/s$/) {
      $minage =~ s/s$//;
      $minage = $minage + 0;
    }
    elsif ($minage =~ m/m$/) {  
      $minage =~ s/m$//;
      $minage = $minage * 60;
    }
    elsif ($minage =~ m/h$/) { 
      $minage =~ s/h$//;
      $minage = $minage * 3600;
    }
    my $maxtimestamp = time() - $minage;
    _log(message=>"Filtering on files with access time < {{TS}} ({{TS|::formatDateTime %Y%m%d-%H:%M:%S}})",evalcontext=>{TS=>$maxtimestamp},level=>"trace");
    @readfiles = grep { $_->{'stats'}->{'mtime'} le $maxtimestamp;  } @readfiles;
  }
  else {
    #_log(message=>"not filtering on minage",level=>"debug");
  }

  if (defined $args{'sortorder'} and $args{'sortorder'} eq 'age') {
    _log(level=>"trace",message=>"Sorting files by age");
    @readfiles = sort { $a->{'stats'}->{'mtime'} cmp $b->{'stats'}->{'mtime'} } @readfiles;
    @readfiles = reverse @readfiles;
  }
  elsif (defined $args{'sortorder'} and $args{'sortorder'} eq 'timestamp') {
    _log(level=>"trace",message=>"Sorting files by timestamp");
    @readfiles = sort { $a->{'stats'}->{'mtime'} cmp $b->{'stats'}->{'mtime'} } @readfiles;
    #@readfiles = sort { (stat(File::Spec->catfile($dir,$a)))[9] cmp (stat(File::Spec->catfile($dir,$b)))[9]} @readfiles;
  }
  elsif (defined $args{'sortorder'} and $args{'sortorder'} eq 'filename') {
    @readfiles = sort { $a->{'filename'} cmp $b->{'filename'} } @readfiles;
  }

  my @returnfiles = map { $_->{'filename'}; } @readfiles;
  my @returnfiles_2 = ();

  for my $f (@returnfiles) {
    if ($basename) {
      push @returnfiles_2,$f;
    }
    else {
      push @returnfiles_2,join('/',($dir,$f)); #File::Spec->catfile($dir,$f);
    }
  }

  #if (defined $args{'filter'}) {
  #  @returnfiles_2 = $args{'filter'}->(list=>\@returnfiles_2);
  #}

 use Data::Dumper;
 print "getfilelist_ssh returning ",Dumper(\@returnfiles_2),"\n";
	return @returnfiles_2;

}

sub getFileList_ftp {
  my %args = @_;
  my $filepattern;
  my $dir = $args{'directory'};
  my $parsed_uri = parseURI(uri=>$dir,resolve_credentials=>1);

  if (defined $args{'filepattern'}) {
    $filepattern = $args{'filepattern'};
  }
  elsif (defined $args{'globpattern'}) {
    $filepattern = glob2Regex(globpattern=>$args{'globpattern'});
  }
  else {
    $filepattern = '.*';
  }
  my $fileprefix;
  if (defined $args{'prefix'}) {
    $fileprefix = $args{'prefix'};
  }
  else {
    $fileprefix = undef;
  }
  my $basename;
  if (not exists $args{'basename'}) {
    $basename = 0;
  }
  else {
    $basename = evalBoolean(value=>$args{'basename'});
  }
  use Net::FTP;
  my $ssh_options = {};
	if (defined $parsed_uri->{'username'}) {
		$ssh_options->{'user'} = $parsed_uri->{'username'};
	}
	if (defined $parsed_uri->{'password'}) {
		$ssh_options->{'password'} = $parsed_uri->{'password'};
	}
  print STDERR "Retrieving filelist for protocol ftp for host $parsed_uri->{'host'}\n";
  my $ftp = Net::FTP->new($parsed_uri->{'host'}) or die "failed to connect to ftp: $!\n";
  $ftp->login($parsed_uri->{'username'},$parsed_uri->{'password'});
  use Fcntl ':mode';
  my $ls = $ftp->dir($parsed_uri->{'path'} or '/');
  my $rdir = $parsed_uri->{'path'};
  my @readfiles = @$ls;
  use Data::Dumper;
  print "ftp get filelist got: ",Dumper(\@readfiles),"\n";
  #@readfiles = grep { S_ISREG($_->{a}->perm)} @readfiles;
  @readfiles = grep { '^-' } @readfiles;
  use Data::Dumper;
  #print "Net::FTP got ",Dumper(\@readfiles),"\n";
  my @fnameonly = map { my @s=  split(/\s+/,$_ ); $s[-1]; } @readfiles;
  #print "Net::FTP got fname only",Dumper(\@fnameonly),"\n";

  # the getting stats from the file through ftp may be time consuming
  # so we make it optional
  my $do_stats = 0;
  if (defined $args{'filter'}) { 
    my $filter = $args{'filter'}; 
    if (defined overload::Method($filter,'&{}')) {
      if ($filter->can('isMTimeBased') and $filter->isMTimeBased()) {
        $do_stats = 1;
      }
    }
  }
  if (defined $args{'maxage'}) { $do_stats = 1; }
  if (defined $args{'minage'}) { $do_stats = 1; }
  if (defined $args{'sortorder'} and $args{'sortorder'} eq 'timestamp') { $do_stats = 1; }
  if (defined $args{'sortorder'} and $args{'sortorder'} eq 'age') { $do_stats = 1; }

  if ($do_stats) {
  	my $filter;
    $filter = $args{'filter'};
    # we now have to build a hash containing directory, filename, and stats
     my @fnameonly = map { my @s=  split(/\s+/,$_ ); $s[-1]; } @readfiles;
     my @nlist = map { { 
                         filename=>$_,
                         directory=>$dir,
                          stats=>{
                                   size=>$ftp->size(File::Spec->catfile($rdir,$_)),
                                   mtime=>$ftp->mdtm(File::Spec->catfile($rdir,$_))
                                 }  
                       } } @fnameonly;
    #print STDERR "Build nlist: ",Dumper(\@nlist),"\n";
       
  	@nlist = $filter->(data=>\@nlist);
    #print STDERR "Got nlist from filter: ",Dumper(\@nlist),"\n";
    @readfiles = @nlist;
  }
  else {
     my @fnameonly = map { my @s=  split(/\s+/,$_ ); $s[-1]; } @readfiles;
     my @nlist = map { { 
                         filename=> $_,
                         directory=>$dir,
                          stats=>{}
                       } } @fnameonly;
    #print STDERR "Build nlist: ",Dumper(\@nlist),"\n";
       
  	#@nlist = $filter->(data=>\@nlist);
    #print STDERR "Got nlist from filter: ",Dumper(\@nlist),"\n";
    @readfiles = @nlist;
    
  }
  if (defined $args{'filter'}) {
    my $filter = $args{'filter'};
    @readfiles = $filter->(data=>\@readfiles);
  }
#  print STDERR "Got readfiles before passing to filter: ",Dumper(\@readfiles),"\n";
  if (defined $fileprefix) {
    my $pattern = "$filepattern";
    $pattern =~ s/\$$//;
    $pattern =~ s/^\^//;
    $pattern = "$fileprefix$filepattern";
    _log(level=>"trace",message=>"Using filename pattern: $pattern");
    
    @readfiles = grep { $_->{'filename'} =~ m/^$pattern$/} @readfiles;
  }
  else {
    my $pattern = $filepattern;
    #print STDERR "Filtering files by filepattern $filepattern\n";
    my $negmatch = 0;
    if ($pattern =~ m/^!/) {
      $negmatch = 1;
      $pattern =~ s/^!//;
    }
    $pattern =~ s/\$$//;
    $pattern =~ s/^\^//;
    if ($negmatch) {
      @readfiles = grep { $_->{'filename'} !~ m/^$pattern$/} @readfiles;
    }
    else {
      @readfiles = grep { $_->{'filename'} =~ m/^$pattern$/} @readfiles;
    }
  }

  if (defined $args{'maxage'}) {
    my $maxage = $args{'maxage'};
    _log(message=>"filtering on age: maxage = $maxage",level=>"debug");
    # by default we take maxage in days  ... but we need it in seconds ...
    if ($maxage =~ m/^\d+$/) {
      $maxage = $maxage * 86400;
    }
    elsif ($maxage =~ m/d$/) {
      $maxage =~ s/d$//;
      $maxage = $maxage * 86400;
    }
    elsif ($maxage =~ m/s$/) {
      $maxage =~ s/s$//;
      $maxage = $maxage + 0;
    }
    elsif ($maxage =~ m/m$/) {  
      $maxage =~ s/m$//;
      $maxage = $maxage * 60;
    }
    elsif ($maxage =~ m/h$/) { 
      $maxage =~ s/h$//;
      $maxage = $maxage * 3600;
    }
    my $mintimestamp = time() - $maxage;
    @readfiles = grep { $_->{'stats'}->{'mtime'} >= $mintimestamp;  } @readfiles;
  }
  else {
   #_log(message=>"not filtering on maxage",level=>"debug" );
  }

  if (defined $args{'minage'}) {
    my $minage = $args{'minage'};
    _log(message=>"filtering on age: minage = $minage",level=>"debug");
    # by default we take maxage in days  ... but we need it in seconds ...
    if ($minage =~ m/^\d+$/) {
      $minage = $minage * 86400;
    }
    elsif ($minage =~ m/d$/) {
      $minage =~ s/d$//;
      $minage = $minage * 86400;
    }
    elsif ($minage =~ m/s$/) {
      $minage =~ s/s$//;
      $minage = $minage + 0;
    }
    elsif ($minage =~ m/m$/) {  
      $minage =~ s/m$//;
      $minage = $minage * 60;
    }
    elsif ($minage =~ m/h$/) { 
      $minage =~ s/h$//;
      $minage = $minage * 3600;
    }
    my $maxtimestamp = time() - $minage;
    _log(message=>"Filtering on files with access time < {{TS}} ({{TS|::formatDateTime %Y%m%d-%H:%M:%S}})",evalcontext=>{TS=>$maxtimestamp},level=>"trace");
    @readfiles = grep { $_->{'stats'}->{'mtime'} <= $maxtimestamp;  } @readfiles;
  }
  else {
    #_log(message=>"not filtering on minage",level=>"debug");
  }

  if (defined $args{'sortorder'} and $args{'sortorder'} eq 'age') {
    _log(level=>"trace",message=>"Sorting files by age");
    @readfiles = sort { $a->{'stats'}->{'mtime'} cmp $b->{'stats'}->{'mtime'} } @readfiles;
    @readfiles = reverse @readfiles;
  }
  elsif (defined $args{'sortorder'} and $args{'sortorder'} eq 'timestamp') {
    _log(level=>"trace",message=>"Sorting files by timestamp");
    @readfiles = sort { $a->{'stats'}->{'mtime'} cmp $b->{'stats'}->{'mtime'} } @readfiles;
    #@readfiles = sort { (stat(File::Spec->catfile($dir,$a)))[9] cmp (stat(File::Spec->catfile($dir,$b)))[9]} @readfiles;
  }
  elsif (defined $args{'sortorder'} and $args{'sortorder'} eq 'filename') {
    @readfiles = sort { $a->{'filename'} cmp $b->{'filename'} } @readfiles;
  }

  my @returnfiles = map { $_->{'filename'}; } @readfiles;
  my @returnfiles_2 = ();

  for my $f (@returnfiles) {
    if ($basename) {
      push @returnfiles_2,$f;
    }
    else {
      push @returnfiles_2,join('/',($dir,$f)); #File::Spec->catfile($dir,$f);
    }
  }

  #if (defined $args{'filter'}) {
  #  @returnfiles_2 = $args{'filter'}->(list=>\@returnfiles_2);
  #}

	return @returnfiles_2;

}

sub getFileList {
  my %args=@_;
  my $filepattern = $args{'filepattern'};
  my $dir;
  my $origdir;
  if (defined $args{'directory'}) {
    $dir = $args{'directory'};
  }
  else {
    use Cwd;
    $dir = getcwd();
  }
  if (defined $args{'evalcontext'}) {
    $dir = expand(src=>$dir,evalcontext=>$args{'evalcontext'});
  }
  my $parsed = parseURI(uri=>$dir);
  if ($parsed->{'scheme'} =~ m/SCP|SFTP|SSH/i) {
    my @sshlist = getFileList_ssh(@_);
    if (wantarray) {
      return @sshlist;
    }
    elsif (defined wantarray) {
      return \@sshlist;
    }
    else {
      return undef;
    }
  }
  elsif ($parsed->{'scheme'} =~ m/FTP/i) {
    my @ftplist = getFileList_ftp(@_);
    if (wantarray) {
      return @ftplist;
    }
    elsif (defined wantarray) {
      return \@ftplist;
    }
    else {
      return undef;
    }
  }
  else {
    $dir = $parsed->{'path'};
    $origdir = $args{'directory'};
  }
  if (defined $args{'filepattern'}) {
    $filepattern = $args{'filepattern'};
  }
  elsif (defined $args{'globpattern'}) {
    $filepattern = glob2Regex(globpattern=>$args{'globpattern'});
  }
  else {
    $filepattern = '.*';
  }
  if (defined $args{'evalcontext'}) {
    dprint "Trying to expand filepattern $filepattern\n";
    $filepattern = expand(src=>$filepattern,evalcontext=>$args{'evalcontext'});
    dprint "Expanded filepattern: $filepattern\n";
  }
  my $fileprefix;
  if (defined $args{'prefix'}) {
    $fileprefix = $args{'prefix'};
  }
  else {
    $fileprefix = undef;
  }
  my $basename;
  if (not exists $args{'basename'}) {
    $basename = 0;
  }
  else {
    $basename = evalBoolean(value=>$args{'basename'});
  }

  opendir(FILEDIR,$dir);
  my @readfiles = readdir FILEDIR;
  close FILEDIR;

  @readfiles =  grep { !/^\./} @readfiles;
  my @nodirs = ();
  for my $checknodir (@readfiles) {
    if (-f File::Spec->catfile($dir,$checknodir)) {
      push (@nodirs,$checknodir);
    }
  }
  @readfiles = @nodirs;
  #my $filter;
  #if (defined $args{'filter'}) {
  #  $filter = $args{'filter'};
  #}
  #else { 
  #  $filter = sub { my %args = @_; my $files = $args{'data'}; return @$files; };
  #}
  #@readfiles = $filter->(data=>\@readfiles);
  if (defined $args{'filter'}) {
  	my $filter;
    $filter = $args{'filter'};
    # we now have to build a hash containing directory, filename, and stats
    my @nlist = ();
    for my $f (@readfiles) {
      my @st = stat(File::Spec->catfile($dir,$f));
      push @nlist, { filename=>$f, directory=>$dir,stats=>{ size=>$st[7], atime=>$st[8],mtime=>$st[9]}};
    }
    #print STDERR "Build nlist: ",Dumper(\@nlist),"\n";
       
  	@nlist = $filter->(data=>\@nlist);
    #print STDERR "Got nlist from filter: ",Dumper(\@nlist),"\n";
    @readfiles = map { $_->{'filename'} } @nlist;
  }

  if (defined $fileprefix) {
    my $pattern = "$filepattern";
    $pattern =~ s/\$$//;
    $pattern =~ s/^\^//;
    $pattern = "$fileprefix$filepattern";
    _log(level=>"trace",message=>"Using filename pattern: $pattern");
    
    @readfiles = grep { /^$pattern$/} @readfiles;
  }
  else {
    my $pattern = $filepattern;
    my $negmatch = 0;
    if ($pattern =~ m/^!/) {
      $negmatch = 1;
      $pattern =~ s/^!//;
    }
    $pattern =~ s/\$$//;
    $pattern =~ s/^\^//;
    if ($negmatch) {
      @readfiles = grep { !/^$pattern$/} @readfiles;
    }
    else {
      @readfiles = grep { /^$pattern$/} @readfiles;
    }
  }

  if (defined $args{'maxage'}) {
    my $maxage = $args{'maxage'};
    _log(message=>"filtering on age: maxage = $maxage",level=>"debug");
    # by default we take maxage in days  ... but we need it in seconds ...
    if ($maxage =~ m/^\d+$/) {
      $maxage = $maxage * 86400;
    }
    elsif ($maxage =~ m/d$/) {
      $maxage =~ s/d$//;
      $maxage = $maxage * 86400;
    }
    elsif ($maxage =~ m/s$/) {
      $maxage =~ s/s$//;
      $maxage = $maxage + 0;
    }
    elsif ($maxage =~ m/m$/) {  
      $maxage =~ s/m$//;
      $maxage = $maxage * 60;
    }
    elsif ($maxage =~ m/h$/) { 
      $maxage =~ s/h$//;
      $maxage = $maxage * 3600;
    }
    my $mintimestamp = time() - $maxage;
    @readfiles = grep { my @st = stat(File::Spec->catfile($dir,$_)); _log(message=>"Timestamp for file $_ : $st[9]", level=>"debug"); $st[9] >= $mintimestamp;  } @readfiles;
  }
  else {
   #_log(message=>"not filtering on maxage",level=>"debug" );
  }

  if (defined $args{'minage'}) {
    my $minage = $args{'minage'};
    _log(message=>"filtering on age: minage = $minage",level=>"debug");
    # by default we take maxage in days  ... but we need it in seconds ...
    if ($minage =~ m/^\d+$/) {
      $minage = $minage * 86400;
    }
    elsif ($minage =~ m/d$/) {
      $minage =~ s/d$//;
      $minage = $minage * 86400;
    }
    elsif ($minage =~ m/s$/) {
      $minage =~ s/s$//;
      $minage = $minage + 0;
    }
    elsif ($minage =~ m/m$/) {  
      $minage =~ s/m$//;
      $minage = $minage * 60;
    }
    elsif ($minage =~ m/h$/) { 
      $minage =~ s/h$//;
      $minage = $minage * 3600;
    }
    my $maxtimestamp = time() - $minage;
    _log(message=>"Filtering on files with access time < {{TS}} ({{TS|::formatDateTime %Y%m%d-%H:%M:%S}})",evalcontext=>{TS=>$maxtimestamp},level=>"trace");
    #@readfiles = grep { my @st = stat(File::Spec->catfile($dir,$_)); _log(message=>"Filestamp for file $_: $st[9]",level=>"debug"); $st[9] <= $maxtimestamp; } @readfiles;
    @readfiles = grep { my @st = stat(File::Spec->catfile($dir,$_)); $st[9] <= $maxtimestamp; } @readfiles;
  }
  else {
    #_log(message=>"not filtering on minage",level=>"debug");
  }

  if (defined $args{'sortorder'} and $args{'sortorder'} eq 'age') {
    _log(level=>"trace",message=>"Sorting files by age");
    @readfiles = sort { (stat(File::Spec->catfile($dir,$a)))[9] cmp (stat(File::Spec->catfile($dir,$b)))[9]} @readfiles;
    @readfiles = reverse @readfiles;
  }
  elsif (defined $args{'sortorder'} and $args{'sortorder'} eq 'timestamp') {
    _log(level=>"trace",message=>"Sorting files by timestamp");
    @readfiles = sort { (stat(File::Spec->catfile($dir,$a)))[9] cmp (stat(File::Spec->catfile($dir,$b)))[9]} @readfiles;
  }
  elsif (defined $args{'sortorder'} and $args{'sortorder'} eq 'filename') {
    @readfiles = sort @readfiles;
  }
  my @returnfiles;
  if ($args{'directory'} =~ m/^[^:]+:\/\//) {
    $basename = 0; # force this
  }
  for my $f (@readfiles) {
    if ($basename) {
      push @returnfiles,$f;
    }
    else {
      my $nf = File::Spec->catfile($dir,$f);
      if ($args{'directory'} =~ m/^([^:]+:\/\/)/) {
        $nf = "$1${nf}";
      }
      push @returnfiles,$nf;
    }
  }

  #if (defined $args{'filter'}) {
  #  @returnfiles = $args{'filter'}->(list=>\@returnfiles);
  #}

  if ( wantarray ) {if (@returnfiles) { return @returnfiles; } else { return (); }}
  elsif (defined wantarray) { if (@returnfiles) { \@returnfiles; } else { return []; }}
}


sub getPMTSysConfig {
  my %args = @_;
  my $section = $args{'section'};
  if (not defined $section) {
    $section = 'defaults';
  }
  my $use_defaults = $args{'use_defaults'};
  if (not defined $use_defaults) {
    my $use_defaults = 0;
  }

  # Loading config file
  my $configfile = $ENV{'PMTCONFIG'};
  #print "loading configfile: $configfile\n";
  my $cfg = new Config::Simple($configfile) or die "failed to load config file: $!";
  my $chash;
  if ($use_defaults) {
    $chash = $cfg->get_block('defaults');
  }
  else {
    $chash = {};
  }

  if ($section) {
    my $shash = $cfg->get_block($section);
    for my $k (keys %$shash) {
      $chash->{$k} = $shash->{$k};
    }
  }
  return $chash;
}

sub isSelf {
  my %args = @_;
  my $address = $args{'address'};
  print STDERR "Checking address: $address\n";
  my ($name,$aliases,$addrtype,$length,@addrs) = gethostbyname($address);

  # check for interfaces that we will always consider to be remote
  my @discard_addresses = ();
  my $netsection = getPMTSysConfig(section=>'net');
  my $force_local = [];
  if ($netsection and keys %$netsection) {
    if (defined $netsection->{'remote_addresses'}) {
      #print "I found a remote_addresses section\n";
    }
    if (defined $netsection->{'force_local'}) {
      $force_local = $netsection->{'force_local'};
      print STDERR "Forcing these to local: $force_local\n";
      $force_local =~ s/^s+//;
      $force_local =~ s/s+$//;
      my @fp = split(/\s+/,$force_local);
      if (grep { /$address/ } @fp) {
        print "force local: $address\n";
        return 1;
      }
    }
  }

  use IO::Interface::Simple;
  my @ifaces = IO::Interface::Simple->interfaces;
  my @ia = ();
  for my $if (@ifaces) {
    my $ad = $if->address();
    if ($ad) {
      #print "This is an address of mine: $ad\n";
      push @ia,$ad;
    }
  }
  my $found = 0;
  for my $a (@addrs) {
    my $a = join(".",unpack('W4',$addrs[0]));
    #print "Checking addresses: $a\n";
    if (grep (/^$a$/,@ia)) {
      return 1;
    }
  }
  #print STDERR "Nothing found, returning 0\n";
  return 0;
}

sub getCredentials {
  my %args = @_;
  my $username; # = $args{'user'};
  my $host; # = $args{'host'};
  my $password;
  my $scheme;

  my $uri = $args{'uri'};
  my $rc = {};
  $rc->{'local_username'} = getpwuid($<);
	#dprint "Geting credentials for uri $uri\n";
  if (defined $uri) { 
		if (ref $uri and ref $uri eq 'HASH') {
			$scheme = $uri->{'scheme'};
			$username = $uri->{'username'};
			$host = $uri->{'host'};
			$password = $uri->{'password'};
		}
    else {
    	my $cc = parseURI(uri=>$uri,no_force_local=>1,resolve_credentials=>0);
    	#dprint "Parse Uri gave me:\n";
    	#for my $k (keys %$cc) {
      #	dprint "   $k = $cc->{$k}\n";
    	#}
      $scheme = $cc->{'scheme'};
      $host = $cc->{'host'};
      $username = $cc->{'username'};
      $password = $cc->{'password'};
    }
  }
  else {
     $username = $args{'username'};
     $host  = $args{'host'};
     $scheme = $args{'scheme'};
		 $password = $args{'password'};
  }
  my $confkey;
  if (not defined $scheme) {
		dprint "assuming scheme: ssh\n";
    $confkey = 'ssh';
  }
  elsif ($scheme =~ m/^SSH|SCP|SFTP$/i) {
    $confkey = 'ssh';
    #dprint "scheme $scheme corresponds to confkey $confkey\n";
  }
  elsif ($scheme =~ m/^FTP|HTTP|HTTPS$/i) {
    $confkey = lc $scheme;
  }
  else {
    ##croak { message=>"Unsupported uri scheme: $scheme" };
    return {};
  }
  my $config_section = getPMTSysConfig(section=>$confkey);
  my $credval;
  my $matchkey;
  if (defined $username) {
		if (exists $config_section->{"${username}\@${host}"}) {
      $matchkey = "${username}\@${host}";
      $credval = $config_section->{"${username}\@${host}"};
    }
		elsif (exists $config_section->{"default:${username}"}) {
      $matchkey = "default:${username}";
      $credval = $config_section->{"default:${username}"};
    }
		elsif (exists $config_section->{"default\@${host}"}) {
      $matchkey = "default\@${host}";
      $credval = $config_section->{"default\@${host}"};
    }
		elsif (exists $config_section->{'default'}) {
      $matchkey = 'default';
      $credval = $config_section->{'default'};
    }
  }
  else {
		if (exists $config_section->{"default\@${host}"}) {
      $matchkey =  "default\@${host}";
      $credval =  $config_section->{"default\@${host}"};
    }
		elsif (exists $config_section->{'default'}) {
      $matchkey = 'default';
      $credval = $config_section->{'default'};
    }
  }
  if ($credval) {
    #dprint "now using credval: $matchkey = $credval\n";
		if ($confkey eq 'ssh') {
			if ($credval =~ m/^PRIVKEY:(.*)/i) {
				my $dirref = $1;

        #dprint "using dirref : $dirref\n";
				if ($dirref =~ m/^(HOME|SSH|PMTROOT|PMTCONFIG)\/(.*)/i) {
					my $key = expand(src=>$2,evalcontext=>[{username=>$username,scheme=>$scheme,host=>$host}]);
					dprint "keyfile = $key\n";
					my $directory;
					if ($dirref =~ m/^HOME\//i) {
						use File::HomeDir;
            $directory = File::HomeDir->my_home;
          }
					elsif ($dirref =~ m/SSH/i) {
						use File::HomeDir;
						$directory = File::Spec->catfile(File::HomeDir->my_home,'.ssh');
          }
					elsif ($dirref =~ m/PMTROOT/) {
            $directory = $ENV{'PMTROOT'};
          }
					elsif ($dirref =~ m/PMTCONFIG/) {
						use File::Basename qw(dirname);
            $directory = dirname $ENV{'PMTCONFIG'};
          }
				  $rc->{'private_key'} = File::Spec->catfile($directory,$key);
        }
        else {
					$rc->{'private_key'} = PMTUtilities::expand(src=>$dirref,evalcontext=>[{username=>$username,scheme=>$scheme,host=>$host}]);
        }
      }
      elsif ($credval =~ m/^PASSWD:(.*)/) {
				# the credential is a password
        my $encrypted_password = $1;
				$rc->{'password'} = $encrypted_password;
      }
      elsif ($credval =~ m/^SSHCONFIG/) {
        # we don't need to do anything since everything is declared in ssh config files
      }
    }
    elsif ($confkey eq 'ftp') {
      #print "for ftp Using credval:$credval\n";
      if ($credval =~ m/^\s*PASSWD:(.*)/) {
        my $passwd = $1;
        
				$rc->{'password'} = $passwd;
      }
      else {
        print "Could not parse credval\n";
      }
    }
    else {
      dprint "methods for evaluating confkey $confkey not implemented yet\n";
    }
  }
  if (defined $username) {
    $rc->{'username'} = $username;
  }
  return $rc;
}

sub resolveSymbolicDirectory {
  my %args = @_;
  my $directory = $args{'directory'};
	my $method = $args{'method'};
	
}

sub parseURI {
  my %args = @_;
  my $locspec = $args{'uri'};
  my $olocspec = $args{'uri'};
  my $no_force_local = $args{'no_force_local'};
  if (not defined $no_force_local) {
    $no_force_local = 0;
  }
  #dprint "parsing uri $locspec\n--------------------\n";
  use URI::Split qw(uri_split);
  my $is_relpath = 0;

  if ($locspec =~ /[^:]*\/\//) {
    # $locspec seems well formed
  }
  else {
    my $lscheme;
    if (defined $args{'scheme'}) {
      $lscheme = $args{'scheme'};
    }
    else {
			if ($locspec =~ m/^\//) {
        $lscheme = 'file';
      }
			elsif ($locspec =~ m/^\./) {
        $lscheme = 'file';
				$is_relpath = 1;
      }
      elsif ($locspec =~ m/^[0-9a-zA-Z:._]*\@/) {
       	$lscheme = 'scp';
      }
			elsif ($locspec =~ m/^[0-9a-zA-Z:._]+:/) {
				$lscheme = 'scp';
      }
      else {
        croak {message=>"invalid url: $locspec"};
      }
    }
    $locspec = "${lscheme}://${locspec}";
  }
  my ($scheme,$location,$path,$query,$fragment) = uri_split($locspec);
  my @comps1 = uri_split($locspec);
  #print "uri split found scheme = $scheme\n";
  #print "uri_split found location = $location\n";
  #print "path = $path\n";
  #print "fragment = $fragment\n";
  #print "components: @comps1\n";
  my $rh = {};
  if ($fragment) {
    $rh->{'fragment'} = $fragment;
  }
  if ($is_relpath) {
    $path = File::Spec->rel2abs( $path ) ;
  }
  $rh->{'path'} = $path;
  $rh->{'scheme'} = $scheme;
  if ($query) {
    $rh->{'query'} = $query;
  }
  my $auth;
  # i basically need to determine whether this is actually on the host itself
  # if it is, I should transform it to a file uri
  my $locw = $location;
  if ($scheme =~ m/file/i) {
    $rh->{'local'} = 1;
  }
  if ($scheme =~ m/scp|ssh|sftp/i) {
    $locw =~ s/:$//;
    #print "locw is now $locw\n";
    my @comps = split(/\@/,$locw);
    my $locw2;
    if (scalar @comps == 1) { 
      $locw2 = $comps[0];
    }
    else {
      $locw2 = $comps[1];
    }
    #print "testing isself with address $locw2\n";
    if (isSelf(address=>$locw2) and not $no_force_local ) {
      print "it is self\n";
      $rh->{'orig_uri'} = $olocspec;
      $rh->{'corrected_uri'} = $locspec;
      $rh->{'scheme'} = 'file';
      $rh->{'uri'} = 'file://'.$path;
      # query don't make sense for file, but then again it don't make sense for scp either
      if ($fragment) {
        $rh->{'uri'} = $rh->{'uri'}.'#'.$fragment;
      }
    }
    else {
      $rh->{'host'} = $locw2;
      $rh->{'uri'} = "$scheme://$locw2";
      if ($path) {
        $rh->{'uri'} = $rh->{'uri'}.$path;
      }
      if ($query) {
        $rh->{'uri'} = $rh->{'uri'}."?".$query;
      }
      if ($fragment) {
        $rh->{'uri'} = $rh->{'uri'}.'#'.$fragment;
      }
      if (scalar @comps > 1) {
        my $auth_information = $comps[0];
        my @ac = split(/:/,$auth_information);
        if (scalar @ac == 2) {
          $rh->{'username'} = $ac[0];
          $rh->{'password'} = $ac[1];
        }
        elsif (scalar @ac == 1) {
          $rh->{'username'} = $ac[0];
        }
        else {
          croak { message=>"Invalid URL (auth information format mismatch in $locspec"};
        }
        $rh->{'orig_uri'} = $olocspec;
        $rh->{'corrected_uri'} = $locspec;
      }
    }
    $rh->{'fetch'} = "${scheme}://${location}${path}";
    if ($query) {
      $rh->{'fetch'} = $rh->{'fetch'}."?${query}";
    }
  }
  elsif ($scheme =~ m/ftp/i) {
    $locw =~ s/:$//;
    #print "locw is now $locw\n";
    my @comps = split(/\@/,$locw);
    my $locw2;
    if (scalar @comps == 1) { 
      $locw2 = $comps[0];
    }
    else {
      $locw2 = $comps[1];
    }
    #print "testing isself with address $locw2\n";
    if (isSelf(address=>$locw2) and not $no_force_local ) {
      print "it is self\n";
      $rh->{'orig_uri'} = $olocspec;
      $rh->{'corrected_uri'} = $locspec;
      $rh->{'scheme'} = 'file';
      $rh->{'uri'} = 'file://'.$path;
      # query don't make sense for file, but then again it don't make sense for scp either
      if ($fragment) {
        $rh->{'uri'} = $rh->{'uri'}.'#'.$fragment;
      }
    }
    else {
      $rh->{'host'} = $locw2;
      $rh->{'uri'} = "$scheme://$locw2";
      if ($path) {
        $rh->{'uri'} = $rh->{'uri'}.$path;
      }
      if ($query) {
        $rh->{'uri'} = $rh->{'uri'}."?".$query;
      }
      if ($fragment) {
        $rh->{'uri'} = $rh->{'uri'}.'#'.$fragment;
      }
      if (scalar @comps > 1) {
        my $auth_information = $comps[0];
        my @ac = split(/:/,$auth_information);
        if (scalar @ac == 2) {
          $rh->{'username'} = $ac[0];
          $rh->{'password'} = $ac[1];
        }
        elsif (scalar @ac == 1) {
          $rh->{'username'} = $ac[0];
        }
        else {
          croak { message=>"Invalid URL (auth information format mismatch in $locspec"};
        }
        $rh->{'orig_uri'} = $olocspec;
        $rh->{'corrected_uri'} = $locspec;
      }
    }
    $rh->{'fetch'} = "${scheme}://${location}${path}";
    if ($query) {
      $rh->{'fetch'} = $rh->{'fetch'}."?${query}";
    }
  }
  else {
    $rh->{'uri'} = $locspec;
    $rh->{'fetch'} = "${scheme}://${location}${path}";
    if ($query) {
      $rh->{'fetch'} = $rh->{'fetch'}."?${query}";
    }
  }
  my $resolve_credentials;
  if ($args{'resolve_credentials'}) {
    $resolve_credentials = $args{'resolve_credentials'};
  }
  else {
    $resolve_credentials = 0;
  }
  if ($resolve_credentials) {
    #print STDERR "I should be resolving credentials\n";
    my $creds = getCredentials(uri=>$rh);
    for my $k (keys %$creds) {
      if (not defined $rh->{$k} and defined $creds->{$k}) {
        $rh->{$k} = $creds->{$k};
      }
    }
  }
  else {
    #print STDERR "I should not be resolving credentials\n";
  }
  return $rh;
}

sub getXPathDoc {
  my %args = @_;
  my $buffer = $args{'buffer'};
	use XML::XPath;
  my $xp;
  if (ref $buffer ) {
    print STDERR "WARNING: ref buffer in getXPathDoc not implemented yet\n";
    return $buffer;
  }
  else {
		# the buffer is a string or so it seems
    return XML::XPath->new(xml=>$buffer);
  }
}

sub loadResource_async {
}

sub uploadResource {
  my %args = @_;
}

sub loadResource {
  my %args = @_;
  my $resource = $args{'resource'};
  if (not defined $resource and defined $args{'resource_name'}) {
      my $resource_name = $args{'resource_name'};
			my $config = getPMTSysConfig(section=>'resources');
			$resource = $config->{$resource_name};
  }
  if (not defined $resource) {
    die "Failed to load resource since resource is not defined: @_\n";
  }
  my $parsedresource;
  if (not ref $resource) {
    $parsedresource = parseURI(uri=>$resource); 
  }
  else {
    $parsedresource = $resource;
  }
  my $return_handle;
  my $fragment_handler = $args{'fragment_handler'};
  my $io;
  if (exists $args{'io'}) {
    $io =  $args{'io'};
  }
  else {
    $io = undef;
  }
  if (exists $args{'return_handle'}) {
    $return_handle = $args{'return_handle'};
  }
  else {
    $return_handle = 0;
  }
  use IO::Wrap;
  use StreamingHandleTie;

  my $writerfunction;
  if (exists $args{'return_handle'}) {
    use IO::Wrap;
    use StreamingHandleTie;

    
    tie *o,'StreamingHandleTie';
    $io = IO::Wrap->new(\*o);
    #use threads;
    #print "in getresource io = ",$io," in thread ",threads->tid(),"\n";
    setInOutValue(args=>\@_,name=>'return_handle',value=>$io);
    $writerfunction = sub {
      use bytes;
      my $easy = shift;
      my $data = shift;
      eval {
      syswrite o,$data;
      };
      if ($@) {
        dprint "Something went wrong while writing to the handle: $@\n";
      }
      return length($data);
    };
  }
  elsif (exists $args{'fifo_name'}) {
    #print STDERR "This should be using a fifo\n";
    my $fh;
    use Fcntl;
    sysopen ($fh,$args{'fifo_name'},O_RDWR) or die "couldn't open fifo: $!";
    binmode $fh;
    $io = $fh;
    #print "in loadresource, fh is now ",$fh,"\n";
    $writerfunction = sub {
      my $easy = shift;
      my $data = shift;
      #print STDERR "Attempting to write : $data\n";
      use bytes;
      eval {
        syswrite $fh,$data;
        flush $fh;
      };
      if ($@) {
        print STDERR "An error occurred while writing to fifo: $@\n";
      }
      return length $data;
    };
  }
  
  my $buffer='';
  if (not defined $io) {
    $writerfunction = sub {
      use bytes;
      my $easy = shift;
      my $data = shift;
    
      #print "received $data\n";
      $buffer = $buffer.$data;
      return length($data);
    };
  }
  my $easy = Net::Curl::Easy->new();
  $easy->setopt( CURLOPT_URL, $parsedresource->{'fetch'} );
  $easy->setopt(CURLOPT_WRITEFUNCTION, $writerfunction);
  my $rc = $easy->perform();
  if ($args{'postload'}) {
    for my $c (@{$args{'postload'}}) {
      $c->();
    }
  }
  if ($io) {
    eval {
      close $io or die "couldn't close: $!";
    };
  }
  if (defined $io) {
    return undef;
  } 
  if (not defined $args{'parser'}) {
		return $buffer;
  }
  else {
    my $parser = partial($args{'parser'},buffer=>$buffer);
		return $parser->();
  }
}

# sub executeInHelper {
#   my %args = @_;
#   my $code = $args{'code'};
#   my $data = $args{'data'};
#   my $helperscript = $args{'helper'};
#   my $channel = $args{'channel'};
#   my $ic = $args{'initialcontext'};
# 
#   if (not defined $data) { $data = {}; }
#   if (not defined $helperscript) { $helperscript = 'PMTHelper'; }
#  
#   use IO::Select;
#   use IO::Socket::INET;
# 
#   my $do_continue = 1;
#   my $workerpool = {};
#   my $io_pid_mapping = {};
#   my $selector = IO::Select->new();
# 
#   my ($child_writer,$child_reader);
#   my $pid = open2($child_reader,$child_writer,$workerprocess);
# 
# 
#   while ($do_continue > 0) {
#     for my $pid (keys %$workerpool) {
#       my $check = kill 0=>$pid; 
#       if (not $check) {
#          print "pid $pid is dead\n";
#          delete $workerpool->{$pid};
#       }   
#     }
#     my @can_read = $selector->can_read(0.1); 
#     if (scalar @can_read) {
#       for my $h (@can_read) {
#         my $p = $io_pid_mapping->{$h};
#         my $data = deserializeFrom(source=>$h,format=>'JSON');
#         if (defined $data->{'action'}) {
#         }
#         elsif (defined $data->{'end'}) {
#           my $rc = waitpid($p,WHOHANG);
#           delete $workerpool->{$p};
#           delete $io_pid_mapping->{$h};
#           $selector->remove($h);
#         }
#       }
#     }
#   }
# 
#   print STDERR "Executing in helper: \n$code\n";
#   return 0;
# }

sub getJobDefinitions {
  my %args = @_;
  # I should basically use the argument resource
  my $jobdef = {};

  my $jobdefparser = sub {
    my %args = @_;
    my $buffer = $args{'buffer'};
  };
  my $resource = loadResource(resource_name=>'flowdefinition',parser=>\&getXPathDoc);
  print STDERR "resource is now $resource\n";

  my $flowcd = $args{'flowcd'};
  my $role = $args{'role'};
 
  dprint "checking for flowcd $flowcd and role $role\n";
  my $jobnodes = $resource->find(expand(src=>'/flow_definitions/flow[@name="{{flowcd}}"]/role[@name="{{role}}"]',evalcontext=>{flowcd=>$flowcd,role=>$role}));
  my $jobnode;
  if ($jobnodes->isa('XML::XPath::NodeSet')) {
    #print "Found $jobnodes\n";
  	$jobnode = $jobnodes->shift();
  }
  else {
    dprint "Found no nodes\n";
    print STDERR "it doesn't look like a valid document\n";
  }
  print "jobnode is now $jobnode\n";
  if (not defined $jobnode) {
    print STDERR "Returning right away, I should be throwing an exception\n";
    return;
  }
  # jobnode does now become the new context ...
  if ($resource->exists('job/driver/class',$jobnode)) {
    print STDERR "We're still good\n";
    my $driver_class = $resource->findvalue('job/driver/class',$jobnode)->value();
    dprint "using driver class=$driver_class\n";
    $jobdef->{'job_driver'} = $driver_class;
  }
  else {
    print STDERR "I'm lost\n";
    return; # should really be an exception, or better still, I should be looking for what's in the shared section
  }
  $jobdef->{'job_config'} = {};
  if ($resource->exists('job/config/param',$jobnode)) {  
    my $config_nodes = $resource->find('job/config/param',$jobnode);
    if ($config_nodes->isa('XML::XPath::NodeSet')) {
      for my $cf ($config_nodes->get_nodelist()) {
        my $param_name = $resource->findvalue('@name',$cf);
        my $param_value;
        if ($resource->exists('value',$cf)) { 
          my @pv = ();
          my $value_elements = $resource->find('value',$cf); 
          for my $vel ($value_elements->get_nodelist()) { 
            my $vv = $resource->findvalue(".",$vel);
            push @pv,$vv->value();
          }
          $param_value = \@pv;
        }
        else {
          $param_value = $resource->findvalue('.',$cf)->value();
        }
        $jobdef->{'job_config'}->{$param_name} = $param_value;
      }
    }  
  }
  if ($resource->exists('job/resources/resource'),$jobnode) {
		$jobdef->{'job_resources'} = {};
    my $resource_names = $resource->find('job_resources/resource',$jobnode);
    if ($resource_names->isa('XML::XPath::NodeSet')) {
      #print STDERR "I did find ressourcenames\n";
      for my $rn ($resource_names->get_nodelist()) {
        my $rtype  = $resource->findvalue('@type',$rn)->value();
				if (not defined $jobdef->{'job_resources'}->{lc $rtype}) {
          $jobdef->{'job_resources'}->{lc $rtype} = [];
        }
        my $rname = $resource->findvalue(".",$rn)->value();
        #print STDERR "found resourcename: $rname\n";
        push @{$jobdef->{'job_resources'}->{lc $rtype}},$rname;
        #$jobdef->{'job_resources'}->{$rname} = undef;
      }
    }
    else {
      print STDERR "I did not find ressourcenames\n";
    }
  }
  
  use Data::Dumper;

  dprint "flowdef-doc\n";
  dprint Dumper($jobdef);
  
  return $jobdef;
}

sub getFlowRunId {
  my %args = @_;
  my $flowcd = $args{'flowcd'};

  return 5;
}

sub getDBConnectionParameters {
  my %args = @_;
  my $connection_name = $args{'conn_name'};
  my $features = $args{'features'}; 

  my $config = getPMTSysConfig(section=>'db');
  #my $res_uri = $config->{'resource'};
  #my $resource = loadResource(resource=>$res_uri);

  # This should be an XML file
  
  #my $doc = XML::Simple::XMLin($resource);

  use Data::Dumper;

  dprint Dumper($config);
}

sub fileExists {
  my %args = @_;
  my $file = $args{'file'};

  if ( -f $file ) {
    return 1;
  }
  return 0;
}

sub runSysCmd {
  my %args = @_;
  my $cmd = $args{'command'};

  if (evalBoolean(value=>$args{'verbose'})) {
    _log(domain=>"system",level=>"trace",message=>"Running system command: $cmd");
  }
  $cmd = "$cmd 2>&1";
  my $CHANDLE;
  my $returnval;
  open($CHANDLE,"$cmd |") or croak { message=>"Failed to open command $args{'command'}:$!"};
  my @lines = <$CHANDLE>;
  close $CHANDLE;
  my $rc = $?;
  $rc = $rc >> 8;
  @lines = map { chomp; $_; } @lines;
  if (evalBoolean(value=>$args{'logoutput'})) {
     my $domain = $args{'logoutput'}->{'domain'};
     my $level = $args{'logoutput'}->{'level'};
     _log(domain=>$domain,level=>$level,message=>"Output of command $args{command}:",data=>\@lines);
     #for my $line (@lines) {
     #  _log(domain=>$domain,level=>$level,message=>">>> $line");
     #}   
     _log(domain=>$domain,level=>$level,message=>"---------- END OF OUTPUT");
  }
  if (evalBoolean(value=>$args{'verbose'})) {
    _log(domain=>"system",level=>"info",message=>"Exitcode of command = $rc");
  }
  $returnval = {rc=>$rc, output=>\@lines}; 
  return $returnval;
}

1;
