##############################################################################
#
# mh_luserstats.pl v0.09 (201805011800)
#
# Copyright (c) 2018  Michael Hansen
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
# OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
##############################################################################
#
# collect server and network usercounts in CSV files
#
# about:
#
# 	alpha quality. be carefull! please read documentation before loading
#
# 	*** <timestamp> format is uncertain and being tested, do not use ***
#
# 	note: both datadir layout and CSV file format have changed slightly since
# 	v0.06 and are no longer compatible. the mh_luserstats_servertag setting
# 	have gone and replaced by the slightly different mh_luserstats_server
#
# 	this will collect luserstats for the local server and global network set
# 	in mh_luserstats_server (while you are connected to it) into a set of CSV
# 	files stored under the directory set in mh_luserstats_datadir. the idea
# 	being these files can be used to generate pretty graphs of usercounts on
# 	a server and/or network over time. it is currently hardcoded to request
# 	data once per minute
#
# 	datadir layout: data/<network>/<server>/<year>/<month>/<dayofmonth>.csv
#
# 	<month> and <dayofmonth> are zeropadded numbers
#
# 	the collected data is local, and global usercounts and their max values
# 	as returned by the server 'USERS' command. this will not work if the
# 	server is in strict rfc1459 mode and it may not be portable across ircds
#
# 	CSV file format: <timestamp>,<local>,<local max>,<global>,<global max>
#
# 	should the script for some reason only collect some of the data and still
# 	write it to file, the missing fields will have a value of -1
#
# 	the command '/mh_luserstats' will show the script version, information
# 	about available servers, lastlog of script events (hardcoded to 42), and
# 	a few other details
#
# 	comments, suggestions and bug-reports are welcome
#
# 	-- Michael Hansen
#
# settings:
#
# 	mh_luserstats_debug (boolean; default: ON)
# 		enable/disable debug output
# 		you should probably leave this on unless you are very confident in my
# 		coding skills...
#
# 	mh_luserstats_datadir (string; default: '<irssi_dir>/mh_luserstats')
# 		directory under which we store out data files
# 		(<irssi_dir> is '~/.irssi' in a standard configuration of Irssi)
#
# 	mh_luserstats_server (string; default: '<network>/<server>')
# 		server we are getting luserstats from
# 		for example: /SET mh_luserstats_server IRCnet/irc.psychz.net
# 		(can be tricky to get right, but mh_luserstats_debug is your friend)
#
# todo:
#
# 	there are still a few unfinished parts and rough edges to file down...
#
# 	* persistently store all-time max local and global users for the server
# 	  (this is the next 'big' item. now that we have - i think - settled on
# 	  format for the data, introducing this extra file should be seamless
# 	* _debug should be for debugging only (and eliminated from the release)
#
# 	some thoughts on possible future changes?
#
# 	- <timestamp> could adjustable to some other format and/or timezone
# 	- the mh_luserstats_server setting could use a simple explanation - but i
# 	  cant come up with one. i barely know how it works myself :/  but it is
# 	  not very easy to get this setting right it seems
# 	- configurable delay between requests? it currently takes a reading every
# 	  minute, i feel this is often enough to get usefull data for graphs, but
# 	  not too often to be a strain on neither the client nor the server
# 	- 'LUSERS' return more info (including 'USERS') but is that really a job
# 	  for this script?
# 	- log multiple servers (either via multiple Irssi connections or via
# 	  remote requests (ie: 'USERS <someserver>')) this also needs the logfile
# 	  structure changed slightly and would open several concurrent files. i
# 	  am also not convinced we need this
# 	- flushing to files on each write (->autoflush(1)) could be optional, as
# 	  it is not needed unless we wanna check the CSV files 'live' (ex. for
# 	  generating per-hour graphs) or possibly to avoid dataloss should the
# 	  client crash. we could also flush at intervals
# 	- generating the graphs, i feel should be done externally via cron or
# 	  Some other means. but i am not against having the script trigger it at
# 	  intervals in some way
# 	- info/warn/error reporting is just a short list in memory, it could be
# 	  be stored to disk to avoid missing errors in lastlog, size of lastlog
# 	  could be configurable too
#
# 	and in case you actually read the code: i use a mix of tabs for indention
# 	and spaces for alignement. tabs are set to 4 characters. i have also, for
# 	some reason, attempted to stay within 78 character columns
#
# history:
#
# 	v0.09 (201805011800) --mh
# 		- debug release with extra code to hunt down timing issue
# 		- messages from script are now in lastlog via '/mh_luserstats'
# 		  (not entirely, still a few to test before moving out of debug)
# 		- added command '/mh_luserstats' (and removed the welcome banner)
# 		- added support for scriptassists module and commands scriptinfo
# 		- minor cosmetic changes to comments and code
#
# 	v0.08 (201804292135) --mh
# 		- hopefully fixed the <timestamp> to be localtime
# 		- cosmetic changes to comments and code
#
# 	v0.07 (201804281730) --mh
# 		- rewrite/cleanup. alpha release
#
# 	v0.06 (201804251140) --mh
# 	v0.05 (201804240615) --mh
# 	v0.04 (201804240215) --mh
# 	v0.03 (201804240200) --mh
# 	v0.02 (201804212245) --mh
# 	v0.01 (201804210000) --mh
# 		- initial pre-alpha release
#
##############################################################################

