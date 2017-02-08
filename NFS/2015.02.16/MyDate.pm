package MyDate;

use Exporter 'import';
use POSIX;
use Time::Local;

@EXPORT=qw(getDate compareDate getDateDifference);

sub getDate
{
        my $days_to_go_back;
        my $format = "%Y%m%d";
        if($#_ == 0){
                $days_to_go_back=shift;
        }
        elsif( $#_ == 1){
                $days_to_go_back=shift;
                $format=shift;
        }
        else {
                $days_to_go_back=0;
        }
        my $epoctime = time + (24*60*60*$days_to_go_back);
        my $date=POSIX::strftime("$format",localtime($epoctime));
        return $date;
}
sub compareDate
{
        my $date1=shift;
        my $date2=shift;
        $date1 == $date2 ? return 0 :  $date1 > $date2 ? return -1 : return 1;
}
sub getDateDifference
{
         my $date1=shift;
        my $date2=shift;
        $date1 =~ tr/ /,/;
        my @temp=split(/\,/,$date1);
        my @arr1=split(/\-/,$temp[0]);
        my @arr2=split(/\:/,$temp[1]);
        my $sec1=timelocal($arr2[2],$arr2[1],$arr2[0],$arr1[2],$arr1[1]-1,$arr1[0]);
        $date2=~ tr/ /,/;
        my @temp=split(/\,/,$date2);
        @arr1=split(/\-/,$temp[0]);
        @arr2=split(/\:/,$temp[1]);
        my $sec2=timelocal($arr2[2],$arr2[1],$arr2[0],$arr1[2],$arr1[1]-1,$arr1[0]);
         $sec1>$sec2?return difftime($sec1,$sec2):return difftime($sec2,$sec1);
}

