#!/usr/bin/perl -T

use strict;
use warnings;
$ENV{PATH}='/bin:/usr/bin';

use FindBin '$RealBin';
use File::stat;
use Fcntl ':mode';
use YAML::Tiny;
use Data::Dumper 'Dumper';

BEGIN {
    my $maindir=$RealBin;
    $maindir =~ s{/bin/?$}{};
    printf("MAIN DIR is -%s-\n", $maindir);
    if ($maindir =~ m{^(/home/\w+/Web-CASB_tiny|/opt/webapp/casb_tiny)$}) {
        $::maindir = $1; # untainted
    } else {
      die("bad --$maindir--");
    }
}

use lib "$::maindir/lib";
use Policy::CASB_tiny;

chdir($::maindir) or die("chdir $!");
foreach my $spool (qw(uploads staging rejects)) {
    die("Lacking spool directory $::maindir/$spool") if (! -d $spool);
}

# read applicable policy
# then examine the files in bot_spool for conformity to policy
# and if all ok process with the upload module
sub process_staging {
    my $dirname=shift;
    chdir($::maindir) or die("chdir $!");
    chdir('staging') or die("chdir $!");
    LOOKS_OK: while (1) {
        printf("Studying %s\n", $dirname);
        # read control file _.txt
        open(my $cf, '<', "$dirname/_.txt") or last LOOKS_OK;
        my @cfcontent=<$cf>;
        close($cf);
        my %fnames_expected;
        my ($user, $role, $site);
        foreach my $line_o_text (@cfcontent) {
            chomp($line_o_text);
            if ($line_o_text =~ /^file:\s+(.*)$/) {
                $fnames_expected{$1}=$1;
            } elsif ($line_o_text =~ /^user:\s+(.*)$/) {
                $user = $1;
            } elsif ($line_o_text =~ /^role:\s+(.*)$/) {
                $role = $1;
            } elsif ($line_o_text =~ /^site:\s+(.*)$/) {
                $site = $1;
            } else {
                printf("LINE: %s\n", $line_o_text);
            }
        }
        # list contents and check against control
        opendir(my $dh, $dirname) or last LOOKS_OK;
        my %fnames_present = map { $_ => $_ } readdir($dh);
        closedir($dh) or last LOOKS_OK;
        delete($fnames_present{'.'});
        delete($fnames_present{'..'});
        delete($fnames_present{'_.txt'});
        #
        last LOOKS_OK if ((scalar keys %fnames_present) != (scalar keys %fnames_expected));
        foreach my $k (keys %fnames_expected) {
            last LOOKS_OK if (!defined($fnames_present{$k}));
        }

        # obtain user/role/site data
        my $policy = Policy::CASB_tiny->new($user);
        printf("Created a policy: %s\n", $policy);
        $policy->display();
        $policy->discover_options();
        $policy->display();
        $policy->choose_option($role .'@'. $site);
        $policy->display();

        # check against policy
        foreach my $k (keys %fnames_expected) {
            if (!$policy->test_file($k)) {
                printf("Policy check failed for file %s\n", $k);
                last LOOKS_OK;
            }
        }


        # upload by suitable means (e.g. FTP)
        # rm from staging
          # system({'rm'} 'rm', '-rf', $ufn);
          # my $rcrm = $?;
          # die("problem running rm: $rcrm $!") if ($rcrm);
        return;
    }
   #  OR move to rejects
      rename($dirname, "../rejects/$dirname".'_at_'.scalar time);
}

# see if there is anything new and finished in uploads
# if so copy it to staging
# and delete from uploads.
sub scrape_uploads {
   TILL_BORED: while (1) {
       chdir($::maindir) or die("chdir $!");
       chdir('uploads') or die("chdir $!");
       sleep(1);
       my $done_work=0;
       opendir(my $dh, '.') or die("opendir $!");
       my @fnames = readdir($dh);
       closedir($dh) or die("closedir $!");
       ONE_UPLOAD: foreach my $fn (@fnames) {
           next ONE_UPLOAD if ('.' eq $fn or '..' eq $fn);
           my $ufn;
           if ($fn =~ /^(\d+)$/) {
               $ufn = $1; # untainted
           } else {
               next ONE_UPLOAD; # should never happen
           }
           my $end_status;
           open(my $control, '<', "$ufn/_.txt") or next ONE_UPLOAD;
           my @line_o_text = <$control>;
           $end_status = $line_o_text[-1];
           chomp($end_status);
           close($control);
           if ('END' eq $end_status) {
               system({'cp'} 'cp', '-r', $ufn, '../staging/');
               my $rccp = $?;
               if ($rccp) {
                   die("problem running cp: $rccp $!");
               } else {
                   system({'rm'} 'rm', '-rf', $ufn);
                   my $rcrm = $?;
                   die("problem running rm: $rcrm $!") if ($rcrm);
                   $done_work = 1;
                   process_staging($ufn);
               }
           }
       }
       last TILL_BORED if (!$done_work);
   }
}

# XXX want a lock

scrape_uploads();

# purge old files
my %age = (uploads => 7200, staging => 7200, rejects => 604800, tmp => 3600);
foreach my $spool (keys %age) {
    chdir($::maindir) or die("chdir $!");
    chdir($spool) or die("chdir $!");
    printf("Spool: %s age %d\n", $spool, $age{$spool});
    # remove stuff above the specified age
    opendir(my $dh, '.') or next;
    my @dirnames = grep {/^\d+$/} readdir($dh);
    closedir($dh) or next;
    foreach my $d (@dirnames) {
        if ($d =~ /^(\d+)$/) {
            my $ud = $1;
            my $sb = lstat($ud);
            next unless S_ISDIR($sb->mode);
            next unless (($^T - $sb->mtime) > $age{$spool});
            system({'rm'} 'rm', '-rf', $ud);
        }
    }
}

# XXX release lock