use strict;
use warnings;

use File::Path ();  # make_path()
use IO::Handle ();  # ->autoflush()
use Time::Local (); # timelocal_nocheck()

##############################################################################
#
# Irssi header
#
##############################################################################

use Irssi;

our $VERSION = '0.09';
our %IRSSI   =
(
	'name'        => 'mh_luserstats',
	'description' => 'collect server and network usercounts in CSV files',
	'changed'     => '201805011800',
	'license'     => 'ISC/BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => '-',
	'url'         => 'https://github.com/mh-source/irssi-scripts/',
	'modules'     => 'File::Path IO::Handle Time::Local',
	'commands'    => 'mh_luserstats',
);

##############################################################################
#
# global variables
#
##############################################################################

our $state = # global state/data information and storage
{
	'log'     => # logfile state information
	{
		'networkname' => undef, # networkname of current filname
		'servername'  => undef, # servername of current filname
		'fh'          => undef, # file-handle
		'mday'        => -1,    # day-of-month for filename and nightly
		                        # filename rotation
	},
	'data'    => # most recently collected data
	{
	},
	'lastlog' => # list of most recent errors/messages
	{
		'max' => 42,     # keep at most this many lastlog lines
		'log' => undef,  # array of lastlog lines
	},
};

##############################################################################
#
# debug functions
#
##############################################################################

sub debug_print
{
	#
	# print $data to Irssi if debug setting is enabled
	#
	# always returns true
	#
	my ($data) = @_;

	if (Irssi::settings_get_bool($IRSSI{'name'} . '_debug'))
	{
		Irssi::print('dbg: ' . $data,
			Irssi::MSGLEVEL_CLIENTCRAP |
			Irssi::MSGLEVEL_NOHILIGHT  |
			Irssi::MSGLEVEL_NO_ACT
		);
	}

	return(1);
}

##############################################################################
#
# Irssi functions
#
##############################################################################

sub irssi_print
{
	#
	# print $data to Irssi
	#
	# always returns true
	#
	my ($data) = @_;

	Irssi::print($data,
		Irssi::MSGLEVEL_CRAP      |
		Irssi::MSGLEVEL_NOHILIGHT |
		Irssi::MSGLEVEL_NO_ACT
	);

	return(1);
}

sub irssi_servers_qstr
{
	#
	# returns a sorted string of current network/servername pairs, space
	# separated, and individually quoted in doublequotes. if there are no
	# servers the string contains the unquoted word '<none>'
	#

	my $string = '';

	for my $serverrec (sort { $a->{'tag'} cmp $b->{'tag'} } Irssi::servers())
	{
		if (ref($serverrec) eq 'Irssi::Irc::Server') # only want irc servers
		{
			if (not $serverrec->{'connected'}) # only connected servers so we
			{                                  # can trust the 'real_address'
				next;
			}

			if ($string ne '') # prefix a space unless first servertag
			{
				$string .= ' '
			}

			my $chatnet = $serverrec->{'chatnet'};

			if ($chatnet eq '') # if server has no network, use tag instead
			{
				$chatnet = $serverrec->{'tag'};
			}

			$string .= '"' . $chatnet . '/'
			               . $serverrec->{'real_address'} . '"';
		}
	}

	if ($string eq '') # no servers found
	{
		return('<none>');
	}

	return($string);
}

##############################################################################
#
# script functions
#
##############################################################################

