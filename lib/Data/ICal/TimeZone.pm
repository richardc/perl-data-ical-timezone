package Data::ICal::TimeZone;
use strict;
use Carp;
use UNIVERSAL::require;

sub new {
    my $class = shift;
    my %args  = @_;
    my $timezone = delete $args{timezone}
      or croak "No timezone specified";
    my $tz = __PACKAGE__."::$timezone";
    $tz =~ s{/}{::}g;
    $tz->require or croak "Couldn't require $tz: $@";
    return $tz->new;
}

package Data::ICal::TimeZone::_Base;
use base qw( Class::Singleton Class::Accessor );
__PACKAGE__->mk_accessors(qw( _cal ));
use Data::ICal;

sub new {
    my $self = shift;
    return $self->instance;
}

sub event {
    my $self = shift;
    my @zones = grep {
        $_->ical_entry_type eq 'VTIMEZONE'
    } @{ $self->_cal->entries };
    return $zones[0];
}

sub property {
    my $self = shift;
    my $time = shift;
    return [ $time => { TZID => $self->timezone } ];
}

sub _load {
    my $self = shift;
    my $ics = shift;
    my $cal = Data::ICal->new( data => $ics );
    $self->_cal( $cal );
    return;
}

1;
__END__

=head1 NAME

  Data::ICal::TimeZone - timezones for Data::ICal

=head1 SYNOPSIS

  use Data::ICal;
  use Data::ICal::TimeZone;

  my $cal = Data::ICal->new;
  my $zone = Data::ICal::TimeZone->new( timezone => 'Europe/London' );
  $cal->add_event( $zone->event );
  my $meeting = Data::ICal::Event->new;
  $meeting->add_properties(
    summary => 'Go to the pub',
    dtstart => [ $opening_time, { TZID => $zone->timezone } ],
    dtend   => $zone->property( $closing_time ),
  );
  $cal->add_event( $meeting );
