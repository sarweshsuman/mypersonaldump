####################################################################################################
#						NFS archiving System - PMT
#	Author : Sarwesh Suman
#
#
####################################################


# <configuration>
	# <archive>
		# <directory name='/data/ADT_archive/HWE_CM/archive/' archive=1 pattern='*.csv' archiveolderthandays='2' archiveifsizemorethan='350mb' tar=1 gzip=1 archivepath='/data/ADT_archive/HWE_CM/archiveRepository'>
	# </archive>
	# <delete>
		# <directory name='/data/ADT_archive/HWE_CM/archivedRepository/' pattern='*.csv' deleteolderthandays='2' deleteifsizemorethan='350mb'>
	# </delete>
# </configuration>
# 
use MyDate;
use FSM_ReadConfiguration;
use Archive::Tar;
use File::stat;
use Time::localtime;
use Getopt::Long;
use POSIX;

#my $obj=Archive::Tar->new;
#Archive::Tar->create_archive('Archive.test.tar',COMPRESS_GZIP,@file);

my $config;

my %parameters=(
					"config=s" => \$config,
				);
					
my $config_obj=FSM_ReadConfiguration->new($config);

exit 1 if ( not defined $config_obj);

my @directories = $config_obj->getArchiveDirList();

foreach my $dir (@directories){
	unless ( -d $dir ){
		print "Dir $dir does not exists skipping..\n";
		next;
	}
	my $archivepath=$config_obj->getArchivePath($dir);
	my $pattern=$config_obj->getArchivePattern($dir);
	my $archiveolderthandays=$config_obj->getArchiveOlderThanDays($dir);
	my $sizelimitofdir=$config_obj->getArchiveSizeLimit($dir);
	my $tarenabled=$config_obj->getTarEnabled($dir);
	my $archivefilename=$config_obj->getArchiveFileName($dir);
	
	my @files_to_archive;
	my $stats={};
	my $tot_size=0;
	#get the list of files from that dir of pattern $pattern
	opendir DIR,$dir or next;
	while(my $f=readdir(DIR)){
		if( -e $f and $f =~ m/$pattern/i){
			push(@files_to_archive,$f);
			$stats->{'file'}->{$f}=stat($dir.'/'.$f);
			$stats->{'file'}->{$f}->{'modifiedTime'}=strftime("%Y%m%d%H%M%S",localtime $stats->{'file'}->{$f}->mtime);
			$tot_size += ($stats->{'file'}->{$f})[7];


		}
	}
	closedir DIR;
	
	my $useDays=0;
	
	if(defined $sizelimitofdir){
		# archiveolderthandays ignored.
		if ($sizelimitofdir =~ /^[\d]+$/){
			# size specified is in bytes
			# do nothing
		}
		elsif($sizelimitofdir =~ /kb$/i){
			# converting to bytes
			$sizelimitofdir=sprintf("%.2f",($sizelimitofdir/1024));
		}		
		elsif($sizelimitofdir =~ /mb$/i){
			# converting to bytes
			#$tot_size=sprintf("%.2f",($tot_size/1024));
			$sizelimitofdir=sprintf("%.2f",($sizelimitofdir/1024)/1024);
		}
		elsif($sizelimitofdir =~ /gb$/i){
			#$tot_size=sprintf("%.2f",(($tot_size/1024)/1024));
			$sizelimitofdir=sprintf("%.2f",(($sizelimitofdir/1024)/1024)/1024);
		}
		elsif($sizelimitofdir =~ /tb$/i){
			#$tot_size=sprintf("%.2f",(($tot_size/1024)/1024)/1024);
			$sizelimitofdir=sprintf("%.2f",((($sizelimitofdir/1024)/1024)/1024)/1024);			
		}
		else{
			print "Size Specified is unknown using archiveolderthandays parameter\n";
			$useDays=1;
		}
		if($useDays == 0){
			my @files=sortInOrderOfUsage($stats);
			if($tot_size > $sizelimitofdir){
				# i need to get old files enough to reduce it  just below sizelimitofdir
				my @files_to_remove=();
				my $tmp_size=0;
				foreach my $f (@files){
					$tmp_size += ($stats->{'file'}->{$f})[7];
					push(@files_to_remove,$f);
					if($tot_size-$tmp_size < $sizelimitofdir ){
						last;
					}
				}
				# using unlink to delete the files
				foreach my $f (@files_to_remove){
					unlink($dir."/".$f);
				}
			}
		}
	}
	if((defined $archiveolderthandays and not defined $sizelimitofdir) or (defined $sizelimitofdir and $useDays == 1)){
			my @files=sortInOrderOfUsage($stats);
			my @files_to_remove=();			
			foreach my $f (@files){			
				if(getDateDifference(strftime("%Y-%m-%d %H:%M:%S",localtime $stats->{'file'}->{$f}->mtime),getDate(0,"%Y-%m-%d %H:%M:%S")) > $archiveolderthandays){
					push(@files_to_remove,$f);
				}
			}
	}
}
sub sortInOrderOfUsage{
	my $file=shift;
	my @files_tmp=();
	my @files_tmp2=();
	my @files;
	foreach my $f (keys %{$file->{'file'}}){
			push(@files_tmp,$file->{'file'}->{$f}->{'modifiedTime'}.','.$f);
	}
	@files_tmp2=sort { $a cmp $b } @files_tmp;
	foreach my $f (@files_tmp2){
		push(@files,$(split($f,','))[1];
	}
	return @files;
}