sub lastlog
{
	#
	# add new entry to lastlog containing $data. if the log has grown larger
	# than it is configured to, we remove the older entries
	#
	# always returns true
	#
	my ($data) = @_;

	#
	# prefix a timestamp in 'MM/DD HH:mm' format
	#

	my @now_struct = localtime();
		# 0    1    2     3     4    5     6     7     8
		# sec, min, hour, mday, mon, year, wday, yday, isdst

	$data = sprintf('%02d/%02d %02d:%02d'
			, (1+$now_struct[4]) # month
			, $now_struct[3]     # day of month
			, $now_struct[2]     # hour
			, $now_struct[1]     # minute
		)
	 	. '  ' . $data
	;

	push(@{$state->{'lastlog'}->{'log'}}, $data);

	while (@{$state->{'lastlog'}->{'log'}} > $state->{'lastlog'}->{'max'})
	{
		shift(@{$state->{'lastlog'}->{'log'}});
	}

	return(1);
}

sub luserstats
{
	#
	# this is called everytime we have a new set of data in $state
	#
	# always returns true
	#

	my $log  = $state->{'log'};
	my $data = $state->{'data'};

	#
	# do we need to roll over to or open a new logfile
	#

	my @time_struct = localtime($data->{'time'});
	   # 0    1    2     3     4    5     6     7     8
	   # sec, min, hour, mday, mon, year, wday, yday, isdst

	if (defined($log->{'fh'}))
	{
		if ($time_struct[3] != $log->{'mday'}) # day-of-month change or first
	                                           # write to the file
		{
			# close old file handle
			close($log->{'fh'}); # this can fail, but out of our hands then
			$log->{'fh'} = undef;
		}
		elsif (($log->{'networkname'} ne $data->{'networkname'}) or
		       ($log->{'servername'}  ne $data->{'servername'}))
		{
			#TODO: untested condition. when tested (re)move to lastlog
			debug_print('luserstats() network or server name changed.'
				. ' logfile re-open');
			# the server we are logging changed name, close old file handle
			close($log->{'fh'}); # this can fail, but out of our hands then
			$log->{'fh'} = undef;
		}
	}

	#
	# open logfile if needed
	#

	if (not defined($log->{'fh'}))
	{
		$log->{'networkname'} = $data->{'networkname'};
		$log->{'servername'}  = $data->{'servername'};
		$log->{'mday'}        = $time_struct[3];

		# path part first, so we can create it (aka 'mkdir -p')
		my $filename = Irssi::settings_get_str($IRSSI{'name'} . '_datadir')
			. '/data'
			. '/' . $log->{'networkname'}
			. '/' . $log->{'servername'}
			. '/' . (1900+$time_struct[5])               # year
			. '/' . sprintf('%02d', (1+$time_struct[4])) # month (zeropadded)
		;

		File::Path::make_path $filename; # this can fail but we catch that at
		                                 # open()-time

		# add the filename part
		$filename .= '/' . sprintf("%02d", $log->{'mday'}) . '.csv';

		if (not open($log->{'fh'}, '>>:encoding(UTF-8)', $filename))
		{
			#TODO: untested condition. when tested (re)move to lastlog
			debug_print('luserstats() error! open failed for "' . $filename
				. '": ' . "$!");
			$log->{'fh'} = undef;
			return(1);
		}

		$log->{'fh'}->autoflush(1);
	}

	#
	# lets get our data stored on file
	#

	if (not print( { $log->{'fh'} }
		Time::Local::timelocal_nocheck(@time_struct)
		. ',' . $data->{'users'}->{'local'}->{'current'}
		. ',' . $data->{'users'}->{'local'}->{'max'}
		. ',' . $data->{'users'}->{'global'}->{'current'}
		. ',' . $data->{'users'}->{'global'}->{'max'}
		. "\n"))
	{
		#TODO: might try open the file and write to it once more before
		#      giving up.
		#TODO: this should be reported in the script proper and removed
		#TODO: untested condition. when tested (re)move to lastlog
		debug_print('luserstats() error! print failed: ' . "$!" );
		# close old file handle
		close($log->{'fh'}); # this will probably fail, but meh
		$log->{'fh'} = undef;
		return(1);
	}

	return(1);
}

sub next_timeout_luserstats
{
	#
	# calculate how long time until next timeout_luserstats() and
	# add an Irssi timeout for it
	#
	# always returns true
	#

	my @now_struct = localtime();
	   # 0    1    2     3     4    5     6     7     8
	   # sec, min, hour, mday, mon, year, wday, yday, isdst

	# add timeout at next    whole minute       (in msecs)
	Irssi::timeout_add_once((60 - $now_struct[0]) * 1000,
		'timeout_luserstats', undef
	);

	return(1);
}

