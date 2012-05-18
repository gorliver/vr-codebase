package Pathogens::Variant::Allele;
use Moose;

use namespace::autoclean;








has 'coverage'   => ( is => 'rw', isa => 'Int');
has 'base'       => ( is => 'rw', isa => 'Str');
has 'quality'    => ( is => 'rw', isa => 'Num');
has 'coverage'   => ( is => 'rw', isa => 'Int');

=head1 BUGS

=head1 AUTHOR

    Feyruz Yalcin
    CPAN ID: FYALCIN


=head1 SEE ALSO

=cut

__PACKAGE__->meta->make_immutable;

1;
