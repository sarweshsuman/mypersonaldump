#!/bin/perl
####################################################################################################
#						NFS archiving System - PMT
#	Author : Sarwesh Suman
#
#
####################################################


# <configuration>
	# <archive>
		# <directory name='/data/ADT_archive/HWE_CM/archive/' archive=1 pattern='*.csv' archiveolderthandays='2' archiveifsizemorethan='350mb' tar=1 gzip=1 archivepath='/data/ADT_archive/HWE_CM/archiveRepository'>
		# <directory name='/data/ADT_archive/' repeatforallsubdir='1' pattern='.*' archiveolderthandays='2' archiveifsizemorethan='350mb' tar=1 gzip=1 archivepath='/data/ADT_archive/HWE_CM/archiveRepository'>
	# </archive>
	# <delete>
		# <directory name='/data/ADT_archive/HWE_CM/archivedRepository/' pattern='*.csv' deleteolderthandays='2' deleteifsizemorethan='350mb'>
		# 
	# </delete>
# </configuration>
# 
BEGIN{
	push(@INC,"/home/pmtd/NFS");
};

use MyDate;
use FSM_ReadConfiguration;
use Archive::Tar;
use File::stat;
#use Time::localtime;
use Getopt::Long;
use POSIX (strftime);
use Data::Dumper;

my $logDir='/opt/PMT/logs';

my $logname='FSM_log';

our $WRITELOG;

open $WRITELOG ,">>$logDir/$logname.".getDate(0,'%Y%m%d');

sub logg{
	my $text=shift;
	my $tmstmp=getDate(0,'%Y-%m-%d %H:%M:%S');
	print $WRITELOG "$tmstmp\t$text\n";
}


logg "----------Starting New Run--------------";
#my $obj=Archive::Tar->new;
#Archive::Tar->create_archive('Archive.test.tar',COMPRESS_GZIP,@file);

my $config;

my %parameters=(
					"config=s" => \$config,
				);
					
&GetOptions(%parameters);

my $config_obj=FSM_ReadConfiguration->new($config);

exit 1 if ( not defined $config_obj);

logg "config File received $config";

our @directories = $config_obj->getArchiveDirList();

