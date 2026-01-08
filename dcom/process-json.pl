use warnings;
use strict;
use utf8;
#use open qw(:std :encoding(UTF-8));
#use Encode qw(decode_utf8);
#@ARGV = map { decode_utf8($_, 1) } @ARGV;

use JSON;
# Data::Dumper makes it easy to see what the JSON returned actually looks like 
# when converted into Perl data structures.
use Data::Dumper;
use MIME::Base64;

my $metais;
my $dcom;
my $data;
my $report;

use Getopt::Long;
GetOptions (
            "metais=s"  => \$metais,
            "dcom=s"  => \$dcom,
            "report=s"  => \$report,
)
or die("Error in arguments!\n");

sub from_file {
    #use open qw(:std :encoding(UTF-8));
    my $file = shift;
    my $hash;
    my $json;
    use File::Path qw(make_path);
    use POSIX 'strftime';
    use File::stat;
    my $datestamp = strftime '%Y-%m-%d', localtime;

    open(FH, '<:encoding(UTF-8)', "$file") or die $!;
    $json = do { local $/; <FH> };

    $hash = decode_json($json);
    close(FH);
    #print Dumper $hash;
    return $hash;
}

sub find_vilige {
    my $v = shift;
}

sub report {
    my $d = shift;
    #print Dumper $d;
    # service .metais.obce[].sluzby[].ci.attributes[].name
    # service .dcom.obce[].sluzby[].nazov_sluzba
    foreach my $obec (@{$d->{'dcom'}->{'obce'}}) {
        print Dumper map { map { $_->{'name'} =~ /Gen_Profil_Nazov/ } @{$_->{'attributes'}} } @{$d->{'metais'}->{'obce'}};
        #print grep { $_->{'name'} = "Gen_Profil_nazov" } @{@{$d->{'metais'}->{'obce'}}->{'attributes'}};
    }
}

$data->{'metais'} = from_file ($metais)->{'metais'};
$data->{'dcom'} = from_file ($dcom)->{'dcom'};
#from_file ($dcom, $data);
#print Dumper $data;

report ($data);

1;