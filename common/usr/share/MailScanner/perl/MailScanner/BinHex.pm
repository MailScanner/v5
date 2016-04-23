#
#
# This package is now deprecated and is no longer used.
#
#

package MailScanner::BinHex;


=head1 NAME

MIME::Decoder::BinHex - decode a "binhex" stream


=head1 SYNOPSIS

A generic decoder object; see L<MIME::Decoder> for usage.

Also supports a preamble() method to recover text before
the binhexed portion of the stream.


=head1 DESCRIPTION

A MIME::Decoder subclass for a nonstandard encoding whereby
data are binhex-encoded.  Common non-standard MIME encodings for this:

    x-uu
    x-uuencode


=head1 AUTHOR

Julian Field (F<mailscanner@ecs.soton.ac.uk>).

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.

=head1 VERSION

$Revision: 3036 $ $Date: 2005-05-17 11:27:12 +0100 (Tue, 17 May 2005) $

=cut


require 5.002;
use vars qw(@ISA $VERSION);
use MIME::Decoder;
use MIME::Tools;
use Convert::BinHex;

@ISA = qw(MIME::Decoder);

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 3036 $, 10;


#------------------------------
#
# decode_it IN, OUT
#
sub decode_it {
    my ($self, $in, $out) = @_;
    my ($mode, $file);
    my (@preamble, @data);
    local $_;
    my $H2B = Convert::BinHex->hex2bin;
    #my $H2B = Convert::BinHex->open($in);
    my $line;

    $self->{MDU_Preamble} = \@preamble;
    $self->{MDU_Mode} = '600';
    $self->{MDU_File} = undef;

    ### Find beginning...
    $MailScanner::BinHex::Inline = 1;
    if ($MailScanner::BinHex::Inline) {
      while (defined($_ = $in->getline)) {
        #print STDERR "Line is \"$_\"\n";
        if (/^\(This file must be converted/) {
          $_ = $in->getline;
          last if /^:/;
        }
        push @preamble, $_;
      }
      die("binhex decoding: fell off end of file\n") if !defined($_);
    } else {
      while (defined($_ = $in->getline)) {
        # Found the header? So start decoding it
        last if /^:/;
        push @preamble, $_;
      }
      ## hit eof!
      die("binhex decoding: no This file must be... found\n") if !defined($_);
    }

    ### Decode:
    # Don't rely on the comment always being there
    #$self->whine(":H2B is $H2B\n");
    #$self->whine("Header is " . $H2B->read_header . "\n");
    #@data = $H2B->read_data;
    #$out->print(@data);
    #print STDERR "End of binhex stream\n";
    #return 1;
    #if (/^:/) {
    my $data;
    $data = $H2B->next($_); # or whine("Next error is $@ $!\n");
    #print STDERR "Data line 1 is length \"" . length($data) . "\" \"$data\"\n";
    my $len = unpack("C", $data);
    while ($len > length($data)+21 && defined($line = $in->getline)) {
      $data .= $H2B->next($line);
    }
    $data = substr($data, 22+$len);
    $out->print($data);
    #}
    while (defined($_ = $in->getline)) {
        $line = $_;
        $data = $H2B->next($line);
        #print STDERR "Data is length " . length($data) . " \"$data\"\n";
        $out->print($data);
        #chomp $line;
        #print STDERR "Line is length " . length($line) . " \"$line\"\n";
        #print STDERR "Line matches end\n" if $line =~ /:$/;
        last if $line =~ /:$/;
    }
    #print STDERR "Broken out of loop\n";
    #print STDERR "file incomplete, no end found\n" if !defined($_); # eof
    1;
}

#------------------------------
#
# encode_it IN, OUT
#
sub encode_it {
    my ($self, $in, $out) = @_;
    my $line;
    my $buf = '';

    my $fname = (($self->head && 
		  $self->head->mime_attr('content-disposition.filename')) ||
		 '');
    my $B2H = Convert::BinHex->bin2hex;
    $out->print("(This file must be converted with BinHex 4.0)\n");
    #while (defined($line = <$in>)) {
    while ($in->read($buf, 1000)) {
      $out->print($B2H->next($buf));
    }
    $out->print($B2H->done);
    1;
}

#------------------------------
#
# last_preamble
#
# Return the last preamble as ref to array of lines.
# Gets reset by decode_it().
#
sub last_preamble {
    my $self = shift;
    return $self->{MDU_Preamble} || [];
}

#------------------------------
#
# last_mode
#
# Return the last mode.
# Gets reset to undef by decode_it().
#
sub last_mode {
    shift->{MDU_Mode};
}

#------------------------------
#
# last_filename
#
# Return the last filename.
# Gets reset by decode_it().
#
sub last_filename {
    shift->{MDU_File} || undef; #[];
}

#------------------------------
1;
