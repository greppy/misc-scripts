#!/usr/bin/perl

# The MIT License (MIT)

# Copyright (c) 2013 Matt Okeson-Harlow

# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# wordpress comment spam cleanup

use strict;
use warnings;
use English qw( -no_match_vars );
use Carp;
use DBI;
use Getopt::Long;
use Term::ReadKey;

# database settings
# these can be set to your defaults to avoid having to enter them as cli
# options.

my $database = q{};
my $username = q{};
my $password = q{};
my $prefix = q{wp_};

my $ip_limit = 3;  # how many times does an IP have to be listed to get banned

# flags
my $debug;
my $ip_report;   # print ip counts
my $word_report; # print word counts
my $tables;      # print ip tables block
my $delete;      # do delete
my $verbose;

my $output = q{-};
my $output_fh;
my %ip_list;
my %word_list;
my @delete_id;


# process command line options
my $options_ok = GetOptions(
    'database=s' => \$database,
    'username=s' => \$username,
    'password=s' => \$password,
    'prefix=s'   => \$prefix,
    'output=s'   => \$output,
    'limit=i'    => \$ip_limit,
    'ip'         => \$ip_report,
    'tables'     => \$tables,
    'delete'     => \$delete,
    'word'       => \$word_report,
    'verbose'    => \$verbose,
);

croak q{Username required.} if $username eq q{};
croak q{Database required.} if $database eq q{};

# setup our output filehandle
if ( $output eq q{-} ) {
    $output_fh = \*STDOUT;
}
else {
    open $output_fh, '>', $output or croak qq{ERROR: $OS_ERROR};
}

# if a password is not configured in the script and it is not specified on the
# cli, prompt for one.
if ( $password eq q{} ) {
    print {$output_fh} qq{Enter password for '$username' on '$database': };
    ReadMode 'noecho';
    $password = ReadLine 0;
    chomp $password;
    ReadMode 'normal';
}

print {$output_fh} qq{\nWorking...\n};

# setup the database DSN for later
my $dsn = qq{DBI:mysql:database=$database};

my $comment_table = $prefix . q{comments};

# words that will be checked against comment_author, comment_author_url,
# comment_content
# in vim, select the list, then :!sort
my @banned_list = (
    'acyclovir',
    'adderall',
    'adipex',
    'allegra',
    'ambien',
    'amoxicillin',
    'ativan',
    'carisoprodol',
    'casino',
    'celebrex',
    'cialis',
    'claritin',
    'clomid',
    'codiene',
    'codeine',
    'coumadin',
    'crestor',
    'diflucan',
    'effexor',
    'ephedra',
    'ephedrine',
    'erectile',
    'femdom',
    'fioricet',
    'flexeril',
    'flonase',
    'forex',
    'fuck',
    'hoodia',
    'hydrocodone',
    'incest',
    'ionamin',
    'lamisil',
    'lasix',
    'lexapro',
    'levitra',
    'lipitor',
    'lortab',
    'mevacor',
    'milf',
    'morphine',
    'nexium',
    'nude',
    'oxycodone',
    'oxycontin',
    'parishilton',
    'paxil',
    'percocet',
    'plavix',
    'porn',
    'prevacid',
    'prilosec',
    'propecia',
    'prozac',
    'ringtone',
    'ring tone',
    'rolex',
    'soma',
    'tagamet',
    'tamoxifen',
    'tenuate',
    'tramadol',
    'tramal',
    'ultram',
    'valium',
    'valtrex',
    'viagra',
    'vicodin',
    'vioxx',
    'wellbutrin',
    'xanax',
    'xxx',
    'zithromax',
    'zoloft',
    'zyban',
    'zyrtec',
);

# regexp matches, use this for website url's mostly
my @banned_regexp = (
    '[.]cn/',
    'quizilla[.]com',
);

# setup the database connection
my $dbh = DBI->connect($dsn,$username,$password) 
    or croak qq{ERROR: $DBI::errstr};

# process the banned list
# get the comment ID and IP address
for my $word (@banned_list) { 
    my $sql = qq{
        select comment_ID,comment_author_IP from $comment_table 
        where
        comment_author_url like '%$word%' 
        or comment_content like '%$word%'
        or comment_author like '%$word%'};
    my $sth = $dbh->prepare($sql) or croak qq{ERROR: $DBI::errstr};
    $sth->execute or croak qq{ERROR: $DBI::errstr};
    while ( my ($id,$ip) = $sth->fetchrow_array ) {
        $ip_list{$ip}++;
        push @delete_id, $id;
    }
    $word_list{$word} = $DBI::rows;
    $sth->finish;
}

# process the regexp list
for my $regexp (@banned_regexp) { 
    my $sql = qq{
        select comment_ID,comment_author_IP from $comment_table 
        where
        comment_author_url regexp '$regexp' 
        or comment_content regexp '$regexp'
        or comment_author regexp '$regexp'};
    my $sth = $dbh->prepare($sql) or croak qq{ERROR: $DBI::errstr};
    $sth->execute or croak qq{ERROR: $DBI::errstr};
    while ( my ($id,$ip) = $sth->fetchrow_array ) {
        $ip_list{$ip}++;
        push @delete_id, $id;
    }
    $word_list{$regexp} = $DBI::rows;
    $sth->finish;
}


# reporting

for my $ip ( keys %ip_list) {
    if ( $ip_report) {
        print {$output_fh} qq{IP: $ip : $ip_list{$ip}\n};
    }

    if ($tables) {
        if ( $ip_list{$ip} ge $ip_limit ) {
            print 
                {$output_fh} qq{iptables -A INPUT -p tcp -m tcp --src $ip --dport 80 -j DROP -m comment --comment 'WordPress $database spam'\n}
                or croak qq{ERROR: $OS_ERROR};
        }
    }
}

if ( $word_report ) {
    for my $word ( sort keys %word_list) {
        if ( $word_list{$word} ) { 
            print {$output_fh} qq{WORD : $word : $word_list{$word}\n}
                or croak qq{ERROR: $OS_ERROR};
        }
    }
}

# deleting
if ( $delete ) {
    my $sql = qq{delete from $comment_table where comment_id=?};
    my $sth = $dbh->prepare($sql) or croak qq{ERROR: $DBI::errstr};
    for my $id ( @delete_id ) {
        if ( $verbose ) {
            print {$output_fh} qq{Deleting $id\n} or croak qq{ERROR :$OS_ERROR};
        }
        $sth->execute($id) or croak qq{ERROR: $DBI::errstr};
    }
    $sth->finish or croak qq{ERROR: $DBI::errstr};
}

$dbh->disconnect;
