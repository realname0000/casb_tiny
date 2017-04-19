package Web::CASB_tiny;
use strict;
use warnings;
use Dancer2;

our $VERSION = '0.1';

get '/' => sub {
    session('cnt' => 1);
    session('subdir' => (int rand(1_000_000)));
    template 'index' => { 'title' => 'Web::CASB_tiny' };
};

# show login intro
# login openid
# show site policy
# collect uploads into a record for this session
# finalise and logoff

get '/logout' => sub {
     app->destroy_session;
     redirect '/';
};

get '/upload' => sub {
    session('csrf' => "Csrf_".(int rand(1_000_000_000)));
    template 'upload.tt' => { 'csrf' => session('csrf') };
};

post '/upload' => sub {
    my $data = request->upload('file');

    # What did the form get and does it match the session?
    my $form_csrf = request->{body_parameters}->{csrf_token};
    if ($form_csrf ne session('csrf')) {
        my $ds=sprintf("CSRF: test (%s is %s)", $form_csrf, session('csrf'));
        debug($ds);
        return template 'form_failed';
    }

    my $dir = path(config->{appdir}, 'uploads');
    mkdir $dir if not -e $dir;
    if (!defined(session('subdir'))) {
        session('subdir' => (int rand(1_000_000)));
    }
    my $half = path($dir, session('subdir'));
    mkdir $half if not -e $half;
    my $path = path($half, $data->basename);
    if (-e $path) {
        return "'$path' already exists";
    }

    $data->link_to($path) or return "Link failed :$path: $!";

    my $sess_file_list=session('file_list');
    $sess_file_list="" if (!defined($sess_file_list));
    $sess_file_list .= "<br />";
    $sess_file_list .= $data->basename;
    session('file_list' => $sess_file_list);

    template 'progress' => { list => session('file_list') };
};

get '/finish' => sub {
     my $trigger_file = 'uploads/' . session('subdir') . '/_.txt';
     open(my $tf, '>', $trigger_file) or die("open $!");
     foreach my $n (1..3) {
         printf($tf "Number %d\n", $n);
     }
     printf($tf "END\n");
     close($tf) or die("close $!");
     app->destroy_session;
     redirect '/';
};

# default - either serve a static file or not_found
any qr{.*} => sub {
    if (request->path =~ m{^(/[/\w-]+.?\w+)$}) {
        if ( -f "public/www".$1) {
           return send_file "www".$1;
        } else {
            status 'not_found';
            template 'special_404', { path => $1 };
        }
    }
    status 'not_found';
    template 'special_404', { path => 'something with special characters in' };
};

true;
