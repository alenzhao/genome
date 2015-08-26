package Genome::Model::RnaSeq::Command::DetectFusions::Chimerascan::FilterOutput;

use strict;
use warnings;

use Genome;
use Genome::File::BedPe::Entry;
use Genome::File::BedPe::Reader;

class Genome::Model::RnaSeq::Command::DetectFusions::Chimerascan::FilterOutput {
    is  => 'Command::V2',
    has_input => [
        bedpe_file => {
            is => 'Text',
        },
        output_file => {
            is => 'Text',
        },
        total_frag_limit => {
            is => 'Number',
            is_optional   => 1,
            default_value => 5,
        },
        span_frag_limit  => {
            is => 'Number',
            is_optional   => 1,
            default_value => 1,
        },
        fusion_partner_limit => {
            is => 'Number',
            is_optional   => 1,
            default_value => 3,
        },
        annotation_build_id => {
            is => 'Text',
        },
        annotation_build => {
            is    => 'Genome::Model::Build::ImportedAnnotation',
            id_by => 'annotation_build_id',
        },
    ],
    has_output => [
        filtered_bedpe_file => {
            is => 'Text',
        },
    ],
    has_param => [
        lsf_queue => {
            default_value => Genome::Config::get('lsf_queue_build_worker_alt'),
            is_optional => 1,
            doc => 'queue to use when running in a workflow',
        },
    ],
};


sub execute {
    my $self = shift;

    my $bedpe_file           = $self->bedpe_file;
    my $output_file          = $self->output_file;
    my $total_frag_limit     = $self->total_frag_limit;
    my $span_frag_limit      = $self->span_frag_limit;
    my $fusion_partner_limit = $self->fusion_partner_limit;
    my $annot_build          = $self->annotation_build;

    my @headers      = qw(Fusion 5P 3P Id_5p Id_3p geneId_5p geneId_3p Total_Frag Spanning_Frag Type Span:Total);
    my @bedpe_fields = @Genome::File::BedPe::Entry::ALL_FIELDS;
    $bedpe_fields[0] = '#'.$bedpe_fields[0];
    my @all_headers  = (@bedpe_fields, @headers);

    my $writer = Genome::Utility::IO::SeparatedValueWriter->create(
        headers   => \@all_headers,
        separator => "\t",
        output    => $output_file,
    );

    my $reader = Genome::File::BedPe::Reader->new($bedpe_file);
    my (%FP_ct, %TP_ct, %output);
    
    #cache transcript and external gene id
    my %params = (
        reference_build_id => $annot_build->reference_sequence_id,
        data_directory     => $annot_build->_annotation_data_directory,
    );
    my @cached_egi = Genome::ExternalGeneId->get(%params, id_type => 'ensembl');
    my @cached_transcripts = Genome::Transcript->get(%params);

    while (my $entry = $reader->next) {
        my $score = $entry->{score};
        my ($id_5p, $id_3p, $FP, $TP, $type, $total_frag, $span_frag, $repeat) = map{$entry->{custom}->[$_]}qw(0 1 2 3 4 6 7 11);
        $FP_ct{$FP}++;
        $TP_ct{$TP}++;

        next if $FP eq $TP;
        next if $repeat and $repeat =~ /AAAAAAAAAA|TTTTTTTTTT|GGGGGGGGGG|CCCCCCCCCC/;
        next if $total_frag == $span_frag;

        my $fusion = $FP . ':' . $TP;
        
        my %bedpe_content;
        @bedpe_content{@bedpe_fields} = map{$entry->{$_}}@bedpe_fields;
        $bedpe_content{'#chrom1'}     = $entry->{chrom1};

        $output{$fusion}->{total_frag} += $total_frag;
        $output{$fusion}->{span_frag}  += $span_frag;
        $output{$fusion}->{score}      += $score;
        $output{$fusion}->{type}        = $type;
        $output{$fusion}->{span_total}  = $span_frag . ':' . $total_frag;
        $output{$fusion}->{id_5p}       = $id_5p;
        $output{$fusion}->{id_3p}       = $id_3p;
        $output{$fusion}->{geneId_5p}   = $self->_get_gene_ids($id_5p, \%params);
        $output{$fusion}->{geneId_3p}   = $self->_get_gene_ids($id_3p, \%params);
        $output{$fusion}->{bedpe_entry} = \%bedpe_content;
    }

    for my $fusion (sort keys %output) {
        my ($FP, $TP) = split /\:/, $fusion;
        next unless $FP_ct{$FP} <= $fusion_partner_limit and $TP_ct{$TP} <= $fusion_partner_limit;

        my $total_frag  = $output{$fusion}->{total_frag};
        my $span_frag   = $output{$fusion}->{span_frag};
        my $span_total  = $output{$fusion}->{span_total};
        my $bedpe_entry = $output{$fusion}->{bedpe_entry};

        my $sample_freq = 0;
        if ($span_total) {
            my ($s) = $span_total =~ /^(\S+)\:/;
            $sample_freq++ if $s != 0;
        }

        if (($sample_freq == 1 || $sample_freq == 2) 
            and $total_frag >= $total_frag_limit
            and $span_frag  >= $span_frag_limit)
        {
            
            $bedpe_entry->{score} = $output{$fusion}->{score} || 0;

            my %content;
            @content{@headers} = (
                $fusion,
                $FP,
                $TP,
                $output{$fusion}->{id_5p}     || 'NA',
                $output{$fusion}->{id_3p}     || 'NA',
                $output{$fusion}->{geneId_5p} || 'NA',
                $output{$fusion}->{geneId_3p} || 'NA',
                $total_frag,
                $span_frag,
                $output{$fusion}->{type}  || 'NA',
                $span_total,
            );

            %content = (%content, %$bedpe_entry);
            $writer->write_one(\%content);
        }
    }

    $self->filtered_bedpe_file($output_file);
    return 1;
}


sub _get_gene_ids {
    my ($self, $trans_ids, $params) = @_;
    my @id_info = split /,/, $trans_ids;
    my %gene_ids;
   
    for my $id_info (@id_info) {
        my ($trans_id) = $id_info =~ /^(E\S+)\:/;
        if ($trans_id) {
            my $trans = Genome::Transcript->get(transcript_name => $trans_id, %$params);
            if ($trans) {
                my $gene_id = $trans->gene_id;
                if ($gene_id) {
                    #my $gene_name = $gene->name('ensembl');
                    my ($gene_id_obj) = Genome::ExternalGeneId->get(
                        %$params,
                        gene_id => $gene_id,
                        id_type => 'ensembl',
                    );
                    if ($gene_id_obj) {
                        $gene_ids{$gene_id_obj->id_value} = 1;
                    }
                    else {
                        $self->warning_message("Failed to get ensembl gene name from trans id: $trans_id");
                    }
                }
                else {
                    $self->warning_message("Failed to get gene from trans id: $trans_id");
                }
            }
            else {
                $self->warning_message("Failed to get transcript from id: $trans_id");
            }
        }
        else {
            $self->warning_message("Failed to get transcript id from $id_info");
        }
    }

    return join ',', sort keys %gene_ids;
}

1;

