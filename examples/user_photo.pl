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

# IF it's private user when require user id and password.
#
my $wassr = WWW::Wassr->new(
#  user   => 'your username on wassr',
#  passwd => 'your password on wassr',
);
#
#$wassr->login();

my $page = 1;
my $target_user_id = 'likkradyus';

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
