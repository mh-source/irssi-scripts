##############################################################################
#
# mh_luserstats.pl
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
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
# IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
##############################################################################
#
# collects server lusers stats
#
# about:
#
# 	pre-alpha quality, beware!
#
# 	very verbose debug info is being printed by default, it can be disabled
# 	and enabled in Irssi with (respectively):
# 		/SCRIPT EXEC $Irssi::Script::mh_luserstats::debug = 0;
# 		/SCRIPT EXEC $Irssi::Script::mh_luserstats::debug = 1;
#
# 	probably very IRCnet specific
#
# 	make sure you set mh_luserstats_servertag in Irssi or the script will
# 	collect no data
#
# 	theres currently a hardcoded 1 minute delay between requests
#
# 	and it simply prints the data in Irssi, so it doenst even really collect
# 	data... yet
#
# 	the printed data format is:
# 	"luserstats: <servertag> <servername> <unixtime> <local>(<max>) <global>(<max>) <channels> <operators> <servers> <services>"
#                                                    |local->       |global->
#
# settings:
#
# 	mh_luserstats_servertag (string, default: '')
# 		server tag of server we monitor. you must set this to whatever Irssi
# 		calls the connection you want monitor or the script will not work.
# 		f.ex.: /SET mh_luserstats_servertag IRCnet
#
# history:
#
# 	v0.02 (201804212245) --mh
# 		- minor comment, code and header typo corrections/updates
# 		- added very verbose debug output
# 		- moved all numeric event handling into one sub
# 		- added channels formed to recorded data
# 		- added operators online to recorded data
# 		- added global server and service counts to recorded data
#
# 	v0.01 (20180421000) --mh
# 		- initial pre-alpha release
#
##############################################################################

use strict;
use warnings;

##############################################################################
#
# irssi header
#
##############################################################################

use Irssi;

our $VERSION = '0.02';
our %IRSSI   =
(
	'name'        => 'mh_luserstats',
	'description' => 'collects server lusers stats',
	'changed'     => '201804212245',
	'license'     => 'MIT',
	'authors'     => 'Michael Hansen',
	'contact'     => '-',
	'url'         => 'https://github.com/mh-source/irssi-scripts/',
);

##############################################################################
#
# script global variables
#
##############################################################################

our $debug        = 1; # set to 0 to disable
our $debug_indent = 0; # internal use for indenting debug output

our $state = {}; # we need to store data globally inbetween signals

##############################################################################
#
# script functions
#
##############################################################################

sub print_dbg
{
	my ($data) = @_;

	if ($debug)
	{
		print('luserstats: dbg:' . (' ' x $debug_indent) . $data);
	}

	return(1);
}

sub sec2msec
{
	my ($secs) = @_;
	return(1000 * $secs);
}

sub secs_till_0
{
	my ($secs) = @_;
	return(60 - $secs);
}

sub luserstats
{
	#
	# this is called everytime we have a new set of data in $state
	#
	$debug_indent++; print_dbg('luserstats() called');

	# print the data for debugging (and reference)
	print('luserstats: '
		. $state->{'servertag'}  . ' ' # servertag as set in mh_luserstats_servertag
		. $state->{'servername'} . ' ' # servername as returned by the server
		. $state->{'time'}       . ' ' # unix timestamp of current data
		. $state->{'local'}->{'current'}  . '(' . $state->{'local'}->{'max'}  . ') ' # local usercounts as returned by server
		. $state->{'global'}->{'current'} . '(' . $state->{'global'}->{'max'} . ') ' # global usercounts as returned by server
		. $state->{'channels'}        . ' ' # channels formed as returned by server
		. $state->{'operators'}       . ' ' # operators online as returned by server
		. $state->{'global_servers'}  . ' ' # servers online as returned by server
		. $state->{'global_services'} . ' ' # services online as returned by server
	);

	#TODO: do something with the data...

	print_dbg('luserstats() call done'); $debug_indent--;
	return(1);
}

##############################################################################
#
# irssi timeout functions
#
##############################################################################

