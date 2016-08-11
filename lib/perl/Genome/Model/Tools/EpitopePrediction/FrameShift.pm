package Genome::Model::Tools::EpitopePrediction::FrameShift;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::Model::Tools::EpitopePrediction::FrameShift {
    is  => ['Genome::Model::Tools::EpitopePrediction::Base'],
    doc => '',
    has => [
        bed_file => {
            is  => 'Text',
            doc => '',
        },
        vcf_file => {
            is  => 'Text',
            doc => '',
        },
        database_directory => {
            is  => 'Text',
            doc => '',
        },
        output_directory => {
            is  => 'Text',
            doc => '',
        },
    ],
    has_calculated => [
        output_file => {
            is  => 'File',
            calculate_from => ['output_directory'],
            calculate => q|return File::Spec->join($output_directory, 'proteome-indel.fasta'); |,
        },
        output_mod_file => {
            is  => 'File',
            calculate_from => ['output_directory'],
            calculate => q|return File::Spec->join($output_directory, 'proteome-indel-mod.fasta'); |,
        },
    ],
};

sub execute {
    my $self = shift;

    my $filename = $self->bed_file;
    my $dir = $self->database_directory;
    my $filename_vcf_somatic = $self->vcf_file;

    my $out_dir = $self->output_directory;
    Genome::Sys->create_directory($out_dir);

    my %mapping = (
        "TTT" => "F",
        "TTC" => "F",
        "TTA" => "L",
        "TTG" => "L",
        "CTT" => "L",
        "CTC" => "L",
        "CTA" => "L",
        "CTG" => "L",
        "ATT" => "I",
        "ATC" => "I",
        "ATA" => "I",
        "ATG" => "M",
        "GTT" => "V",
        "GTC" => "V",
        "GTA" => "V",
        "GTG" => "V",

        "TCT" => "S",
        "TCC" => "S",
        "TCA" => "S",
        "TCG" => "S",
        "CCT" => "P",
        "CCC" => "P",
        "CCA" => "P",
        "CCG" => "P",
        "ACT" => "T",
        "ACC" => "T",
        "ACA" => "T",
        "ACG" => "T",
        "GCT" => "A",
        "GCC" => "A",
        "GCA" => "A",
        "GCG" => "A",

        "TAT" => "Y",
        "TAC" => "Y",
        "TAA" => "*",
        "TAG" => "*",
        "CAT" => "H",
        "CAC" => "H",
        "CAA" => "Q",
        "CAG" => "Q",
        "AAT" => "N",
        "AAC" => "N",
        "AAA" => "K",
        "AAG" => "K",
        "GAT" => "D",
        "GAC" => "D",
        "GAA" => "E",
        "GAG" => "E",

        "TGT" => "C",
        "TGC" => "C",
        "TGA" => "*",
        "TGG" => "W",
        "CGT" => "R",
        "CGC" => "R",
        "CGA" => "R",
        "CGG" => "R",
        "AGT" => "S",
        "AGC" => "S",
        "AGA" => "R",
        "AGG" => "R",
        "GGT" => "G",
        "GGC" => "G",
        "GGA" => "G",
        "GGG" => "G"
    );

    my $ofh = Genome::Sys->open_file_for_writing($self->output_file);
    my $modfh = Genome::Sys->open_file_for_writing($self->output_mod_file);

    open( LOG,     ">$out_dir/proteome-indel.log" );

    my (%chr, %bed);
    my $ifh = Genome::Sys->open_file_for_reading($filename);
    while (my $line = $ifh->getline) {
        chomp $line;
        my @fields = split("\t", $line);
        my $chr  = $fields[0];
        my $name = $fields[3];
        $bed{$name} = $line;
        $chr{$chr} .= "#$name#";
    }
    $ifh->close;

    my (%vcf_old, %vcf_new, %vcf_type, %vcf_anno);
    my $vcf_ifh = Genome::Sys->open_file_for_reading($filename_vcf_somatic);
    while (my $line = $vcf_ifh->getline ) {
        chomp($line);
        print $line, "\n";
        my @fields = split("\t", $line);
        my $chr  = "chr" . $fields[0];
        my $pos  = $fields[1];
        my $id   = $fields[2];
        my $old  = $fields[3];
        my $new  = $fields[4];
        my $qaul = $fields[5];
        my $anno = $fields[6];
        my $type = $fields[7];
        unless (defined $chr and defined $pos and defined $id and defined $old 
                and defined $new and defined $qaul and defined $anno and defined $type) {
            die $self->error_message("Failed to parse line: ($line)");
        }

        $pos--;
        $new =~ s/\,.*$//;    #####
        print "pos=$pos", "\t", "id=$id", "\t", "old=$old", "\t",
        "new=$new", "\t", "qaul=$qaul", "\t", "anno=$anno", "\t",
        "type=$type", "\n";

        $vcf_old{"$chr#$pos"} = $old;
        $vcf_new{"$chr#$pos"} = $new;
        if ( $type eq "SOMATIC" ) { $vcf_type{"$chr#$pos"} = "S"; }
        else                      { $vcf_type{"$chr#$pos"} = "G"; }

        $vcf_anno{"$chr#$pos"} = $anno;
    }
    $vcf_ifh->close;

    foreach my $chr ( sort keys %chr ) {

        #Get the reference sequence
        print qq!$chr\n!;
        my $database_fh = Genome::Sys->open_file_for_reading("$dir/$chr.fa");
        print qq!opened $chr\n!;
        my $sequence = "";
        my $line = $database_fh->getline;
        chomp($line);
        my $chr_ = $chr;
        $chr_ =~ s/^chr//i;
        if ( $line =~ /^>$chr\s*/ or $line =~ /^>$chr_\s*/ ) {
            while ( $line = $database_fh->getline ) {
                chomp($line);
                if ( $line =~ /^>/ ) {
                    print LOG qq!Error: > not expected: $line\n!;
                }
                else {
                    $line =~ s/\s+//g;
                    if ( $line !~ /^[atcgATCGnN]+$/ ) {
                        print LOG
                        qq!Error: unexpected character: $line\n!;
                    }
                    else {
                        $sequence .= "\U$line";
                    }
                }
            }
            my $temp = $chr{$chr};
            my %seq_chr_pos;

            #For each protein in the bed file, get the sequence from the reference sequence
            while ( $temp =~ s/^#([^#]+)#// ) {
                my $name     = $1;

                my @fields = split("\t", $bed{$name});
                my $start                    = $fields[1];
                my $strand                   = $fields[5];
                my $segment_lengths          = $fields[10] . ",";
                my $segment_starts           = $fields[11] . ",";

                my $seq_original     = "";
                my $segment_starts_  = $segment_starts;
                my $segment_lengths_ = $segment_lengths;
                my $accu_c           = 0;
                #For each exon in the protein, get the sequence from the reference sequence
                while ( $segment_starts_ =~ s/^([0-9\-]+)\,// ) {
                    my $segment_start = $1;
                    if ( $segment_lengths_ =~ s/^([0-9]+)\,// ) {
                        my $segment_length = $1;

                        my $seq_ = substr $sequence,
                        $start + $segment_start, $segment_length;
                        #For each base in the protein, record the mapping between the position in the protein and the absolute
                        #position on the reference chromosome (e.g. position 4 [0-based] of a protein that is at
                        #position 2 [1-based] on a segment that starts at position 6 [0-based] relative to
                        #the protein start, which starts at chr3 pos 10 [0-based] maps to chr3 pos 17 [0-based]:
                        #  $seq_chr_pos{4} = 10 + 6 + 2 - 1 = 17
                        #  line from bed file:
                        #  chr3  10  20  ENSP1-FAKE  .  +  10  20  0  2  3,5  0,6
                        #  start (0-based, relative to reference):     10 11 12 13 14 15 16 |17| 18 19 20
                        #  segment_start (0-based, relative to start): 0   1  2  3  4  5 |6|  7   8  9 10
                        #  pos (1-based, relative to segment_start:    1   2  3           1  |2|  3  4  5
                        #  accu_c (0-based, relative to start):        0   1  2           3  |4|  5  6  7
                        for (
                            my $pos = 1 ;
                            $pos <= $segment_length ;
                            $pos++
                        )
                        {
                            $seq_chr_pos{$accu_c} =
                            $start + $segment_start + $pos - 1;
                            $accu_c++;
                        }
                        $seq_original .= $seq_;

                    }
                    else {
                        print LOG qq!Error parsing $bed{$name}\n!;
                    }
                }

                my $seq             = $seq_original;
                #This reverse complemented seq is never used???
                my $seq_original_rc = reverse $seq_original;
                $seq_original_rc =~ tr/ATCG/TAGC/;

                my $description        = "";
                my $num_indel           = 0;

                #Starting at the end of the original protein seq, look for variants starting
                #inside the protein seq.
                for (
                    my $i = length($seq_original) - 1 ;
                    $i >= 0 ;
                    $i--
                )
                {
                    my $var_pos = $seq_chr_pos{$i};

                    if ( defined $vcf_old{"$chr#$var_pos"} ) {

                        print $name,    "\n";
                        print $var_pos, "\n";
                        print $vcf_old{"$chr#$var_pos"}, "\n";
                        print $vcf_new{"$chr#$var_pos"}, "\n";

                        my $length_old = $vcf_old{"$chr#$var_pos"} eq "-" ? 0 : length( $vcf_old{"$chr#$var_pos"} );
                        my $length_new = $vcf_new{"$chr#$var_pos"} eq "-" ? 0 : length( $vcf_new{"$chr#$var_pos"} );
                        $num_indel++;
                        #if the difference in length is a multiple of 3, then it is in-frame
                        my $inframe = ( abs( $length_old - $length_new ) % 3 == 0 ) ? 1 : 0;
                        my $frame_type = $inframe == 1 ? 'in_frame_del' : 'fs'; #Why is it always del??
                        my ($int_3s, $int_3e);
                        if ( $strand =~ /\-/ ) {
                            my $rev_pos = length($seq_original) - $i - $length_old;
                            $int_3s = int( ( $rev_pos + 1 ) / 3 ) + 1;
                            $int_3e = int( ( $rev_pos + $length_new + 1 ) / 3 ) + 1;
                        }

                        else {
                            $int_3s = int( ( $i + 1 ) / 3 ) + 1;
                            $int_3e = int( ( $i + $length_new + 1 ) / 3 ) + 1;
                        }
                        my ($indel_type, $length, $int);
                        if ( $vcf_new{"$chr#$var_pos"} eq "-" ) {  #Does not handle complex indels properly
                            $indel_type = 'DEL';
                            $length = $length_old;
                            $int = $int_3s;
                        }
                        else {
                            $indel_type = 'INS';
                            $length = $length_new;
                            $int = $inframe == 1 ? "$int_3s-$int_3e" : $int_3s;
                        }
                        $description .= sprintf(
                            "(%s:%s-%s-%s-%s:%s%s)",
                            $indel_type, $chr, $var_pos, $length, $vcf_type{"$chr#$var_pos"}, $int, $frame_type
                        );

                        my $seql = substr( $seq, 0, $i );
                        print $seql, "\n";
                        my $seqr = substr( $seq, $i + $length_old, length($seq) - length($seql) - $length_old );

                        $seq = $length_new >= 1 ? $seql . $vcf_new{"$chr#$var_pos"} . $seqr :  $seql . $seqr;
                    }
                }

                my $protein          = "";
                my $protein_original = "";

                if ( $strand =~ /\-/ ) {
                    my $seq_ = reverse $seq;
                    $seq = $seq_;
                    $seq =~ tr/ATCG/TAGC/;
                    $seq_         = reverse $seq_original;
                    $seq_original = $seq_;
                    $seq_original =~ tr/ATCG/TAGC/;
                }

                for (
                    my $n = 0 ;
                    $n < length($seq_original) ;
                    $n = $n + 3
                )
                {
                    my $triplet = substr( $seq_original, $n, 3 );
                    if ( length($triplet) == 3 ) {
                        if ( $mapping{$triplet} !~ /[\w\*]/ ) {
                            $mapping{$triplet} = "X";
                        }
                        $protein_original .= $mapping{$triplet};
                    }
                }

                my $stop_found    = 0;
                for (
                    my $n = 0 ;
                    $n < length($seq) and $stop_found == 0 ;
                    $n = $n + 3
                )
                {
                    my $n_ = $n + 2;

                    my $triplet = substr( $seq, $n, 3 );
                    if ( length($triplet) == 3 ) {

                        if ( $mapping{$triplet} !~ /[\w\*]/ ) {
                            $mapping{$triplet} = "X";
                        }

                        if ( $mapping{$triplet} =~ /\*/ ) {
                            $stop_found = 1;
                        }
                        $protein .= $mapping{$triplet};
                    }
                }

                $protein_original =~ s/\*$//;

                if ( $protein_original =~ /^([^\*]+)\*.*$/ ) {
                    print LOG
                    qq!Error: Stop codon found in middle of sequence:$name \n$protein_original\n!;
                    $protein_original = "";
                }

                $protein =~ s/\*$//;
                $protein =~ s/^([^\*]+)\*.*$//;

                if (   ( $protein ne $protein_original )
                    && ( $num_indel == 1 ) )
                {

                    print "original protein\n";
                    print $protein_original, "\n";
                    print "modified protein\n";
                    print $protein, "\n";

                    if ( length($protein) > 6
                            and $protein !~ /^\*/ )
                    {
                        $ofh->print(qq!>$name (MAP:$chr:$start$strand $segment_lengths $segment_starts)\n$protein_original\n!);
                        $modfh->print(qq!>$name-indel (MAP:$chr:$start$strand $segment_lengths $segment_starts) $description\n$protein\n!);
                    }

                }
            }
        }
        else { print LOG qq!Error in name $chr: $line\n!; }

        $database_fh->close;
    }

    $ofh->close;
    $modfh->close;

    close(LOG);
}
