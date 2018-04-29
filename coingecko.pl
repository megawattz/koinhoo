#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use IO::Socket;
use JSON;
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

sub Commaize {
    my @rval = ();
    for my $v (@_) {
	my $r = reverse($v);
	$r =~ s/(\d\d\d)/$1,/g;
	$r = reverse($r);
	$r =~ s/^,//;
	$r =~ s/\.,/./;
	push(@rval, $r);
    }
    return @rval;
}

sub FixUp {
    my ($values, $remove) = @_;
    for my $v (@$values) {
	$v =~ s/$remove//g;
	$v = "0" if $v eq "";
    }
    return $values;
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

my $Url = $Config->{Options}->{url};

my $Browser = LWP::UserAgent->new;
$Browser->cookie_jar({});
$Browser->agent("Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36");

my $Request = HTTP::Request->new(GET => $Url);

my $Response = $Browser->request($Request);

my $Columns = ['COIN','PRICE','24H','7D','30D','MKT CAP','LIQUIDITY','DEVELOPER','COMMUNITY','PUBLIC INTEREST','TOTAL'];  # only extract columns with these names (in the table header)

my $Extractor = HTML::TableExtract->new(headers => $Columns);

$Extractor->parse($Response->content);

my @Tables = $Extractor->tables;

my $TableIndex = $Config->{Options}->{table_index};

my $Table = $Tables[$TableIndex];

my $index = 0;

if ($Config->{Options}->{format} eq "flat") 
{
    my $D = $Config->{Options}->{delimiter};
    
    Output(1, sprintf("%8s$D%10s$D%10s$D%10s$D%10s$D%15s$D%15s$D%9s$D%9s$D%9s$D%s$D%s\n", 'Symbol','Price','Change24h','Change7d','Change30d','MarketCap','Liquidity','Developer','Community','PublicInterest','Total','Name'));
    
    foreach my $columns ($Table->rows) {
	my @names = $columns->[0] =~ /(\w.+?)[\r\n]/g;
	next if not $names[1];
	$names[1] =~ s/\s/_/g;
	shift @$columns, 0;
	unshift(@$columns, $names[0]);
	push(@$columns, $names[1]);
	$columns = FixUp($columns, qr/[\s,\$%\*]/);
	eval {
	    my $line = sprintf("%8s$D%10.3f$D%10.2f$D%10.2f$D%10.2f$D%15d$D%15d$D%9d$D%9d$D%9d$D%9d$D%s\n", @$columns);
	    Output(1, $line);
	};
    }
}
elsif ($Config->{Options}->{format} eq "json") 
{
    my $Tree = {};
    my @Fields = ('Price', 'Change24h', 'Change7d', 'Change30d',
		  'MarketCap', 'Liquidity', 'Developer', 'Community',
		  'PublicInterest', 'Total', 'Name');
    
    foreach my $row ($Table->rows) {
	my @names = $row->[0] =~ /(\w.+?)[\r\n]/g;
	next if not $names[1];
	$names[1] =~ s/\s/_/g;
	my $symbol = shift @$row, 0; # remote symbol from row (it will become the key)
	push(@$row, $names[1]); #add fullname of coin at end of attributes
	$row = FixUp($row, qr/[\s,\$%\*]/);
	
	my $attributes = {};
	my $index = 0;
	
	foreach my $field (@Fields) {
	    $attributes->{$field} = $row->[$index++];
	}
	
	$Tree->{$names[0]} = $attributes;
    }

   print to_json($Tree, {pretty => 1});
} 
else
{
    die("Invalid --format= specified (must be json or flat)");
}

# Main code ends here

__DATA__
{
    Options => {
	url => "https://www.coingecko.com/en/coins/all",
	table_index => 0,          # which table on the page are we extracting
	exchange => 'coingecko',
	verbosity => 2,
	delimiter => " ",
	filter => undef,
	format => 'json', # or "flat"
	version => "coingecko.pl version_info: 1.0.0 be80504 perl-docker-additions 04/29/18-18:48:36",
	end => 0
    }
}

