#!perl -w
use strict;
use Test::More;

eval { require Data::ICal::TimeZone::Zoneinfo; 1 }
    or plan skip_all => 'Data::ICal::TimeZone::Zoneinfo not usable here';

# Frozen ical() output for zones chosen to cover the arithmetic branches:
# simple DST (London), shifted southern-hemisphere DST (Santiago), a fixed
# offset with no DST (Casablanca), and a rule whose transition window
# crosses the year boundary (Cairo).
my %zones = (
    'Europe/London' => [
        'BEGIN:DAYLIGHT',
        'TZOFFSETFROM:+0000',
        'TZOFFSETTO:+0100',
        'TZNAME:BST',
        'DTSTART:19700329T010000',
        'RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU',
        'END:DAYLIGHT',
        'BEGIN:STANDARD',
        'TZOFFSETFROM:+0100',
        'TZOFFSETTO:+0000',
        'TZNAME:GMT',
        'DTSTART:19701025T020000',
        'RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU',
        'END:STANDARD',
    ],
    'America/Santiago' => [
        'BEGIN:DAYLIGHT',
        'TZOFFSETFROM:-0400',
        'TZOFFSETTO:-0300',
        'TZNAME:-03',
        'DTSTART:19700906T000000',
        'RRULE:FREQ=YEARLY;BYMONTH=9;BYMONTHDAY=2,3,4,5,6,7,8;BYDAY=SU',
        'END:DAYLIGHT',
        'BEGIN:STANDARD',
        'TZOFFSETFROM:-0300',
        'TZOFFSETTO:-0400',
        'TZNAME:-04',
        'DTSTART:19700405T000000',
        'RRULE:FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=2,3,4,5,6,7,8;BYDAY=SU',
        'END:STANDARD',
    ],
    'Africa/Casablanca' => [
        'BEGIN:STANDARD',
        'TZOFFSETFROM:+0100',
        'TZOFFSETTO:+0100',
        'TZNAME:+01',
        'DTSTART:19700101T000000',
        'END:STANDARD',
    ],
    'Africa/Cairo' => [
        'BEGIN:DAYLIGHT',
        'TZOFFSETFROM:+0200',
        'TZOFFSETTO:+0300',
        'TZNAME:EEST',
        'DTSTART:19700424T000000',
        'RRULE:FREQ=YEARLY;BYMONTH=4;BYDAY=-1FR',
        'END:DAYLIGHT',
        'BEGIN:STANDARD',
        'TZOFFSETFROM:+0300',
        'TZOFFSETTO:+0200',
        'TZNAME:EET',
        'DTSTART:19701030T000000',
        'RRULE:FREQ=YEARLY;BYYEARDAY=-67,-66,-65,-64,-63,-62,-61;BYDAY=FR',
        'END:STANDARD',
    ],
);

my %have = map { $_ => 1 } Data::ICal::TimeZone::Zoneinfo::zones();
my @known = grep { $have{$_} } sort keys %zones;

plan skip_all => 'none of the frozen test zones are in the system database'
    unless @known;
plan tests => scalar @known;

for my $zone (@known) {
    my $expect = join '', map {"$_\r\n"} 'BEGIN:VCALENDAR',
        'PRODID:-//My Organization//NONSGML My Product//EN', 'VERSION:2.0',
        'BEGIN:VTIMEZONE', "TZID:$zone", "X-LIC-LOCATION:$zone",
        @{ $zones{$zone} }, 'END:VTIMEZONE', 'END:VCALENDAR';
    is( Data::ICal::TimeZone::Zoneinfo::ical($zone), $expect, $zone );
}
