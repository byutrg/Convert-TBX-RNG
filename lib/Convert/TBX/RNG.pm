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
    OK => [ qw(generate_rng core_structure_rng) ],#TODO: add others
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
print ${ generate_rng(xcs_file => $ARGV[0]) } unless caller;

=head1 METHODS

=head2 C<generate_rng>

Creates an RNG representation of this dialect and returns it in a string pointer.

Currently one argument is requried: C<xcs_file>, which specifies the location of
an XCS file which defines the desired dialect.

=cut

sub generate_rng {
    my (%args) = @_;
    if(! $args{xcs_file}){
        croak "missing 'xcs_file' parameter";
    }
    my $xcs = TBX::XCS->new();
    $xcs->parse(file => $args{xcs_file});

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

=head1 FUTURE WORK

In the future we may provide functionality to tweak the TBX core structure.

=head1 SEE ALSO


1;

