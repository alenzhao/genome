package Genome::Model::ClinSeq::Command::AnnotateGenesByDgidb;

use strict;
use warnings;
use Genome;
use File::Basename;

class Genome::Model::ClinSeq::Command::AnnotateGenesByDgidb {
    is        => 'Command::V2',
    has_input => [
        input_file => {
            is  => 'FilesystemPath',
            doc => 'tsv formatted file to added DGIDB annotations to',
        },
        gene_name_regex => {
            is  => 'Text',
            doc => 'regular expression of column names containing gene names/symbols'
        },
    ],
    has_input_output => [
        output_dir => {
            is          => 'FilesystemPath',
            is_optional => 1,
            doc => 'result directory of DGIDB output, it will create a xxx.dgidb subdir under input file source dir',
        },
    ],
    doc => 'take a tsv file as input, extract gene list and annotate genes against DGIDB',
};

sub help_synopsis {
    return <<EOS
    genome model clin-seq annotate-genes-by-dgidb --input-file=/clinseq_build_path/AML103/snv/wgs_exome/snvs.hq.tier1.v1.annotated.compact.readcounts.tsv --gene-name-column=mapped_gene_name 
EOS
}

sub help_detail {
    return <<EOS
    Generate a DGIDB gene annotation output. It will run dgidb guery gene with three options:
    1. All interactions
    2. Expert curated interaction sources only + antineoplastic drugs only
    3. All interactions but limiting to kinases only
EOS
}

sub execute {
    my $self            = shift;
    my $infile          = $self->input_file;
    my $gene_name_regex = $self->gene_name_regex;

    $self->debug_message(
        "Adding DGIDB gene annotation to $infile using genes in this gene name column: $gene_name_regex");

    my $reader = Genome::Utility::IO::SeparatedValueReader->create(
        input     => $infile,
        separator => "\t",
    );

    my $gene_list = __PACKAGE__->convert($reader, $gene_name_regex);
    unless ($gene_list) {
        $self->warning_message("gene list is empty.  Will not annotate. Check $infile") unless $gene_list;
        return 1;
    }

    my $outdir_name = $self->_prepare_output_directory;

    my @parameter_sets = (
        {output_file => "$outdir_name/all_interactions.tsv"},
        {
            output_file         => "$outdir_name/expert_antineoplastic.tsv",
            source_trust_levels => 'Expert curated',
            antineoplastic_only => 1,
        },
        {
            output_file     => "$outdir_name/kinase_only.tsv",
            gene_categories => 'KINASE',
        },
    );

    for my $parameter_set (@parameter_sets) {
        my $cmd = Genome::Model::Tools::Dgidb::QueryGene->create(%$parameter_set, genes => $gene_list,);

        unless ($cmd->execute) {
            die $self->error_message("Failed to run gmt dgidb query-gene on gene list: $gene_list");
        }
    }

    return 1;
}

sub convert {
    my ($class, $reader, $column_regex) = @_;
    my %list;

    while (my $data = $reader->next) {
        my $flag = 0;
        for my $column_name (keys %$data) {
            if ($column_name =~ /$column_regex/) {
                $list{$data->{$column_name}} = 1;
                $flag++;
            }
        }
        die "$column_regex not found in file" unless $flag;
    }

    return join ',', sort keys %list;
}

sub _prepare_output_directory {
    my $self = shift;

    unless ($self->output_dir) {
        my $infile = $self->input_file;
        my ($outdir_name, $dir) = fileparse($infile);
        $outdir_name .= '.dgidb';
        $outdir_name = $dir . $outdir_name;
        $self->output_dir($outdir_name);
    }

    my $outdir_name = $self->output_dir;
    Genome::Sys->create_directory($outdir_name) or die "Failed to create directory $outdir_name";

    return $outdir_name;
}

1;

