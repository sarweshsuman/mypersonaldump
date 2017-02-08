############################################################################################################################################
#
#						Server.pl
#	Author			Version				Description					Input Parameter
#	Sarwesh Suman		1				Simple HTTP request response Server  		Server Configuration File
#
#
############################################################################################################################################
BEGIN{
	push(@INC,"/opt/CMT/CMTU_DASHBOARD/lib/HTTP-Daemon-6.01/lib/");
        push(@INC,"/opt/CMT/CMTU_DASHBOARD/lib/HTTP-Message-6.06/lib/");
        push(@INC,"/opt/CMT/CMTU_DASHBOARD/lib/URI-1.60/");
        push(@INC,"/opt/CMT/CMTU_DASHBOARD/lib/HTTP-Date-6.02/lib/");
        push(@INC,"/opt/CMT/CMTU_DASHBOARD/lib/LWP-MediaTypes-6.02/lib");

}
use HTTP::Daemon;
use HTTP::Status;
use MyDate;
use Data::Dumper;

use ReadConfig;
use Getopt::Long;

my $config_file;
my %options=(
				"config=s" => \$config_file,
	);
my $server;
my $date=getDate(0,"%Y-%m-%d");

&GetOptions(%options);

unless(defined $config_file){
	die "No Configuration File entered";
}

my $config=ReadConfig->new($config_file);

$server=$config->getServerName();
my $port=$config->getServerPort($server);
my $documentroot=$config->getServerDocumentRoot($server);

my $loggingon=$config->getIsLoggingOn($server);
my $loggingpath=$config->getLoggingPath($server);
my $logginlevel=$config->getLoggingLevel($server);
my $logoverwrite=$config->getLogOverwrite($server);
my $logremoveafter=$config->getLogRemoveAfter($server);

my $indexpage=$config->getIndexPage($server);
my $indexpageformat=$config->getIndexPageFormat($server);
my $indexpagerunas=$config->getIndexPageRunAs($server);

my %files=$config->getFileList($server);
my @filepattern=$config->getFilePatternList($server);


#print "\nserver=$server\nport=$port\ndocumentroot=$documentroot\nloggingon=$loggingon\nloggingpath=$loggingpath\nlogginlevel=$logginlevel\nlogoverwrite=$logoverwrite\nlogremoveafter=$logremoveafter\nindexpage=$indexpage\nindexpageformat=$indexpageformat\nindexpagerunas=$indexpagerunas\n list of filespattern=@filepattern\n";

#print Dumper(%files);die;


if($loggingon =~ m/(?:Y|YES)/i){
	if($logoverwrite =~ m/(?:Y|YES)/i){
		open LOG1,">$loggingpath./CMTU.Dashboard.Server" if($logginlevel == 1);
		open LOG2,">$loggingpath./CMTU.Dashboard.Server" if($logginlevel == 2);
	}
	elsif($logoverwrite =~ m/(?:N|NO)/i and defined $logremoveafter){
		open LOG1,">>$loggingpath./CMTU.Dashboard.Server.$date" if($logginlevel == 1);
		open LOG2,">>$loggingpath./CMTU.Dashboard.Server.$date" if($logginlevel == 2);
		opendir $LOG,"$loggingpath";
		while(my $file=readdir($LOG)){
			if($file =~ m/CMTU.Dashboard.Server/ and $file !~ /pid/){
				my @temp_arr=split(/\./,$file);
				if((getDateDifference($temp_arr[3]." 00:00:00",$date." 00:00:00"))/(24*60*60) > $logremoveafter){
					unlink $loggingpath."/".$file;
				}
			}
		}
		closedir $LOG;
	}
	else {
		die "No Logging option mentioned";
	}
}


print LOG1 getDate(0,"%H:%M:%S")," \nRegistering to listen to $port port\n" if($logginlevel == 1 and $loggingon =~ m/(?:Y|YES)/i);
print LOG2 getDate(0,"%H:%M:%S")," \nRegistering to listen to $port port\n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);

$serverobj=HTTP::Daemon->new(LocalPort => $port ,);

