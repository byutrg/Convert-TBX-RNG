package XML::TBX::Dialect;
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
    OK => [ qw(core_structure_rng) ],#TODO: add others
);

# VERSION


# ABSTRACT: Create new TBX dialects
=head1 SYNOPSIS

    my $dialect = XML::TBX::Dialect->new(
        xcs => '/path/to/xcs'
    );
    print $dialect->as_rng();

=head1 DESCRIPTION

This module allows you to create new resources to work with TBX dialects. Currently it only provides RNG generation from XCS information, but
in the future we plan to add XSD generation and to allow tweaking the core structure DTD.

=cut

__PACKAGE__->new->_run unless caller;

sub _run {
    my ($application) = @_;
    print { $application->{output_fh} }
        $application->message;
}

=head1 METHODS

=head2 C<new>

Creates a new instance of XML::TBX::Dialect.

=cut

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    return $self;
}

=head2 C<new>

Sets the XCS of this dialect. Arguments are identical to those in C<XML::TBX::Dialect::XCS::parse>.

=cut

sub set_xcs {
    my ($self, @xcs_args) = @_;
    my $xcs = TBX::XCS->new();
    # print join ':', @xcs_args;
    $xcs->parse(@xcs_args);
    $self->{xcs} = $xcs;
    # print Dumper $self->{xcs}->get_languages();
    return;
}

=head2 C<new>

Creates an RNG representation of this dialect and returns it in a string pointer. The XCS must already be set.

=cut

sub as_rng {
    my ($self) = @_;
    my $xcs = $self->{xcs};
    if(!$xcs){
        croak "No XCS set yet! Can't create an RNG.";
    }
    my $twig = new XML::Twig(
        pretty_print            => 'indented',
        output_encoding     => 'UTF-8',
        do_not_chain_handlers   => 1, #can be important when things get complicated
        keep_spaces         => 0,
        no_prolog           => 1,
    );

    _add_language_handlers($twig, $xcs->get_languages());
    _add_ref_objects_handlers($twig, $xcs->get_ref_objects());
    _add_data_cat_handlers($twig, $xcs->get_data_cats());

    $twig->parsefile(_core_structure_rng_location());

    my $rng = $twig->sprint;
    return \$rng;
}

#add handlers to add the language choices to the langSet specification
sub _add_language_handlers {
    my ($twig, $languages) = @_;

    #make an RNG spec for xml:lang, to be placed
    my $choice = XML::Twig::Elt->new('choice');
    my @lang_spec = ('choice');
    for my $abbrv(sort keys %$languages){
        XML::Twig::Elt->new('value', $abbrv )->paste($choice);
    }
    $twig->setTwigHandler(
        'define[@name="attlist.langSet"]/attribute[@name="xml:lang"]',
        sub {
            my ($twig, $elt) = @_;
            $choice->paste($elt);
        }
    );
    return;
}

sub _add_ref_objects_handlers{
    my ($rng, $ref_objects) = @_;
    #unimplemented
}

#add the language choices to the xml:lang attribute section
sub _add_data_cat_handlers {
    my ($twig, $data_cats) = @_;
    for my $meta_type (qw(admin adminNote hi)){
        $twig->setTwigHandler(_get_meta_cat_handler($meta_type, $data_cats));
    }
}

sub _get_meta_cat_handler {
    my ($meta_cat, $data_cats) = @_;
    return ("define[\@name='$meta_cat']/element[\@name='$meta_cat']",
        sub {
           my ($twig, $el) = @_;
           unless(exists $data_cats->{$meta_cat}){
               $el->set_outer_xml('<empty/>');
               return;
           }
           #replace children with choices based on data categories
           $el->cut_children;
           my $admin_spec = $data_cats->{$meta_cat};
           my $choice = XML::Twig::Elt->new('choice');
           for my $data_cat(@{$admin_spec}){
               my $group = XML::Twig::Elt->new('group');
               XML::Twig::Elt->new('ref', { name => $data_cat->{datatype} })->
                   paste($group);
               XML::Twig::Elt->parse(
                   '<attribute name="type"><value>' .
                   $data_cat->{name} .
                   '</value></attribute>')->
                   paste($group);
               $group->paste($choice);
            }
            $choice->paste($el);
        }
    );
}

=head2 C<core_structure_rng>

Returns a pointer to a string containing the TBX core structure (version 2) RNG.

=cut

sub core_structure_rng {
    my $rng = read_file(_core_structure_rng_location());
    return \$rng;
}

sub _core_structure_rng_location {
    return path(dist_dir('XML-TBX-Dialect'),'TBXcoreStructV02.rng');
}

1;