sub timeout_luserstats
{
	 $debug_indent++; print_dbg('timeout_luserstats() called');

	# clean state and start next timeout so we get that out of the way
	$state = {};
	$state->{'time'} = time();
	timeout_luserstats_next();

	#
	# find the right server and see if it is connected
	#

	$state->{'servertag'} = Irssi::settings_get_str('mh_luserstats_servertag');

	if ($state->{'servertag'} eq '')
	{
		# servertag not configured
		$state = {};
		print_dbg('timeout_luserstats() warning: servertag not configured. done'); $debug_indent--;
		return(1);
	}

	print_dbg('timeout_luserstats() servertag is "' . $state->{'servertag'}  . '"');

	my $serverrec = Irssi::server_find_tag($state->{'servertag'});

	if (ref($serverrec) ne 'Irssi::Irc::Server')
	{
		# serverrec not found
		print_dbg('timeout_luserstats() warning: serverrec not found for "' . $state->{'servertag'}  . '". done'); $debug_indent--;
		return(1);
	}

	if (not $serverrec->{'connected'})
	{
		# server not fully connected
		print_dbg('timeout_luserstats() warning: server "' . $state->{'servertag'}  . '" not fully connected. done'); $debug_indent--;
		return(1);
	}

	#
	# request luserstats
	#

	print_dbg('timeout_luserstats() sending request...');

	$serverrec->redirect_event('mh_luserstats lusers',
		1,  # stop events count
		'', # comparison argument
		-1, # remote (-1: use default)
		'', # failure signal
		{   # signals
			'event 251' => 'redir mh_luserstats event numeric', # RPL_LUSERCLIENT
			'event 252' => 'redir mh_luserstats event numeric', # RPL_LUSEROP
			'event 254' => 'redir mh_luserstats event numeric', # RPL_LUSERCHANNELS
			'event 265' => 'redir mh_luserstats event numeric', # RPL_LOCALUSERS
			'event 266' => 'redir mh_luserstats event numeric', # RPL_GLOBALUSERS
			''          => 'event empty',                       # ignore everything else
		}
	);

	$serverrec->send_raw_now('LUSERS');

	print_dbg('timeout_luserstats() call done'); $debug_indent--;
	return(1);
}

sub timeout_luserstats_next
{
	$debug_indent++; print_dbg('timeout_luserstats_next() called');

	my @now_struct = localtime(); # sec, min, hour, mday, mon, year, wday, yday, isdst
	                              # 0    1    2     3     4    5     6     7     8

	# next timeout at next whole minute
	Irssi::timeout_add_once(sec2msec(secs_till_0($now_struct[0])), 'timeout_luserstats', undef);

	print_dbg('timeout_luserstats_next() call done [next timeout_luserstats() in ' . secs_till_0($now_struct[0]) . ' secs]'); $debug_indent--; 
	return(1);
}

##############################################################################
#
# irssi signal functions
#
##############################################################################

