#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use IO::Socket;
use HTML::TableExtract;
use LWP::Simple;
use JSON;

$| = 1; # immediately flush output
$Data::Dumper::Indent = 1;

my $Config =  eval(join('', <DATA>));

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
	$v =~ s/\?/0/g;
	$v =~ s/LowVol/0/g;
    }
    return $values;
}

sub OverrideConfigWithCommandLineOptions {
    # Cheapo command line argument processing --option=value,value,value
    foreach my $arg (@ARGV) {
	my ($key, $value) = $arg =~ /-+([^=]+)=?[\'\"]?([^\'\"]*)/;
	if (!$key || !defined $Config->{Options}->{$key}) {
	    die(sprintf("Unknown option: %s", $key));
	}
	$value = "1" if !$value; # key without a value just means "turn me on"
	if ($value =~ ',') {
	    my @values = split(/[,]/, $value);
	    $value = \@values;
	}
	$Config->{Options}->{$key} = $value;
    }
}

sub Main {
    OverrideConfigWithCommandLineOptions();
    
    my $Extractor = HTML::TableExtract->new(headers => ['Symbol','Market Cap','Price','Circulating Supply','Volume','1h','24h','7d']);

    $Extractor->parse(get($Config->{Options}->{url}));
    
    my @Tables = $Extractor->tables;
    
    my $Table = $Tables[$Config->{Options}->{table_index}];
    my $index = 0;

    # not configurable because they are dependent on the website
    my @Fields = qw/Symbol MarketCap Price Supply Volume Change1h Change24h Change7d/;

    if ($Config->{Options}->{format} eq "flat") 
    {
	print sprintf("%-8s %15s %12s %20s %15s %10s %10s %10s\n", qw/Symbol MarketCap Price Supply Volume Change1h Change24h Change7d/);
	
	# make an internal map/hash of the values so we can do sort and filtering operations
	my @Dbase = map {FixUp($_, qr/[\s,\$%\*]/)} $Table->rows;
	
	my $SortField = $Config->{Options}->{sort};
	my @Sorted = sort {$b->[$SortField] <=> $a->[$SortField]} @Dbase;
	
	# print rows
	foreach my $row (@Sorted) {
	    my $c = FixUp($row, qr/[\s,\$%\*]/);
	    my $filter = eval $Config->{Options}->{filter};
	    next unless &$filter(@$c);
	    my $line = sprintf("%-8s %15s %12s %20s %15s %10s %10s %10s\n", Commaize(@$c));
	    print $line;
	}
    }

    if ($Config->{Options}->{format} eq "json") 
    {
	my $Tree = {};
	
	foreach my $row ($Table->rows) {
	    $row = FixUp($row, qr/[\s,\$%\*]/);
	    
	    my $attributes = {};
	    my $index = 0;
	    
	    foreach my $field (@Fields) {
		$attributes->{$field} = $row->[$index++];
	    }
	    
	    $Tree->{$row->[0]} = $attributes;
	}
	
	print to_json($Tree, {pretty => 1});
	
    }
}

Main();
    
__DATA__
{
    Options => {
	url => "https://coinmarketcap.com/all/views/all",
	table_index => 0,
	exchange => 'coinmarketcap',
	sort => 2,
        format => "json", # or "flat"
	filter => 'sub {return $_[4] > 1000000 && $_[1] > 10000000; }',
	version => "coinmarketcap.pl version_info: 1.0.0-75-g3373969 3373969 master 04/13/18-13:38:23",
	end => 0
    }
}