##############################################################################
#
# Irssi timeout handlers
#
##############################################################################

sub timeout_luserstats
{
	#
	# main timeout running in the background requesting data from the server
	#
	# always returns true
	#

	$state->{'data'} =
	{
		'time'        => time(), # timestamp of current data
		'networkname' => undef,  # networkname from Irssi, based on setting
		'servername'  => undef,  # servername from Irssi, based on setting
		'users'       =>         # usercounts from server, default to -1
		{
			'local'   =>
			{
				'current' => -1,
				'max'     => -1,
			},
			'global'  =>
			{
				'current' => -1,
				'max'     => -1,
			},
		},
	};

	my $data = $state->{'data'};

	#
	# find a serverrec matching our setting
	#

	my ($networkname, $servername, undef) =
		# '<networkname>/<server>'
		# any additional '/' and text following it will be dropped
		split('/', Irssi::settings_get_str($IRSSI{'name'} . '_server'), 3
	);

	my $serverrec = undef;

	for (Irssi::servers())
	{
		$serverrec = $_; # 'for $var (...)' would localize $var

		if (ref($serverrec) eq 'Irssi::Irc::Server') # only want irc servers
		{
			my $chatnet = $serverrec->{'chatnet'};

			if ($chatnet eq '') # server has no networkname, use tag instead
			{
				$chatnet = $serverrec->{'tag'};
			}

			if (($serverrec->{'connected'}) and
			    (lc($chatnet) eq lc($networkname)) and
			    (lc($serverrec->{'real_address'}) eq lc($servername)))
			{
				# we got a match, update state data and move on
				$data->{'networkname'} = $chatnet;
				$data->{'servername'}  = $serverrec->{'real_address'};
				last;
			}
		}

		# not a match
		$serverrec = undef;
	}

	if (not defined($serverrec)) # no matching server found this time
	{
		lastlog('no available server matching "'
			. Irssi::settings_get_str($IRSSI{'name'} . '_server') . '"'
		);
		$state->{'data'} = {};
		next_timeout_luserstats();
		return(1);
	}

	#
	# request luserstats
	#

	$serverrec->redirect_event($IRSSI{'name'} . ' USERS',
		1,  # stop events count
		'', # comparison argument
		-1, # remote (-1: use default)
		'', # failure signal
		{   # signals
			'event 265' => 'redir ' . $IRSSI{'name'} # RPL_LOCALUSERS
				. ' event numeric',
			'event 266' => 'redir ' . $IRSSI{'name'} # RPL_GLOBALUSERS
				. ' event numeric',
			''          => 'event empty',            # ignore everything else
		}
	);

	$serverrec->send_raw_now('USERS');
	next_timeout_luserstats();

	return(1);
}

##############################################################################
#
# Irssi signal handlers
#
##############################################################################

sub signal_redir_event_numeric
{
	#
	# numeric 265 and 266 signal handler for 'USERS' redirected commands
	#
	# always returns true
	#
	my ($serverrec, $data, $nickname, $userhost) = @_;

	#
	# $nickname contains the servername and $userhost is empty (for numeric
	# events)
	#

	if (not defined($nickname))
	{
		# should never happen. lets play it safe, we need it set to something
		$nickname = '<unknown>';
	}

	if (lc($nickname) ne lc($state->{'data'}->{'servername'}))
	{
		# should never happen. but we dont want the wrong data if it does
		#
		# (and i dont like not checking the networkname against $serverrec,
		# but the chances of that not matching are (i think) very slim. we
		# should after all never get a numeric redir event for something we
		# never requested. and we do not currently request from more than one
		# server)
		return(1);
	}

	#
	# numeric replies 265 and 266 are very similiar, so we use a little magic
	# to catch either
	#

	if ($data =~ m/^\S+\s+(\d+)\s+(\d+)\s+:Current (local|global)/)
	{
		# $3 is either 'local'/265 or 'global'/266
		my $numeric_type = lc($3);
		$state->{'data'}->{'users'}->{$numeric_type}->{'current'} = int($1);
		$state->{'data'}->{'users'}->{$numeric_type}->{'max'}     = int($2);

		if ($numeric_type eq 'global') # 'global' is our last expected event
		{
			# process collected data
			luserstats();
			$state->{'data'} = {};
		}
	}

	return(1);
}

