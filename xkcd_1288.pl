#!/usr/bin/perl

# Inspired by http://xkcd.com/1288
# I hope I am not the only one that decided to write a filtering proxy to do
# this.
# Matt Okeson-Harlow matt@technomage.net 
# This script is licensed under the same license as the comic that inspired
# it:  http://creativecommons.org/licenses/by-nc/2.5/
# Creative Commons Attribution-NonCommercial 2.5 License.

use strict;
use warnings;
use Getopt::Long;
use HTTP::Proxy;

{
    package XKCDFilter;
    use base qw( HTTP::Proxy::BodyFilter );

    sub filter {
        my ( $self, $dataref, $message, $protocol, $buffer ) = @_;
        $$dataref =~ s{witnesses}{these dudes I know}ig;
        $$dataref =~ s{allegedly}{kinda probably}ig;
        $$dataref =~ s{new study}{tumbler post}ig;
        $$dataref =~ s{rebuild}{avenge}ig;
        $$dataref =~ s{space}{spaaace}ig;
        $$dataref =~ s{google glass}{virtual boy}ig;
        $$dataref =~ s{smartphone}{pokedex}ig;
        $$dataref =~ s{electric}{atomic}ig;
        $$dataref =~ s{senator}{elf-lord}ig;
        $$dataref =~ s{car}{cat}ig;
        $$dataref =~ s{election}{eating contest}ig;
        $$dataref =~ s{congressional leaders}{river spirits}ig;
        $$dataref =~ s{homeland security}{homestar runner}ig;
        $$dataref =~ s{could not be reached for comment}{is guilty and everyone knows it}ig;
    }
}
my $port = 3128;

my $options_ok = GetOptions( 
    'port=i'    => \$port,
);

my $proxy = HTTP::Proxy->new( port => $port );
$proxy->push_filter( response => XKCDFilter->new() );
$proxy->start;

