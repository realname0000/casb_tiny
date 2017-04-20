#!/usr/bin/perl -T

# see if there is anything new and finished in uploads
# if so copy it to staging
# and delete from uploads.
#
# read applicable policy
#
# then examine the files in bot_spool for conformity to policy
# and if all ok process with the upload module

use strict;
use warnings;
use FindBin '$RealBin';

$ENV{PATH}='/bin:/usr/bin';

my $maindir=$RealBin;
$maindir =~ s{/bin/?$}{};
printf("MAIN DIR is -%s-\n", $maindir);
if ($maindir =~ m{^(/home/\w+/Web-CASB_tiny|/opt/webapp/casb_tiny)$}) {
    $maindir = $1; # untainted
}
chdir($maindir) or die("chdir $!");

foreach my $spool (qw(uploads staging rejects)) {
    die("Lacking spool directory $maindir/$spool") if (! -d $spool);
}

sub process_staging {
    my $dirname=shift;
    chdir($maindir) or die("chdir $!");
    chdir('staging') or die("chdir $!");
    # read control file _.txt
    # list contents and check against control
    # obtain user/role/site data
    # check against policy
    # upload by suitable means (e.g. FTP)
    # rm from staging
      # system({'rm'} 'rm', '-rf', $ufn);
      # my $rcrm = $?;
      # die("problem running rm: $rcrm $!") if ($rcrm);
   #  OR move to rejects
      rename($dirname, "../rejects/$dirname".'_at_'.scalar time);
}

sub scrape_uploads {
   TILL_BORED: while (1) {
       chdir($maindir) or die("chdir $!");
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

my %age = (uploads => 86400, staging => 86400, rejects => 86400, tmp => 86400);
foreach my $spool (keys %age) {
    chdir($maindir) or die("chdir $!");
    chdir($spool) or die("chdir $!");
    printf("Spool: %s age %d\n", $spool, $age{$spool});
    system({'ls'} 'ls', '-la');
    # remove stuff above the specified age
}

# XXX release lock
