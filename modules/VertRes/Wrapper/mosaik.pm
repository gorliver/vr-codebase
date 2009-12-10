=head1 NAME

VertRes::Wrapper::mosaik - wrapper for mosaik

=head1 SYNOPSIS

[stub]

=head1 DESCRIPTION

Since author mentioned no settings, nothing on wiki, will use defaults for
all steps. Below are examples from example scripts supplied with release.

MosaikBuild -fr reference/c.elegans_chr2.fasta -oa reference/c.elegans_chr2.dat
MosaikBuild -q fastq/c_elegans_chr2_test.fastq -out sequence_archives/c_elegans_chr2_test.dat -st illumina
MosaikAligner -in sequence_archives/c_elegans_chr2_test.dat -out sequence_archives/c_elegans_chr2_test_aligned.dat -ia reference/c.elegans_chr2.dat -hs 14 -act 17 -mm 2 -m unique
MosaikSort -in sequence_archives/c_elegans_chr2_test_aligned.dat -out sequence_archives/c_elegans_chr2_test_sorted.dat
# MosaikAssembler -in sequence_archives/c_elegans_chr2_test_sorted.dat -out assembly/c.elegans_chr2_test -ia reference/c.elegans_chr2.dat -f ace
MosaikText -in yeast_aligned.dat -sam yeast_aligned.sam


=head1 AUTHOR

Sendu Bala: bix@sendu.me.uk

=cut

package VertRes::Wrapper::mosaik;

use strict;
use warnings;
use File::Copy;
use File::Basename;
use VertRes::IO;

use base qw(VertRes::Wrapper::MapperI);


=head2 new

 Title   : new
 Usage   : my $wrapper = VertRes::Wrapper::mosaik->new();
 Function: Create a VertRes::Wrapper::mosaik object.
 Returns : VertRes::Wrapper::mosaik object
 Args    : quiet   => boolean

=cut

sub new {
    my ($class, @args) = @_;
    
    my $self = $class->SUPER::new(@args, exe => '/lustre/scratch102/user/sb10/mapper_comparisons/mappers/mosaik-aligner/bin/');
    
    return $self;
}

=head2 version

 Title   : version
 Usage   : my $version = $obj->version();
 Function: Returns the program version.
 Returns : string representing version of the program 
 Args    : n/a

=cut

sub version {
    return 0;
}

=head2 setup_reference

 Title   : setup_reference
 Usage   : $obj->setup_reference($ref_fasta);
 Function: Do whatever needs to be done with the reference to allow mapping.
 Returns : boolean
 Args    : n/a

=cut

sub setup_reference {
    my ($self, $ref) = @_;
    
    my $out = $ref.'.dat';
    unless (-s $out) {
        my $orig_exe = $self->exe;
        $self->exe($orig_exe.'MosaikBuild');
        $self->simple_run("-fr $ref -oa $out");
        $self->exe($orig_exe);
    }
    
    return -s $out ? 1 : 0;
}

=head2 setup_fastqs

 Title   : setup_fastqs
 Usage   : $obj->setup_fastqs($ref_fasta, @fastqs);
 Function: Do whatever needs to be done with the fastqs to allow mapping.
 Returns : boolean
 Args    : n/a

=cut

sub setup_fastqs {
    my ($self, $ref, @fqs) = @_;
    
    my $out = $self->_fastqs_dat(@fqs);
    
    unless (-s $out) {
        my $orig_exe = $self->exe;
        $self->exe($orig_exe.'MosaikBuild');
        $self->simple_run("-q $fqs[0] -q2 $fqs[1] -out $out -st illumina");
        $self->exe($orig_exe);
    }
    
    return -s $out ? 1 : 0;
}

sub _fastqs_dat {
    my ($self, @fqs) = @_;
    
    my $merged_fq;
    if (@fqs > 1) {
        foreach my $fq (@fqs) {
            my ($name) = $fq =~ /^(.+)\.fastq\.gz$/;
            
            unless($merged_fq) {
                $merged_fq = $name;
            }
            else {
                $merged_fq .= basename($name);
            }
        }
        
        $merged_fq .= '.fastq.gz';
    }
    else {
        $merged_fq = $fqs[0];
    }
    
    $merged_fq =~ s/\.fastq\.gz$/.dat/;
    
    return $merged_fq;
}

=head2 generate_sam

 Title   : generate_sam
 Usage   : $obj->generate_sam($out_sam, $ref_fasta, @fastqs);
 Function: Do whatever needs to be done with the reference and fastqs to
           complete mapping and generate a sam/bam file.
 Returns : boolean
 Args    : n/a

=cut

sub generate_sam {
    my ($self, $out, $ref, @fqs) = @_;
    
    my $orig_exe = $self->exe;
    
    # align
    my $align_out = $out.'.align';
    unless (-s $align_out) {
        $self->exe($orig_exe.'MosaikAligner');
        my $fastqs_dat = $self->_fastqs_dat(@fqs);
        $self->simple_run("-in $fastqs_dat -out $align_out -ia $ref.dat");
        $self->exe($orig_exe);
    }
    unless (-s $align_out) {
        die "failed during the align step\n";
    }
    
    # sort
    my $sort_out = $out.'.sort';
    unless (-s $sort_out) {
        $self->exe($orig_exe.'MosaikSort');
        $self->simple_run("-in $align_out -out $sort_out");
        $self->exe($orig_exe);
    }
    unless (-s $sort_out) {
        die "failed during the sort step\n";
    }
    
    # assemble??
    # MosaikAssembler -in sequence_archives/c_elegans_chr2_test_sorted.dat -out assembly/c.elegans_chr2_test -ia reference/c.elegans_chr2.dat -f ace
    
    # convert to sam
    unless (-s $out) {
        $self->exe($orig_exe.'MosaikText');
        $self->simple_run("-in $sort_out -sam $out");
        $self->exe($orig_exe);
    }
    
    return -s $out ? 1 : 0;
}

=head2 add_unmapped

 Title   : add_unmapped
 Usage   : $obj->add_unmapped($sam_file, $ref_fasta, @fastqs);
 Function: Do whatever needs to be done with the sam file to add in unmapped
           reads.
 Returns : boolean
 Args    : n/a

=cut

sub add_unmapped {
    my ($self, $sam, $ref, @fqs) = @_;
    return 1;
}

=head2 do_mapping

 Title   : do_mapping
 Usage   : $wrapper->do_mapping(ref => 'ref.fa',
                                read1 => 'reads_1.fastq',
                                read2 => 'reads_2.fastq',
                                output => 'output.sam');
 Function: Run mapper on the supplied files, generating a sam file of the
           mapping. Checks the sam file isn't truncated.
 Returns : n/a
 Args    : required options:
           ref => 'ref.fa'
           output => 'output.sam'

           read1 => 'reads_1.fastq', read2 => 'reads_2.fastq'
           -or-
           read0 => 'reads.fastq'

=cut

=head2 run

 Title   : run
 Usage   : Do not call directly: use one of the other methods instead.
 Function: n/a
 Returns : n/a
 Args    : paths to input/output files

=cut

1;
