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

get '/count' => sub {
    my $counter = session('cnt');
    debug("Counter from session: $counter");
    $counter++;
    session('cnt' => $counter);
};

get '/a_static_page' => sub {
        send_file '/some_static.html'
};

get '/logout' => sub {
     app->destroy_session;
     set_flash('You are logged out.');
     redirect '/';
};

get '/upload' => sub {
    session('csrf' => "Csrf_".(int rand(1_000_000_000)));
    template 'upload.tt' => { 'csrf' => session('csrf') };
};

post '/upload' => sub {
    my $data = request->upload('file');

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

    # What did the form get and does it match the session?
    my $form_csrf = request->{body_parameters}->{csrf_token};
    if ($form_csrf ne session('csrf')) {
        my $ds=sprintf("CSRF: test (%s is %s)", $form_csrf, session('csrf'));
        debug($ds);
        return template 'form_failed';
    }

    $data->link_to($path) or return "Link failed :$path: $!";
    #
    my $sess_file_list=session('file_list');
    $sess_file_list="" if (!defined($sess_file_list));
    $sess_file_list .= "<br />";
    $sess_file_list .= $data->basename;
    session('file_list' => $sess_file_list);
    #
    template 'progress' => { list => session('file_list') };
};


true;
