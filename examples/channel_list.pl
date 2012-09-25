#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use Encode;
use YAML;
use WWW::Wassr;
use Time::HiRes;

my $wassr = WWW::Wassr->new();
my $page = 1;
my $channels = [];
while(1){
  warn $page;
  my $data = $wassr->channel_list(page => $page);
  push @$channels, @$data;
  last unless scalar @$data;
  sleep 1;
  $page++;
}

warn YAML::Dump $channels;