sub signal_redir_event_numeric
{
	my ($serverrec, $data, $nickname, $userhost) = @_;

	my $numeric = Irssi::parse_special('$H');

	$debug_indent++; print_dbg('signal_redir_event_numeric() called [numeric: ' . $numeric . ']');

	#
	# $nickname contains the servername and $userhost is empty (for numeric events)
	#

	if (not defined($nickname))
	{
		# should never happen, but lets play it safe
		$nickname = '<unknown>';
	}

	print_dbg('signal_redir_event_numeric() nickname/servername is "' . $nickname . '"');

	#
	# set the servername or make sure it is the same if already set
	#

	if (defined($state->{'servername'}))
	{
		if ($state->{'servername'} ne $nickname)
		{
			# this should never happen, but would mess stats badly
			print_dbg('signal_redir_event_numeric() warning: nickname "' . $nickname  . '" not same as servername "' . $state->{'servername'}  . '". done'); $debug_indent--;
			return(1);
		}
	}
	else
	{
		$state->{'servername'} = $nickname;

		# in case we do not get any 25# replies
		$state->{'channels'}        = -1;
		$state->{'operators'}       = -1;
		$state->{'global_services'} = -1;
		$state->{'global_servers'}  = -1;
	}

	#
	# $data should be from one of:
	#
	# 251 RPL_LUSERCLIENT   "nickname :There are 123 users and 1 services on 12 servers"
	# 252 RPL_LUSEROP       "nickname 12 :operators online"
	# 254 RPL_LUSERCHANNELS "nickname 123 :channels formed"
	# 265 RPL_LOCALUSERS    "nickname 123 456 :Current local users 123, max 456"
	# 266 RPL_GLOBALUSERS   "nickname 123 456 :Current global users 123, max 456"
	#
	#TODO: numerics left to parse (if needed)
	#
	# 253 "nickname 1 :unknown connections"
	# 255 "nickname :I have 3901 users, 0 services and 1 servers"

	if ($numeric == 251)
	{
		if ($data =~ m/^\S+\s+:There are (\d+) users and (\d+) services on (\d+) servers/)
		{
			# we also got a global user count, but it is (or should be) the same as in 266
			# so ignore it for now (but it is in $1 if needed)
			$state->{'global_services'} = int($2);
			$state->{'global_servers'}  = int($3);

			print_dbg('signal_redir_event_numeric() matched event 251/servs');
		}
		else
		{
			print_dbg('signal_redir_event_numeric() warning: matched event 251 but not data');
		}
	}
	elsif ($numeric == 252)
	{
		if ($data =~ m/^\S+\s+(\d+)\s+:operators online/)
		{
			$state->{'operators'} = int($1);

			print_dbg('signal_redir_event_numeric() matched event 252/operators');
		}
		else
		{
			print_dbg('signal_redir_event_numeric() warning: matched event 252 but not data');
		}
	}
	elsif ($numeric == 254)
	{
		if ($data =~ m/^\S+\s+(\d+)\s+:channels formed/)
		{
			$state->{'channels'} = int($1);

			print_dbg('signal_redir_event_numeric() matched event 254/channels');
		}
		else
		{
			print_dbg('signal_redir_event_numeric() warning: matched event 254 but not data');
		}
	}
	elsif (($numeric == 265) or ($numeric == 266))
	{
		if ($data =~ m/^\S+\s+(\d+)\s+(\d+)\s+:Current (local|global)/)
		{
			$state->{$3}->{'current'} = int($1);
			$state->{$3}->{'max'}     = int($2);

			print_dbg('signal_redir_event_numeric() matched event "' . $3 . '"');

			# 266 is our last event so this is where it ends
			if ($numeric == 266)
			{
				luserstats(); # this is where we process the global $state data
				$state = {};
			}
		}
		else
		{
			print_dbg('signal_redir_event_numeric() warning: matched event 265/6 but not data');
		}
	}

	print_dbg('signal_redir_event_numeric() call done'); $debug_indent--;
	return(1);
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::settings_add_str('mh_luserstats', 'mh_luserstats_servertag', ''); # server tag of server we monitor

Irssi::Irc::Server::redirect_register('mh_luserstats lusers',
	0, # remote
	0, # remote timeout
	{  # start events
		'event 251' => 1, # RPL_LUSERCLIENT   (this is where we get global service and server counts)
		'event 252' => 1, # RPL_LUSEROP       (this is where we get global operator count)
		'event 253' => 1, # RPL_LUSERUNKNOWN  (currently ignored)
		'event 254' => 1, # RPL_LUSERCHANNELS (this is where we get global channel count)
		'event 255' => 1, # RPL_LUSERME       (currently ignored)
		'event 265' => 1, # RPL_LOCALUSERS    (this is where we get local user counts)
	},
	{  # stop events
		'event 266' => 1, # RPL_GLOBALUSERS   (this is where we get global user counts)
	},
	{  # optional events
	}
);

Irssi::signal_add('redir mh_luserstats event numeric', 'signal_redir_event_numeric');

Irssi::timeout_add_once(100, 'timeout_luserstats_next', undef);

print_dbg(' mh_luserstats.pl loaded');

1;

##############################################################################
#
# eof mh_luserstats.pl
#
##############################################################################
