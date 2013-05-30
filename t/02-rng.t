#make sure that the core structure RNG validates a TBX file
use t::TestRNG;
use Test::More 0.88;
plan tests => 18;
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

=== ref
--- xcs xcs_with_datCats

        <refSpec name="crossReference" datcatId="ISO12620A-1018">
            <contents targetType="element"/>
        </refSpec>

--- good tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term>foo</term>
                        <ref target="bar" type="crossReference" id="foo" datatype="text" xml:lang="en">
                            "foo" and "bar" go together</ref>
                    </tig>
                </langSet>
                <langSet xml:lang="en">
                    <tig>
                        <term id="bar">bar</term>
                    </tig>
                </langSet>
            </termEntry>

--- bad tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term>foo</term>
                        <ref target="bar" type="bad_type" id="foo" datatype="text" xml:lang="en">
                            "foo" and "bar" go together</ref>
                    </tig>
                </langSet>
                <langSet xml:lang="en">
                    <tig>
                        <term id="bar">bar</term>
                    </tig>
                </langSet>
            </termEntry>

=== transac
--- xcs xcs_with_datCats

        <transacSpec name="transactionType" datcatId="ISO12620A-1001">
            <contents/>
        </transacSpec>

--- good tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term id="foo">foo</term>
                        <transacGrp>
                            <transac type="transactionType" id="bar" datatype="text" xml:lang="en" target="foo">
                                random transaction...</transac>
                        </transacGrp>
                    </tig>
                </langSet>
            </termEntry>

--- bad tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term id="foo">foo</term>
                        <transacGrp>
                            <transac type="bad_cat" id="bar" datatype="text" xml:lang="en" target="foo">
                                random transaction...</transac>
                        </transacGrp>
                    </tig>
                </langSet>
            </termEntry>

=== transacNote
--- xcs xcs_with_datCats

        <transacSpec name="transactionType" datcatId="ISO12620A-1001">
            <contents/>
        </transacSpec>
        <transacNoteSpec name="generalNote" datcatId="">
            <contents/>
        </transacNoteSpec>

--- good tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term id="foo">foo</term>
                        <transacGrp>
                            <transac type="transactionType" id="bar" datatype="text" xml:lang="en" target="foo">
                                random transaction...</transac>
                            <transacNote type="generalNote" id="baz" datatype="text" xml:lang="en" target="bar">
                                just random</transacNote>
                        </transacGrp>
                    </tig>
                </langSet>
            </termEntry>

--- bad tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term id="foo">foo</term>
                        <transacGrp>
                            <transac type="transactionType" id="bar" datatype="text" xml:lang="en" target="foo">
                                random transaction...</transac>
                            <transacNote type="bad_cat" id="baz" datatype="text" xml:lang="en" target="bar">
                                just random</transacNote>
                        </transacGrp>
                    </tig>
                </langSet>
            </termEntry>

=== termCompList
--- xcs xcs_with_datCats

        <termCompListSpec name="termElement" datcatId="ISO12620A-020802">
            <contents forTermComp="yes"/>
        </termCompListSpec>

--- good tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <ntig>
                        <termGrp>
                            <term id="foo">foo-bar</term>
                            <termCompList id="bar" type="termElement">
                                <termComp id="buzz" xml:lang="en">
                                    boo
                                </termComp>
                            </termCompList>
                        </termGrp>
                    </ntig>
                </langSet>
            </termEntry>

--- bad tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <ntig>
                        <termGrp>
                            <term id="foo">foo-bar</term>
                            <termCompList id="bar" type="bad_category">
                                <termComp id="buzz" xml:lang="en">
                                    boo
                                </termComp>
                            </termCompList>
                        </termGrp>
                    </ntig>
                </langSet>
            </termEntry>

=== termNote
--- xcs xcs_with_datCats

        <termNoteSpec name="generalNote" datcatId="">
            <contents/>
        </termNoteSpec>

--- good tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term id="foo">foo</term>
                        <termNote type="generalNote" id="bar" datatype="text" xml:lang="en" target="foo">
                            some note
                        </termNote>
                    </tig>
                </langSet>
            </termEntry>

--- bad tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term id="foo">foo</term>
                        <termNote type="bad_cat" id="bar" datatype="text" xml:lang="en" target="foo">
                            some note
                        </termNote>
                    </tig>
                </langSet>
            </termEntry>

=== termNote with forTermComp
--- SKIP
--- xcs xcs_with_datCats

        <termNoteSpec name="generalNote" datcatId="">
            <contents/>
        </termNoteSpec>

        <termNoteSpec name="compNote" datcatId="">
            <contents forTermComp="yes"/>
        </termNoteSpec>

        <termNoteSpec name="compNote" datcatId="">
            <contents forTermComp="yes"/>
        </termNoteSpec>

--- good tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <ntig>
                        <termGrp>
                            <term id="foo">foo</term>
                            <termNote type="generalNote" id="bar" datatype="text" xml:lang="en" target="foo">
                                some note
                            </termNote>
                            <termNote type="compNote" id="baz" datatype="text" xml:lang="en" target="foo">
                                some note
                            </termNote>
                            <termCompList>
                                <termCompGrp>
                                    <termComp id="buzz" xml:lang="en">
                                        some
                                    </termComp>
                                    <termNote type="compNote" id="biz" datatype="text" xml:lang="en" target="buzz">
                                        some note
                                    </termNote>
                                </termCompGrp>
                            </termCompList>
                        </termGrp>
                    </ntig>
                </langSet>
            </termEntry>

--- bad tbx_with_body
           <termEntry>
                <langSet xml:lang="en">
                    <ntig>
                        <termGrp>
                            <term id="foo">foo</term>
                            <termCompList>
                                <termCompGrp>
                                    <termComp id="buzz" xml:lang="en">
                                        some
                                    </termComp>
                                    <termNote type="generalNote" id="biz" datatype="text" xml:lang="en" target="buzz">
                                        this can't be here!
                                    </termNote>
                                </termCompGrp>
                            </termCompList>
                        </termGrp>
                    </ntig>
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