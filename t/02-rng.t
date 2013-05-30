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
my $temp_xcs = path($corpus_dir, 'temp.xcs');
my $temp_tbx = path($corpus_dir, 'temp.tbx');

#can't use TBXChecker with these because of bad behavior
# my @checker_broken = qw( hiBad.tbx );

# for each block, create an RNG from an XCS file,
# then test it against valid and invalid TBX
# double check validity with TBX::Checker
for my $block(blocks){
    note $block->name;
    #create an RNG and write it to a temporary file
    # my $dialect = XML::TBX::Dialect->new();
    my $xcs = $block->xcs
        or next;
    # print $$xcs;

    # $dialect->set_xcs(file => path($corpus_dir, $xcs));
    my $rng = generate_rng(xcs => $xcs);
    my $rng_tmp = File::Temp->new();
    write_file($rng_tmp, $rng);
    # print $$rng;
    write_file($temp_xcs, $xcs);
    my $jing = XML::Jing->new($rng_tmp->filename);

    for my $good( $block->good ){
        write_file($temp_tbx, $good);
        compare_validation($jing, $temp_tbx, 1);
    }

    for my $bad( $block->bad ){
        write_file($temp_tbx, $bad);
        compare_validation($jing, $temp_tbx, 0);
    }
}

#clean up temp files
unlink $temp_xcs
    if -e $temp_xcs;
unlink $temp_tbx
    if -e $temp_tbx;
# pass in a pre-loaded XML::Jing, the name of the TBX file to check, and a boolean
# representing whether the file should be valid
#  Tests for TBX validity via $jing and via TBX::Checker
sub compare_validation {
    my ($jing, $tbx_file, $expected) = @_;
    subtest 'TBX should ' . ($expected ? q() : 'not ') . 'be valid' =>
    sub {
        plan tests => 2;

        my ($valid, $messages) = check($tbx_file);
        is($valid, $expected, 'TBXChecker')
            or note explain $messages;

        my $error = $jing->validate($tbx_file);
        print $error if defined $error;
        #undefined error means it's valid, defined invalid
        ok((defined($error) xor $expected), 'Core structure RNG')
            or ($error and note $error);
    };
}

__DATA__
=== langSet languages
--- xcs xcs_with_languages
    <langInfo>
        <langCode>en</langCode>
        <langName>English</langName>
    </langInfo>
    <langInfo>
        <langCode>fr</langCode>
        <langName>French</langName>
    </langInfo>
    <langInfo>
        <langCode>de</langCode>
        <langName>German</langName>
    </langInfo>
--- bad tbx_with_body
            <termEntry id="c2">
                <!-- Should fail, since XCS doesn't have Lushootseed -->
                <langSet xml:lang="lut">
                    <tig>
                        <term>bar</term>
                    </tig>
                </langSet>
            </termEntry>
--- good tbx_with_body
            <termEntry id="c2">
                <langSet xml:lang="fr">
                    <tig>
                        <term>bar</term>
                    </tig>
                </langSet>
            </termEntry>

=== admin
--- good tbx_with_body
            <termEntry id="c1">
                <langSet xml:lang="en">
                    <tig>
                        <term>foo</term>
                        <adminGrp>
                            <admin type="annotatedNote" id="fluff" datatype="text" xml:lang="es">fu</admin>
                        </adminGrp>
                    </tig>
                </langSet>
            </termEntry>
--- bad tbx_with_body
            <termEntry id="c1">
                <langSet xml:lang="en">
                    <tig>
                        <term>foo</term>
                        <adminGrp>
                            <admin type="bad_category" id="fluff" datatype="text" xml:lang="es">fu</admin>
                        </adminGrp>
                    </tig>
                </langSet>
            </termEntry>
--- xcs xcs_with_datCats
        <adminSpec name="annotatedNote" datcatId="">
            <contents/>
        </adminSpec>
        <adminNoteSpec name="noteSource" datcatId="">
            <contents/>
        </adminNoteSpec>

=== admin note
--- good tbx_with_body
            <termEntry id="c1">
                <langSet xml:lang="en">
                    <tig>
                        <term>foo</term>
                        <adminGrp>
                            <admin type="annotatedNote" id="fluff" datatype="text" xml:lang="es" target="bar">fu</admin>
                            <adminNote type="noteSource" id="bar" datatype="text" xml:lang="en" target="fluff">bar</adminNote>
                        </adminGrp>
                    </tig>
                </langSet>
            </termEntry>
--- bad tbx_with_body
            <termEntry id="c1">
                <langSet xml:lang="en">
                    <tig>
                        <term>foo</term>
                        <adminGrp>
                            <admin type="annotatedNote" id="fluff" datatype="text" xml:lang="es" target="bar">bar</admin>
                            <adminNote type="bad_category" id="bar" datatype="text" xml:lang="en" target="fluff">baz</adminNote>
                        </adminGrp>
                    </tig>
                </langSet>
            </termEntry>
--- xcs xcs_with_datCats
        <adminSpec name="annotatedNote" datcatId="">
            <contents/>
        </adminSpec>
        <adminNoteSpec name="noteSource" datcatId="">
            <contents/>
        </adminNoteSpec>

=== descripNote
TODO: may need to move this to another file with descrip, since they're related
and descrip is special
--- xcs xcs_with_datCats

        <descripSpec name="context" datcatId="ISO12620A-0503">
            <contents/>
            <levels>langSet termEntry term</levels>
        </descripSpec>
        <descripNoteSpec name="contextDescription" datcatId="">
            <contents/>
        </descripNoteSpec>

--- good tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term>federated database</term>
                        <descripGrp>
                            <descrip type="context" id="foo">Users and applications interface with the federated
                                database managed by the federated server. </descrip>
                            <descripNote type="contextDescription" id="bar" target="foo" xml:lang="en" datatype="text">
                                some description
                            </descripNote>
                        </descripGrp>
                    </tig>
                </langSet>
            </termEntry>

--- bad tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term>federated database</term>
                        <descripGrp>
                            <descrip type="context" id="foo">Users and applications interface with the federated
                                database managed by the federated server. </descrip>
                            <descripNote type="bad_type" id="bar" target="foo" xml:lang="en" datatype="text">
                                some description
                            </descripNote>
                        </descripGrp>
                    </tig>
                </langSet>
            </termEntry>


=== hi
--- SKIP
--- good chomp
hiGood.tbx
--- bad chomp
hiBad.tbx
--- xcs chomp
hi.xcs