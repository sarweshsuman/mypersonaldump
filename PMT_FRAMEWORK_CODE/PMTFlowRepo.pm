package PMTLock;


use strict;
use Carp;

sub new {
  my $package = shift;
  my $sem = shift;
  my $o = { };
  $o->{'sem'} = $sem;
  return bless $o;
}

sub DESTROY {
  my $self = shift;
  my $sem = $self->{'sem'};
  $sem->op(0,1,0);
}
 
1;

package DBHandle;

use strict;
use Carp;
use Data::Dumper;
use IPC::SysV qw(IPC_PRIVATE S_IRUSR S_IWUSR IPC_CREAT);
use IPC::Semaphore ;

sub getPMTDbLock {
  my $self = shift;
  my $directory = shift;
  my @stats = stat($directory);
  my $inode = @stats[1];
  my $sem = IPC::Semaphore->new($inode,1,S_IRUSR | S_IWUSR );
  if (not $sem) {
    $sem = IPC::Semaphore->new($inode,1,S_IRUSR | S_IWUSR | IPC_CREAT);
    $sem->setall((1));
  }
  $sem->op(0,-1,0);
  return new PMTLock($sem);
}

sub new {
  my $package = shift;
  my %args = @_;
  #print "DBHandle creating with ",Dumper(\%args),"\n";
  my $o = {};
  $o->{'manager'} = $args{'xmlmanager'};
  #print "creating a handle with xmlmanager: $o->{'manager'}\n";
  $o->{'dbenv'} = $args{'dbenv'};
  $o->{'containers'} = {};
  my $c = $args{'containers'};
  for my $k (keys %$c) {
    $o->{'containers'}->{$k} = $c->{$k};
  }
  bless $o;
  $o->{'lock'} = $o->getPMTDbLock($args{'directory'});
  return $o;
}

sub DESTROY {
  my $self = shift;
  my $opencontainers = $self->{'containers'};
  delete $self->{'lock'};
  for my $ckey (keys %$opencontainers) {
   	delete $opencontainers->{$ckey};
  }
  #print "releasing handle\n";
}

sub AUTOLOAD {
  my $self = shift;
  our $AUTOLOAD;
  my @methodcomps = split('::',$AUTOLOAD);
  my $method = pop(@methodcomps);
  my $mgr = $self->{'manager'};
  return $mgr->$method(@_);
}

1;

package PMTFlowRepo;

use PMTUtilities qw(dprint partial getPMTSysConfig);
use Data::Dumper;
use strict;
use Carp;

use Sleepycat::Db;
use Sleepycat::DbXml;
use XML::DOM;
use File::Basename qw(basename dirname);

require Exporter;
our @ISA=qw(Exporter);
our @EXPORT_OK = qw(DBDo removeFlowDef listFlows DBgetJobConfig getJobDefinitions DBinitializeLog DBcloseLog DBlog roleIsEnabled DBgetRunId DBregisterFlowRun retrieveFlowDef closeFlowCurrentRunId postFlowDef flowdefExists isFlowRunning getFlowCurrentRunId);

sub handleDbXMLException {
  croak { message=>"An XML Exception has occurred"};
}

my $DBXMLMANAGER;
my $xquerylibdir;
my $opencontainers;
my $dbenv;
my $initialized;



sub getDBHandle {
  my $dbxmlconfig = getPMTSysConfig(section=>'dbxml');
  my $db_dir;
  my $dbs={}; 
  for my $k (keys $dbxmlconfig) {
    if ($k =~ m/envdir/) {
       $db_dir = $dbxmlconfig->{$k};
    }
    elsif ($k =~ m/^db:/) {
      my $lk = $k;
      $lk =~ s/^db://i;
    
      $dbs->{$lk} = $dbxmlconfig->{$k};
    }
    elsif ($k=~ m/xquerylibdir/i) {
      $xquerylibdir = $dbxmlconfig->{$k};
      if ($xquerylibdir =~ m/\/$/) {
        # all is well
      }
      else {
        $xquerylibdir = "${xquerylibdir}/";
      }
    }
  }

  if (not $dbenv) {
  	$dbenv = new DbEnv(0);
		$dbenv->open($db_dir,Db::DB_INIT_MPOOL,0);
  	$DBXMLMANAGER = new XmlManager($dbenv,DbXml::DBXML_ALLOW_EXTERNAL_ACCESS);
  };
  # open the containers and set the aliases
  my $lopencontainers = {};
  for my $ck (keys %$dbs) {
    #$lopencontainers->{$ck} = $DBXMLMANAGER->openContainer($MAINTRANSACTION,$dbs->{$ck});
    $lopencontainers->{$ck} = $DBXMLMANAGER->openContainer(undef,$dbs->{$ck},0);
    #print "Opened container:",$lopencontainers->{$ck},"\n";
    my $rc = $lopencontainers->{$ck}->addAlias($ck);
    #print "setting alias $ck: $rc\n";
  }
  $initialized = 1;
  #print "Creating a handle with manager $DBXMLMANAGER\n";

  return new DBHandle(directory=>$db_dir,xmlmanager=>$DBXMLMANAGER,dbenv=>$dbenv,containers=>$lopencontainers); 

} # 

