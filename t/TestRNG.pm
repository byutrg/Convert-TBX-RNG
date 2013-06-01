package t::TestRNG;
use Test::Base -Base;
use Test::More 0.88;
use TBX::Checker qw(check);
use File::Slurp;
use File::Temp;
use FindBin qw($Bin);
use Path::Tiny;
use feature 'state';
our @EXPORT = qw(compare_validation remove_temps);

my $corpus_dir = path($Bin, 'corpus');
my $temp_xcs = path($corpus_dir, 'temp.xcs');

# pass in a pre-loaded XML::Jing, the name of the TBX file to check, and a boolean (expect to pass?)
# representing whether the file should be valid
#  Tests for TBX validity via $jing and via TBX::Checker
sub compare_validation {
    # (my ($self), @_) = find_my_self(@_); #doesn't work quite right...
    my ($jing, $tbx_string, $should_pass) = @_;

    state $temp_tbx = File::Temp->new(TEMPLATE => 'tbx.temp.XXXX', DIR => $corpus_dir);
    write_file($temp_tbx->filename, $tbx_string);

    subtest 'TBX should ' . ($should_pass ? q() : 'not ') . 'be valid' =>
    sub {
        plan tests => 3 - ($should_pass ? 1 : 0);

        my ($valid, $messages) = check($temp_tbx->filename);
        is($valid, $should_pass, 'TBXChecker')
            or note explain $messages;
        if(!$should_pass){
            ok((grep {$_ =~ /XCS Adherence Errors/} @$messages),
                'XCS adherence was the cause of failure');
        }

        my $error = $jing->validate($temp_tbx->filename);
        #undefined error means it's valid, defined invalid
        ok((defined($error) xor $should_pass), 'Generated RNG')
            or ($error and note $error);
    };
    # unlink $temp_tbx;
}

#delete temporary files used for testing
sub remove_temps {
    unlink $temp_xcs;
}

1;

package t::TestRNG::Filter;
use Test::Base::Filter -base;
use Data::Section::Simple qw (get_data_section);
use File::Temp;
use File::Slurp;
use File::Temp;
use feature 'state';

#write the xcs to a temp file and return a File::Temp object
sub write_xcs{
    my ($self, $xcs_contents) = @_;
    # print $$xcs_contents;
    write_file($temp_xcs, $xcs_contents);
    return $temp_xcs;
}

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
