#!perl -w
use strict;
use Data::ICal::TimeZone;
use Test::More tests => scalar @{ [ Data::ICal::TimeZone->zones ] };


for my $zone ( Data::ICal::TimeZone->zones ) {
    eval { Data::ICal::TimeZone->new( timezone => $zone ) };
    is ($@, '', "Loaded $zone ok" );
}
