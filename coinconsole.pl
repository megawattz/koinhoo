#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
#use IO::File;
#use POSIX;
use IO::Socket;
#use Cwd;
#use JSON;
use FindBin qw($Bin);
#use Carp;
#use Digest::SHA qw(hmac_sha256_hex hmac_sha512_hex);
#use WWW::Curl::Easy;
#use File::Slurp;
use HTML::TableExtract;
use LWP::Simple;

$| = 1; # immediately flush output
$Data::Dumper::Indent = 1;

my $Config =  eval(join('', <DATA>));

sub Output {
    # priorities 0 = no output, 1 = errors, 2 = normal, 3 = extra
    my $priority = shift;
    return if $priority > $Config->{Options}->{verbosity};
    print @_;
}

sub ExecString # open process as a file
{
    my $command = "@_";
    my $pid = open(my $pipe_handle, "$command 2>&1 |") or die "ExecStringError($command) fails open(): $!";
    my @lines = <$pipe_handle>;
    my $output = join('', @lines);
    die "waitpid($pid, 0)) failed for $command" if (-1 == waitpid($pid, 0));
    my $rval = $?;
    close $pipe_handle;
    #die "@_ FAILED: $output: $rval" if $rval;
    return ($rval, $output)
}

sub Exec # open process as a file
{
    my $command = "@_";
    my $pid = open(my $pipe_handle, "$command 2>&1 |") or die "ExecStringError($command) fails open(): $!";
    return ($pid, $pipe_handle);
}

sub ReadIfReady
{
    my ($filehandle, $timeout) = @_;
    vec (my $rfd, fileno($filehandle), 1) = 1;
    my $rval = 1;
    # Wait for something to happen, and make sure
    # that it happened to the right filehandle.
    if (select ($rfd, undef, undef, $timeout) >= 0
	&& vec($rfd, fileno($filehandle), 1))
    {
	# Something came in!
	my ($buffer);
	my $rval = sysread ($filehandle, $buffer, 99999999);
	return ($buffer, $rval);
    }
    return ("", 1);
}

foreach my $arg (@ARGV) {
    my ($key, $value) = $arg =~ /-+([^=]+)=?[\'\"]?([^\'\"]*)/;
    if (!$key || !defined $Config->{Options}->{$key}) {
	Output(1, sprintf("Unknown option: %s", $key));
	exit -1;
    }
    $value = "1" if !$value; # key without a value just means "turn me on"
    if ($value =~ /,/) {
	my @values = split(/,/, $value);
	$value = \@values;
    }
    $Config->{Options}->{$key} = $value;
}

Output(4, Dumper($Config));

my $Sources = {};

# start feeds
for my $source (@{$Config->{Options}->{drivers}}) {
    if ($source !~ m|/|) {
	$source = "$Bin/${source}";
    }

    my ($pid, $stream) = Exec($source);
    Output(3, "Exec $source pid:$pid handle:".Dumper($stream));

    $Sources->{$pid}->{source} = $source;
    $Sources->{$pid}->{stream} = $stream;
    $Sources->{$pid}->{data} = "";
}

# drain output
while (grep {$Sources->{$_}->{stream}} keys %$Sources) {
    for my $pid (keys %$Sources) {
	next unless ($Sources->{$pid}->{stream});
	my ($data, $rval) = ReadIfReady($Sources->{$pid}->{stream}, 0.1);
	if ($data) {
	    Output(3, $data);
	    $Sources->{$pid}->{data} = $Sources->{$pid}->{data}.$data;
	}
	if ($rval == 0) {
	    $Sources->{$pid}->{stream} = undef;
	}
    }
}

# collect up the data from all of them
while () {
    my $status = 0;
    Output(3, "waiting\n");
    my $pid = waitpid(-1, $status);
    Output(3, sprintf("wait returns %d\n", $pid));
    last if $pid <= 0;
    #my $pid_output;
    #my $count = sysread ($Sources->{$pid}->{stream}, $Sources->{$pid}->{data}, 999999); # read everything
    #Output(3, sprintf("Child process %s pid %d exit status %d produced %d bytes of data\n", $Sources->{$pid}->{source}, $pid, $status, $count));
    #Output(4, $Sources->{$pid}->{data});
}

Output(1, "Done\n");

__DATA__
{
    Options => {
    drivers => ["coinmarketcap.pl"],
    verbosity => 2,
    filter => undef,
    version => "coinconsole version_info: 1.0.0-75-g3373969 3373969 master 04/13/18-13:38:23",
    end => 0
}
}
