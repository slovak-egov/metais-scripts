use warnings;
use strict;
use utf8;
#use open qw(:std :encoding(UTF-8));
#use Encode qw(decode_utf8);
#@ARGV = map { decode_utf8($_, 1) } @ARGV;

use REST::Client;
use JSON;
# Data::Dumper makes it easy to see what the JSON returned actually looks like 
# when converted into Perl data structures.
use Data::Dumper;
use MIME::Base64;
use LWP::UserAgent::Determined;
my $ua = LWP::UserAgent::Determined->new;
$ua->agent('Mozilla/5.0, MIRRI scrapper');

my $tokendcom = '';
my $tokenmetais = '';
my $hostmeta = 'https://metais-test.slovensko.sk';
my $src;
my $source;
my $file;
my $cache;
my $proxy;
my $data;
my $limit = undef;

use Getopt::Long;
GetOptions (
            "source=s" => \$source,
            "proxy=s" => \$proxy,
            "file=s"  => \$file,
            "cache=s" => \$cache,
            "limit=s" => \$limit)
or die("Error in arguments!\n");

if ($source =~ /^dcom$/) {
    $src->{'host'} = 'https://www.dcom.sk/';
    $src->{'uri_obce'} = '/IsmSelektor/GetTenants';
    $src->{'uri_sluzby'} = '/IsmSelektor/GetServicesForTenantById?tenantId=OBECID';
    $src->{'uri_sluzba'} = '/IsmSelektor/GetSubmissionsByDomainAndService?domainName=OBEC&serviceCode=KOD';
} elsif ($source =~ /^metais$/) {
    $src->{'host'} = 'https://metais-test.slovensko.sk/';
    $src->{'uri_obce'} = '/api/cmdb/read/cilistfiltered';
    $src->{'data_obce'} = '{"filter":{"type":["PO"]}, "attributes": [{"name": "EA_Profil_PO_typ_osoby", "filterValue": [{ "value": "c_typ_osoby.c1", "equality": "EQUAL"}]}], "perpage":10000, "page":1}';
    $src->{'uri_sluzby'} = '/api/cmdb/read/relations/neighbourswithallrels/OBECID?ciTypes=KS,AS&page=1&perPage=10000&state=DRAFT&lang=sk';
    $src->{'uri_sluzba'} = '/api/cmdb/read/cilistfiltered';
    $src->{'data_sluzba'} = '{"filter":{"type":["KS"]}, "attributes": [{"name": "EA_Profil_KS_typ_ks", "filterValue": [{ "value": "c_typ_ks.3", "equality": "EQUAL"}]}], "perpage":10000, "page":1}';
    #{"name": "EA_Profil_PO_typ_osoby", "filterValue": [{ "value": "c_typ_osoby.c1", "equality": "EQUAL"}]}], "perpage":10000, "page":1}';
}

sub to_file {
    #use open qw(:std :encoding(UTF-8));
    my $hash = shift;
    use File::Path qw(make_path);
    use POSIX 'strftime';
    use File::stat;
    my $datestamp = strftime '%Y-%m-%d', localtime;

    open(FH, '>', "$file.$datestamp") or die $!;
    my $json_output = to_json($hash, {utf8 => 1, pretty => 1, canonical => 1,
                        allow_blessed => 1, convert_blessed => 1, allow_tags => 1});
    print FH $json_output;
    close(FH);
}


# proxy support
if(defined $proxy){
    $ua->proxy(['http', 'https'], $proxy);
}

if (defined $cache) {
    use HTTP::Cache::Transparent;
    HTTP::Cache::Transparent::init( {
        BasePath => $cache,
        Verbose   => 1,
        MaxAge    => 8*24,
        NoUpdate  => 60*60,
    } );
}

#my $headers = {Accept => 'application/json', Authorization => 'Bearer '.$tokendcom };
$src->{'client'} = REST::Client->new({useragent => $ua});
$src->{'client'}->setHost($src->{'host'});
if (!defined $src->{'data_obce'}) {
    $src->{'client'}->GET( $src->{'uri_obce'});
} else {
    $src->{'client'}->POST( $src->{'uri_obce'}, $src->{'data_obce'}, {'Content-Type' => 'application/json'});
}

if ($source eq 'metais') {$data->{$source}->{'obce'} = from_json($src->{'client'}->responseContent())->{'configurationItemSet'};}
else {$data->{$source}->{'obce'} = from_json($src->{'client'}->responseContent());}
#print Dumper $data;
foreach my $obec (@{$data->{$source}->{'obce'}}) {
    next if defined $limit && $limit < 1;
    #print Dumper $obec;
    #print Dumper $obec->{'tenant_id'} . $dcom{'uri_sluzby'};
    my $obecid;
    if ( defined $obec->{'tenant_id'} && $source eq 'dcom' ) {
        #DCOM
        $obecid = $obec->{'tenant_id'};
    } elsif ( defined $obec->{'uuid'} && $source eq 'metais') {
        # METAIS
        $obecid = $obec->{'uuid'};
    } else {
        #print Dumper $obec;
        print "UUID obce nie je dostupne alebo nie je platny zdroj dat";
    }

if (defined $obecid) {    
    $src->{'client'}->GET(
        $src->{'uri_sluzby'} =~ s/OBECID/$obecid/r,
#        $headers
    );
    if ( defined $obec->{'tenant_id'} && $source eq 'dcom' ) {
        $obec->{'sluzby'} = from_json($src->{'client'}->responseContent())->{'services'};
    } elsif ( defined $obec->{'uuid'} && $source eq 'metais') {
        $obec->{'sluzby'} = from_json($src->{'client'}->responseContent())->{'ciWithRels'};
    } else {
        print "UUID obce nie je dostupne alebo nie je platny zdroj dat";
    }
    # print Dumper $obec;
    foreach my $sluzba (@{$obec->{'sluzby'}}){
        next unless defined $sluzba;
        #print "$obec->{'full_name'}: $dcom{'host'}$dcom{'uri_sluzby'}$obec->{'tenant_id'} / $sluzba->{'kod_sluzby'} \n";
        #print $dcom{'uri_sluzba'} =~ s/KOD/$sluzba->{'kod_sluzby'}/r =~ s/OBEC/$obec->{'domain_name'}/r;
        if ( $source eq 'dcom' ) {
            $src->{'client'}->GET(
                $src->{'uri_sluzba'} =~ s/KOD/$sluzba->{'kod_sluzby'}/r =~ s/OBEC/$obec->{'domain_name'}/r,
            );
            $sluzba->{'subs'} = from_json($src->{'client'}->responseContent());
        } elsif ($source eq 'metais') {
            #$src->{'client'}->GET(
            #    $src->{'uri_sluzba'} =~
        } else {

        }
    }
    $limit = $limit - 1 if defined $limit;
    #sleep 5;
}

}

print Dumper $data;

to_file($data) if (defined $file);

1;