# Over-ride the standard MIME::Parser::FileInto class with our own to pre-
# pend all filenames with an "n" to show they were normal attachments and
# did not come from within an archive.
package MIME::Parser::MailScanner;

use MIME::WordDecoder;
use strict;
use vars qw(@ISA);
@ISA = qw(MIME::Parser::Filer);

sub init {
    my ($self, $dir) = @_;
    $self->{MPFI_Dir} = $self->cleanup_dir($dir);
}
sub output_dir {
    shift->{MPFI_Dir};
}
sub output_path {
    my ($self, $head) = @_;

    ### Get the output directory:
    my $dir = $self->output_dir($head);

    ### Get the output filename, decoding into the local character set:
    my $fname = unmime $head->recommended_filename;

    ### Can we use it:
    if    (!defined($fname)) {
        $self->debug("no filename recommended: synthesizing our own");
        $fname = $self->output_filename($head);
    }
    elsif ($self->ignore_filename) {
        $self->debug("ignoring all external filenames: synthesizing our own");
        $fname = $self->output_filename($head);
    }
    elsif ($self->evil_filename($fname)) {

        ### Can we save it by just taking the last element?
        my $ex = $self->exorcise_filename($fname);
        if (defined($ex) and !$self->evil_filename($ex)) {
            $self->whine("Provided filename '$fname' is regarded as evil, ",
                         "but I was able to exorcise it and get something ",
                         "usable.");
            $fname = $ex;
        }
        else {
            $self->whine("Provided filename '$fname' is regarded as evil; ",
                         "I'm ignoring it and supplying my own.");
            $fname = $self->output_filename($head);
        }
    }

    # JKF Added next line to put an "n" on the front of every attachment fname.
    # JKF This separates them from "a" files which came from archives.
    $fname = 'n' . $fname; # JKF 20090327

    $self->debug("planning to use '$fname'");

    ### Resolve collisions and return final path:
    return $self->find_unused_path($dir, $fname);
}

1;

