#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

# draws on this tutorial
# https://perlmaven.com/uploading-files-with-dancer2

use Web::CASB_tiny;
Web::CASB_tiny->to_app;

use Plack::Builder;
builder {
    enable 'Deflater';
    Web::CASB_tiny->to_app;
}