open PID,">$loggingpath./CMTU.Dashboard.Server.pid";
print PID "$$";
close PID;

if(defined $serverobj){
	print LOG1 getDate(0,"%H:%M:%S")," Successfully Registered to $port, URL will be\n",$serverobj->url,"\n" if($logginlevel == 1 and $loggingon =~ m/(?:Y|YES)/i);
	print LOG2 getDate(0,"%H:%M:%S")," Successfully Registered to $port, URL will be\n",$serverobj->url,"\n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
}
else {
	print LOG1 getDate(0,"%H:%M:%S")," Unable to register port $port, exiting\n" if($logginlevel == 1 and $loggingon =~ m/(?:Y|YES)/i);
	print LOG2 getDate(0,"%H:%M:%S")," Unable to register port $port, exiting\n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
	die "Unable to register port";
}

print LOG2 getDate(0,"%H:%M:%S")," Going to listen to the port now. Waiting for a connection from client \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);

while (my $c = $serverobj->accept) {
   print LOG2 getDate(0,"%H:%M:%S")," Got a connection from client, fetching the request \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
   while (my $r = $c->get_request){
   print LOG1 getDate(0,"%H:%M:%S"),"Got a request, processing..\n" if($logginlevel == 1 and $loggingon =~ m/(?:Y|YES)/i);
   print LOG2 getDate(0,"%H:%M:%S")," Successfully fetched the request object\nMethod of request=",$r->method,"\nURI requested=",$r->uri->path,"\n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
	  if($r->method eq 'GET'){ 
		print "\n Got a method\r\n";
		# 1st thing i do is check if there is a uri mentioned.
		print LOG2 getDate(0,"%H:%M:%S")," Checking the URI Path Now. \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
		
		print $r->uri," PATH=",$r->uri->path;
		if($r->uri->path eq "/") {
			# Need to load Index Page.
			print LOG2 getDate(0,"%H:%M:%S")," Loading Index Page \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
			if($indexpageformat =~ /html/){
				print LOG2 getDate(0,"%H:%M:%S")," Index Page is an HTML \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
				if(-e "$documentroot./$indexpage"){
					print LOG2 getDate(0,"%H:%M:%S")," Index Page successfully found. \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
					$c->send_file_response("$documentroot./$indexpage");
					print LOG2 getDate(0,"%H:%M:%S")," Index Page sent \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
					last;
				}
				else {
					print LOG2 getDate(0,"%H:%M:%S")," Index page Not Found \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
					$c->send_error(RC_NOT_FOUND);
					print LOG2 getDate(0,"%H:%M:%S")," Sending the error response \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
					last;
				}
			}
			elsif($indexpageformat =~ /unix/ or $indexpageformat =~ /perl/) {
				print LOG2 getDate(0,"%H:%M:%S")," perl or unix type index page not implemented yet \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
				$c->send_error(RC_NOT_FOUND);
				print LOG2 getDate(0,"%H:%M:%S")," Sent not found response \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
				last;
				# Not Implemented Yet.
			}
			else {
				$c->send_error(RC_NOT_FOUND);
				last;
			}
		 }
		 else {
			print "\ngot uri as",$r->uri->path,"\n";
				print LOG2 getDate(0,"%H:%M:%S")," Other than Index Page requested \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
				my $uri_path=$r->uri->path;
				if(-e $documentroot."/".$uri_path){
					print "\nexists",$documentroot."/".$uri_path,"\n";
					print LOG2 getDate(0,"%H:%M:%S")," $documentroot$uri_path page exists \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
					my $uri=$r->uri;
					if( $uri =~ m/\?/){  # even if no parameter has to be passed to the script still ? has to be given in the config for this server to identify it as a script
						my @arr=split("/",$uri);
						my ($script,$input_parameter)=split(/\?/,$arr[$#arr]);
						$input_parameter =~ s/\&/ /g;
						print "\n\n Got uri as $uri and arr=@arr \n and \n script=$script and input_parameter=$input_parameter\n";
						if(defined $files{$script}){
							print "\n return = ",$files{$script}->{return},"\n ";
							if($files{$script}->{return} =~ m/(?:yes|y)/i){
								my $comm=$files{$script}->{command};
								my $rettype=$files{$script}->{returntype};
								$comm =~ s/DOCUMENT_ROOT/$documentroot/;
								print "\n",$comm,"\n";	
								my $content=`$comm $input_parameter`;
								print "\nresponse content=$content\n";
								$c->send_response($rettype); # this has to be made dynamic
								#$c->send_response("HELLO WORLD");  -- this didnt work because it was attaching html meta data with it while respoinding.
								print $c $content;
								last;
							}
							elsif($files{$script}->{return} =~ m/(?:no|n)/i){
								my $comm=$files{$script}->{command};
								my $rettype=$files{$script}->{returntype};
								 $comm =~ s/DOCUMENT_ROOT/$documentroot/;
								system("$comm $input_parameter");
								$c->send_response($rettype); # this has to be made dynamic
								print $c "success";
								last;
							}
						}
						print "\nI am here\n";
						foreach my $f (@filepattern){
							if($script =~ m/$f/i){
								if($config->getFilePatternReturn($server,$f) =~ m/(?:yes|y)/i){
									my $invokescript=$config->getFilePatternInvokeScript($server,$f);
									my $rettype=$config->getReturnTypeOfAPattern($server,$f);
									my $content=`$invokescript $documentroot/scripts/$script $input_parameter`; # limitation using hardcoding of scripts.
									$c->send_response($rettype);
									print $c $content;
									last;
								}
								elsif($config->getFilePatternReturn($server,$f) =~ m/(?:no|n)/i){
									my $invokescript=$config->getFilePatternInvokeScript($server,$f);
									my $rettype=$config->getReturnTypeOfAPattern($server,$f);
									system("$invokescript $documentroot/scripts/$script $input_parameter");
									$c->send_response($rettype); # this has to be made dynamic
									print $c "success";
									last;
								}
							}
							$c->send_error(RC_NOT_FOUND);
						}
					}
					else {
						$c->send_file_response("$documentroot"."$uri_path");
					}
					print LOG2 getDate(0,"%H:%M:%S")," response sent \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
				}
				else {
					print LOG2 getDate(0,"%H:%M:%S")," $documentroot$uri_path page not found \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
					$c->send_error(RC_NOT_FOUND);
					print LOG2 getDate(0,"%H:%M:%S")," sent not found response \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
				}
		 }
	  }
	  else {
		  print LOG2 getDate(0,"%H:%M:%S")," Only GET method is implemented yet. \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
		  $c->send_error(RC_FORBIDDEN);
	  }
	  last;
  }
  print LOG1 getDate(0,"%H:%M:%S")," Waiting for a new connection. \n" if($logginlevel == 1 and $loggingon =~ m/(?:Y|YES)/i);
  print LOG2 getDate(0,"%H:%M:%S")," connection closed. Waiting for new connection \n" if($logginlevel == 2 and $loggingon =~ m/(?:Y|YES)/i);
  $c->close;
  undef($c);
  if(getDateDifference(getDate(0,"%Y-%m-%d")." 00:00:00",$date." 00:00:00") > 0){
		$date=getDate(0,"%Y-%m-%d");
		close LOG1 if($logginlevel == 1);
		close LOG2 if($logginlevel == 2);
  		open LOG1,">$loggingpath./CMTU.Dashboard.Server.$date" if($logginlevel == 1);
		open LOG2,">$loggingpath./CMTU.Dashboard.Server.$date" if($logginlevel == 2);
		opendir $LOG,"$loggingpath";
		while(my $file=readdir($LOG)){
			if($file =~ m/CMTU.Dashboard.Server/ and $file !~ /pid/){
				my @temp_arr=split(/\./,$file);
				if((getDateDifference($temp_arr[3]." 00:00:00",$date." 00:00:00"))/(24*60*60) > $logremoveafter){
					unlink $loggingpath."/".$file;
				}
			}
		}
		closedir $LOG;
  }
}


