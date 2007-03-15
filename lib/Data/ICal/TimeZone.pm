=head1 NAME

Data::ICal::TimeZone - timezones for Data::ICal

=head1 SYNOPSIS

  use Data::ICal;
  use Data::ICal::TimeZone;

  my $cal = Data::ICal->new;
  my $zone = Data::ICal::TimeZone->new( timezone => 'Europe/London' );
  $cal->add_event( $zone->definition );
  my $event = Data::ICal::Entry::Event->new;
  $event->add_properties(
      summary => 'Go to the pub',
      dtstart => [ '20070316T180000' , { TZID => $zone->timezone } ],
      dtend   => [ '20070316T230000' , { TZID => $zone->timezone } ],
  );
  $cal->add_event( $event );

=head1 DESCRIPTION

Data::ICal::TimeZone provides a mechanism for adding the Olsen
standard timezones to your ical documents, plus a copy of the Olsen
timezone database.

=head1 METHODS

=over

=item new( timezone => 'zone_name' )

Returns a timezone object, this will be a Data::ICal::TimeZone::Object

=back

=head1 VERSION

The current zone data was generated from tzdata2007c using Vzic 1.3.

=head1 SEE ALSO

L<Data::ICal::TimeZone::Object>, L<Data::ICal>

http://dialspace.dial.pipex.com/prod/dialspace/town/pipexdsl/s/asbm26/vzic/

=cut

package Data::ICal::TimeZone;
use strict;
use Carp;
use UNIVERSAL::require;

sub new {
    my $class = shift;
    my %args  = @_;
    my $timezone = delete $args{timezone}
      or croak "No timezone specified";
    my $tz = __PACKAGE__."::Object::$timezone";
    $tz =~ s{/}{::}g;
    $tz->require or croak "Couldn't require $tz: $@";
    return $tz->new;
}

1;
