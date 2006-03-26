package Text::CSV::Separator;

use 5.008;
use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.01';

use Exporter;
use base 'Exporter';
our @EXPORT = qw(get_separator);


sub get_separator {
    
    my %options = @_;
    
    my $file_path = $options{path};
    
    my (@excluded, @included);
    if (exists $options{exclude}) {
        @excluded = @{$options{exclude}};
    }
    
    if (exists $options{include}) {
        @included = @{$options{include}};
    }

    
    # Default set of candidates
    my @candidates = (',', ';', ':', '|', "\t");
    
    my %survivors;
    $survivors{$_} = [] foreach (@candidates);
    
    if (@excluded > 0) {
        foreach (@excluded) {
            delete $survivors{$_} if (exists $survivors{$_});
        }
    }
    
    if (@included > 0) {
        foreach (@included) {
            if (length($_) == 1) {
                $survivors{$_} = [];
            }
        }
    }
    
    if (scalar(keys %survivors) == 0) {
        die "No candidates left!";
    }
    
    
    my $csv;
    if (-e $file_path) {
        open ($csv, "<:crlf", $file_path) || croak "Couldn't open csv file: $!";
    } else {
        croak "Couldn't find the specified file.\n";
    }
    
    while (<$csv>) {
        my $record = $_;
        chomp $record;
        
        foreach my $candidate (keys %survivors) {
            
            my $rex = qr/\Q$candidate\E/;
            
            my $count = 0;
            $count++ while ($record =~ /$rex/g);
            
            
            if ($count > 0) {
                push @{$survivors{$candidate}}, $count;
            } else {
                delete $survivors{$candidate};
            }
            
        }
        if (scalar(keys %survivors) == 1 || scalar (keys %survivors) == 0) {
            close $csv;
            return (keys %survivors);
        }
    }
    
    #  More than 1 survivor. 2nd pass to determine variability of candidate counts.
    my %std_dev;
    foreach my $candidate (keys %survivors) {
        my $mean = _mean(@{$survivors{$candidate}});
        $std_dev{$candidate} = _std_dev($mean, @{$survivors{$candidate}});
    }
    
    close $csv;
    
    return (sort {$std_dev{$a} <=> $std_dev{$b}} keys %survivors);
}


sub _mean {
    my @array = @_;
    
    my $sum = 0;
    $sum += $_ foreach (@array);
    
    my $mean = $sum / scalar(@array);
    
    return $mean;
}


sub _std_dev {
    my ($mean, @array) = @_;
    
    my $sum = 0;
    $sum += ($_ - $mean)**2 foreach (@array);
    
    my $std_dev = sqrt($sum / (scalar(@array) - 1));
    
    return $std_dev;      
}



1;
__END__


=head1 NAME

Text::CSV::Separator - Determine the field separator of a CSV file

=head1 SYNOPSIS

    use Text::CSV::Separator;
    
    my @char_list = get_separator(
                                    path => $csv_path,
                                    exclude => $array1_ref, # optional
                                    include => $array2_ref, # optional
                                 );
  
    
    my $char_count = @char_list;
    
    my $separator;
    if ($char_count == 1) {        # successful detection, we've got a winner
      $separator = $char_list[0];
      
    } elsif  ($char_count > 1) {   # several candidates passed the tests
      warning message or any other action
      
    } else {                       # none of the candidates passed the tests
      warning message or any other action
      
    }

=head1 DESCRIPTION

This module provides a fast detection of the field separator character of a
CSV file, and returns it ready to use in a CSV parser (e.g., Text::CSV_XS,
Tie::CSV_File, or Text::CSV::Simple). 
This may be useful when processing batches of heterogeneous CSV files.

The default set of candidates contains the following characters:
',' ';' ':' '|' '\t'

The only required parameter is the CSV file path. Optionally, the user can
specify characters to be excluded or included in the list of candidates. 

The routine returns an array containing the list of candidates that passed
the tests. If it succeeds, this array will contain only one value: the field
separator we are looking for.


The technique used is based on the following principle:

=over 8

=item *

The number of instances of the separator character contained in a line must be
an integer constant > 0 for all the lines in the file (although some of these
instances can be escaped literal characters).

=item *

Most of the other candidates won't appear in a typical CSV line (they will be
removed from the candidates list as soon as they miss a line).

=back

This is the first test done to the CSV file. In most cases, it will detect the
separator after processing the first few rows.
Processing will stop and return control to the caller as soon as the program
reaches a status of 1 single candidate (or 0 candidates left).

If the routine cannot determine the separator in the first pass, it will do
a second pass based on a heuristic technique: even if the other candidates
appear in many lines, their count will likely vary significantly in the
different lines. So it measures the variability of the remaining candidates and
returns the list of possible separators sorted by their likelihood, being the
first array item the most probable separator.
Since this is a rule of thumb, you can always create a CSV file that breaks
this logic. Nevertheless, it will work correctly in many cases.
The possibility of excluding some of the default candidates may help to resolve
cases with more than one possible winner.


=head2 EXPORT

=over

=item get_separator

=back

=head1 SEE ALSO

There's another module in CPAN for this task, Text::CSV::DetectSeparator,
which follows a different approach.

=head1 AUTHOR

Enrique Nell, E<lt>enell@cpan.orgE<gt>

=head1 ACKNOWLEDGEMENTS

Many thanks to Xavier Noria for wise suggestions.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Enrique Nell.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut


