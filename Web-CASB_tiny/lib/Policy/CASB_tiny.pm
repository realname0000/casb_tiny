package Policy::CASB_tiny;
use strict;
use warnings;

use Data::Dumper;

sub new {
    my ($class, $username) = @_;
    my $self = {
        username => $username,
        rules => {},
        errors => [],
    };
    bless $self, $class;
}

sub display {
    my ($self) = @_;
    print "----- $self -----\n";
    print Dumper($self);
    print ".................\n";

}

sub new_error {
    my ($self, $text)=@_;
    push(@{$self->{errors}}, $text);
}

sub get_errors {
    my ($self)=@_;
    return $self->{errors};
}


sub get_role_options {
    my ($self)=@_;
    my @answer;
    foreach my $k (keys %{$self->{role_options}}) {
        push(@answer, $k) if ($self->{role_options}->{$k} eq 'role');
    }
    return @answer;
}

sub discover_options
{
    my ($self)=@_;
    return if (!defined($self->{username}));
    #
    my $users_yaml = YAML::Tiny->read($::maindir.'/etc/users.yaml');
    my $user_data  = $users_yaml->[0]->{$self->{username}};
    if (defined($user_data->{expires})) {
        return if ($^T > $user_data->{expires});
    }
    $self->{role_options} = $user_data;
}

sub choose_option
{
    my ($self, $rolesite)=@_;
    if (!defined($self->{role_options}->{$rolesite})) {
        die("cannot choose role that does not exist (asked for $rolesite)");
    }
    if ($self->{role_options}->{$rolesite} eq 'role') {
        if ($rolesite =~ (/^(\w+)\@(\w[\w.-]+\w)$/)) {
            $self->{role} = $1;
            $self->{site} = $2;
            delete($self->{role_options});
            #
            my $roles_yaml = YAML::Tiny->read($::maindir.'/etc/roles.yaml');
            my $role_data  = $roles_yaml->[0]->{$self->{role}};
            @{$self->{rules}}{keys %{$role_data}} = values %{$role_data};
            #
            # Site rules take precedence as they are are applied after role rules.
            my $sites_yaml = YAML::Tiny->read($::maindir.'/etc/sites.yaml');
            my $site_data  = $sites_yaml->[0]->{$self->{site}};
            @{$self->{rules}}{keys %{$site_data}} = values %{$site_data};
        }
    }
}

sub test_file {
    my ($self,$file) = @_;
    my $total_success = 1;
    foreach my $rule (sort keys %{$self->{rules}}) {
        # test all rules and record which of them fail
        $total_success &&= $self->$rule($self->{rules}->{$rule}, $file);
    }
    return $total_success;
}

sub basename_re {
    my ($self,$parm) = @_;
    warn("no check for basename_re");
    return 1;
}

sub compulsory_new_directory {
    my ($self,$parm) = @_;
    warn("no check for compulsory_new_directory");
    return 1;
}

sub dirname_re {
    my ($self,$parm) = @_;
    warn("no check for dirname_re");
    return 1;
}

sub file_has_mp3_content {
    my ($self,$parm) = @_;
    warn("no check for file_has_mp3_content");
}

sub file_has_mp3_name {
    my ($self,$parm,$file) = @_;
    return 1 if ($file =~ /\.mp3$/);
    $self->new_error("Filename $file not *.mp3");
    return;
}

sub max_file_size {
    my ($self,$parm) = @_;
    warn("no check for max_file_size");
    return 1;
}

sub max_subdir_depth {
    my ($self,$parm) = @_;
    return 1;
}

1;
