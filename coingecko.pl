#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
#use IO::File;
#use POSIX;
use IO::Socket;
#use Cwd;
#use JSON;
#use FindBin;
#use Carp;
#use Digest::SHA qw(hmac_sha256_hex hmac_sha512_hex);
#use WWW::Curl::Easy;
#use File::Slurp;
use HTML::TableExtract;
use LWP;

$| = 1; # immediately flush output
$Data::Dumper::Indent = 1;

my $Config =  eval(join('', <DATA>));

sub Output {
  # priorities 0 = no output, 1 = errors, 2 = normal, 3 = extra
  my $priority = shift;
  return if $priority > $Config->{Options}->{verbosity};
  print @_;
}

foreach my $arg (@ARGV) {
  my ($key, $raw_value) = $arg =~ /-+([^=]+)=?[\'\"]?([^\'\"]*)/;
  if (!$key || !defined $Config->{Options}->{$key}) {
    Output(1, sprintf("Unknown option: %s", $key));
    exit -1;
  }
  my $value = eval {$raw_value} || 1;
  print "$key=$value\n";
  $Config->{Options}->{$key} = $value;
}

Output(3, Dumper($Config));

my $Url = $Config->{Options}->{url};

Output(4, sprintf("Request:%s\n", $Url));

my $Browser = LWP::UserAgent->new;
$Browser->cookie_jar({});
$Browser->agent("Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36");

my $Request = HTTP::Request->new(GET => $Url);

my $Response = $Browser->request($Request);

Output(4, "Raw Response:\n", Dumper($Response));

my $Extractor = HTML::TableExtract->new(headers => $Config->{Options}->{columns});

Output(5, "Extractor:".Dumper($Extractor));

$Extractor->parse($Response->content);

my @Tables = $Extractor->tables;

Output(4, "Tables:".Dumper(@Tables));

my $TableIndex = $Config->{Options}->{table_index};

my $Table = $Tables[$TableIndex];

Output(3, "Table:".Dumper($Table));

my $index = 0;

sub Trim {
    my ($values, $remove) = @_;
    for my $v (@$values) {
	$v =~ s/$remove//g;
    }
    return $values;
}

my $Tree = {};

my $D = $Config->{Options}->{delimiter};

Output(1, sprintf("%8s$D%10s$D%10s$D%10s$D%10s$D%15s$D%15s$D%9s$D%9s$D%9s %s\n", 
		  'Symbol','Price','Change24h','Change7d','Change30d','MarketCap','Liquidity','Developer','Community','PublicInterest','Total','Name'));

foreach my $columns ($Table->rows) {
    my @names = $columns->[0] =~ /(\w.+?)[\r\n]/g;
    $names[1] = $names[1] =~ s/./_/g;
    #print "NAMES:",join(':', @names),":\n";
    shift @$columns, 0;
    unshift(@$columns, $names[0]);
    #$names[2] =~ s/\s+/_/g;
    push(@$columns, $names[0]);
    my $columns = Trim($columns, qr/[\s,\$%\*]/);
    my $line = sprintf("%8s$D%10.3f$D%10.2f$D%10.2f$D%10.2f$D%15d$D%15d$D%9d$D%9d$D%9d$D%9d$D%s\n", @$columns);
    Output(1, $line);
}

Output(1, "Done");

# Main code ends here

__DATA__
{
    Options => {
	url => "https://www.coingecko.com/en/coins/all",
	table_index => 0,          # which table on the page are we extracting
	user => 'crypto',
	exchange => 'coingecko',
	password => 'crypto',
	verbosity => 2,
        delimiter => " ",
	filter => undef,
	schema => 0,
	primary => 2,       # which column will contain the primary key
	columns => ['COIN','PRICE','24H','7D','30D','MKT CAP','LIQUIDITY','DEVELOPER','COMMUNITY','PUBLIC INTEREST','TOTAL'],             # only extract columns with these names (in the table header)
	version => "cgo.pl version_info: 1.0.0-75-g3373969 3373969 master 04/13/18-13:38:23",
	end => 0
    }
}

