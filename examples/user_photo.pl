#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use Encode;
use YAML;
use WWW::Wassr;
use Sub::Retry;
use IO::File;
use Time::HiRes;
use Getopt::Long;

sub usage {
    my $usage = <<"END_USAGE";
Usage: $0 [-u username] [-p password] target_user_id
Options:
    -u/--user:     your username on wassr
    -p/--password: your password on wassr

it is required usernme and password to take private user's photos.

END_USAGE

    return $usage;
}

die usage() if (scalar @ARGV == 0);

my $user;
my $password;

GetOptions(
    'user=s'     => \$user,
    'password=s' => \$password
);

my $target_user_id = $ARGV[0];

my $wassr;
if (defined($user) && defined($password)) {
    $wassr = WWW::Wassr->new(
        user   => $user,
        passwd => $password
    );
    $wassr->login();
} else {
    $wassr = WWW::Wassr->new();
}

my $page = 1;
while(1){
  my $tl =
    retry 1, 1, sub {
    $wassr->user_photo(
      user_id => $target_user_id,
      page    => $page
    );
   };
  last unless $tl;

  for my $line (@$tl){
    my $image_path = $line->{image_path};
    warn $image_path;
    my $image_url  = $wassr->{site_root} . $image_path;
    my $binary     = $wassr->{wm}->get($image_url)->decoded_content();
    my $io = IO::File->new($line->{status_id}. '.jpg', 'w');
    $io->print($binary);
    $io->close;
    Time::HiRes::usleep(100000);
  }
  $page++;
}

1;
