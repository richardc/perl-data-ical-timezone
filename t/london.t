#!perl -w
use strict;
use Test::More tests => 5;

my $class = 'Data::ICal::TimeZone';
require_ok( $class );
my $zone;
ok( $zone = $class->new( timezone => 'Europe/London' ) );
is( ref $zone, "$class\::Object::Europe::London" );
is( $zone->timezone, 'Europe/London' );

is( ref $zone->definition, 'Data::ICal::Entry::TimeZone' );



__END__
use Data::ICal;
my $cal = Data::ICal->new;
$cal->add_entry( $zone->definition );
diag( $cal->as_string );
