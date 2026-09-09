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

Returns the sorted list of supported timezones: the union of those the system
database offers and those the bundled classes provide.

=item source

Reports where the zone definitions are coming from. Returns C<'system'> when
they are built from the system time zone database, whose location is
C<$Data::ICal::TimeZone::Zoneinfo::DIR>, so they follow whatever tzdata the
system has installed. Returns C<'bundled'> when they come from the classes
under Data::ICal::TimeZone::Object, which were generated from tzdata2007g in
2007 and are wrong for any zone whose rules have changed since. Returns undef
when neither source is available.

=item flush

Discards the cached zone list and every definition built from the system time
zone database, so later calls rebuild them. Call it when the system tzdata has
been updated in place; a change to C<$Data::ICal::TimeZone::Zoneinfo::DIR> is
picked up without it.

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

Zone definitions follow the system time zone database when one is available,
so they are as current as the installed tzdata. Otherwise they fall back to a
bundled copy generated from tzdata2007g using Vzic 1.3 - present in the CPAN
release, not in this source repository.

=head1 SEE ALSO

L<Data::ICal::TimeZone::Object>, L<Data::ICal::TimeZone::Zoneinfo>, L<Data::ICal>

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

# Definitions built from the system database, keyed on the directory they
# came from. Class::Singleton cannot be used here: its cache is keyed on
# class name only, and there is no way to clear it.
my %BUILT;

sub flush {
    %BUILT = ();
    Data::ICal::TimeZone::Zoneinfo::flush() if $SYSTEM;
    return;
}

sub _system_zones {
    return $SYSTEM ? Data::ICal::TimeZone::Zoneinfo::zones() : ();
}

sub zones {
    my %seen;
    my @zones = sort grep { !$seen{$_}++ } _system_zones(),
        ( $GENERATED ? Data::ICal::TimeZone::List::zones() : () );
    return @zones;
}

sub source {
    my @zones = _system_zones();
    return 'system' if @zones;
    return $GENERATED ? 'bundled' : undef;
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
    if ($SYSTEM) {
        my $key = join "\0", $Data::ICal::TimeZone::Zoneinfo::DIR, $timezone;
        return $BUILT{$key} if $BUILT{$key};
        if ( my $ics = Data::ICal::TimeZone::Zoneinfo::ical($timezone) ) {
            no strict 'refs';
            @{"${tz}::ISA"} = ( 'Data::ICal::TimeZone::Object' )
                unless $tz->isa( 'Data::ICal::TimeZone::Object' );
            my $obj = $tz->from_ics( $ics )
                or return $class->_error( "Couldn't parse generated definition for '$timezone'" );
            return $BUILT{$key} = $obj;
        }
    }
    return $tz->new if $tz->isa( 'Data::ICal::TimeZone::Object' )
        and $tz->has_instance;
    $tz->require
      or return $class->_error( "Couldn't require $tz: $@" );
    return $tz->new;
}

1;
