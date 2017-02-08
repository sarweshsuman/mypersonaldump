package FSM_ReadConfiguration;

####################################################################################################
#						FSM_ReadConfiguration   			   #
#	Author : Sarwesh Suman									   #
#	Date   : 29-07-2014									   #
#	Version: 1.0										   #
####################################################################################################


use Data::Dumper;
use XML::Simple;

my $xmlO;
my $ref;


sub new{
	my $class=shift;
	my $xml_file=shift;
	my $xmlO=new XML::Simple(KeepRoot=>1);
	unless(-e $xml_file){
		print 'Config File Not Found\n';
		return undef;
	}
	$ref=$xmlO->XMLin($xml_file);
	#print Dumper $ref;
	bless $ref,__PACKAGE__;
	return $class;
}
sub getArchiveDirList{
	my $self=shift;
	my @dir=();
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'archive'} eq '1'){
		push(@dir,$ref->{'configuration'}->{'archive'}->{'directory'}->{'name'});
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'}){
		foreach my $key (keys %{$ref->{'configuration'}->{'archive'}->{'directory'}}){
			if($ref->{'configuration'}->{'archive'}->{'directory'}->{$key}->{'archive'} eq '1'){
				push(@dir,$key);
			}
		}
	}
	else{
		return ();
	}
	return @dir;
}
sub getDeleteDirList{
	my $self=shift;
	my @dir=();
	if(defined $ref->{'configuration'}->{'delete'}->{'directory'}->{'name'}){
		push(@dir,$ref->{'configuration'}->{'delete'}->{'directory'}->{'name'});
	}
	elsif(defined $ref->{'configuration'}->{'delete'}->{'directory'}){
		foreach my $key (keys %{$ref->{'configuration'}->{'delete'}->{'directory'}}){
				push(@dir,$key);
		}
	}
	else{
		return ();
	}
	return @dir;
}
sub getArchivePath{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'archivepath'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{'archivepath'};
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'} and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'archivepath'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'archivepath'};
	}
	else{
		return undef;
	}
}
sub getArchivePattern{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'pattern'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{'pattern'};
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'} and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'pattern'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'pattern'};
	}
	else{
		return undef;
	}
}
sub getDeletePattern{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'delete'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'delete'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'delete'}->{'directory'}->{'pattern'}){
		return $ref->{'configuration'}->{'delete'}->{'directory'}->{'pattern'};
	}
	elsif(defined $ref->{'configuration'}->{'delete'}->{'directory'} and defined $ref->{'configuration'}->{'delete'}->{'directory'}->{$dir}->{'pattern'}){
		return $ref->{'configuration'}->{'delete'}->{'directory'}->{$dir}->{'pattern'};
	}
	else{
		return undef;
	}
}
sub getArchiveOlderThanDays{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'archiveolderthandays'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{'archiveolderthandays'};
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'} and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'archiveolderthandays'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'archiveolderthandays'};
	}
	else{
		return undef;
	}
}
sub getDeleteOlderThanDays{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'delete'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'delete'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'delete'}->{'directory'}->{'deleteolderthandays'}){
		return $ref->{'configuration'}->{'delete'}->{'directory'}->{'deleteolderthandays'};
	}
	elsif(defined $ref->{'configuration'}->{'delete'}->{'directory'} and defined $ref->{'configuration'}->{'delete'}->{'directory'}->{$dir}->{'deleteolderthandays'}){
		return $ref->{'configuration'}->{'delete'}->{'directory'}->{$dir}->{'deleteolderthandays'};
	}
	else{
		return undef;
	}
}
sub getArchiveSizeLimit{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'archiveifsizemorethan'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{'archiveifsizemorethan'};
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'} and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'archiveifsizemorethan'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'archiveifsizemorethan'};
	}
	else{
		return undef;
	}
}
sub getDeleteSizeLimit{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'delete'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'delete'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'delete'}->{'directory'}->{'deleteifsizemorethan'}){
		return $ref->{'configuration'}->{'delete'}->{'directory'}->{'deleteifsizemorethan'};
	}
	elsif(defined $ref->{'configuration'}->{'delete'}->{'directory'} and defined $ref->{'configuration'}->{'delete'}->{'directory'}->{$dir}->{'deleteifsizemorethan'}){
		return $ref->{'configuration'}->{'delete'}->{'directory'}->{$dir}->{'deleteifsizemorethan'};
	}
	else{
		return undef;
	}
}
sub getTarEnabled{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'tar'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{'tar'};
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'} and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'tar'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'tar'};
	}
	else{
		return undef;
	}
}
sub getGzipEnabled{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'gzip'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{'gzip'};
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'} and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'gzip'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'gzip'};
	}
	else{
		return undef;
	}
}

sub getArchiveFileName{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'archivefilename'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{'archivefilename'};
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'} and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'archivefilename'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'archivefilename'};
	}
	else{
		return undef;
	}
}
sub getArchiveAtOnce{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'atoncearchive'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{'atoncearchive'};
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'} and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'atoncearchive'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'atoncearchive'};
	}
	else{
		return undef;
	}
}
sub getRepeatForAllSubdir{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'repeatforallsubdir'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{'repeatforallsubdir'};
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'} and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'repeatforallsubdir'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'repeatforallsubdir'};
	}
	else{
		return undef;
	}
}
sub getExcludeList{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'exclude'}){
		my @arr=split /\,/,$ref->{'configuration'}->{'archive'}->{'directory'}->{'exclude'};
		return @arr;
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'} and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'exclude'}){
		my @arr=split /\,/,$ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'exclude'};
		return @arr;
	}
	else{
		return ();
	}
}
sub getRepeatForAllSubdirDelete{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'delete'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'delete'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'delete'}->{'directory'}->{'repeatforallsubdir'}){
		return $ref->{'configuration'}->{'delete'}->{'directory'}->{'repeatforallsubdir'};
	}
	elsif(defined $ref->{'configuration'}->{'delete'}->{'directory'} and defined $ref->{'configuration'}->{'delete'}->{'directory'}->{$dir}->{'repeatforallsubdir'}){
		return $ref->{'configuration'}->{'delete'}->{'directory'}->{$dir}->{'repeatforallsubdir'};
	}
	else{
		return undef;
	}
}
sub getExcludeListDelete{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'delete'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'delete'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'delete'}->{'directory'}->{'exclude'}){
		my @arr=split /\,/,$ref->{'configuration'}->{'delete'}->{'directory'}->{'exclude'};
		return @arr;
	}
	elsif(defined $ref->{'configuration'}->{'delete'}->{'directory'} and defined $ref->{'configuration'}->{'delete'}->{'directory'}->{$dir}->{'exclude'}){
		my @arr=split /\,/,$ref->{'configuration'}->{'delete'}->{'directory'}->{$dir}->{'exclude'};
		return @arr;
	}
	else{
		return ();
	}
}
sub getDeleteAfterArchive{
	my $self=shift;
	my $dir=shift;
	if(defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} and $ref->{'configuration'}->{'archive'}->{'directory'}->{'name'} eq $dir and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{'deleteafterarchive'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{'deleteafterarchive'};
	}
	elsif(defined $ref->{'configuration'}->{'archive'}->{'directory'} and defined $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'deleteafterarchive'}){
		return $ref->{'configuration'}->{'archive'}->{'directory'}->{$dir}->{'deleteafterarchive'};
	}
	else{
		return undef;
	}
}
1;
