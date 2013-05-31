#make sure that generated RNG validates the TBX/XCS pairs that TBX::Checker does
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
        #undefined error means it's valid, defined invalid
        ok((defined($error) xor $expected), 'Generated RNG')
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
TODO: TBXChecker doesn't verify this
--- SKIP
--- xcs xcs_with_datCats

        <termCompListSpec name="termElement" datcatId="ISO12620A-020802">
            <contents forTermComp="yes"/>
        </termCompListSpec>

        <termNoteSpec name="generalNote" datcatId="">
            <contents/>
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
                            <termCompList type="termElement">
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
                            <termCompList type="termElement">
                                <termCompGrp>
                                    <termComp id="buzz" xml:lang="en">
                                        some
                                    </termComp>
                                    <!-- This is disallowed at this level-->
                                    <termNote type="generalNote" id="biz" datatype="text" xml:lang="en" target="buzz">
                                        bad note
                                    </termNote>
                                </termCompGrp>
                            </termCompList>
                        </termGrp>
                    </ntig>
                </langSet>
            </termEntry>

=== termNote with forTermComp, in termNoteGrp
TODO: TBXChecker doesn't verify this
--- SKIP
--- xcs xcs_with_datCats

        <termCompListSpec name="termElement" datcatId="ISO12620A-020802">
            <contents forTermComp="yes"/>
        </termCompListSpec>

        <termNoteSpec name="generalNote" datcatId="">
            <contents/>
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
                            <termCompList type="termElement">
                                <termCompGrp>
                                    <termComp id="buzz" xml:lang="en">
                                        some
                                    </termComp>
                                    <termNoteGrp id="quz">
                                        <termNote type="compNote" id="biz" datatype="text" xml:lang="en" target="buzz">
                                            some note
                                        </termNote>
                                        <note>Here is a group!</note>
                                    </termNoteGrp>
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
                            <termCompList type="termElement">
                                <termCompGrp>
                                    <termComp id="buzz" xml:lang="en">
                                        some
                                    </termComp>
                                    <!-- This is disallowed at this level-->
                                    <termNoteGrp id="quz">
                                        <termNote type="bad_cat" id="biz" datatype="text" xml:lang="en" target="buzz">
                                            some note
                                        </termNote>
                                        <note>Here is a group!</note>
                                    </termNoteGrp>
                                </termCompGrp>
                            </termCompList>
                        </termGrp>
                    </ntig>
                </langSet>
            </termEntry>

=== hi
TODO: TBXChecker doesn't verify this
--- SKIP
--- xcs xcs_with_datCats

        <hiSpec name="emph" datcatId="">
            <contents/>
        </hiSpec>

--- good tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term id="foo"><hi type="emph" target="foo" xml:lang="en">foo</hi>
                        <hi target="foo" xml:lang="en">bar</hi></term>
                    </tig>
                </langSet>
            </termEntry>

--- bad tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <tig>
                        <term id="foo"><hi type="bad_cat" target="foo" xml:lang="en">foo</hi></term>
                    </tig>
                </langSet>
            </termEntry>

=== xref
TODO: TBXChecker doesn't verify this
--- SKIP
--- xcs xcs_with_datCats

        <xrefSpec name="wikipedia" datcatId="">
            <contents/>
        </xrefSpec>

--- good tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <xref id="fooBar" type="wikipedia"
                        target="http://en.wikipedia.org/wiki/Foobar">
                        see Wikipedia
                    </xref>
                    <tig>
                        <term id="foo">foo bar</term>
                    </tig>
                </langSet>
            </termEntry>

--- bad tbx_with_body
            <termEntry>
                <langSet xml:lang="en">
                    <xref id="fooBar" type="bad_cat"
                        target="http://en.wikipedia.org/wiki/Foobar">
                        see Wikipedia
                    </xref>
                    <tig>
                        <term id="foo">foo bar</term>
                    </tig>
                </langSet>
            </termEntry>

=== descrip
--- ONLY
--- xcs xcs_with_datCats

        <descripSpec name="general" datcatId="">
            <contents/>
            <levels>term termEntry langSet</levels>
        </descripSpec>

        <descripSpec name="termLangSet" datcatId="">
            <contents/>
            <levels>term langSet</levels>
        </descripSpec>

        <descripSpec name="termEntryLangSet" datcatId="">
            <contents/>
            <levels>termEntry langSet</levels>
        </descripSpec>

        <descripSpec name="termEntryTerm" datcatId="">
            <contents/>
            <levels>termEntry term</levels>
        </descripSpec>

        <descripSpec name="term" datcatId="">
            <contents/>
            <levels>term</levels>
        </descripSpec>

        <descripSpec name="termEntry" datcatId="">
            <contents/>
            <levels>termEntry</levels>
        </descripSpec>

        <descripSpec name="langSet" datcatId="">
            <contents/>
            <levels>langSet</levels>
        </descripSpec>

