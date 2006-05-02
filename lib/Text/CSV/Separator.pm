package Text::CSV::Separator;

use 5.008;
use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.05';

use Exporter;
use base 'Exporter';
our @EXPORT_OK = qw(get_separator);


sub get_separator {
    
    my %options = @_;
    
    my $file_path = $options{path};
    
    # check the options
    my $echo;
    if (exists $options{echo} && $options{echo} eq 'on') {
        $echo = 1;
        print "\nDetecting field separator of $file_path\n";
    }
    
    my (@excluded, @included);
    if (exists $options{exclude}) {
        @excluded = @{$options{exclude}};
    }
    
    if (exists $options{include}) {
        @included = @{$options{include}};
    }
    
    my $lucky;
    if (exists $options{lucky} && $options{lucky} == 1) {
        $lucky = 1;
        print "Scalar context...\n\n" if $echo;
    } else {
        print "Array context...\n\n" if $echo;
    }
    
    # Default set of candidates
    my @candidates = (',', ';', ':', '|', "\t");
    
    my %survivors;
    $survivors{$_} = [] foreach (@candidates);
    
    if (@excluded > 0) {
        foreach (@excluded) {
            delete $survivors{$_} if (exists $survivors{$_});
            if ($echo) {
                if (ord($_) == 9) { # tab character
                    print "Deleted \\t from candidates list\n";
                } else {
                    print "Deleted $_ from candidates list\n";
                }
            }
        }
    }
    
    if (@included > 0) {
        foreach (@included) {
            if (length($_) == 1) {
                $survivors{$_} = [];
            }
            if ($echo) {
                if (ord($_) == 9) { # tab character
                    print "Added \\t to candidates list\n";
                } else {
                    print "Added $_ to candidates list\n";
                }
            }
        }
    }
    
    if (scalar(keys %survivors) == 0) {
        croak "No candidates left!";
    }
    
    
    my $csv;
    if (-e $file_path) {
        open ($csv, "<:crlf", $file_path) ||
        croak "Couldn't open $file_path: $!";
    } else {
        croak "Couldn't find $file_path.\n";
    }
    
    my $record_count = 0; # if $echo
    while (<$csv>) {
        my $record = $_;
        chomp $record;
        
        if ($echo) {
            $record_count++;
            print "\nRecord #", $record_count, "\n";
        }
        
        foreach my $candidate (keys %survivors) {
            if ($echo) {
                if (ord($candidate) == 9) { # tab character
                    print "Candidate: \\t\t";
                } else {
                    print "Candidate: $candidate\t";
                }
            }
            
            my $rex = qr/\Q$candidate\E/;
            
            my $count = 0;
            $count++ while ($record =~ /$rex/g);
            
            print "Count: $count\n" if $echo;
            
            if ($count > 0 && !$lucky) {
                push @{$survivors{$candidate}}, $count;
            } elsif ($count == 0) {
                delete $survivors{$candidate};
            }
            
        }
        my @alive = keys %survivors;
        my $survivors_count = @alive;
        if ($survivors_count == 1) {
            if ($echo) {
                if (ord($alive[0]) == 9) {
                    print "\nSeparator detected: \\t\n";
                } else {
                    print "\nSeparator detected: $alive[0]\n";
                }
                print "Returning control to caller...\n\n";
            }
            close $csv;
            if (!$lucky) {
                return @alive;
            } else {
                return $alive[0];
            }
        } elsif ($survivors_count == 0) {
                croak "No candidates left!\n\n";
        }
    }
    
    #  More than 1 survivor. 2nd pass to determine count variability
    if ($lucky) {
        print "\nSeveral candidates left\n" if $echo;
        croak "Bad luck. Couldn't determine the separator of $file_path.\n\n";
    } else {
        print "\nVariability:\n\n" if $echo;
        my %std_dev;
        foreach my $candidate (keys %survivors) {
            my $mean = _mean(@{$survivors{$candidate}});
            $std_dev{$candidate} = _std_dev($mean, @{$survivors{$candidate}});
            if ($echo) {
                if (ord($candidate) == 9) {
                    print "Candidate: \\t\tMean: $mean",
                } else {
                    print "Candidate: $candidate\tMean: $mean",
                }
                print "\tStd Dev: $std_dev{$candidate}\n\n";
            }
        }
    
        print "Couldn't determine the separator\n" if $echo;
            
        close $csv;
        
        my @alive = sort {$std_dev{$a} <=> $std_dev{$b}} keys %survivors;
        if ($echo) {
            print "Remaining candidates: ";
            foreach my $left (@alive) {
                if (ord($left) == 9) {
                    print " \\t ";
                } else {
                    print " $left ";
                }
            }
            print "\n\nReturning control to caller...\n\n";
        }
        return @alive;
    }
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

=head1 VERSION

Version 0.05 May 2, 2006

=head1 SYNOPSIS

    use Text::CSV::Separator qw(get_separator);
    
    my @char_list = get_separator(
                                    path => $csv_path,
                                    exclude => $array1_ref, # optional
                                    include => $array2_ref, # optional
                                    echo => 'on',           # optional
                                 );
  
    
    my $char_count = @char_list;
    
    my $separator;
    if ($char_count == 1) {       # successful detection
      $separator = $char_list[0];
      
    } elsif  ($char_count > 1) {  # several candidates passed the tests
      warning message or any other action
      
    } else {                      # no candidate passed the tests
      warning message or any other action
      
    }
    
    
    # "I'm Feeling Lucky" alternative interface
    # Don't forget to include the 'lucky' parameter
    
    use Text::CSV::Separator qw(get_separator);
    
    my $separator = get_separator(
                                    path => $csv_path,
                                    lucky => 1, 
                                    exclude => $array1_ref, # optional
                                    include => $array2_ref, # optional
                                    echo => 'on',           # optional
                                 );
    


=head1 DESCRIPTION

This module provides a fast detection of the field separator character (also
called field delimiter) of a CSV file, or more generally, of a character
separated text file (also called delimited text file), and returns it ready
to use in a CSV parser (e.g., Text::CSV_XS, Tie::CSV_File, or
Text::CSV::Simple). 
This may be useful to the vulnerable -and often ignored- population of
programmers who need to process automatically CSV files from different sources.

The default set of candidates contains the following characters:
','  ';'  ':'  '|'  '\t'

The only required parameter is the CSV file path. Optionally, the user can
specify characters to be excluded or included in the list of candidates. 

The routine returns an array containing the list of candidates that passed
the tests. If it succeeds, this array will contain only one value: the field
separator we are looking for.


The technique used is based on the following principle:

=over 8

=item *

For every line in the file, the number of instances of the separator
character acting as separators must be an integer constant > 0 , although
a line may also contain some instances of that character as escaped
literal characters.

=item *

Most of the other candidates won't appear in a typical CSV line.

=back

As soon as a candidate misses a line, it will be removed from the candidates
list.

This is the first test done to the CSV file. In most cases, it will detect the
separator after processing the first few lines. In particular, if the file
contains a header line, one line will probably be enough to get the job done.
Processing will stop and return control to the caller as soon as the program
reaches a status of 1 single candidate (or 0 candidates left).

If the routine cannot determine the separator in the first pass, it will do
a second pass based on a heuristic technique: Even if the other candidates
appear in every line, their count will likely vary significantly in the
different lines. So it measures the variability of the remaining candidates and
returns the list of possible separators sorted by their likelihood, being the
first array item the most probable separator.
Since this is a rule of thumb, you can always create a CSV file that breaks
this logic. Nevertheless, it will work correctly in many cases.
The possibility of excluding some of the default candidates may help to resolve
cases with several possible winners.

As an alternative, if you think that the files your program will have to
deal with aren't too exotic, you can use the B<"I'm Feeling Lucky"> interface.
This interface has a simpler syntax.
To use it you only have to add the B<lucky =E<gt> 1> key-value pair to the
parameters hash and the routine will return a single value, so you can assign
it directly to a scalar variable.
The code skips the 2nd test, which is usually unnecessary, so the program
will run faster and will require less memory. This approach should be enough in
most cases.

=head1 FUNCTIONS

=over4

=item get_separator(%options)

Returns an array containing the field separator character (or characters, if
more than one candidate passed the tests) of a CSV file.
The available parameters are:

=over8

=item path

Required. The path to the CSV file to be analyzed.

=item exclude

Optional. Array containing characters to be excluded from the candidates list.

=item include

Optional. Array containing characters to be included in the candidates list.

=item lucky

Optional. Activates the scalar context of the function. It will return
one single character. Off by default.

=item echo

Optional. Writes to the standard output messages describing the actions
performed. Off by default.
This is useful to keep track of what's going on, especially for debugging
purposes.

=back

=head1 EXPORT

None by default.

=head1 EXAMPLE

Consider the following scenario: Your program must process a batch of csv files,
and you know that the separator could be a comma, a semicolon or a tab.
You also know that one of the fields contains time values. This field will
provide a fixed number of colons that could mislead the detection code.
In this case, you should exclude the colon (and you can also exclude the other
default candidate not considered, the pipe character):

    my @char_list = get_separator(
                                    path => $csv_path,
                                    exclude => [':', '|'],
                                 );
  
    my $char_count = @char_list;
    
    my $separator;
    if ($char_count == 1) {       
      $separator = $char_list[0];
    } 
    ...
    
    
    # Using the "I'm Feeling Lucky" interface:
    
    my $separator = get_separator(
                                    path => $csv_path,
                                    lucky => 1,
                                    exclude => [':', '|'],
                                  );
    
    

=head1 MOTIVATION

Despite the popularity of XML, the CSV file format is still widely used
for data exchange between applications, because of its much lower overhead:
It requires much less bandwidth and storage space than XML, and it also has
a better performance under compression (see the References below).

Unfortunately, there is no formal specification of the CSV format.
The Microsoft Excel implementation is the most widely used and it has become
a I<de facto> standard, but the variations are almost endless.

One of the biggest annoyances of this format is that in most cases you don't
know a priori what is the field separator character used in a file.
CSV stands for "comma-separated values", but most of the spreadsheet
applications let the user select the field delimiter from a list of several
different characters when saving or exporting data to a CSV file.
Furthermore, in a Windows system, when you save a spreadsheet in Excel as a
CSV file, Excel will use as the field delimiter the default list separator of
your system's locale, which happens to be a semicolon for several European
languages. You can even customize this setting and use the list separator you
like. For these and other reasons, automating the processing of CSV files is a
risky task.

This module can be used to determine the separator character of a delimited
text file of any kind, but since the aforementioned ambiguity problems occur
mainly in CSV files, I decided to use the Text::CSV:: namespace.

=head1 REFERENCES

L<http://www.creativyst.com/Doc/Articles/CSV/CSV01.htm>

L<http://www.xml.com/pub/a/2004/12/15/deviant.html>

=head1 SEE ALSO

There's another module in CPAN for this task, Text::CSV::DetectSeparator,
which follows a different approach.

=head1 ACKNOWLEDGEMENTS

Many thanks to Xavier Noria for wise suggestions.

=head1 AUTHOR

Enrique Nell, E<lt>enell@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Enrique Nell.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut


