package ReadConfig;
#######################################################################################################################################################
#
#
#						ReadConfig.pm
#       Author                  Version                         Description                                     Input Parameter
#       Sarwesh Suman           1                               module to read server configuration             none
#
#
############################################################################################################################################

BEGIN{
	push(@INC,"/opt/CMT/CMTU_DASHBOARD/lib/XML-Simple-2.20/lib/");	
}
use XML::Simple;
use Data::Dumper;

my $xmlfile;
my $xml;
my $hash;

# $VAR1 = 'configuration';
# $VAR2 = {
          # 'server' => {
                      # 'documentroot' => '/opt/pmt/DailyChecks/nithya/Sar/',
                      # 'file' => {
                                # 'pattern' => '*.pl',
                                # 'access' => 'all'
                              # },
                      # 'name' => 'CMTU_DASHBOARD',
                      # 'directory' => {
                                     # 'execute' => 'all',
                                     # 'pattern' => '*.pl',
                                     # 'access' => 'all',
                                     # 'type' => 'perl'
                                   # },
                      # 'port' => '20300',
                      # 'logging' => 'yes',
                      # 'index' => {
                                 # 'runas' => '',
                                 # 'format' => 'html',
                                 # 'page' => 'index.html'
                               # },
                      # 'log' => {
                               # 'level' => '1',
                               # 'removelogsafter' => '3',
                               # 'overwrite' => 'yes',
                               # 'path' => './'
                             # },
                      # 'alive' => 'yes',
                      # 'denied' => {
                                  # 'mailto' => 'sarwesh.suman.ext@belgacom.be',
                                  # 'mail' => 'yes',
                                  # 'displaypage' => 'a.html'
                                # }
                    # }
        # };
# <configuration>
	# <server name= port= documentroot= logging=yes/no>
		# <index page= format=html/dynamic runas=perl/c/unix>
		# <log path= level=1/2/3 overwrite=yes/no removelogsafter=>
		# </log>
	# </server>
# </configuration>


sub new {
	my $class=shift;
	my $config=shift;
	print "here with config=$config\n";
	$xml=new XML::Simple(KeepRoot=>1);
	$hash=$xml->XMLin($config) or return "error $!";
	print Dumper %$hash;
	bless $hash,$class;
	return $class;
}

