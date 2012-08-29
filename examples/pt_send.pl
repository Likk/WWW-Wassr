#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Encode;
use Getopt::Long;
use Config::Pit;
use WWW::Wassr;

sub usage {
    my $usage = <<"END_USAGE";
Usage: $0 [-i file] user_id user_id ...
Options:
    -i/-infile : message
END_USAGE

    return $usage;
}

# get password
my $config = pit_get("wassr.jp", require => {
    "username" => "your username on wassr",
    "password" => "your password on wassr",
});

# get message
my $infile = '-';
my $options = GetOptions(
    'in=s' => \$infile,
);

die usage() if (scalar @ARGV == 0);

my $message;
if ($infile  eq '-') {
    $message = do { local $/; <STDIN> };
}
else {
    open( my $fh, "<:utf8", $infile ) or die "$!";
    $message = do { local $/; <$fh> };
}

die "message must be less than 255." if length($message) > 255;

# login
my $wassr = WWW::Wassr->new(
    user => $config->{username},
    passwd => $config->{password}
);
$wassr->login();

# send pt
for my $user_id (@ARGV) {
    $wassr->private_update(
        (
            user_id => $user_id,
            message => $message,
        )
    );
}
