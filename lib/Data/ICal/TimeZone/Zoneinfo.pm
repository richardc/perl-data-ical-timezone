=head1 NAME

Data::ICal::TimeZone::Zoneinfo - VTIMEZONE definitions from the system tzdata

=head1 SYNOPSIS

  use Data::ICal::TimeZone::Zoneinfo;

  my @zones = Data::ICal::TimeZone::Zoneinfo::zones;
  my $ical  = Data::ICal::TimeZone::Zoneinfo::ical( 'Europe/London' );

=head1 DESCRIPTION

Builds VTIMEZONE definitions from the system time zone database rather than
from a bundled copy, so they follow whatever tzdata is installed.

TZif version 2 and later files end with a POSIX C<TZ> string describing the
zone's current, open-ended rule. That is the same thing a VTIMEZONE needs,
so it is read and translated directly. Parsing of the C<TZ> string is done
by L<DateTime::TimeZone::SystemV>.

=head1 FUNCTIONS

=over

=item zones

Returns the sorted list of available zone names, or the empty list if no
usable database was found.

=item ical( $zone )

Returns an iCalendar document holding a single VTIMEZONE for C<$zone>, or
undef if it could not be built.

=back

=head1 CONFIGURATION

C<$Data::ICal::TimeZone::Zoneinfo::DIR> is the database location. It
defaults to the C<TZDIR> environment variable, or F</usr/share/zoneinfo>.

=head1 LIMITATIONS

Only each zone's current rule is described, not its history. The POSIX C<TZ>
footer of a TZif file gives the zone's final, open-ended rule and nothing
before it, so transitions earlier than the most recent rule change are
reported using the current rule. A zone in the middle of a change is
therefore wrong for the remainder of the old rule: as of tzdata 2026b,
C<America/Vancouver> has already switched to a permanent C<MST7> footer, so
it is an hour out for the rest of 2026 and correct from November onwards.

Zones whose transitions are not annual are not described at all. Morocco
suspends its offset during Ramadan, which follows the lunar calendar and has
no C<RRULE> equivalent; C<Africa/Casablanca> and C<Africa/El_Aaiun> therefore
get their base offset with no transitions.

The C<Etc/> zones are omitted, as names such as C<Etc/GMT+5> cannot be
mapped onto Perl package names.

=head1 SEE ALSO

L<Data::ICal::TimeZone>, L<DateTime::TimeZone::SystemV>, tzfile(5)

=cut

package Data::ICal::TimeZone::Zoneinfo;
use strict;
use warnings;

use Date::ISO8601 qw( ymd_to_cjdn cjdn_to_ymd month_days );
use DateTime::TimeZone::SystemV ();

our $DIR = $ENV{TZDIR} || '/usr/share/zoneinfo';

my @DOW  = qw( SU MO TU WE TH FR SA );
my $RD   = 1721425;    # cjdn minus this is DateTime's rata die
my $YEAR = 1970;       # DTSTART is expressed in the epoch year

# Zone names are Area/Location, two or three components deep. Etc/ is
# skipped because its names cannot be mapped onto package names.
#
# Scanning the database costs about 2 ms, and new() calls this once per
# object, so cache it. The key is $DIR, which callers may change.
my %CACHE;
sub zones {
    $CACHE{$DIR} ||= [
        sort grep { !m{\A(?:posix|right|Etc)/} }
            map { substr $_, length($DIR) + 1 }
            grep {-f} map { glob "$DIR/$_" } '*/*', '*/*/*'
    ];
    return @{ $CACHE{$DIR} };
}

# TZif v2 and later end with a POSIX TZ string giving the zone's current
# open-ended rule.
sub _tz_string {
    open my $fh, '<:raw', "$DIR/$_[0]" or return undef;
    my $head;
    return undef
        unless read( $fh, $head, 5 ) == 5
        and substr( $head, 0, 4 ) eq 'TZif'
        and substr( $head, 4, 1 ) ge '2';
    my $body = do { local $/; <$fh> };
    return $body =~ /\n([^\n]+)\n\z/ ? $1 : undef;
}

# SystemV only calls ->utc_rd_values on its argument.
{   package Data::ICal::TimeZone::Zoneinfo::Instant;
    sub utc_rd_values { return @{ $_[0] } }
}
sub _instant { return bless [ $_[0] - $RD, 0 ], __PACKAGE__ . '::Instant' }

sub _offset {
    my $s = abs $_[0];
    return sprintf '%s%02d%02d', $_[0] < 0 ? '-' : '+', int( $s / 3600 ),
        int( $s % 3600 / 60 );
}

