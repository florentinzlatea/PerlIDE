#!/usr/local/bin/perl
################################################################################
# PROGRAM: $Id: alarm_sd.pl,v 1.6 2004/12/07 09:22:10 fontane1 Exp $ 
# @(#) $Revision: 1.6 $
#
# COPYRIGHT ALCANET INTERNATIONAL 1995-2000
# Alcanet International - Services Engineering
# for ICL i500 Enterprise Directory Server
#
# DESCRIPTION
# this program is a deamon, it sends the alarms to the server(will treat them)
# 
# USAGE: See the script alarm_s for usage
# 
# INPUT  
#
# OUTPUT : 
# NOTES
# Do not remove the $Keyword$ 
#
#@BEGIN
# HISTORIC
# $Log: alarm_sd.pl,v $
# Revision 1.6  2004/12/07 09:22:10  fontane1
# BUG: USR:DF MSG:Config{sig_name} returns list of signals - prepended by ZERO - removed that value from the list of signals since it has an unpredictable effect
#
# Revision 1.5  2002/11/22 10:43:58  pgouley
# BUG:DEFUNCT USR:PGY MSG:Some child processess could become <defunct> on SunOS. Catch now the SIGCHLD signal
#
# Revision 1.4  2002/11/21 15:15:05  pgouley
# BUG:HOSTNAME USR:PGY MSG:Change the method to get the hostname (for SunOS)
#
# Revision 1.3  2002/03/26 15:28:51  pgouley
# BUG:EVOL USR:PGY MSG:use the conf key alarm_client and better daemonize process
#
# Revision 1.2  2002/03/08 14:25:15  pgouley
# BUG:EVOL USR:PGY MSG:Use getParam of library Trace
#
# Revision 1.1  2001/12/26 15:24:53  pgouley
# BUG:ALARM USR:PGY MSG:Creation
# 
#
#@END
################################################################################

use Env(HOME);

use lib "$HOME/COMMON/lib";
use Conf;
use Trace;
use strict;
use vars qw($opt_d $opt_o $opt_t $opt_k);
use Getopt::Std;
use POSIX qw(setsid);
use Config;
use Sys::Hostname;

my $CONF =new Conf("alarm_client");
my $TRACE = new Trace($CONF->getParam("logFile"),"debug");

my $HOST=hostname();

my @sig_exclu = ('ZERO','CLD','CHLD','CONT');
defined $Config{sig_name} || die "No sigs?";
foreach my $name (split(' ', $Config{sig_name})) {
  unless(grep {/^$name$/}@sig_exclu){
    $SIG{$name}  = \&catch_sig;
  }
} 


my $diedpid;
sub deadbabe {
        $diedpid=wait;
        $SIG{CHLD} = \&deadbabe;
# stupid sys5 resets the signal when called - but only -after- the wait...
}
$SIG{CHLD} = \&deadbabe;
# Catch any dead child process


my $USER=$ENV{USER};

getopts('dotk');


my $debug=0;
if ($opt_t) {
	$debug=1;
}


#Verify the parameters
if (($opt_d && $opt_o)||($opt_d && $opt_k)||($opt_o && $opt_k)) { 
  &usage(1);
}
if (!$opt_d && !$opt_o && !$opt_k) {
  &usage(2);
}

if ($opt_k) {
	&kill_daemon
}

if ($opt_d){
 
  &daemonize();
  $TRACE->print("$0 started");
  
  my $first_sec=0;
  while (1){
    sleep($CONF->getParam("sleep_delay"));
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    
    if (-e "$HOME/COMMON/LOG/collector_local" && $sec!=$first_sec) {
      $first_sec=$sec;
      &send;
	}
  }
}
else {
  if (-e "$HOME/COMMON/LOG/collector_local") {
    &send;
  }
}

$TRACE->close_trace();



sub usage {
  my $error = shift;
  if($error==1){
    print STDERR "Can't use two modes option in same time\n";
  }
  if($error==2){
    print STDERR "precise launch method\n";
  }
  
  print STDERR "Please, use the script alarm_s to launch this command !\n\n";
  print STDERR "$0 <-d|-o|-k> [-t]\n";
  print STDERR "\t-d : start daemon (action every minute)\n";
  print STDERR "\t-o : start one shot\n";
  print STDERR "\t-k : kill the daemon\n";
  print STDERR "\t-t : testing mode (no ict alarm, mail to developer...)\n";
  exit(1);	
}


