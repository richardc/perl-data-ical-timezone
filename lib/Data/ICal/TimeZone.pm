package Data::ICal::TimeZone;
use strict;

sub new {
    my $class = shift;
    my %args  = @_;
    return bless {}, $class;
}

1;
__END__