##############################################################################
#
# Irssi command handlers
#
##############################################################################

sub command_luserstats
{
	#
	# print version and other useful information
	#
	# always returns true
	#
	my ($data, $server, $witem) = @_;

	irssi_print('mh_luserstats.pl v' . $VERSION
		. ' (' . $IRSSI{'changed'} . ') Copyright (c) 2018  Michael Hansen'
	);

	irssi_print(' with debug       : '
		. ((Irssi::settings_get_bool($IRSSI{'name'} . '_debug'))
		  ? ('ON') : ('OFF'))
	);
	irssi_print(' available servers: ' . irssi_servers_qstr);

	irssi_print('type "/SET ' . $IRSSI{'name'} . '" to see all settings');

	my $lastlog_line = 0;

	for my $line (@{$state->{'lastlog'}->{'log'}})
	{
		if ($lastlog_line == 0)
		{
			irssi_print(' lastlog:');
		}

		$lastlog_line++;

		irssi_print(' ' . $line);
	}

	#
	# trying to hunt down that pesky timestamp issue
	#

	irssi_print('<debug timestamp>');

	my $time  = time();
	my $ltstr = localtime();
	my @ltarr = localtime();
	my $gtstr = gmtime();
	my @gtarr = gmtime();
	my $sysd  = `date`;       chomp($sysd);
	my $sysu  = `date -u`;    chomp($sysu);
	my $sysr  = `date -R`;    chomp($sysr);
	my $syst  = `date +"%s"`; chomp($syst); $syst=int($syst);
	my $time2 = time();
	my $tllt  = Time::Local::timelocal(@ltarr);
	my $tlgt  = Time::Local::timelocal(@gtarr);
	my $tglt  = Time::Local::timegm(@ltarr);
	my $tggt  = Time::Local::timegm(@gtarr);

	my @arr_name = qw(se mi hr md mo yr wd yd ds
	                   -- -- -- -- -- -- -- -- --
	                  );

	if ($time2 != $time)
	{
		irssi_print('WARN : bad timing!');
	}

	my $ltarrstr = '';
	my $tmp_cnt     = @ltarr;

	while ($tmp_cnt)
	{
		$ltarrstr .= $arr_name[(@ltarr-$tmp_cnt)] . '=' . $ltarr[@ltarr-$tmp_cnt] . ' ';
		$tmp_cnt--;
	}

	my $gtarrstr = '';
	$tmp_cnt        = @gtarr;

	while ($tmp_cnt)
	{
		$gtarrstr .= $arr_name[(@gtarr-$tmp_cnt)] . '=' . $gtarr[@gtarr-$tmp_cnt] . ' ';
		$tmp_cnt--;
	}

	my $envtz = '<none>';

	if (exists($ENV{'TZ'}))
	{
		if (defined($ENV{'TZ'}))
		{
			$envtz = '"' . $ENV{'TZ'} . '"';
		}
		else
		{
			$envtz = '<undf>';
		}
	}

	irssi_print('e_tz : ' . $envtz);
	irssi_print('lt_a : ' . $ltarrstr);
	irssi_print('gt_a : ' . $gtarrstr);
	irssi_print('lt() : ' . $ltstr);
	irssi_print('gt() : ' . $gtstr);
	irssi_print('sysd : ' . $sysd );
	irssi_print('sysu : ' . $sysu );
	irssi_print('sysr : ' . $sysr );
	irssi_print('time : ' . $time . '  '
	                                 . (($time==$time) ? ('.... ') : ('???? '))
	                                 . (($time==$syst) ? ('syst ') : ('     '))
	                                 . (($time==$tllt) ? ('tllt ') : ('     '))
	                                 . (($time==$tlgt) ? ('tlgt ') : ('     '))
	                                 . (($time==$tglt) ? ('tglt ') : ('     '))
                                     . (($time==$tggt) ? ('tggt ') : ('     '))
	);

	irssi_print('syst : ' . $syst . '  '
	                                 . (($syst==$time) ? ('time ') : ('     '))
	                                 . (($syst==$syst) ? ('.... ') : ('???? '))
	                                 . (($syst==$tllt) ? ('tllt ') : ('     '))
	                                 . (($syst==$tlgt) ? ('tlgt ') : ('     '))
	                                 . (($syst==$tglt) ? ('tglt ') : ('     '))
                                     . (($syst==$tggt) ? ('tggt ') : ('     '))
	);
	irssi_print('tllt : ' . $tllt . '  '
	                                 . (($tllt==$time) ? ('time ') : ('     '))
	                                 . (($tllt==$syst) ? ('syst ') : ('     '))
	                                 . (($tllt==$tllt) ? ('.... ') : ('???? '))
	                                 . (($tllt==$tlgt) ? ('tlgt ') : ('     '))
	                                 . (($tllt==$tglt) ? ('tglt ') : ('     '))
                                     . (($tllt==$tggt) ? ('tggt ') : ('     '))
	);
	irssi_print('tlgt : ' . $tlgt . '  '
	                                 . (($tlgt==$time) ? ('time ') : ('     '))
	                                 . (($tlgt==$syst) ? ('syst ') : ('     '))
	                                 . (($tlgt==$tllt) ? ('tllt ') : ('     '))
	                                 . (($tlgt==$tlgt) ? ('.... ') : ('???? '))
	                                 . (($tlgt==$tglt) ? ('tglt ') : ('     '))
                                     . (($tlgt==$tggt) ? ('tggt ') : ('     '))
	);
	irssi_print('tglt : ' . $tglt . '  '
	                                 . (($tglt==$time) ? ('time ') : ('     '))
	                                 . (($tglt==$syst) ? ('syst ') : ('     '))
	                                 . (($tglt==$tllt) ? ('tllt ') : ('     '))
	                                 . (($tglt==$tlgt) ? ('tlgt ') : ('     '))
	                                 . (($tglt==$tglt) ? ('.... ') : ('???? '))
                                     . (($tglt==$tggt) ? ('tggt ') : ('     '))
	);
	irssi_print('tggt : ' . $tggt . '  '
	                                 . (($tggt==$time) ? ('time ') : ('     '))
	                                 . (($tggt==$syst) ? ('syst ') : ('     '))
	                                 . (($tggt==$tllt) ? ('tllt ') : ('     '))
	                                 . (($tggt==$tlgt) ? ('tlgt ') : ('     '))
	                                 . (($tggt==$tglt) ? ('tglt ') : ('     '))
                                     . (($tggt==$tggt) ? ('.... ') : ('???? '))
	);

	irssi_print('ltime:' . localtime($time));
	irssi_print('gtime:' . gmtime($time));
	irssi_print('lsyst:' . localtime($syst));
	irssi_print('gsyst:' . gmtime($syst));
	irssi_print('ltllt:' . localtime($tllt));
	irssi_print('gtllt:' . gmtime($tllt));
	irssi_print('ltlgt:' . localtime($tlgt));
	irssi_print('gtlgt:' . gmtime($tlgt));
	irssi_print('ltglt:' . localtime($tglt));
	irssi_print('gtglt:' . gmtime($tglt));
	irssi_print('ltggt:' . localtime($tggt));
	irssi_print('gtggt:' . gmtime($tggt));

	irssi_print('</debug timestamp>');

	return(1);
}


