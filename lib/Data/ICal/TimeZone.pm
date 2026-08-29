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

Data::ICal::TimeZone provides a mechanism for adding the Olson standard
timezones to your ical documents.

Where a system time zone database is readable, definitions are built from
it on demand, so they follow whatever tzdata the system has installed. This
needs L<DateTime::TimeZone::SystemV>; see L<Data::ICal::TimeZone::Zoneinfo>.
Otherwise the bundled copy is used, which was generated from tzdata2007g
and is wrong for any zone whose rules have changed since.

=head1 METHODS

=over

=item new( timezone => 'zone_name' )

Returns a timezone object, this will be a Data::ICal::TimeZone::Object

Returns a false value upon failure to locate the specified timezone or
load it's data class; this false value is a Class::ReturnValue object
and can be queried as to its C<error_message>.

=item zones

Returns the a list of the supported timezones

=back

=head1 DIAGNOSTICS

=over

=item No timezone specified

You failed to specify a C<timezone> argument to ->new

=item No such timezone '%s'

The C<timezone> you specifed to ->new wasn't one this module knows of.

=item Couldn't require Data::ICal::TimeZone::Object::%s: %s

The underlying class didn't compile cleanly.

=back


=head1 AUTHOR

Richard Clamp <richardc@unixbeard.net>

=head1 LICENCE AND COPYRIGHT

Copyright 2007, Richard Clamp.  All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>.

=head1 BUGS

None currently known, please report any you find to the author.

=head1 VERSION

The current zone data was generated from tzdata2007g using Vzic 1.3.

=head1 SEE ALSO

L<Data::ICal::TimeZone::Object>, L<Data::ICal>

http://dialspace.dial.pipex.com/prod/dialspace/town/pipexdsl/s/asbm26/vzic/

=cut

package Data::ICal::TimeZone;
use strict;
use UNIVERSAL::require;
use Class::ReturnValue;
use Data::ICal::TimeZone::Object;

# Zone definitions come from the system time zone database when one is
# readable, and from the generated classes otherwise. Either may be absent.
my $SYSTEM    = eval { require Data::ICal::TimeZone::Zoneinfo; 1 } || 0;
my $GENERATED = eval { require Data::ICal::TimeZone::List;     1 } || 0;

sub zones {
    my @zones = $SYSTEM ? Data::ICal::TimeZone::Zoneinfo::zones() : ();
    return @zones if @zones;
    return $GENERATED ? Data::ICal::TimeZone::List::zones() : ();
}
our $VERSION = 1.23;

sub _error {
    my $class = shift;
    my $msg   = shift;

    my $ret = Class::ReturnValue->new;
    $ret->as_error( errno => 1, message => $msg );
    return $ret;
}

sub _zone_package {
    my $class = shift;
    my $zone = shift;
    $zone =~ s{-}{_}g;
    $zone =~ s{/}{::}g;
    return __PACKAGE__."::Object::$zone";
}

sub new {
    my $class = shift;
    my %args  = @_;
    my $timezone = delete $args{timezone}
      or return $class->_error( "No timezone specified" );
    grep { $_ eq $timezone } $class->zones
      or return $class->_error( "No such timezone '$timezone'" );
    my $tz = $class->_zone_package( $timezone );
    return $tz->new if $tz->isa( 'Data::ICal::TimeZone::Object' );
    if ( my $ics = $SYSTEM && Data::ICal::TimeZone::Zoneinfo::ical( $timezone ) ) {
        no strict 'refs';
        @{"${tz}::ISA"} = ( 'Data::ICal::TimeZone::Object' );
        $tz->new->_load( $ics );
        return $tz->new;
    }
    $tz->require
      or return $class->_error( "Couldn't require $tz: $@" );
    return $tz->new;
}

1;