logg " ".($#directories+1)." directories defined in Config For Archiving";

logg "Starting with Archiving";

my $subdiroptions={};

foreach my $dir (@directories){
	unless ( -d $dir ){
		logg "$dir does not exists, skipping";
		next;
	}
	logg "Processing [Archiving] $dir";

		my $archivepath;
		my $pattern;
		my $archiveolderthandays;
		my $sizelimitofdir;
		my $tarenabled;
		my $archivefilename;
		my $archiveatonce;
	
	if(not defined $subdiroptions->{$dir}){
		$archivepath=$config_obj->getArchivePath($dir);
		$pattern=$config_obj->getArchivePattern($dir);
		$archiveolderthandays=$config_obj->getArchiveOlderThanDays($dir);
		$sizelimitofdir=$config_obj->getArchiveSizeLimit($dir);
		$tarenabled=$config_obj->getTarEnabled($dir);
		$archivefilename=$config_obj->getArchiveFileName($dir);
		$archiveatonce=$config_obj->getArchiveAtOnce($dir);
	}
	else {
		logg "Will use configuration from parent dir defined in $config for $dir";

		$archivepath=$subdiroptions->{$dir}->{archivepath};
		$pattern=$subdiroptions->{$dir}->{pattern};
		$archiveolderthandays=$subdiroptions->{$dir}->{archiveolderthandays};
		$sizelimitofdir=$subdiroptions->{$dir}->{sizelimitofdir};
		$tarenabled=$subdiroptions->{$dir}->{tarenabled};
		$archivefilename=$subdiroptions->{$dir}->{archivefilename};
		$archiveatonce=$subdiroptions->{$dir}->{archiveatonce};
	}

	my $repeatforallsubdir=$config_obj->getRepeatForAllSubdir($dir);
	
	if(defined $repeatforallsubdir and $repeatforallsubdir eq '1' ){
		logg "Repeat For all Sub Dir option enabled ";
		findAndAddSubDir($dir,$subdiroptions,$archivepath,$pattern,$archiveolderthandays,$sizelimitofdir,$tarenabled,$archivefilename,$archiveatonce);
		logg "Added SubDirectories so now processing for ".($#directories+1)." directories";
	}
	#print "\nprinting dirs @directories\n";
	if(not defined $archiveatonce){
		$archiveatonce=100;	
	}
	if(not defined $archivefilename){
		$archivefilename='PMT.plugin.archive';	# PMT.plugin.archive.20140727.0.tar
	}
	print $archivepath;
	my @files_to_archive;
	my $stats={};
	my $tot_size=0;
	#get the list of files from that dir of pattern $pattern
	opendir DIR,$dir or next;
	while(my $f=readdir(DIR)){
		if( -e $dir.'/'.$f and $f =~ m/$pattern/i and (! -d $dir.'/'.$f )){
			push(@files_to_archive,$f);
			$stats->{'file'}->{$f}->{'stat'}=stat($dir.'/'.$f);
			$stats->{'file'}->{$f}->{'modifiedTime'}=strftime("%Y%m%d%H%M%S",localtime($stats->{'file'}->{$f}->{'stat'}->mtime));
			#print $stats->{'file'}->{$f}->{'modifiedTime'},"\n",${$stats->{'file'}->{$f}->{'stat'}}[7],"\n";
			$tot_size += ${$stats->{'file'}->{$f}->{'stat'}}[7];
		}
	}
	closedir DIR;
	logg "Total Size of $dir in bytes $tot_size";
	my $useDays=0;
	logg "Size Limit Defined in config $sizelimitofdir";
	if(defined $sizelimitofdir){
		# archiveolderthandays ignored.
		if ($sizelimitofdir =~ /^[\d]+$/){
			# size specified is in bytes
			# do nothing
		}
		elsif($sizelimitofdir =~ /kb$/i){
			# converting to bytes
			$sizelimitofdir=sprintf("%.2f",($sizelimitofdir*1024));
		}		
		elsif($sizelimitofdir =~ /mb$/i){
			# converting to bytes
			#$tot_size=sprintf("%.2f",($tot_size/1024));
			$sizelimitofdir=sprintf("%.2f",$sizelimitofdir*1024*1024);
		}
		elsif($sizelimitofdir =~ /gb$/i){
			#$tot_size=sprintf("%.2f",(($tot_size/1024)/1024));
			$sizelimitofdir=sprintf("%.2f",$sizelimitofdir*1024*1024*1024);
		}
		elsif($sizelimitofdir =~ /tb$/i){
			#$tot_size=sprintf("%.2f",(($tot_size/1024)/1024)/1024);
			$sizelimitofdir=sprintf("%.2f",$sizelimitofdir*1024*1024*1024*1024);			
		}
		else{
			logg "Size Specified is unknown using archiveolderthandays parameter";
			$useDays=1;
		}
		logg "Size Limit of Dir converted to $sizelimitofdir";
		if($useDays == 0){
			my @files=sortInOrderOfUsage($stats);
			#print "@files\n";
			if($tot_size > $sizelimitofdir){
				# i need to get old files enough to reduce it  just below sizelimitofdir
				my @files_to_remove=();
				my $tmp_size=0;
				foreach my $f (@files){
					$tmp_size += ${$stats->{'file'}->{$f}->{'stat'}}[7];
					#print "tmp=",$tmp_size," total_size = ",$tot_size-$tmp_size ," size to go belo $sizelimitofdir\n";
					push(@files_to_remove,$dir."/".$f);
					if($tot_size-$tmp_size < $sizelimitofdir ){
						last;
					}
				}
				logg "Total Files Got [Archive] ".($#files_to_remove+1);
				# using unlink to delete the files
				#foreach my $f (@files_to_remove){
					#unlink($dir."/".$f);
				#}
				unless( -d $archivepath ){
					my $ret=system("mkdir -p $archivepath");
					if($ret == 1 ){
						logg "Error creating archive path $archivepath";
					}
				}
				if(defined $tarenabled and $tarenabled eq '1')
				{
					my $counter;
					my $date=getDate(0,"%Y%m%d");
					$counter=getArchiveSerialNumber($date,$archivepath,$archivefilename);
					my @files_at_once=();
					my $i=0;
					my $j=1;
					while($i<=$#files_to_remove){
						push(@files_at_once,$files_to_remove[$i]);
						$j++;
						if($j==$archiveatonce){
							Archive::Tar->create_archive($archivepath."/$archivefilename.$date.$counter.tar",COMPRESS_GZIP,@files_at_once);
							$j=1;	
							@files_at_once=();
							$counter++;
						}
					$i++;
					}
					Archive::Tar->create_archive($archivepath."/$archivefilename.$date.$counter.tar",COMPRESS_GZIP,@files_at_once) unless ($#files_at_once == -1 );
					foreach my $f (@files_to_remove){
						#rint "Removing file $f\n";
						unlink($f);
					}
				}
				elsif(not defined $tarenabled or $tarenabled eq '0' ){
					foreach my $f (@files_to_remove){
						system("mv $f $archivepath");
					}
				}
			}
		}
	}
	if((defined $archiveolderthandays and not defined $sizelimitofdir) or (defined $sizelimitofdir and $useDays == 1)){
			my @files=sortInOrderOfUsage($stats);
			#print "@files\n";
			my @files_to_remove=();			
			#print "$archiveolderthandays\n";
			foreach my $f (@files){			
				my $diff=getDateDifference(strftime("%Y-%m-%d %H:%M:%S",localtime $stats->{'file'}->{$f}->{'stat'}->mtime),getDate(0,"%Y-%m-%d %H:%M:%S")) ;
				#print "Got diff $diff \n";
				if( $diff > $archiveolderthandays*60*60*24){
					#print $f,"\n";	
					push(@files_to_remove,$dir."/".$f);
				}
			}
				logg "Total Files Got [Archive] ".($#files_to_remove+1);
				unless( -d $archivepath ){
					my $ret=system("mkdir -p $archivepath");
					if($ret == 1 ){
						logg "Error creating archive path $archivepath";
					}
				}
				if(defined $tarenabled and $tarenabled eq '1')
				{
					my $counter;
					my $date=getDate(0,"%Y%m%d");
					$counter=getArchiveSerialNumber($date,$archivepath,$archivefilename);
					my @files_at_once=();
					my $i=0;
					my $j=1;
					while($i<=$#files_to_remove){
						push(@files_at_once,$files_to_remove[$i]);
						$j++;
						if($j==$archiveatonce){
							Archive::Tar->create_archive($archivepath."/$archivefilename.$date.$counter.tar",COMPRESS_GZIP,@files_at_once);
							$j=1;	
							@files_at_once=();
							$counter++;
						}
					$i++;
					}
					Archive::Tar->create_archive($archivepath."/$archivefilename.$date.$counter.tar",COMPRESS_GZIP,@files_at_once) unless ($#files_at_once == -1 );
					foreach my $f (@files_to_remove){
						#print "Removing file $f\n";
						unlink($f);
					}
				}
				elsif(not defined $tarenabled or $tarenabled eq '0' ){
					foreach my $f (@files_to_remove){
						system("mv $f $archivepath");
					}
				}
	}
	logg "Processing [Archive] Complete for $dir";
}
# Deletion Part

@directories = $config_obj->getDeleteDirList();

logg " ";

logg " ".($#directories+1)." Dir for Deletion Processing";

$subdiroptions={};

foreach my $dir (@directories){
	unless ( -d $dir ){
		print "Dir $dir does not exists skipping..\n";
		next;
	}
	logg "Processing [Deletion] $dir ";


 my $pattern;
 my $deleteolderthandays;
 my $sizelimitofdir;
	
	if(not defined $subdiroptions->{$dir}){
		$pattern=$config_obj->getDeletePattern($dir);
		$deleteolderthandays=$config_obj->getDeleteOlderThanDays($dir);
		$sizelimitofdir=$config_obj->getDeleteSizeLimit($dir);
	}
	else {
		$pattern=$subdiroptions->{$dir}->{pattern};
		$deleteolderthandays=$subdiroptions->{$dir}->{deleteolderthandays};
		$sizelimitofdir=$subdiroptions->{$dir}->{sizelimitofdir};
	}

	my $repeatforallsubdir=$config_obj->getRepeatForAllSubdir($dir);
	
	if(defined $repeatforallsubdir and $repeatforallsubdir eq '1' ){
		logg "[Delete] Repeat option enabled";
		findAndAddSubDirForDelete($dir,$subdiroptions,$pattern,$deleteolderthandays,$sizelimitofdir);
		logg "[Delete] Added SubDirectories so now processing for ".($#directories+1)." directories";
	}
	my @files_to_delete;
	my $stats={};
	my $tot_size=0;
	#get the list of files from that dir of pattern $pattern
	opendir DIR,$dir or next;
	while(my $f=readdir(DIR)){
		if( -e $dir.'/'.$f and $f =~ m/$pattern/i and (! -d $dir.'/'.$f )){
			push(@files_to_delete,$f);
			$stats->{'file'}->{$f}->{'stat'}=stat($dir.'/'.$f);
			$stats->{'file'}->{$f}->{'modifiedTime'}=strftime("%Y%m%d%H%M%S",localtime($stats->{'file'}->{$f}->{'stat'}->mtime));
			#print $stats->{'file'}->{$f}->{'modifiedTime'},"\n",${$stats->{'file'}->{$f}->{'stat'}}[7],"\n";
			$tot_size += ${$stats->{'file'}->{$f}->{'stat'}}[7];
		}
	}
	closedir DIR;
	logg "Total Size of $dir in bytes $tot_size";	
	my $useDays=0;
	logg "Size limit of dir $sizelimitofdir";
	if(defined $sizelimitofdir){
		# deleteolderthandays ignored.
		if ($sizelimitofdir =~ /^[\d]+$/){
			# size specified is in bytes
			# do nothing
		}
		elsif($sizelimitofdir =~ /kb$/i){
			# converting to bytes
			$sizelimitofdir=sprintf("%.2f",($sizelimitofdir*1024));
		}		
		elsif($sizelimitofdir =~ /mb$/i){
			# converting to bytes
			#$tot_size=sprintf("%.2f",($tot_size/1024));
			$sizelimitofdir=sprintf("%.2f",$sizelimitofdir*1024*1024);
		}
		elsif($sizelimitofdir =~ /gb$/i){
			#$tot_size=sprintf("%.2f",(($tot_size/1024)/1024));
			$sizelimitofdir=sprintf("%.2f",$sizelimitofdir*1024*1024*1024);
		}
		elsif($sizelimitofdir =~ /tb$/i){
			#$tot_size=sprintf("%.2f",(($tot_size/1024)/1024)/1024);
			$sizelimitofdir=sprintf("%.2f",$sizelimitofdir*1024*1024*1024*1024);			
		}
		else{
			logg "Size Specified is unknown using deleteolderthandays parameter";
			$useDays=1;
		}
		logg "Size Limit of Dir after converstion $sizelimitofdir";
		if($useDays == 0){
			my @files=sortInOrderOfUsage($stats);
			#print "@files\n";
			if($tot_size > $sizelimitofdir){
				# i need to get old files enough to reduce it  just below sizelimitofdir
				my @files_to_remove=();
				my $tmp_size=0;
				foreach my $f (@files){
					$tmp_size += ${$stats->{'file'}->{$f}->{'stat'}}[7];
					#print "tmp=",$tmp_size," total_size = ",$tot_size-$tmp_size ," size to go belo $sizelimitofdir\n";
					push(@files_to_remove,$dir."/".$f);
					if($tot_size-$tmp_size < $sizelimitofdir ){
						last;
					}
				}
				logg "Total files to remove ".($#files_to_remove+1);
				# using unlink to delete the files
				#print "@files_to_remove";
				foreach my $f (@files_to_remove){
					unlink($f);
				}
			}
		}
	}
	if((defined $deleteolderthandays and not defined $sizelimitofdir) or (defined $sizelimitofdir and $useDays == 1)){
			my @files=sortInOrderOfUsage($stats);
			#print "@files\n";
			my @files_to_remove=();			
			#print "$deleteolderthandays\n";
			foreach my $f (@files){			
				my $diff=getDateDifference(strftime("%Y-%m-%d %H:%M:%S",localtime $stats->{'file'}->{$f}->{'stat'}->mtime),getDate(0,"%Y-%m-%d %H:%M:%S")) ;
				#print "Got diff $diff \n";
				if( $diff > $deleteolderthandays*60*60*24){
					#print $f,"\n";	
					push(@files_to_remove,$dir."/".$f);
				}
			}
			logg "Total Files to remove  ".($#files_to_remove+1);
					foreach my $f (@files_to_remove){
						unlink($f);
					}
	}
	logg "Processing [Deletion] complete for $dir";
}

logg "Processing Complete";

sub sortInOrderOfUsage{
	my $file=shift;
	my @files_tmp=();
	my @files_tmp2=();
	my @files=();
	foreach my $f (keys %{$file->{'file'}}){
			#print "\nIn Sort processing file $f";
			push(@files_tmp,$file->{'file'}->{$f}->{'modifiedTime'}.','.$f);
	}
	#print "@files_tmp";
	@files_tmp2=sort { $a cmp $b } @files_tmp;
	#print "\n@files_tmp2";
	foreach my $f (@files_tmp2){
		#print $f,"\n";
		my @f_tmp=split(",",$f);
		#print $f_tmp[1];
		push(@files,$f_tmp[1]);
	}
	#print "filenames=@files";
	return @files;
}
sub getArchiveSerialNumber{
	#gets the serial number if various archive is being made
	my $date=shift;
	my $dir=shift;
	my $achivename=shift;
	my @files=();
	my @files_2=();
	my $counter;
	opendir DIR,$dir or return undef;
	while (my $f=readdir(DIR)){
		if($f =~ m/$date/ and $f =~ /$archivename/i){
			push(@files,$f);
		}	
	}
	closedir DIR;
	print "Got Files @files\n";
	if($#files == -1){
		return 0;
	}
	@files_2=sort { $a cmp $b } @files;
	my @file_sep_tmp=split(/\./,$files_2[$#files_2]);
	$counter=$file_sep_tmp[$#file_sep_tmp-1];
	return $counter+1;
}
sub findAndAddSubDir{
	my $dir = shift;
	my $subdiroptions=shift;
	my $archivepath=shift;
	my $pattern=shift;
	my $archiveolderthandays=shift;
	my $sizelimitofdir=shift;
	my $tarenabled=shift;
	my $archivefilename=shift;
	my $archiveatonce=shift;
	my @callagainDir=();
	#print "\nGot Dir $dir\n";
	opendir $DIR,$dir or return undef;
	while(my $d=readdir($DIR)){
		if( -d $dir.'/'.$d  and $d ne '.' and $d ne '..' ){
			#print "Pushing $dir/$d ";
			push(@directories,$dir.'/'.$d);
			push(@callagainDir,$dir.'/'.$d);
			$subdiroptions->{$dir.'/'.$d}->{enabled}=1;
			$subdiroptions->{$dir.'/'.$d}->{archivepath}=$archivepath;
			$subdiroptions->{$dir.'/'.$d}->{pattern}=$pattern;
			$subdiroptions->{$dir.'/'.$d}->{archiveolderthandays}=$archiveolderthandays;
			$subdiroptions->{$dir.'/'.$d}->{sizelimitofdir}=$sizelimitofdir;
			$subdiroptions->{$dir.'/'.$d}->{tarenabled}=$tarenabled;
			$subdiroptions->{$dir.'/'.$d}->{archivefilename}=$archivefilename;
			$subdiroptions->{$dir.'/'.$d}->{archiveatonce}=$archiveatonce;
		}
	}
	closedir $DIR;	
	foreach my $d (@callagainDir){
		#print "calling for $d\n";
		findAndAddSubDir($d,$subdiroptions,$archivepath,$pattern,$archiveolderthandays,$sizelimitofdir,$tarenabled,$archivefilename,$archiveatonce);
		#print "here done for subdir of $d\n";
	}
}
sub findAndAddSubDirForDelete{
	my $dir = shift;
	my $subdiroptions=shift;
	my $pattern=shift;
	my $deleteolderthandays=shift;
	my $sizelimitofdir=shift;
	my @callagainDir=();
	#print "\nGot Dir $dir\n";
	opendir $DIR,$dir or return undef;
	while(my $d=readdir($DIR)){
		if( -d $dir.'/'.$d  and $d ne '.' and $d ne '..' ){
			#print "Pushing $dir/$d ";
			push(@directories,$dir.'/'.$d);
			push(@callagainDir,$dir.'/'.$d);
			$subdiroptions->{$dir.'/'.$d}->{enabled}=1;
			$subdiroptions->{$dir.'/'.$d}->{deleteolderthandays}=$deleteolderthandays;
			$subdiroptions->{$dir.'/'.$d}->{pattern}=$pattern;
			$subdiroptions->{$dir.'/'.$d}->{sizelimitofdir}=$sizelimitofdir;
		}
	}
	closedir $DIR;	
	foreach my $d (@callagainDir){
		#print "calling for $d\n";
		findAndAddSubDir($d,$subdiroptions,$pattern,$deleteolderthandays,$sizelimitofdir);
		#print "here done for subdir of $d\n";
	}
}