sub getServerName {
	my $class=shift;
	if(defined $hash->{'configuration'}->{'server'}->{'name'}){
		if(defined $hash->{'configuration'}->{'server'}->{'alive'} and $hash->{'configuration'}->{'server'}->{'alive'} =~ m/yes/i){
			return $hash->{'configuration'}->{'server'}->{'name'};
		}
		else {
			return "Error : No server alive";
		}
	}
	else {
		my @servers=keys %{$hash->{'configuration'}->{'server'}};
		if($#servers > -1){
			foreach my $s (@servers){
				next if($s =~ m/Dummy/);
				if(defined $hash->{'configuration'}->{'server'}->{$s}->{'alive'} and $hash->{'configuration'}->{'server'}->{$s}->{'alive'} =~ m/yes/i){
					return $s;
				}
			}
			return "Error : No server alive";
		}
		else {
			return "Error : No server defined";		
		}
	}
}
sub getServerPort{
	my $class=shift;
	my $server=shift;
	if(defined $hash->{'configuration'}->{'server'}->{$server}->{'port'})
	{
		return $hash->{'configuration'}->{'server'}->{$server}->{'port'};
	}
	else {
		return "Error : no port defined for $server";
	}
}
sub getServerDocumentRoot{
	my $class=shift;
	my $server=shift;
	if(defined $hash->{'configuration'}->{'server'}->{$server}->{'documentroot'})
	{
		return $hash->{'configuration'}->{'server'}->{$server}->{'documentroot'};
	}
	else {
		return "Error : no documentroot defined for $server";
	}
}
sub getIsLoggingOn{
	my $class=shift;
	my $server=shift;
	if(defined $hash->{'configuration'}->{'server'}->{$server}->{'logging'})
	{
		return $hash->{'configuration'}->{'server'}->{$server}->{'logging'};
	}
	else {
		return "no";
	}
}
sub getIndexPage{
	my $class=shift;
	my $server=shift;
	if(defined $hash->{'configuration'}->{'server'}->{$server}->{'index'}->{page})
	{
		return $hash->{'configuration'}->{'server'}->{$server}->{'index'}->{page};
	}
	else {
		return "Error : no index page defined for $server";
	}
}
sub getIndexPageFormat{
	my $class=shift;
	my $server=shift;
	if(defined $hash->{'configuration'}->{'server'}->{$server}->{'index'}->{format})
	{
		return $hash->{'configuration'}->{'server'}->{$server}->{'index'}->{format};
	}
	else {
		return "Error : no format defined for index page defined for $server";
	}
}
sub getIndexPageRunAs{
	my $class=shift;
	my $server=shift;
	if(defined $hash->{'configuration'}->{'server'}->{$server}->{'index'}->{runas})
	{
		return $hash->{'configuration'}->{'server'}->{$server}->{'index'}->{runas};
	}
	else {
		return "Error : no runas defined for index page defined for $server";
	}	
}
sub getLoggingLevel{
	my $class=shift;
	my $server=shift;
	if(defined $hash->{'configuration'}->{'server'}->{$server}->{'log'}->{level})
	{
		return $hash->{'configuration'}->{'server'}->{$server}->{'log'}->{level};
	}
	else {
		return "Error : no level defined for logging defined for $server";
	}	
}
sub getLoggingPath{
	my $class=shift;
	my $server=shift;
	if(defined $hash->{'configuration'}->{'server'}->{$server}->{'log'}->{path})
	{
		return $hash->{'configuration'}->{'server'}->{$server}->{'log'}->{path};
	}
	else {
		return "Error : no path defined for logging defined for $server";
	}
}
sub getLogOverwrite{
	my $class=shift;
	my $server=shift;
	if(defined $hash->{'configuration'}->{'server'}->{$server}->{'log'}->{overwrite})
	{
		return $hash->{'configuration'}->{'server'}->{$server}->{'log'}->{overwrite};
	}
	else {
		return "Error : no overwrite defined for logging defined for $server";
	}
}
sub getLogRemoveAfter{
	my $class=shift;
	my $server=shift;
	if(defined $hash->{'configuration'}->{'server'}->{$server}->{'log'}->{removelogsafter})
	{
		return $hash->{'configuration'}->{'server'}->{$server}->{'log'}->{removelogsafter};
	}
	else {
		return "Error : no removelogsafter defined for logging defined for $server";
	}
}

sub getFileList{  # will return pattern only
	my $class=shift;
	my $server=shift;
	my %ret_hash=();
	if(defined $hash->{'configuration'}->{'server'}->{'name'}){
		if(defined $hash->{'configuration'}->{'server'}->{'alive'} and $hash->{'configuration'}->{'server'}->{'alive'} =~ m/yes/i){
			#return $hash->{'configuration'}->{'server'}->{'name'};
			return "Error : method not implemented";
		}
		else {
			return "Error : No server alive";
		}
	}
	else {
		if(defined $hash->{'configuration'}->{'server'}->{$server}->{'alive'} and $hash->{'configuration'}->{'server'}->{$server}->{'alive'} =~ m/yes/i){
			#server is alive so 
			# checking if there is only one entry of a file or more than one 
			# if one entry only then file->name will be defined or has to be defined
			# if more than one entry then the file will contain hashes with key as name of the files.
			if(defined $hash->{'configuration'}->{'server'}->{$server}->{file}){
				if(defined $hash->{'configuration'}->{'server'}->{$server}->{file}->{name}){
					#there is only one file mentioned
					$ret_hash{$hash->{'configuration'}->{'server'}->{$server}->{file}->{name}}={
														"return" => $hash->{'configuration'}->{'server'}->{$server}->{file}->{return},
														"command" => $hash->{'configuration'}->{'server'}->{$server}->{file}->{command},
														"returntype" => $hash->{'configuration'}->{'server'}->{$server}->{file}->{returntype},
					};
				}
				else {	
					# there is more than one entry of file
					foreach my $key (keys %{$hash->{'configuration'}->{'server'}->{$server}->{file}}){
						$ret_hash{$key}={
									"return" => $hash->{'configuration'}->{'server'}->{$server}->{file}->{$key}->{return},
									"command" => $hash->{'configuration'}->{'server'}->{$server}->{file}->{$key}->{command},
									"returntype" => $hash->{'configuration'}->{'server'}->{$server}->{file}->{$key}->{returntype},
						};
					}
				}
			}
			# else part not defined because empty file has will be returned.			
		}
		else {
			return "Error : No server alive";
		}		
	}
	return %ret_hash;	
 }
 sub getFilePatternList{
	my $class=shift;
	my $server=shift;
	my @ret_array;
	if(defined $hash->{'configuration'}->{'server'}->{'name'}){
		if(defined $hash->{'configuration'}->{'server'}->{'alive'} and $hash->{'configuration'}->{'server'}->{'alive'} =~ m/yes/i){
			#return $hash->{'configuration'}->{'server'}->{'name'};
			return "Error : method not implemented";
		}
		else {
			return "Error : No server alive";
		}
	}
	else {
		if(defined $hash->{'configuration'}->{'server'}->{$server}->{'alive'} and $hash->{'configuration'}->{'server'}->{$server}->{'alive'} =~ m/yes/i){
			#server is alive so 
			# checking if there is only one entry of a filepattern or more than one 
			# if one entry only then filepattern->name will be defined or has to be defined
			# if more than one entry then the filepattern will contain hashes with key as name pattern of the files.
			if(defined $hash->{'configuration'}->{'server'}->{$server}->{filepattern}){
				if(defined $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{name}){
					#there is only one file mentioned
					push(@ret_array,$hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{name});
				}
				else {	
					# there is more than one entry of file
					foreach my $key (keys %{$hash->{'configuration'}->{'server'}->{$server}->{filepattern}}){
						push(@ret_array,$key);
					}
				}
			}
			# else part not defined because empty file has will be returned.			
		}
		else {
			return "Error : No server alive";
		}		
	}
	return @ret_array;
 }
 sub getFilePatternReturn{
	my $class=shift;
	my $server=shift;
	my $filepattern=shift;
	if(defined $hash->{'configuration'}->{'server'}->{'name'}){
		if(defined $hash->{'configuration'}->{'server'}->{'alive'} and $hash->{'configuration'}->{'server'}->{'alive'} =~ m/yes/i){
			#return $hash->{'configuration'}->{'server'}->{'name'};
			return "Error : method not implemented";
		}
		else {
			return "Error : No server alive";
		}
	}
	else {
		if(defined $hash->{'configuration'}->{'server'}->{$server}->{'alive'} and $hash->{'configuration'}->{'server'}->{$server}->{'alive'} =~ m/yes/i){
			#server is alive so 
			# checking if there is only one entry of a filepattern or more than one 
			# if one entry only then filepattern->name will be defined or has to be defined
			# if more than one entry then the filepattern will contain hashes with key as name pattern of the files.
			if(defined $hash->{'configuration'}->{'server'}->{$server}->{filepattern}){
				if(defined $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{name}){
					#there is only one file mentioned
					if($hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{name} =~ /$filepattern/){
						return $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{return};
					}
				}
				elsif(defined $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{$filepattern}) {	
					# there is more than one entry of file
					return $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{$filepattern}->{return}
				}
				else{
					return "Error : not found";
				}
			}
			# else part not defined because empty file has will be returned.			
		}
		else {
			return "Error : No server alive";
		}		
	}
 }
 sub getFilePatternInvokeScript{
	my $class=shift;
	my $server=shift;
	my $filepattern=shift;
	if(defined $hash->{'configuration'}->{'server'}->{'name'}){
		if(defined $hash->{'configuration'}->{'server'}->{'alive'} and $hash->{'configuration'}->{'server'}->{'alive'} =~ m/yes/i){
			#return $hash->{'configuration'}->{'server'}->{'name'};
			return "Error : method not implemented";
		}
		else {
			return "Error : No server alive";
		}
	}
	else {
		if(defined $hash->{'configuration'}->{'server'}->{$server}->{'alive'} and $hash->{'configuration'}->{'server'}->{$server}->{'alive'} =~ m/yes/i){
			#server is alive so 
			# checking if there is only one entry of a filepattern or more than one 
			# if one entry only then filepattern->name will be defined or has to be defined
			# if more than one entry then the filepattern will contain hashes with key as name pattern of the files.
			if(defined $hash->{'configuration'}->{'server'}->{$server}->{filepattern}){
				if(defined $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{name}){
					#there is only one file mentioned
					if($hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{name} =~ /$filepattern/){
						return $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{invokescript};
					}
				}
				elsif(defined $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{$filepattern}) {	
					# there is more than one entry of file
					return $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{$filepattern}->{invokescript}
				}
				else{
					return "Error : not found";
				}
			}
			# else part not defined because empty file has will be returned.			
		}
		else {
			return "Error : No server alive";
		}		
	}
 }
 sub getReturnTypeOfAPattern{
        my $class=shift;
        my $server=shift;
        my $filepattern=shift;
        if(defined $hash->{'configuration'}->{'server'}->{'name'}){
                if(defined $hash->{'configuration'}->{'server'}->{'alive'} and $hash->{'configuration'}->{'server'}->{'alive'} =~ m/yes/i){
                        #return $hash->{'configuration'}->{'server'}->{'name'};
                        return "Error : method not implemented";
                }
                else {
                        return "Error : No server alive";
                }
        }
        else {
                if(defined $hash->{'configuration'}->{'server'}->{$server}->{'alive'} and $hash->{'configuration'}->{'server'}->{$server}->{'alive'} =~ m/yes/i){
                        #server is alive so
                        # checking if there is only one entry of a filepattern or more than one
                        # if one entry only then filepattern->name will be defined or has to be defined
                        # if more than one entry then the filepattern will contain hashes with key as name pattern of the files.
                        if(defined $hash->{'configuration'}->{'server'}->{$server}->{filepattern}){
                                if(defined $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{name}){
                                        #there is only one file mentioned
                                        if($hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{name} =~ /$filepattern/){
                                                return $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{returntype};
                                        }
                                }
                                elsif(defined $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{$filepattern}) {
                                        # there is more than one entry of file
                                        return $hash->{'configuration'}->{'server'}->{$server}->{filepattern}->{$filepattern}->{returntype}
                                }
                                else{
                                        return "Error : not found";
                                }
                        }
                        # else part not defined because empty file has will be returned.
                }
                else {
                        return "Error : No server alive";
                }
        }
}

# sub getDirectoryList{
	# my $class=shift;
	# my $server=shift;
	# if(defined $hash->{'configuration'}->{'server'}->{'name'}){
		# if(defined $hash->{'configuration'}->{'server'}->{'alive'} and $hash->{'configuration'}->{'server'}->{'alive'} =~ m/yes/i){
			# return $hash->{'configuration'}->{'server'}->{'name'};
		# }
		# else {
			# return "Error : No server alive";
		# }
	# }
	# else {
		# if(defined $hash->{'configuration'}->{'server'}->{$s}->{'alive'} and $hash->{'configuration'}->{'server'}->{$s}->{'alive'} =~ m/yes/i){
			# return $s;
		# }
	# }
# }
# sub getDirectoryAccess{
# }
# sub getDirectoryExecute{
# }
# sub getDirectoryPattern{
# }
# sub getDirectoryType{
# }
# sub getFileList{  # will return pattern only
# }
# sub getFileAccess{
# }
# sub getFileExecute{
# }
# sub getFileType{
# }
# sub getDirectoryFileList{
# }
# sub getDirectoryFileAccess{
# }
# sub getDirectoryFileExecute{
# }
# sub getDirectoryFilePattern{
# }
# sub getDirectoryFileType{
# }
1;