##############################################################################
#
# on load
#
##############################################################################

#
# register Irssi settings
#

Irssi::settings_add_bool($IRSSI{'name'}, $IRSSI{'name'} . '_debug',
	1
);
Irssi::settings_add_str( $IRSSI{'name'}, $IRSSI{'name'} . '_datadir',
	Irssi::get_irssi_dir() . '/' . $IRSSI{'name'}
);
Irssi::settings_add_str( $IRSSI{'name'}, $IRSSI{'name'} . '_server',
	'<network>/<server>'
);

#
# register Irssi command redirections
#

Irssi::Irc::Server::redirect_register($IRSSI{'name'} . ' USERS',
	0, # remote
	0, # remote timeout
	{  # start events
		'event 265' => 1, # RPL_LOCALUSERS
	},
	{  # stop events
		'event 266' => 1, # RPL_GLOBALUSERS
	},
	{  # optional events
	}
);

#
# register Irssi signals
#

Irssi::signal_add('redir ' . $IRSSI{'name'} . ' event numeric',
	'signal_redir_event_numeric'
);

#
# register Irssi commands
#

Irssi::command_bind(lc($IRSSI{'name'}), 'command_luserstats', $IRSSI{'name'});

#
# inital timeout, this sets everything in motion
#

Irssi::timeout_add_once(100, 'next_timeout_luserstats', undef);

#
# and put an entry in the lastlog, for good measure
#

lastlog('script loaded');

1;

##############################################################################
#
# eof mh_luserstats.pl
#
##############################################################################
