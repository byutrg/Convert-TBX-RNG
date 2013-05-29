#make sure that the core structure RNG validates a TBX file
use strict;
use warnings;
use Test::More 0.88;
plan tests => 2;
use Convert::TBX::RNG qw(core_structure_rng);
use XML::Jing;
use TBX::Checker qw(check);
use Path::Tiny;
use FindBin qw($Bin);
use File::Slurp;

my $corpus_dir = path($Bin, 'corpus');
my $rng_file = path($corpus_dir, 'core.rng');
my $min_tbx = path($corpus_dir, 'min.tbx');
my $tbx_basic_sample = path($corpus_dir, 'TBX-basic-sample.tbx');

#clean up previous test
unlink $rng_file
	if -e $rng_file;
write_file($rng_file, core_structure_rng())
	or die "Couldn't write $rng_file";
# note "wrote $rng_file";

my $jing = XML::Jing->new($rng_file);
subtest 'Correct validation of minimal TBX file' =>
sub {
	plan tests => 2;
	my ($valid, $messages) = check($min_tbx);
	ok($valid, 'TBXChecker')
		or note explain $messages;
	my $error = $jing->validate($min_tbx);
	is($error, undef, 'Core structure RNG')
		or note $error;
};

subtest 'Correct validation of TBX-basic file' =>
sub {
	plan tests => 2;
	my ($valid, $messages) = check($tbx_basic_sample);
	ok($valid, 'TBXChecker')
		or note explain $messages;
	my $error = $jing->validate($tbx_basic_sample);
	is($error, undef, 'Core structure RNG')
		or note $error;
};

#clean up after test
unlink $rng_file;