# "Mm.w.d[/time]": the w'th (5 means last) weekday d of month m. The time
# may fall outside its own day, shifting the transition to another date.
sub _rule {
    my ( $month, $week, $dow, $time )
        = $_[0] =~ m{\AM(\d+)\.(\d+)\.(\d+)(?:/(.+))?\z}
        or return undef;
    my ( $sign, $h, $m, $s )
        = defined $time
        ? $time =~ m{\A([-+]?)(\d+)(?::(\d+))?(?::(\d+))?\z}
        : ( '', 2, 0, 0 );
    return undef unless defined $h;
    my $sec = ( $sign eq '-' ? -1 : 1 )
        * ( $h * 3600 + ( $m // 0 ) * 60 + ( $s // 0 ) );
    my $sod = $sec % 86400;
    return {
        month => $month,
        week  => $week,
        dow   => $dow,
        sod   => $sod,
        shift => ( $sec - $sod ) / 86400,
    };
}

sub _cjdn {
    my ($r) = @_;
    my $len = month_days( $YEAR, $r->{month} );
    my $day = 1
        + ( ( $r->{dow} + 6 ) % 7 - ymd_to_cjdn( $YEAR, $r->{month}, 1 ) % 7 ) % 7
        + 7 * ( $r->{week} - 1 );
    $day -= 7 while $day > $len;
    return ymd_to_cjdn( $YEAR, $r->{month}, $day ) + $r->{shift};
}

sub _rrule {
    my ($r) = @_;
    my ( $month, $week, $shift ) = @{$r}{qw( month week shift )};
    my $dow = $DOW[ ( $r->{dow} + $shift ) % 7 ];
    return "FREQ=YEARLY;BYMONTH=$month;BYDAY="
        . ( $week == 5 ? -1 : $week ) . $dow
        unless $shift;

    # Shifted, so the transition lands anywhere in a seven-day window.
    my $len = month_days( $YEAR, $month );
    my @day = map { $_ + $shift } $week == 5
        ? map { $len + $_ } -6 .. 0
        : map { ( $week - 1 ) * 7 + $_ } 1 .. 7;
    return "FREQ=YEARLY;BYMONTH=$month;BYMONTHDAY="
        . join( ',', $week == 5 ? map { $_ - $len - 1 } @day : @day )
        . ";BYDAY=$dow"
        if !grep { $_ < 1 or $_ > $len } @day;

    # The window crosses a month boundary; count back from the year end.
    my $base = ymd_to_cjdn( $YEAR, $month, 1 ) - ymd_to_cjdn( $YEAR, 12, 31 ) - 2;
    return "FREQ=YEARLY;BYYEARDAY="
        . join( ',', map { $base + $_ } @day ) . ";BYDAY=$dow";
}

sub _component {
    my ( $type, $from, $to, $name, $rule ) = @_;
    my @when = ("DTSTART:${YEAR}0101T000000");
    if ($rule) {
        my ( $y, $m, $d ) = cjdn_to_ymd( _cjdn($rule) );
        @when = (
            sprintf( 'DTSTART:%04d%02d%02dT%02d%02d%02d',
                $y, $m, $d, int( $rule->{sod} / 3600 ),
                int( $rule->{sod} % 3600 / 60 ), $rule->{sod} % 60 ),
            'RRULE:' . _rrule($rule),
        );
    }
    return "BEGIN:$type", 'TZOFFSETFROM:' . _offset($from),
        'TZOFFSETTO:' . _offset($to), "TZNAME:$name", @when, "END:$type";
}

# An iCalendar document holding one VTIMEZONE for the named zone.
sub ical {
    my ($zone) = @_;
    my $spec = _tz_string($zone) or return undef;
    my $sv = eval {
        DateTime::TimeZone::SystemV->new( system => 'tzfile3', recipe => $spec );
    } or return undef;

    # Probed clear of the transition, which may fall either side of midnight.
    my $observance = sub {
        my $t = _instant( _cjdn( $_[0] ) + 10 );
        return {
            offset => $sv->offset_for_datetime($t),
            name   => $sv->short_name_for_datetime($t),
            dst    => $sv->is_dst_for_datetime($t),
        };
    };

    my @body;
    my ( $on, $off ) = $spec =~ m{,([^,]+),([^,]+)\z};
    if ( defined $on and $sv->has_dst_changes ) {
        ( $on, $off ) = ( _rule($on), _rule($off) );
        return undef unless $on and $off;
        my ( $dst, $std ) = ( $observance->($on), $observance->($off) );
        return undef unless $dst->{dst} and !$std->{dst};
        @body = (
            _component( 'DAYLIGHT', $std->{offset}, $dst->{offset}, $dst->{name}, $on ),
            _component( 'STANDARD', $dst->{offset}, $std->{offset}, $std->{name}, $off ),
        );
    }
    else {
        my $t = _instant( ymd_to_cjdn( $YEAR, 1, 1 ) );
        my $offset = $sv->offset_for_datetime($t);
        @body = _component( 'STANDARD', $offset, $offset,
            $sv->short_name_for_datetime($t), undef );
    }

    return join '', map {"$_\r\n"} 'BEGIN:VCALENDAR',
        'PRODID:-//My Organization//NONSGML My Product//EN', 'VERSION:2.0',
        'BEGIN:VTIMEZONE', "TZID:$zone", "X-LIC-LOCATION:$zone", @body,
        'END:VTIMEZONE', 'END:VCALENDAR';
}

1;
