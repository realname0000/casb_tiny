package Web::CASB_tiny;
use strict;
use warnings;
use Dancer2;
use Digest::SHA 'sha256_hex';

our $VERSION = '0.1';

get '/casb' => sub {
    template 'index' => { 'title' => 'Web::CASB_tiny' };
};

# show login intro
# login openid
# show site policy
# collect uploads into a record for this session
# finalise and logoff

get '/casb/login' => sub {
    session('authn_user' => 'smithj');
    session('role' => 'audio_upload');
    session('site' => 'fakeisp.local');
    redirect '/casb/upload';
};

get '/casb/logout' => sub {
    app->destroy_session;
    redirect '/casb';
};

get '/casb/upload' => sub {
    my $u = session('authn_user');
    $u //= "not_logged_in";
    my $a = int rand(1_000_000_000);
    my $b = "some string - should come from config";
    session('csrf' => sha256_hex($a . $b));
    template 'upload.tt' => { 'csrf' => session('csrf'), user => $u };
};

post '/casb/upload' => sub {
    my $data = request->upload('file');

    # What did the form get and does it match the session?
    my $form_csrf = request->{body_parameters}->{csrf_token};
    if ($form_csrf ne session('csrf')) {
        app->destroy_session;
        my $ds=sprintf("CSRF: test (%s is %s)", $form_csrf, session('csrf'));
        debug($ds);
        return template 'form_failed';
    }

    if (!defined(session('authn_user'))) {
        redirect '/casb/login';
    }

    if ($data->basename !~ /^\w[\w-]+\.?\w+$/) {
        return template 'progress' => { list => 'rejected bad filename' };
    }

    my $dir = path(config->{appdir}, 'uploads');
    mkdir $dir if not -e $dir;
    my $half;
    if (!defined(session('subdir'))) {
        session('subdir' => (int rand(1_000_000)));
        $half = path($dir, session('subdir'));
        return "directory already exists" if -e $half;
        mkdir $half;
    }
    $half = path($dir, session('subdir'));
    return "directory missing" if not -e $half;
    my $path = path($half, $data->basename);
    if (-e $path) {
        return "'$path' already exists";
    }

    $data->link_to($path) or return "Link failed :$path: $!";

    # files uploaded as array ref
    if (!defined(session('files_uploaded'))) {
        session('files_uploaded' => []);
    }
    push(@{session('files_uploaded')}, $data->basename);
    #
    # also a a single string for display in template
    my $sess_file_list=session('file_list');
    $sess_file_list="" if (!defined($sess_file_list));
    $sess_file_list .= "<br />";
    $sess_file_list .= $data->basename;
    session('file_list' => $sess_file_list);

    template 'progress' => { list => session('file_list') };
};

get '/casb/finish' => sub {
     #
     if (defined(session('subdir'))
         && defined(session('authn_user'))
         && defined(session('role'))
         && defined(session('site'))
         && defined(session('files_uploaded')) ) {
         my $files_aref=session('files_uploaded');
         my $trigger_file = 'uploads/' . session('subdir') . '/_.txt';
         open(my $tf, '>', $trigger_file) or die("open $!");
         printf($tf "user: %s\n", session('authn_user'));
         printf($tf "role: %s\n", session('role'));
         printf($tf "site: %s\n", session('site'));
         foreach my $fn (@{$files_aref}) {
             printf($tf "file: %s\n", $fn);
         }
         printf($tf "END\n");
         close($tf) or die("close $!");
     } else {
         debug('called /finish without prerequisites');
     }
     app->destroy_session;
     redirect '/casb';
};

# default - either serve a static file or not_found
any qr{.*} => sub {
    my $rp = request->path;
    if ($rp eq '/') {
        $rp = '/index.html';
    }
    if ($rp =~ m{^(/[/\w-]+\.?\w+)$}) {
        if (-f "public/www".$1) {
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
