#!perl -w
use strict;
use Test::More tests => 4;

my $class = 'Data::ICal::TimeZone';
require_ok( $class );
my $zone;
ok( $zone = $class->new( timezone => 'Europe/London' ) );
is( ref $zone, "$class\::Europe::London" );
is( $zone->timezone, 'Europe/London' );

is( ref $zone->definition, 'Data::ICal::Entry::TimeZone' );
is( $zone->definition->property('tzid')->[0]->value, $zone->timezone );


__END__
use Data::ICal;
my $cal = Data::ICal->new;
$cal->add_entry( $zone->definition );
diag( $cal->as_string );