sub DBDo {
  my %args = @_;
  my $queries = $args{'queries'};
  if (not defined $queries) {
    croak { message=>"Statements not specified"};
  }
  my $dbhandle;
  if ($args{'dbhandle'}) {
    $dbhandle = $args{'dbhandle'};
  }
  else {
    $dbhandle = getDBHandle();
  }
  my $txn;
  my $ctx = $args{'context'};
  if (not $ctx) {
    $ctx = {};
  }
  if (ref $queries ne 'ARRAY') {
    $queries = [$queries];
  }

  my $qcontext = $dbhandle->createQueryContext();
  $qcontext->setBaseURI('file:///opt/PMT/pmtsys/lib/xquery/');
  if (defined $xquerylibdir) {
    $qcontext->setBaseURI($xquerylibdir);
  }
  for my $ctxk (keys %$ctx) {
    if (defined $ctx->{$ctxk}) {
      #print "setting $ctxk $ctx->{$ctxk}\n";
    	$qcontext->setVariableValue($ctxk,$ctx->{$ctxk});
    }
    else {
      #print "Item $ctxk is not defined\n";
    }
  }

  my @results;
  eval {
  	for my $q (@$queries) {
      # we only want to release the latest results, and therefore ...
      @results = ();
      #print STDERR "Executing query:\n$q->{'statement'}\n";
      my $st;
      my $resultparser;
      my $localcontext;
      if (ref $q eq 'HASH') {
        $st = $q->{'statement'};
        $resultparser = $q->{'resultparser'};
        $localcontext = $q->{'context'};
      }
      else {
        $st = $q;
        $resultparser = undef;
      }
      if (not $localcontext) {
        #print "localcontext is not defined: $localcontext\n";
        $localcontext = {};
      }
      else {
        #print "localcontext is defined: $localcontext\n";      
      }
      #print "localcontext is now: $localcontext\n";
      for my $lc (keys %$localcontext) {
				if (defined $localcontext->{$lc}) {
    			$qcontext->setVariableValue($lc,$localcontext->{$lc});
        }
      }
      
      #if (defined $qcontext) { print "qcontext is defined \n"; } else { print "qcontext is not defined\n"; }
      #print "doing the prepare\n";
    	my $q = $dbhandle->prepare($txn,$st,$qcontext);
      #print "Prepared succeeded\n";
      #if (defined $qcontext) { print "qcontext is defined \n"; } else { print "qcontext is not defined\n"; }
      my $rs = $q->execute($txn,$qcontext);
      #print "I am here now after the execute\n";
      while ($rs->hasNext()) {
        my $buffer;
        $rs->next($buffer);
        push @results,$buffer;
      }
      if (defined $resultparser) {
        @results = $resultparser->(query_results=>\@results);
      }
  	}
  };
  if (my $e = catch XmlException) {
    if (not $args{'dbhandle'}) { print "Cleaning dbhandle locally\n"; undef $dbhandle; }
    croak { message=>'XmlException : '.$e->what() };
  }
  elsif (my $e = catch std::exception) {
    if (not $args{'dbhandle'}) { undef $dbhandle; }
    croak { message=>'std::exception : '.$e->what() };
  }
  elsif ($@) {
    if (not $args{'dbhandle'}) { undef $dbhandle; }
    croak $@;
  }
  #print "I am about to commit in DBDO\n";
  #print "I committed\n";
  
  if (defined $args{'result_parser'}) {
    my $rp=$args{'result_parser'};
    $rp->(context=>$ctx,results=>\@results);
  }
  if (wantarray) {
    return @results;
  }
  elsif (defined wantarray) {
    return \@results;
  }
}


sub roleIsEnabled {
  my %args = @_;
  my $flowcd = $args{'flowcd'};
  my $role=$args{'role'};
  my $queries = [
    {
      statement=>q{ 
        if (exists(collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]/roles/role[@name=$pq_rolename_in]))
        then 1
        else 0
      }
    }
  ];
  my $ctx = { pq_flowname_in=>$flowcd,pq_rolename_in=>$role};
  my $resultparser = sub { my %args = @_; my $results=$args{'results'}; my $lctx=$args{'context'}; $lctx->{'isEnabled'} = $results->[0]; };
  DBDo(dbhandle=>$args{'dbhandle'},queries=>$queries,context=>$ctx,result_parser=>$resultparser,readonly=>1);
  return $ctx->{'isEnabled'};
}