--- good tbx_with_body
            <!-- Test all locations of descrip and descripGrp -->
            <termEntry id="entry">

                <!-- Descrips allowed in termEntry level -->
                <descrip type="general" xml:lang="en" id="desc1" target="entry" datatype="text">
                    description
                </descrip>
                <descrip type="termEntryLangSet" xml:lang="en" id="desc2" target="entry" datatype="text">
                    description
                </descrip>
                <descrip type="termEntryTerm" xml:lang="en" id="desc3" target="entry" datatype="text">
                    description
                </descrip>
                <descrip type="termEntry" xml:lang="en" id="desc4" target="entry" datatype="text">
                    description
                </descrip>

                <descripGrp>
                    <descrip type="general" xml:lang="en" id="desc5" target="entry" datatype="text">
                        description
                    </descrip>
                </descripGrp>
                <descripGrp>
                    <descrip type="termEntryLangSet" xml:lang="en" id="desc6" target="entry" datatype="text">
                        description
                    </descrip>
                </descripGrp>
                <descripGrp>
                    <descrip type="termEntryTerm" xml:lang="en" id="desc7" target="entry" datatype="text">
                        description
                    </descrip>
                </descripGrp>
                <descripGrp>
                    <descrip type="termEntry" xml:lang="en" id="desc8" target="entry" datatype="text">
                        description
                    </descrip>
                </descripGrp>
                <!-- End descrips -->

                <langSet xml:lang="en" id="langSet">

                    <!-- Descrips allowed in langSet level -->
                    <descrip type="general" xml:lang="en" id="desc9" target="langSet" datatype="text">
                        description
                    </descrip>
                    <descrip type="termEntryLangSet" xml:lang="en" id="desc10" target="langSet" datatype="text">
                        description
                    </descrip>
                    <descrip type="termLangSet" xml:lang="en" id="desc11" target="langSet" datatype="text">
                        description
                    </descrip>
                    <descrip type="langSet" xml:lang="en" id="desc12" target="langSet" datatype="text">
                        description
                    </descrip>

                    <descripGrp>
                        <descrip type="general" xml:lang="en" id="desc13" target="langSet" datatype="text">
                            description
                        </descrip>
                    </descripGrp>
                    <descripGrp>
                        <descrip type="termEntryLangSet" xml:lang="en" id="desc14" target="langSet" datatype="text">
                            description
                        </descrip>
                    </descripGrp>
                    <descripGrp>
                        <descrip type="termLangSet" xml:lang="en" id="desc15" target="langSet" datatype="text">
                            description
                        </descrip>
                    </descripGrp>
                    <descripGrp>
                        <descrip type="langSet" xml:lang="en" id="desc16" target="langSet" datatype="text">
                            description
                        </descrip>
                    </descripGrp>
                    <!-- End descrips -->

                    <tig>
                        <term id="term1">foo bar</term>

                        <!-- Descrips allowed in term level -->
                        <descrip type="general" xml:lang="en" id="desc17" target="term1" datatype="text">
                            description
                        </descrip>
                        <descrip type="termEntryTerm" xml:lang="en" id="desc18" target="term1" datatype="text">
                            description
                        </descrip>
                        <descrip type="termLangSet" xml:lang="en" id="desc19" target="term1" datatype="text">
                            description
                        </descrip>
                        <descrip type="term" xml:lang="en" id="desc20" target="term1" datatype="text">
                            description
                        </descrip>

                        <descripGrp>
                            <descrip type="general" xml:lang="en" id="desc21" target="term1" datatype="text">
                                description
                            </descrip>
                        </descripGrp>
                        <descripGrp>
                            <descrip type="termEntryTerm" xml:lang="en" id="desc22" target="term1" datatype="text">
                                description
                            </descrip>
                        </descripGrp>
                        <descripGrp>
                            <descrip type="termLangSet" xml:lang="en" id="desc23" target="term1" datatype="text">
                                description
                            </descrip>
                        </descripGrp>
                        <descripGrp>
                            <descrip type="term" xml:lang="en" id="desc24" target="term1" datatype="text">
                                description
                            </descrip>
                        </descripGrp>
                        <!-- End descrips -->

                    </tig>
                    <ntig id="ntig">

                        <termGrp>
                            <term id="term2">baz</term>
                        </termGrp>

                        <!-- Descrips allowed in term level -->
                        <descrip type="general" xml:lang="en" id="desc25" target="ntig" datatype="text">
                            description
                        </descrip>
                        <descrip type="termEntryTerm" xml:lang="en" id="desc26" target="ntig" datatype="text">
                            description
                        </descrip>
                        <descrip type="termLangSet" xml:lang="en" id="desc27" target="ntig" datatype="text">
                            description
                        </descrip>
                        <descrip type="term" xml:lang="en" id="desc28" target="ntig" datatype="text">
                            description
                        </descrip>

                        <descripGrp>
                            <descrip type="general" xml:lang="en" id="desc29" target="ntig" datatype="text">
                                description
                            </descrip>
                        </descripGrp>
                        <descripGrp>
                            <descrip type="termEntryTerm" xml:lang="en" id="desc30" target="ntig" datatype="text">
                                description
                            </descrip>
                        </descripGrp>
                        <descripGrp>
                            <descrip type="termLangSet" xml:lang="en" id="desc31" target="ntig" datatype="text">
                                description
                            </descrip>
                        </descripGrp>
                        <descripGrp>
                            <descrip type="term" xml:lang="en" id="desc32" target="ntig" datatype="text">
                                description
                            </descrip>
                        </descripGrp>
                        <!-- End descrips -->

                    </ntig>
                </langSet>
            </termEntry>
