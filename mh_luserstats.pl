##############################################################################
#
# mh_luserstats.pl v0.08 (201804292135)
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
# 	<timestamp> is whatever the Irssi client host thinks is localtime
#
# 	should the script for some reason only collect some of the data and still
# 	write it to file, the missing fields will have a value of -1
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
# 	  replaced with _verbose for allowing the script to report some info and
# 	  soft-errors if the user desires. hard-errors should probably always be
# 	  reported, right now we just ignore them silently. it is a more-or-less
# 	  cosmetic issue so not high-priorty but should be done before going beta
# 	* (possibly optional via _verbose) welcome banner and other startup info
# 	  and state information should be moved to a sub(). might want to have a
# 	  command for seeing it (both to check version, but also to check if the
# 	  script tuns and is collecting info (eg. last collected data, active
# 	  availble servers, or file error/ok))
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
#
# 	and in case you actually read the code: i use a mix of tabs for indention
# 	and spaces for alignement. tabs are set to 4 characters. i have also, for
# 	some reason, attempted to stay within 78 character columns
#
# history:
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
#       - initial pre-alpha release
#
##############################################################################

use strict;
use warnings;

use File::Path;  # make_path()
use IO::Handle;  # ->autoflush()
use Time::Local; # timelocal_nocheck()

##############################################################################
#
# Irssi header
#
##############################################################################

use Irssi;

our $VERSION = '0.08';
our %IRSSI   =
(
	'name'        => 'mh_luserstats',
	'description' => 'collect server and network usercounts in CSV files',
	'changed'     => '201804292135',
	'license'     => 'ISC/BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => '-',
	'url'         => 'https://github.com/mh-source/irssi-scripts/',
);

##############################################################################
#
# global variables
#
##############################################################################

our $state = # global state/data information and storage
{
	'log'  => # logfile state information
	{
		'networkname' => undef, # networkname of current filname
		'servername'  => undef, # servername of current filname
		'fh'   => undef,        # file-handle
		'mday' => -1,           # day-of-month for filename and nightly
		                        # filename rotation
	},
	'data' => # most recently collected data
	{
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
			debug_print('luserstats() day changed. logfile roll-over');
			# close old file handle
			close($log->{'fh'}); # this can fail, but out of our hands then
			$log->{'fh'} = undef;
		}
		elsif (($log->{'networkname'} ne $data->{'networkname'}) or
		       ($log->{'servername'}  ne $data->{'servername'}))
		{
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
			. '/' . sprintf("%02d", (1+$time_struct[4])) # month (zeropadded)
		;

		File::Path::make_path $filename; # this can fail but we catch that at
		                                 # open()-time

		# add the filename part
		$filename .= '/' . sprintf("%02d", $log->{'mday'}) . '.csv';

		if (not open($log->{'fh'}, '>>:encoding(UTF-8)', $filename))
		{
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
# Irssi timeouts
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
		# '<networkname>/<servername>'
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
		debug_print('timeout_luserstats() no server match for: "'
			. Irssi::settings_get_str($IRSSI{'name'} . '_server')  . '"'
		);
		debug_print('timeout_luserstats() available servers  : '
			. irssi_servers_qstr()
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
# on load
#
##############################################################################

#
# welcome banner
#

irssi_print('mh_luserstats.pl v' . $VERSION
	. ' (' . $IRSSI{'changed'} . ') Copyright (c) 2018  Michael Hansen'
);

#
# Irssi settings
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
# print settings
#

irssi_print($IRSSI{'name'} . '_debug   = ' .
	Irssi::settings_get_bool($IRSSI{'name'} . '_debug')
);
irssi_print($IRSSI{'name'} . '_datadir = "' .
	Irssi::settings_get_str($IRSSI{'name'} . '_datadir') .'"'
);
irssi_print($IRSSI{'name'} . '_server  = "' .
	Irssi::settings_get_str($IRSSI{'name'} . '_server') .'"'
);

irssi_print('servers (active)      : ' . irssi_servers_qstr());

#
# Irssi command redirection for 'USERS'
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
# Irssi signals
#
Irssi::signal_add('redir ' . $IRSSI{'name'} . ' event numeric',
	'signal_redir_event_numeric'
);

#
# inital timeout, this sets everything in motion
#

Irssi::timeout_add_once(100, 'next_timeout_luserstats', undef);

1;

##############################################################################
#
# eof mh_luserstats.pl
#
##############################################################################
