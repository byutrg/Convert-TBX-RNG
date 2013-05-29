#make sure that the core structure RNG validates a TBX file
use t::TestRNG;
use Test::More 0.88;
plan tests => 6;
use Convert::TBX::RNG qw(generate_rng);
use XML::Jing;
use TBX::Checker qw(check);
use Path::Tiny;
use FindBin qw($Bin);
use File::Slurp;

my $corpus_dir = path($Bin, 'corpus');

#can't use TBXChecker with these because of bad behavior
my @checker_broken = qw( hiBad.tbx );

# for each block, create an RNG from an XCS file,
# then test it against valid and invalid TBX
# double check validity with TBX::Checker
for my $block(blocks){
	note $block->name;
	#create an RNG and write it to a temporary file
	# my $dialect = XML::TBX::Dialect->new();
	my $xcs = $block->xcs
		or next;
	# $dialect->set_xcs(file => path($corpus_dir, $xcs));
	my $rng = generate_rng(xcs_file => path($corpus_dir, $xcs));
	my $tmp = File::Temp->new();
	write_file($tmp, $rng);
	# print $$rng;
	my $jing = XML::Jing->new($tmp->filename);

	for my $good( $block->good ){
		compare_validation($jing, path($corpus_dir, $good), 1);
	}
	for my $bad( $block->bad ){
		compare_validation($jing, path($corpus_dir, $bad), 0);
	}
}

# pass in a pre-loaded XML::Jing, the name of the TBX file to check, and a boolean
# representing whether the file should be valid
#  Tests for TBX validity via $jing and via TBX::Checker
sub compare_validation {
	my ($jing, $tbx_file, $expected) = @_;
	subtest $tbx_file->basename . ' should ' . ($expected ? q() : 'not ') . 'be valid' =>
	sub {
		plan tests => 2;
		my ($valid, $messages);
		#some files can't be checked with the TBXChecker
		if(grep {$_ eq $tbx_file->basename} @checker_broken){
			ok(1, 'Skip TBX::Checker validation');
		}else{
			($valid, $messages) = check($tbx_file);
			is($valid, $expected, 'TBXChecker')
				or note explain $messages;
		}

		my $error = $jing->validate($tbx_file);
		print $error if defined $error;
		#undefined error means it's valid, defined invalid
		ok((defined($error) xor $expected), 'Core structure RNG')
			or ($error and note $error);
	};
}

__DATA__
=== langSet languages
--- xcs: small.xcs
--- bad: langTestBad.tbx
--- good lines chomp
langTestGood.tbx
langTestGood2.tbx

=== admin and adminNote
--- good chomp
adminGood.tbx
--- bad lines chomp
adminBad.tbx
adminNoteBad.tbx
--- xcs chomp
admin.xcs

=== hi
--- SKIP
--- good chomp
hiGood.tbx
--- bad chomp
hiBad.tbx
--- xcs chomp
hi.xcs