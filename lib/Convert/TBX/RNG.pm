package Convert::TBX::RNG;
use strict;
use warnings;
use TBX::XCS;
use feature 'state';
use File::Slurp;
use Path::Tiny;
use autodie;
use Carp;
use Data::Dumper;
use XML::Twig;
use File::ShareDir 'dist_dir';
use Exporter::Easy (
    OK => [qw(generate_rng core_structure_rng)],    #TODO: add others
);

# VERSION

# ABSTRACT: Create new TBX dialects

=head1 SYNOPSIS
    use Convert::TBX::RNG qw(generate_rng);
    my $rng = generate_rng(xcs_file => '/path/to/xcs');
    print $$rng;

=head1 DESCRIPTION

This module creates RNG files for validating TBX dialects. Currently, the user
can generate RNG using XCS files, but in the future there may be functionality
for tweaking the core structure.

=cut

#when used as a script: take an XCS file name and print an RNG
print ${ generate_rng( xcs_file => $ARGV[0] ) } unless caller;

=head1 METHODS

=head2 C<generate_rng>

Creates an RNG representation of this dialect and returns it in a string pointer.

Currently one argument is requried: C<xcs_file>, which specifies the location of
an XCS file which defines the desired dialect.

=cut

sub generate_rng {
    my (%args) = @_;
    if ( not( $args{xcs_file} || $args{xcs} ) ) {
        croak "requires either 'xcs_file' or 'xcs' parameters";
    }
    my $xcs = TBX::XCS->new();
    if ( $args{xcs_file} ) {
        $xcs->parse( file => $args{xcs_file} );
    }
    else {
        $xcs->parse( string => $args{xcs} );
    }

    my $twig = new XML::Twig(
        pretty_print    => 'indented',
        output_encoding => 'UTF-8',
        do_not_chain_handlers =>
          1,    #can be important when things get complicated
        keep_spaces => 0,
        no_prolog   => 1,
    );

    _add_language_handlers( $twig, $xcs->get_languages() );
    _add_ref_objects_handlers( $twig, $xcs->get_ref_objects() );
    _add_data_cat_handlers( $twig, $xcs->get_data_cats() );

    $twig->parsefile( _core_structure_rng_location() );

    my $rng = $twig->sprint;
    return \$rng;
}

#add handlers to add the language choices to the langSet specification
sub _add_language_handlers {
    my ( $twig, $languages ) = @_;

    #make an RNG spec for xml:lang, to be placed
    my $choice    = XML::Twig::Elt->new('choice');
    my @lang_spec = ('choice');
    for my $abbrv ( sort keys %$languages ) {
        XML::Twig::Elt->new( 'value', $abbrv )->paste($choice);
    }
    $twig->setTwigHandler(
        'define[@name="attlist.langSet"]/attribute[@name="xml:lang"]',
        sub {
            my ( $twig, $elt ) = @_;
            $choice->paste($elt);
        }
    );
    return;
}

sub _add_ref_objects_handlers {
    my ( $rng, $ref_objects ) = @_;

    #unimplemented
}

# add the language choices to the xml:lang attribute section
sub _add_data_cat_handlers {
    my ( $twig, $data_cats ) = @_;

# impIDLangTypTgtDtyp includes: admin(Note), descrip(Note), ref, termNote, transac(Note)
# must account for ID, xml:lang, type, target, and datatype
    for my $meta_cat (
        qw(admin adminNote
        descripNote ref transac transacNote termNote descrip)
      )
    {
        $twig->setTwigHandler(
          "define[\@name='$meta_cat']/element[\@name='$meta_cat']",
            _get_meta_cat_handler(
                $data_cats->{$meta_cat}
            )
        );

        #we no longer use the attlists
        $twig->setTwigHandler( qq<define[\@name="attlist.$meta_cat"]>,
            sub { $_->delete } );
    }

    # termNote: unless forTermComp="yes", remove from termCompGrp contents
    # if()
    # TODO: what about termNoteGrp?


    # no longer use the attlists
    # $twig->setTwigHandler('define[@name="attlist.termNote"]', sub {$_->delete});

   # descrip and termNote are like above, but with levels
   # $twig->setTwigHandler('define[@name="attlist.descrip"]', sub {$_->delete});

    # we leave no reference to this entity
    $twig->setTwigHandler( 'define[@name="impIDLangTypTgtDtyp"]',
        sub { $_->delete } );

    # impIDType includes xref
    # ID, type (URI)

    # <termCompList>
    # ID, type

    # <hi>
    # type target xml:lang
}

# args: array ref containing data cat specs for a meta-data category
# handles elements of impIDLangTypTgtDtyp which do not have level specifications
sub _get_meta_cat_handler {
    my ( $data_cat_list ) = @_;
    return
        sub {
            my ( $twig, $el ) = @_;
            #disallow content if none specified
            unless ( $data_cat_list ) {
                $el->set_outer_xml('<empty/>');
                return;
            }

            #replace children with rng:choice, with contents based on data categories
            $el->cut_children;
            my $choice = XML::Twig::Elt->new('choice');
            for my $data_cat ( @{$data_cat_list} ) {
                _get_rng_group_for_datacat($data_cat)->paste($choice);
            }
            $choice->paste($el);

            #allow ID, xml:lang, target, and datatype
            XML::Twig::Elt->new( 'ref', { name => 'impIDLangTgtDtyp' } )
              ->paste($el);
        };
}

#arg: hash ref containing data category information
sub _get_rng_group_for_datacat {
    my ($data_cat) = @_;
    my $group = XML::Twig::Elt->new('group');
    if ( $data_cat->{datatype} eq 'picklist' ) {
        _get_rng_picklist( $data_cat->{choices} )->paste($group);
    }
    else {
        XML::Twig::Elt->new( 'ref',
            { name => $data_cat->{datatype} } )->paste($group);
    }
    _get_rng_attribute( 'type', $data_cat->{name} )->paste($group);
    return $group;
}

sub _get_rng_attribute {
    my ($name, $value) = @_;
    return XML::Twig::Elt->parse(
        '<attribute name="' . $name . '"><value>' . $value . '</value></attribute>' );
}

#create a <choice> element containing values from an array ref
sub _get_rng_picklist {
    my ($picklist) = @_;
    my $choice = XML::Twig::Elt->new('choice');
    for my $value ($picklist) {
        XML::Twig::Elt->new( 'value', $value )->paste($choice);
    }
    return $choice;
}

=head2 C<core_structure_rng>

Returns a pointer to a string containing the TBX core structure (version 2) RNG.

=cut

sub core_structure_rng {
    my $rng = read_file( _core_structure_rng_location() );
    return \$rng;
}

sub _core_structure_rng_location {
    return path( dist_dir('XML-TBX-Dialect'), 'TBXcoreStructV02.rng' );
}

=head1 GOTCHAS

RNG does not validate IDREF attributes, unlike DTD. Therefore, you will not
be able to check that target attributes refer to actual IDs within the file.

=head1 FUTURE WORK

In the future we may provide functionality to tweak the TBX core structure.

=head1 SEE ALSO


1;