sub getJobConfig {
  my %args = @_;
  my $flowcd = $args{'flowcd'};
  my $role = $args{'role'};

  my $queries = [
    {
    	statement=>q{
      <jobconfig>{
       <system>{ for $i in collection('dbxml:/pmtlog')/status/flow[@status="running" and @name=$pq_flowname_in]/system/* return $i }</system>,
       <strategy dataclass="paramset">{ for $i in collection('dbxml:/pmtlog')/status/flow[@status="running" and @name=$pq_flowname_in]/strategy/* return $i}</strategy>,
       <db_connections>{ for $i in collection('dbxml:/pmtlog')/status/flow[@status="running" and @name=$pq_flowname_in]/db_connections/db_connection return $i }</db_connections>,
       <resources>{ for $i in collection('dbxml:/pmtlog')/status/flow[@status="running" and @name=$pq_flowname_in]/resources/resource return $i }</resources>,
       <role>{ for $i in collection('dbxml:/pmtlog')/status/flow[@status="running" and @name=$pq_flowname_in]/roles/role[@name=$pq_role_in]/* return $i}</role>
      }</jobconfig>
    	}
    }
  ];
  my $context = { pq_flowname_in=>$flowcd,pq_role_in=>$role };
  my $out = {};
  use PMTUtilities qw(partial);
  my $result_parser = partial(sub { my %args = @_; 
                            my $r = $args{'results'}; 
                            my $o = $args{'out'}; 
                            $o->{'result'} = $r->[0]; }, out=>$out );
  DBDo(dbhandle=>$args{'dbhandle'},queries=>$queries, context=>$context,result_parser=>$result_parser,readonly=>1,dedicated_connection=>1);
  return $out->{'result'};
  
}

sub retrieveFlowDef {
  # for this one, we also need to take into account the shared components
  my %args = @_;
  my $flowcd = $args{'flowcd'};
  if (not defined $flowcd) {
    croak { message=>"No flowcd defined for retrieval of flowdefinition" };
  }
  my $options = $args{'options'};
  if (not defined $options) {
    $options = { accept=>'text/xml'};
  }

  my $queries = [
    {
      statement=>q{
       collection('dbxml:/pmtconf')/flow_definitions/flow[@name=$pq_flowcd_in]
      }
    }
  ];
  my $context =  { pq_flowcd_in=>$flowcd };
  my $out = {};
  use PMTUtilities qw(partial);
  my $result_parser = partial(sub { my %args = @_; 
                            my $r = $args{'results'}; 
                            my $o = $args{'out'}; 
                            $o->{'result'} = $r->[0]; }, out=>$out );
  DBDo(dbhandle=>$args{'dbhandle'},queries=>$queries, context=>$context,result_parser=>$result_parser,readonly=>1,dedicated_connection=>1);
  return $out->{'result'};
}

sub removeFlowDef {
  # for this one, we also need to take into account the shared components
  my %args = @_;
  my $flowcd = $args{'flowcd'};
  my $full = $args{'full'};
  if (not defined $flowcd) {
    croak { message=>"No flowcd defined for retrieval of flowdefinition" };
  }

  my $queries = [
    {
      statement=>q{
       delete nodes collection('dbxml:/pmtconf')/flow_definitions/flow[@name=$pq_flowcd_in]
      }
    }
  ];
  if ($full) {
    push @$queries,
    {
      statement=>q{
        delete nodes collection('dbxml:/pmtlog')//flow[@name=$pq_flowcd_in]
      }
    }
  }
  my $context =  { pq_flowcd_in=>$flowcd };
  DBDo(dbhandle=>$args{'dbhandle'},queries=>$queries, context=>$context);
  return;
}

# sub DBgetRunId {
#   my %args = @_;
#   my $flowcd = $args{'flowcd'};
#   if (not defined $flowcd) {
#     croak { message=>"Flowname not specified when asking for new runid" };
#   }
#   my $options = $args{'options'};
#   if (not defined $options) {
#     $options = { create=>1,force=>0 };
#   }
#   my $dbxmlconfig = getPMTSysConfig(section=>'dbxml');
#   my $db = $dbxmlconfig->{'log'};
#   my $db_dir = dirname $db;
#   my $db_file = basename $db;
# 
#   my $dbenv; #= new DbEnv(0);
#   my $txn; #= $mgr->createTransaction();
#   my $runid_to_close;
#   my $new_run_id;
#   my $current_run_id;
#   eval {
#     $dbenv = new DbEnv(0);
# 		$dbenv->open($db_dir,Db::DB_CREATE|Db::DB_INIT_MPOOL|Db::DB_INIT_LOCK|Db::DB_INIT_LOG|Db::DB_INIT_TXN,0);
#     my $mgr = new XmlManager($dbenv);
#     $txn = $mgr->createTransaction();
#   	# check if the db is setup correctly
#   	my $container = $mgr->openContainer($txn,$db_file);
#     my $targetDocument = $container->getDocument($txn,'status');
#     # If it does not exist, meaning the database was not setup correctly, this will throw an exception, in other words, if we're still here ... it means all is well.
#     # Now check if /flowdefinitions exists
#     my $qcontext = $mgr->createQueryContext();
#     $qcontext->setDefaultCollection($db_file);
#     # now check if the flow does allready exist 
#     my $qtext;
#     my $runid_to_close;
#     $qtext = q{fn:collection()/status/flow[@name=$flowcd and @status="running"]/@runid/data(.)};
#     my $q = $mgr->prepare($txn,$qtext,$qcontext);
#     my $rs = $q->execute($txn,$qcontext);
#     my $rsize = $rs->size();
#     #print "rsize is now: $rsize\n";
#     if ($rsize == 1) {
#       my $rs = $rs->next($current_run_id);
#       print "I allready found a record\n";
#       if ($options->{'create'} and $options->{'force'}) {
#         # close the current entry
#         $qtext = q{replace value of node fn:collection()/status/flow[@name=$flowcd" and @status="running" and @runid = $current_run_id]/@status with "closed"};
#         $q = $mgr->prepare($txn,$qtext,$qcontext);
#         $rs = $q->execute($txn,$qcontext);
#         $new_run_id = $current_run_id + 1;
#         $qtext = q{replace value of node fn:collection()/run_id/flow[@name=$flowcd] with $new_run_id};
#         $q = $mgr->prepare($txn,$qtext,$qcontext);
#         $rs = $q->execute($txn,$qcontext);
#         $qtext = q{insert node <flow name=$flowcd status="running" runid=$new_run_id> into fn:collection()/status};
#         $q = $mgr->prepare($txn,$qtext,$qcontext);
#         $rs = $q->execute($txn,$qcontext);
#         my $flowdef = retrieveFlowDef(flowcd=>$flowcd);
#         $qtext = q{insert node <config /> into collection()/status/flow[@name=$flowcd" and @status="running"]};
#         $q = $mgr->prepare($txn,$qtext,$qcontext);
#         $rs = $q->execute($txn,$qcontext);
#         $qtext = q{insert node $flowdef into collection()/status/flow[\@name=\"$flowcd\" and \@status=\"running\"]/config};
#         $q = $mgr->prepare($txn,$qtext,$qcontext);
#         $rs = $q->execute($txn,$qcontext);
#       }
#       elsif ($options->{'create'}) {
#         croak { message=>"Cannot create new runid for flowcd $flowcd while flow is still running" };
#       }
#       else {
#         $new_run_id = $current_run_id;
#       }
#       #$txn->commit();
#     }
#     elsif ($rsize > 1) {
#       $txn->abort();
#       croak { message=>"Corrupted database ? Found multiple active entries for flowcd $flowcd under /status" };
#     }
#     else { # size is 0
#       # Nothing to close
#       print "I did not find a running runid\n";
#       if ($options->{'create'}) {
#         print "creating one\n";
#         $qtext = q{collection()/run_id/flow[\@name=\"$flowcd\"]/data(.)};
#         my $q2 = $mgr->prepare($txn,$qtext,$qcontext);
#         my $rs2 = $q2->execute($txn,$qcontext);
#         my $rss = $rs2->size();
#         if ($rss) {
#           $rs2->next($current_run_id);
#         }
#         else {
#           $current_run_id = 0;
#         }
#         $new_run_id = $current_run_id+1;
# 
#         if ($rss) {
#           $qtext = q{replace value of node collection()/run_id/flow[\@name=\"$flowcd\"] with $new_run_id};
#         }
#         else { 
#         	$qtext = q{insert node <flow name=\"$flowcd\">$new_run_id</flow> into collection()/run_id};
#         }
#         $q2 = $mgr->prepare($txn,$qtext,$qcontext);
#         $rs2 = $q2->execute($txn,$qcontext);
#         $qtext = q{insert node <flow name=\"$flowcd\" status=\"running\" runid=\"$new_run_id\" /> into collection()/status};
#         $q2 = $mgr->prepare($txn,$qtext,$qcontext);
#         $rs2 = $q2->execute($txn,$qcontext);
#         my $flowdef = retrieveFlowDef(flowcd=>$flowcd);
#         $qtext = q{insert node <config /> into collection()/status/flow[\@name=\"$flowcd\" and \@status=\"running\"]};
#         $q = $mgr->prepare($txn,$qtext,$qcontext);
#         $rs = $q->execute($txn,$qcontext);
#         $qtext = q{insert node $flowdef into collection()/status/flow[\@name=\"$flowcd\" and \@status=\"running\"]/config};
#         $q = $mgr->prepare($txn,$qtext,$qcontext);
#         $rs = $q->execute($txn,$qcontext);
#         
#       }
#       else {
#         $txn->abort();
#         croak { message=>"No current runid found for flowcd $flowcd and option create is not specified"};
#       }
#       #$txn->commit();
#     }
#     print "committing\n"; 
#     $txn->commit();
#   };
#   if (my $e = catch XmlException ) {
#      $txn->abort();
#      print "an error occurred during database operations a",$e->what(),"\n";
#   }
#   elsif (my $e = catch std::exception) {
#      $txn->abort();
#      print "an error occurred during database operations a",$e->what(),"\n";
#   }
#   elsif ($@) {
#     $txn->abort();
#     if (ref $@ eq 'HASH') { use Data::Dumper; print "Error occurred: ",Dumper($@),"\n"; }
#     else  { print "error occurred: $@\n"; }
#   }
#   
#   return $new_run_id;
# }


# sub getFlowCurrentRunId {
#   my %args = @_;
#   my $flowcd = $args{'flowcd'};
#   if (not defined $flowcd) {
#     croak { message=>"Flowname not specified when searching current runid" };
#   }
#   my $dbxmlconfig = getPMTSysConfig(section=>'dbxml');
#   my $db = $dbxmlconfig->{'log'};
#   my $db_dir = dirname $db;
#   my $db_file = basename $db;
# 
#   my $dbenv; #= new DbEnv(0);
#   my $txn; #= $mgr->createTransaction();
#   my $runid;
#   eval {
#     $dbenv = new DbEnv(0);
# 		$dbenv->open($db_dir,Db::DB_CREATE|Db::DB_INIT_MPOOL|Db::DB_INIT_LOCK|Db::DB_INIT_LOG|Db::DB_INIT_TXN,0);
#     my $mgr = new XmlManager($dbenv);
#     #$txn = $mgr->createTransaction();
#   	# check if the db is setup correctly
#   	my $container = $mgr->openContainer($txn,$db_file);
#     my $targetDocument = $container->getDocument($txn,'status');
#     # If it does not exist, meaning the database was not setup correctly, this will throw an exception, in other words, if we're still here ... it means all is well.
#     # Now check if /flowdefinitions exists
#     my $qcontext = $mgr->createQueryContext();
#     $qcontext->setDefaultCollection($db_file);
#     # now check if the flow does allready exist 
#     my $qtext = "fn:collection()/status/flow[\@name=\"$flowcd\" and \@status=\"running\"]/\@runid/data(.)";
#     my $q = $mgr->prepare($txn,$qtext,$qcontext);
#     my $rs = $q->execute($txn,$qcontext);
#     my $rsize = $rs->size();
#     #print "rsize is now: $rsize\n";
#     if ($rsize == 1) {
#       my $rs = $rs->next($runid);
#       #$txn->commit();
#     }
#     elsif ($rsize > 1) {
#       #$txn->commit();
#       croak { message=>"Corrupted database ? Found multiple active entries for flowcd $flowcd under /status" };
#     }
#     else {
#       #$txn->commit();
#     }
#   };
#   if (my $e = catch XmlException ) {
#      print "an error occurred during database operations a",$e->what(),"\n";
#   }
#   elsif (my $e = catch std::exception) {
#      print "an error occurred during database operations a",$e->what(),"\n";
#   }
#   elsif ($@) {
#     if (ref $@ eq 'HASH') { use Data::Dumper; print "Error occurred: ",Dumper($@),"\n"; }
#     else  { print "error occurred: $@\n"; }
#   }
#   return $runid;
# }

sub isFlowRunning {
  my %args = @_;
  my $flowcd = $args{'flowcd'};
  if (not defined $flowcd) {
    croak { message=>"Flowname not specified when checking whether it is running" };
  }
  my $queries = [
    { statement=>q{
        if(exists(collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowcd_in and @status="running"]))
        then collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowcd_in and @status="running"]/@runid/data(.)
        else 0
      }
    }
  ];
  my $ctx = {pq_flowcd_in=>$flowcd};
  DBDo(dbhandle=>$args{'dbhandle'},
       queries=>$queries,
			 context=>$ctx,
       readonly=>1,
       result_parser=>sub { my %args=@_; my $results= $args{'results'}; my $ctx = $args{'context'}; $ctx->{'result'}=$results->[0]; }
  );
  #print "DBisflowrunning got result: $ctx->{'result'}\n";
  return $ctx->{'result'};
}

sub flowdefExists {
  my %args = @_;
  my $flowcd = $args{'flowcd'};
  my $queries = [
    { statement=>q{
        if(exists(collection('dbxml:/pmtconf')/flow_definitions/flow[@name=$pq_flowcd_in ]))
        then 1
        else 0
      }
    }
  ];
  my $ctx = {pq_flowcd_in=>$flowcd};
  DBDo(dbhandle=>$args{'dbhandle'},
       queries=>$queries,
			 context=>$ctx,
       readonly=>1,
       result_parser=>sub { my %args=@_; my $results= $args{'results'}; my $ctx = $args{'context'}; $ctx->{'result'}=$results->[0]; }
  );
  #print "DBisflowrunning got result: $ctx->{'result'}\n";
  return $ctx->{'result'};
}

sub listFlows {
  my %args = @_;
  my $ctx = {};
  my $queries = [
     { statement=>q{
         collection('dbxml:/pmtconf')/flow_definitions/flow/@name/data(.)
       }
     }
  ];
  DBDo(dbhandle=>$args{'dbhandle'},
       queries=>$queries,
       readonly=>1,
       context=>$ctx,
       result_parser=>sub { my %args=@_; my $results= $args{'results'}; my $ctx = $args{'context'}; $ctx->{'result'}=$results; }
  );
  return $ctx->{'result'};
}

# sub flowdefExists {
#   my %args = @_;
#   my $flowcd = $args{'flowcd'};
#   if (not defined $flowcd) {
#     croak { message=>"No flowcd specified in checking existence" };
#   }
#   my $dbxmlconfig = getPMTSysConfig(section=>'dbxml');
#   my $db = $dbxmlconfig->{'config'};
#   my $db_dir = dirname $db;
#   my $db_file = basename $db;
# 
#   my $dbenv; #= new DbEnv(0);
#   my $txn; #= $mgr->createTransaction();
#   my $rc;
#   eval {
#     $dbenv = new DbEnv(0);
# 		$dbenv->open($db_dir,Db::DB_CREATE|Db::DB_INIT_MPOOL|Db::DB_INIT_LOCK|Db::DB_INIT_LOG|Db::DB_INIT_TXN,0);
#     my $mgr = new XmlManager($dbenv);
#     $txn = $mgr->createTransaction();
#   	# check if the db is setup correctly
#   	my $container = $mgr->openContainer($txn,$db_file);
#     my $targetDocument = $container->getDocument($txn,'flow_definitions');
#     # If it does not exist, meaning the database was not setup correctly, this will throw an exception, in other words, if we're still here ... it means all is well.
#     # Now check if /flowdefinitions exists
#     my $qcontext = $mgr->createQueryContext();
#     $qcontext->setDefaultCollection($db_file);
#     # now check if the flow does allready exist 
#     my $qtext = "fn:collection()/flow_definitions/flow[\@name=\"$flowcd\"]";
#     my $q = $mgr->prepare($txn,$qtext,$qcontext);
#     my $rs = $q->execute($txn,$qcontext);
#     my $rsize = $rs->size();
#     #print "rsize is now: $rsize\n";
#     if ($rsize == 1) {
#       $rc = 1;
#       $txn->commit();
#     }
#     elsif ($rsize > 1) {
#       $txn->commit();
#       croak { message=>"Corrupted database ? Found multiple entries for flowcd $flowcd" };
#     }
#     else {
#       $txn->commit();
#       $rc = 0;
#     }
#   };
#   if (my $e = catch XmlException ) {
#      print "an error occurred during database operations a",$e->what(),"\n";
#   }
#   elsif (my $e = catch std::exception) {
#      print "an error occurred during database operations a",$e->what(),"\n";
#   }
#   elsif ($@) {
#     if (ref $@ eq 'HASH') { use Data::Dumper; print "Error occurred: ",Dumper($@),"\n"; }
#     else  { print "error occurred: $@\n"; }
#   }
#   return $rc;
# }


sub postFlowDef {
  my %args = @_;
  my $src = $args{'src'};
  my $options = $args{'options'};
  if (not defined $options) {
    $options = {};
  }
  my $name = $args{'name'};
  if (not defined $name) {
    $name = $options->{'flowcd'};
  }
  my $force = $args{'force'};
  #my $fname;
  my ($name,$fname);

  use XML::LibXML;
  my $doc = XML::LibXML->load_xml(string=>$src);
  my $de = $doc->getDocumentElement();
  my $tagname = $de->nodeName;
  #print "Trying to insert element with tagname $tagname\n";
  my $element_to_insert;
  if ($tagname eq 'flow') {
    $element_to_insert = $de;
  } 
  else {
    croak { message=>"Invalid src document structure: Root node needs to be a flow element, not a $tagname"};
  }
  if ($element_to_insert->hasAttribute('name')) {
    $fname = $element_to_insert->getAttribute('name');
  }
  if ( not $name and not $fname) {
    croak { message=>"Flowname is not specified when posting flowdefinitions" };
  }

  if ($fname and not $name) {
    # do nothing
    $name = $fname;
  }
  else {
   $element_to_insert->setAttribute('name',$name);
  }

  my $fe = flowdefExists(flowcd=>$name);
  if ($fe and not $force) {
    croak { message=>"Flow $name allready exists and option force is not specified" };
  }
  elsif ($fe) {
    removeFlowDef(flowcd=>$name);
  }
  
  $element_to_insert->setAttribute('name',$name);
  my $newsrc = $element_to_insert->toString();
  #$newsrc =~ s/>\s+</></gm;
  $newsrc =~ s/{{/{{{{/g;
  $newsrc =~ s/}}/}}}}/g;
  $newsrc =~ s/{!/<![CDATA[{!/g;
  $newsrc =~ s/!}/!}]]>/g;

  my $qtext = "insert node ".$newsrc ." into fn:collection('dbxml:/pmtconf')//flow_definitions";

  my $queries = [
    {
      statement=>$qtext
    }
  ];
  DBDo(dbhandle=>$args{'dbhandle'},
       queries=>$queries
      );
  return $name;
}


# sub DBinitializeLog {
#   my %args = @_;
#   my $flowcd = $args{'flowcd'};
#   my $role = $args{'role'};
#   my $runid = $args{'runid'};
#   ##print "DOin initialize log for flow $flowcd role $role runid $runid\n";
#   my $queries = [
#     {
#       statement=>q{
#         if (not (exists (collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in])))
#         then
#           insert node element flow { attribute name { $pq_flowname_in }} into collection('dbxml:/pmtlog')/logs
#         else ()
#       }
#     }
#     ,{
#        statement=>q{
#          if (not (exists (collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in])))
#          then
#           insert node element role { attribute name {$pq_role_in}} into collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]
#          else ()
#        }
#     }
#     ,{
#        statement=>q{
#          if (not (exists ( collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in]/run[@runid=$pq_runid_in])))
#          then
#            insert node element run { attribute runid {$pq_runid_in }} into collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in]
#          else ()
#        }
#     }
#     ,{
#       statement=>q{
#         
#         if (not (exists ( collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in]/run[@runid=$pq_runid_in]/exec)))
#         then insert node element exec { attribute starttime { fn:current-dateTime() } ,attribute seq {'1'}} into collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in]/run[@runid=$pq_runid_in]
#         else insert node element exec { attribute starttime { fn:current-dateTime() }, attribute seq { max( collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in]/run[@runid=$pq_runid_in]/exec/@seq/data(.) ) + 1 }} 
#           as last into collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in]/run[@runid=$pq_runid_in]
#       }
#     }
#     ,{
#        statement=>q{ max( collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in]/run[@runid=$pq_runid_in]/exec/@seq/data(.) ) }
#     }
#   ];
#   my $ctx = { pq_flowname_in=>$flowcd,pq_role_in=>$role,pq_runid_in=>$runid };
#   my $resultparser = sub { my %args = @_; my $ctx = $args{'context'}; my $r = $args{'results'}; $ctx->{'seq'} = $r->[0]; };
#   DBDo(queries=>$queries,context=>$ctx, result_parser=>$resultparser);
#   return $ctx->{'seq'};
# }
# 
# sub DBcloseLog {
#   my %args = @_;
#   my $flowcd = $args{'flowcd'};
#   my $role = $args{'role'};
#   my $runid = $args{'runid'};
#   my $seq = $args{'seq'};
# 
#   my $queries = [
#     {
#       statement=>q{
#         if (exists ( collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in]/run[@runid=$pq_runid_in]/exec[@seq=$pq_seq_in]))
#         then
#           insert node attribute enddtime { fn:current-dateTime() } into collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in]/run[@runid=$pq_runid_in]/exec[@seq=$pq_seq_in]
#         else ()
#       }
#     }
#   ];
#   my $ctx = {
#     pq_flowname_in=>$flowcd,
#     pq_role_in=>$role,
#     pq_runid_in=>$runid,
#     pq_seq_in=>$seq
#   };
#   DBDo(queries=>$queries,context=>$ctx);
# }

sub getJobDefinitions {
  my %args = @_;
  my $flowcd = $args{'flowcd'};
  my $role = $args{'role'};
  my $runid = $args{'runid'};

  my $queries = [
    {
      statement=>q{
         <jobdef>
         <dbresources></dbresources>
         <role></role>
         </jobdef>
      }
    }
  ];

  use PMTUtilities qw(partial);
  my $ctx = { pq_flowname_in=>$flowcd,pq_role_in=>$role,pq_runid_in=>$runid };
  my $context_out = {};
  my $result_parser = partial(sub { my %args = @_; my $r = $args{'results'}; my $co = $args{'context_out'}; $co->{'value'} = join("\n",@$r); },context_out=>$context_out);
  DBDo(dbhandle=>$args{'dbhandle'},queries=>$queries,result_parser=>$result_parser,context=>$ctx);
  return $context_out->{'value'};
}

sub registerFlowRun {
  my %args = @_;
  my $flowcd = $args{'flowcd'};
  my $options = $args{'options'};
  my $params = $args{'params'};
  if (not defined $flowcd) {
    croak {message=>'Flowcd not specified when registering flow'};
  }
  my $queries = [
    {
      statement=>q{
        if (not (exists(collection('dbxml:/pmtlog')/run_id/flow[@name=$pq_flowname_in])))
        then insert node element flow {attribute name {$pq_flowname_in},0} into collection('dbxml:/pmtlog')/run_id
        else ()
      }
    }
    ,{ 
      statement=>q{
         replace value of node collection('dbxml:/pmtlog')/run_id/flow[@name=$pq_flowname_in] with collection('dbxml:/pmtlog')/run_id/flow[@name=$pq_flowname_in] + 1  
      }
    }
    ,{
      statement=>q{
        if (exists (collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status='running']))
        then (
            replace value of node collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status='running']/@enddtime with current-dateTime(),
						replace value of node collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status='running']/@status with "closed"
            )
        else ()
      }
    }
    ,{
 			statement=>q{
         if (not (exists (collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status='running' and @runid=collection('dbxml:/pmtlog')/run_id/flow[@name=$pq_flowname_in]])))
   			then 
 					insert node element flow { attribute name {$pq_flowname_in } , 
 																		 attribute status {'running'}, 
                                     attribute starttime { fn:current-dateTime() },
                                     attribute enddtime { '0' },
 																		 attribute runid { collection('dbxml:/pmtlog')/run_id/flow[@name=$pq_flowname_in] } } into collection('dbxml:/pmtlog')/status
   				else ()
       }
    }
    ,{
       statement=>q{
   			import module namespace pmt='pmt' at 'pmtfuncs.xquery'; 
 
   			for $n in pmt:build_run_config($pq_flowname_in) 
   			return insert node $n into collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status='running' and @runid=collection('dbxml:/pmtlog')/run_id/flow[@name=$pq_flowname_in]]
 			}
    }
    ,{
      statement=>q{
        for $rd in collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]//resource_ref
        return insert node  if (exists(collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]/resources/resource[@name=$rd/@name/data(.) and @resource_type=$rd/@resource_type/data(.)] ))
         then () else collection('dbxml:/pmtconf')/shared/resources/resource[@name=$rd/@name/data(.) and @resource_type=$rd/@resource_type/data(.)]
        as last into collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]/resources
      }
    }
    ,{
      statement=>q{
        for $rd in collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]//resource_ref
        return if (exists(collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]/resources/resource[@name=$rd/@name/data(.) and @resource_type=$rd/@resource_type/data(.)]))
        then ( insert node attribute referral {'yes'} into $rd, insert node <referral>/resources</referral> into $rd)
        else ()
      }
    }
    #,{
    #  statement=>q{
    #    for $rd in collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]//db_connection_ref
    #    return insert node  if (exists(collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]/db_connections/db_connection[@name=$rd/@name/data(.) ] ))
    #     then () else collection('dbxml:/pmtconf')/shared/db_connections/db_connection[@name=$rd/@name]
    #    as last into collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]/db_connections
    #  }
    #}
    ,{ 
      statement=>q{
        for $rd in fn:distinct-values(collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]//db_connection_ref/@name)
        return insert node collection('dbxml:/pmtconf')/shared/db_connections/db_connection[@name=$rd]
        as last into collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]/db_connections
      }
    }
    ,{
      statement=>q{
        for $rd in collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]//db_connection_ref
        return if (exists(collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running"]/db_connections/db_connection[@name/data(.)=$rd/@name/data(.) ]))
        then ( insert node attribute is_referral {'yes'} into $rd, insert node <referral>/db_connections</referral> into $rd,
               rename node $rd as 'db_connection'
             )
        else ()
      }
    }

  ];
  if (scalar keys %$params) {
    # add a section with all the params to the jobconfig
    my $localstatement = "insert node element cmdparams { attribute dataclass {'paramset'}, ";
    my @keys = keys %$params;
    for  ( my $i = 0; $i< scalar @keys; $i++) {
      $localstatement .= " element param { attribute name {'$keys[$i]'}, '$params->{$keys[$i]}' }";
      if ($i < scalar @keys -1) { $localstatement .= ","; }
    }
    $localstatement .= q!} into collection('dbxml:/pmtlog')/status/flow[@name=$pq_flowname_in and @status="running" and @runid=collection('dbxml:/pmtlog')/run_id/flow[@name=$pq_flowname_in]]!;
    #print "make node for cmdline params:\n $localstatement\n";
    push @$queries, { statement=>$localstatement };
  }

  push @$queries, 
    {
      statement=>q{ collection('dbxml:/pmtlog')/run_id/flow[@name=$pq_flowname_in]/data(.)}
    }
  ;
  print "Doing DBRegisterFlowRun\n";
  my $ctx = {pq_flowname_in=>$flowcd,runid=>undef};
  DBDo(queries=>$queries,context=>$ctx,result_parser=>sub {my %args=@_; my $results=$args{'results'}; my $ctx=$args{'context'}; $ctx->{'runid'} = $results->[0]; });
  print "new runid = ",$ctx->{'runid'},"\n";
  return $ctx->{'runid'};
}
# sub DBlog {
#   my %args = @_;
#   my $flowcd = $args{'flowcd'};
#   my $role = $args{'role'};
#   my $runid = $args{'runid'};
#   my $seq = $args{'seq'};
#   my $message = $args{'message'};
#   my $loglevel = $args{'loglevel'};
#   my $caller = $args{'args'};
#   my $pid = $args{'pid'};
#   my $data = $args{'data'};
#   my $domain = $args{'domain'};
#  
#   if (not defined $flowcd or not defined $role or not defined $runid or not defined $seq) {
#     croak { message=>"Invalid arguments in DBlog"};
#   }
#   if (not $pid) { $pid = "UNKNOWN"; }
#   if (not $caller) {$caller = "UNKNOWN";}
#   if (not $loglevel) { $loglevel = "INFO";}
#   if (not $domain) {$domain = "SYSTEM";}
#   if (not $message) { $message = "Unknown message"; }
#  
#    # I need to insert a message into collection('dbxml:pmtlog')/logs/flow[@name=$flowcd]/role[@name=$role]/run[@runid=$runid]/exec[@seq=$seq]
# # 
#    # First check if the logging context is set up correctly
#   my $queries = [
#     {
#        statement=>q{ 
#          if (exists (collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in]/run[@runid=$pq_runid_in]/exec[@seq=$pq_seq_in]))
#          then 1 else 0
#       }    
#     }
#   ];
#   my $context = { pq_flowname_in=>$flowcd,pq_role_in=>$role,pq_runid_in=>$runid,pq_seq_in=>$seq, pq_loglevel_in=>$loglevel, pq_domain_in=>$domain, pq_caller_in=>$caller, pq_message_in=>$message };
#   my $response_context = {};
#   use PMTUtilities qw(partial);
#   my $result_parser = partial(sub { my %args = @_; my $results = $args{'results'}; my $localcontext=$args{'localcontext'}; $localcontext->{'exists'} = $results->[0]; },localcontext=>$response_context);
#   DBDo(queries=>$queries, context=>$context,result_parser=>$result_parser);
#   if (not $response_context->{'exists'}) {
#     print "Logging context is NOT setup allright\n";
#     croak { message => "Logging context is not OK. Please make sure that initializeLog has run properly" };
#   }
#   $queries = [
#     {
#       statement=>q{
#         insert node element message {
#           attribute loglevel { $pq_loglevel_in },
#           attribute timestamp { fn:current-dateTime() },
#           attribute domain   { $pq_domain_in },
#           attribute caller   { $pq_caller_in },
#           element text       { $pq_message_in }
#         }
#         as last into collection('dbxml:/pmtlog')/logs/flow[@name=$pq_flowname_in]/role[@name=$pq_role_in]/run[@runid=$pq_runid_in]/exec[@seq=$pq_seq_in]
#       }
#     }
#   ];
#   DBDo(queries=>$queries,context=>$context);
# }

# sub terminate {
#   print STDERR "Terminating dbxml\n";
#   if ($initialized) {
#   	#$MAINTRANSACTION->abort();
#   	for my $ckey (keys %$opencontainers) {
#     	print STDERR "deleting $ckey\n";
#     	delete $opencontainers->{$ckey};
#   	}
#   	#undef $MAINTRANSACTION;
#   	undef $DBXMLMANAGER;
#     if (defined $dbenv) {
#       #$dbenv->close($dbenv,0);
#     }
#   	undef $dbenv;
#   }
#   $initialized = 0;
# }

END {
  #print STDERR "Cleaning up dbxml\n";
  undef $DBXMLMANAGER;
  undef $dbenv;
 	#print STDERR "this is the end\n";
}

1;
