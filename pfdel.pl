#!/usr/bin/perl

# Inspiried by a script I found at:
# http://www.ustrem.org/en/articles/postfix-queue-delete-en/
# and
# http://stage.seaglass.com/downloads/pfdel.pl

use strict;
use warnings;
use English qw( -no_match_vars );
use Carp;
use Getopt::Long;
use Pod::Usage;

my @input_email = ();
my ( $man, $help, $verbose, $dryrun );

my $options_ok = GetOptions(
    'email=s' => \@input_email,
    'man'     => \$man,
    'help'    => \$help,
    'verbose' => \$verbose,
    'dryrun'  => \$dryrun,
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $man;
pod2usage( -verbose => 1 ) if $help;

# Change these paths if necessary.
my $postqueue = q{/usr/sbin/postqueue -p};
my $postsuper = q{/usr/sbin/postsuper};

open my $queue, qq{$postqueue |}
    or croak qq{Can't get pipe to $postqueue: $OS_ERROR\n};

$INPUT_RECORD_SEPARATOR = q{};    # Rest of queue entries print on
                                  # multiple lines.
while ( my $entry = <$queue> ) {
    next if $entry =~ m{\A-}xms;    # skip the header

    # process each email address passed as input
    for my $email_addr (@input_email) {
        if ( $entry =~ / $email_addr$/m ) {
            my ($qid) = split( /\s+/, $entry, 2 );
            $qid =~ s{[\*\!]}{};    # remove * and ! from $qid
            if ( $verbose or $dryrun ) {
                print qq{$email_addr $qid\n};
                print $entry;
                print q{=} x 80 . qq{\n};
            }
            next unless ($qid);

            # Execute postsuper -d with the queue id.
            # postsuper provides feedback when it deletes
            # messages. Let its output go through.
            if ( not $dryrun ) {
                if ( $EUID == 0 ) {
                    if ( system( $postsuper, "-d", $qid ) != 0 ) {
                        # If postsuper has a problem, bail.
                        croak qq{Error executing $postsuper: }
                            . ( $CHILD_ERROR / 256 ) . qq{\n};
                    }
                }
                else {
                    die qq{Must execute as root to delete queue files.\n};
                }
            }
        }
    }
}
close($queue);

__END__
# Documentation

=head1 NAME

pfdel.pl

=head1 DESCRIPTION

Perl script to delete messages from a postfix mail queue based on email address
in either the sender or recipient field.

=head1 ARGUMENTS

=over

=item --email I<EMAIL_ADDRESS>

This can be done multiple times, each additional address is added to an array.

=back

=head1 OPTIONS

=over

=item --verbose

Print the matching queue ID and email address followed by the raw queue output
for that entry.

=item --dryrun

Print the verbose output, but do not delete anything.

=item --help

Give a short help message.

=item --man

Give the documentation for this script.

=back

=head1 COPYRIGHT

The MIT License (MIT)

Copyright (c) 2013 Matt Okeson-Harlow

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut

# vim: ai ts=4 sts=4 et sw=4 ft=perl