sub send {
	#calcul du nom du fichier destination :
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	if ($mday<10) {$mday="0".$mday;}
	$mon++; 		if ($mon<10) {$mon="0".$mon;}
	$year+=1900; 	if ($year<10) {$year="0".$year;}
	if ($hour<10) {$hour="0".$hour;}
	if ($min<10) {$min="0".$min;}
	if ($sec<10) {$sec="0".$sec;}
	my $dest = "collector_".$HOST."_".$mday.$mon.$year."_".$hour.$min.$sec;
	#print STDERR "fichier dest : $dest\n";
	
	
	
	my $stdout;
	my $stderr;
	
	
	
	&Trace::_lock_on;
		#scp collector_local to the alarm host
		&common::system3($CONF->getParam('path_scp')."/scp -B -q -i ".$CONF->getParam('id_rsa')." $HOME/COMMON/LOG/collector_local ".$CONF->getParam('user_alarm')."\@".$CONF->getParam('host_alarm').":".$CONF->getParam('path_alarm')."/".$dest,\$stdout,\$stderr);

		$stderr =~ s/stty: : Not a typewriter//;
  		chomp($stderr);
  		if ($stderr ne '') {
		# mechanism of fail-over :
			$TRACE->print("secure copy of collector_local to ".$CONF->getParam('user_alarm')."\@".$CONF->getParam('host_alarm').":".$CONF->getParam('path_alarm')."/".$dest." is impossible","ERROR");
			my $nb_try=0;
			if (-e $CONF->getParam('nbtryFile')) {
				&common::system3("cat ".$CONF->getParam('nbtryFile'),\$nb_try,\$stderr);
			}
			$nb_try++;
			system("echo \"$nb_try\" > ".$CONF->getParam('nbtryFile'));
			
			if ($nb_try >= $CONF->getParam('nbtry')){
				&Trace::_lock_off;
				&common::system3("rm ".$CONF->getParam('nbtryFile'),\$stdout,\$stderr);
				
				$TRACE->print($CONF->getParam('nbtry')." attemps failed !!! : daemon stopped","ERROR");
				
				system("echo \"daemon alarm_s ($HOST) was stopped : ".$CONF->getParam('nbtry')." consecutive attemps failed !!!\" > /var/tmp/alarm_sd.$$.tmp;
				$HOME/APPLI/bin/fast_push -s \"Error in Alarm sending daemon\" -F \"Alarm Sending\" /var/tmp/alarm_sd.$$.tmp ".$CONF->getParam('error_recip')."; 
				rm /var/tmp/alarm_sd.$$.tmp");

				&common::system3("$HOME/COMMON/bin/alarm_s stop",\$stdout,\$stderr);
			}
			
		}else{
			if (-e $CONF->getParam('nbtryFile')){
				&common::system3("rm ".$CONF->getParam('nbtryFile'),\$stdout,\$stderr);
			}
			
			#delete collector_local
			&common::system3("rm $HOME/COMMON/LOG/collector_local",\$stdout,\$stderr);
			if ($stderr) {$TRACE->print("couldn't delete collector_local","ERROR");}
			&Trace::_lock_off;

			#create the local file $dest_OK
			#this file is needed to know that the precedent transfer has been successful
			my $dest_OK=$dest."_OK";
			&common::system3("touch /tmp/$dest_OK",\$stdout,\$stderr);
			if ($stderr) {$TRACE->print("couldn't create /tmp/$dest_OK","ERROR");}
			#scp $dest_OK to the alarm host
			&common::system3($CONF->getParam('path_scp')."/scp  -B -q -i ".$CONF->getParam('id_rsa')." /tmp/$dest_OK ".$CONF->getParam('user_alarm')."\@".$CONF->getParam('host_alarm').":".$CONF->getParam('path_alarm')."/".$dest_OK,\$stdout,\$stderr); 
			$stderr =~ s/stty: : Not a typewriter//;
  			chomp($stderr);
  			if ($stderr ne '') {
				$TRACE->print("secure copy of /tmp/$dest_OK to ".$CONF->getParam('user_alarm')."\@".$CONF->getParam('host_alarm').":".$CONF->getParam('path_alarm')."/$dest_OK is impossible","ERROR");
			}
			#delete the local file $dest_OK
			&common::system3("rm /tmp/$dest_OK",\$stdout,\$stderr);
			if ($stderr) {$TRACE->print("couldn't delete /tmp/$dest_OK","ERROR");}


			$TRACE->print("ALARM $dest is sent"); 
		}
}

sub catch_sig {
	my $sig_name =shift;
	$TRACE->print("Receive Signal : $sig_name, end process");
    unlink($CONF->getParam('pidFile'));
    print "$0 Ended\n";
	&Trace::_lock_off;
	exit undef; 
}

sub daemonize {
    chdir "/tmp/"								or die "Can't chdir to /: $!";
    open STDIN, "/dev/null"						or die "Can't read /dev/null: $!";
    open STDOUT, ">>".$CONF->getParam("logFile")	or die "Can't write to ".$CONF->getParam("logFile").": $!";
    open STDERR, ">>".$CONF->getParam("logFile")	or die "Can't write to ".$CONF->getParam("logFile").": $!";
    if(my $pid = fork) {
      system("echo \"$pid\" >".$CONF->getParam("pidFile"));
      exit;
    }
    setsid										or die "Can't start a new session: $!";
    umask 0;
}

