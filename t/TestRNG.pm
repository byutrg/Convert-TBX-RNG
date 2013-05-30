package t::TestRNG;
use Test::Base -Base;

1;

package t::TestRNG::Filter;
use Test::Base::Filter -base;
use Data::Section::Simple qw (get_data_section);
use Data::Dumper;

my $data = get_data_section;

#create a small XCS with the input language contents
sub xcs_with_languages{
    my ($self, $input) = @_;
    my $xcs = $data->{XCS};
    $xcs =~ s/DATCATS/$data->{datCat}/;
    $xcs =~ s/LANGUAGES/$input/;
    return \$xcs;
}

#create a small XCS with the input datacatset contents
sub xcs_with_datCats{
    my ($self, $input) = @_;
    my $xcs = $data->{XCS};
    $xcs =~ s/LANGUAGES/$data->{languages}/;
    $xcs =~ s/DATCATS/$input/;
    return \$xcs;
}

#create a small TBX with the input body contents
sub tbx_with_body {
    my ($input) = @_;
    # warn $input;
    my $tbx = $data->{TBX};
    $tbx =~ s/BODY/$input/;
    return \$tbx;
}

1;

__DATA__
@@ XCS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE TBXXCS SYSTEM "tbxxcsdtd.dtd">
<TBXXCS name="Small" version="2" lang="en">
    <header>
        <title>Example XCS file</title>
    </header>

    <languages>
        LANGUAGES
    </languages>

    <datCatSet>
       DATCATS
    </datCatSet>

    <refObjectDefSet>
        <refObjectDef>
            <refObjectType>Foo</refObjectType>
            <itemSpecSet type="validItemType">
                <itemSpec type="validItemType">data</itemSpec>
            </itemSpecSet>
        </refObjectDef>
    </refObjectDefSet>
</TBXXCS>

@@ languages
        <langInfo>
            <langCode>en</langCode>
            <langName>English</langName>
        </langInfo>
@@ datCat
        <xrefSpec name="xrefFoo" datcatId="">
            <contents targetType="external"/>
        </xrefSpec>

@@ TBX
<?xml version='1.0'?>
<!DOCTYPE martif SYSTEM "TBXcoreStructV02.dtd">
<martif type="TBX-Basic" xml:lang="en-US">
    <martifHeader>
        <fileDesc>
            <titleStmt>
                <title>Minimal TBX File</title>
            </titleStmt>
            <sourceDesc>
                <p>Paired down from TBX-Basic Package sample</p>
            </sourceDesc>
        </fileDesc>
        <encodingDesc>
            <p type="XCSURI">temp.xcs
            </p>
        </encodingDesc>
    </martifHeader>
    <text>
        <body>
        BODY
        </body>
    </text>
</martif>
