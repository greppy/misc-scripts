#!/usr/bin/perl

use strict;
use warnings;
use English qw( -no_match_vars );
use Carp;
use HTML::TableExtract;
use Getopt::Long;

# 
# The MIT License (MIT)
# 
# Copyright (c) 2014 Matt Okeson-Harlow
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 

# This script is a parser for the http://wi-repeaters.org/DirByCity.html
# webpage. The text version on the webpage,
# http://wi-repeaters.org/DirByCity.txt, does not include the repeater input
# offset

# Example usage:
# curl http://wi-repeaters.org/DirByCity.html | perl parse_war.pl

my $input_file = q{-};
my $output_file =  q{-};
my ( $ifh, $ofh );
my $string = q{};

my $options_ok = GetOptions(
    'input=s' => \$input_file,
    'output=s' => \$output_file,
);

if ( $input_file eq q{-} ) {
    $string = do {
        local $/ = undef;
        $ifh = \*STDIN;
        <$ifh>;
    };
}
else {
    $string = do { 
        local $/ = undef;
        open $ifh, '<', $input_file or croak qq{ERROR: $OS_ERROR};
        <$ifh>;
    };
}

if ( $output_file eq q{-} ) {
    $ofh = \*STDOUT;
}
else {
    open $ofh, '>', $output_file or croak qq{ERROR: $OS_ERROR};
}

my $te = HTML::TableExtract->new( depth => 0, count => 1 );
$te->parse( $string );

# prepopulate the widths array with 0s
my @widths = qw( 0 0 0 0 0 0 0 0 0 );

# Run through the entire table and get max lengths
for my $ts ( $te->tables ) {
    for my $row ( $ts->rows ) {
        next if $$row[0] eq q{Location};
        $$row[6] = defined $$row[6] && $$row[6] ne '' ? $$row[6] : q{};
        $$row[7] = defined $$row[7] && $$row[7] ne '' ? $$row[7] : q{};
        for my $i ( 0..$#$row ) {
            $widths[$i] = length( $$row[$i] ) > $widths[$i] 
                ? length( $$row[$i] ) + 2 
                : $widths[$i];
        }    
    }
}

my $format_length = 0;
for my $w ( @widths ) {  
    $format_length = $format_length + $w + 1; 
}

# build the format string;
my $format = sprintf "%%-%is %%-%is %%-%is %%-%is %%-%is %%-%is %%-%is %%-%is %%-%is\n", @widths;

# Print a header
printf {$ofh} "$format", 
    qw( City Rg Output Input Call Sponsor CTCSS Notes Update ) 
    or croak qq{ERROR: $OS_ERROR};

# Run through the entire table again, with output.
print {$ofh} "-" x $format_length . qq{\n} or croak qq{ERROR: $OS_ERROR};
for my $ts ( $te->tables ) {
    for my $row ( $ts->rows ) {
        next if $$row[0] eq q{Location};
        $$row[6] = defined $$row[6] && $$row[6] ne '' ? $$row[6] : q{};
        $$row[7] = defined $$row[7] && $$row[7] ne '' ? $$row[7] : q{};
        printf {$ofh} "$format", @$row or croak qq{ERROR: $OS_ERROR};
    }
}

# vim: sw=4 ts=4 et ft=perl
