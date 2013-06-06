#!/usr/bin/env perl
# PODNAME: xcs2rng.pl
#TODO: test this
# VERSION
# ABSTRACT: Create an RNG from an XCS file
#
=head1 DESCRIPTION

Given an XCS file, create an RNG schema which validates TBX files
against the XCS constraints and the core TBX structure.

Passing C<--json> as the first argument will cause the script to expect
an XCS JSON file instead of an XML file.

=cut

use Convert::TBX::RNG qw(generate_rng);
use TBX::XCS;
use TBX::XCS::JSON qw(xcs_from_json);
use File::Slurp;

my $rng;
if($ARGV[0] eq '--json'){
    my $json = read_file($ARGV[1]);
    my $xcs = xcs_from_json($json);
    $rng = generate_rng(xcs => $xcs);
}else{
    $rng = generate_rng(xcs_file => $ARGV[1]);
}

print $$rng;