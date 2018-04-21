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
# collects server usercount stats
#
# about
#
# 	pre-alpha quality, beware!
#
# 	probably very IRCnet specific
#
# 	make sure you set mh_luserstats_servertag in Irssi or the script will
# 	happilly collect no data and kindly not inform you why
#
# 	theres currently a hardcoded 1 minute delay between requests
#
# 	and it simply prints the data in Irssi, so it doenst even really collect
# 	data... yet
#
# 	the printed data format is:
# 	"<servertag> <servername> <unixtime> <local>(<max>) <global>(<max>)"
#
# settings:
#
# 	mh_luserstats_servertag (string, default: '')
# 		server tag of server we monitor. you must set this to whatever Irssi
# 		calls the connection you want monitor or the script will not work.
# 		f.ex.: /SET mh_luserstats_servertag IRCnet
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

our $VERSION = '0.01';
our %IRSSI   =
(
	'name'        => 'mh_luserstats',
	'description' => 'collects server usercount stats',
	'changed'     => '201804210000',
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

our $state = {}; # we need to store data globally inbetween signals

##############################################################################
#
# script functions
#
##############################################################################

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

	# print the data for debugging (and reference)
	print($state->{'servertag'}  . ' ' # servertag as set in mh_luserstats_servertag
		. $state->{'servername'} . ' ' # servername as returned by the server
		. $state->{'time'}       . ' ' # unix timestamp of current data
		. $state->{'local'}->{'current'}  . '(' . $state->{'local'}->{'max'}  . ') ' # local usercounts as returned by server
		. $state->{'global'}->{'current'} . '(' . $state->{'global'}->{'max'} . ') ' # global usercounts as returned by server
	);

	#TODO: do something with the data...

	return(1);
}

##############################################################################
#
# irssi timeout functions
#
##############################################################################

sub timeout_luserstats
{
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
		# no servertag configured
		$state = {};
		return(1);
	}

	my $serverrec = Irssi::server_find_tag($state->{'servertag'});

	if (ref($serverrec) ne 'Irssi::Irc::Server')
	{
		# no serverrec found
		return(1);
	}

	if (not $serverrec->{'connected'})
	{
		# server not fully connected
		return(1);
	}

	#
	# request luserstats
	#

	$serverrec->redirect_event('mh_luserstats lusers',
		1,  # stop events count
		'', # comparison argument
		-1, # remote (-1: use default)
		'', # failure signal
		{   # signals
			'event 265' => 'redir mh_luserstats event 265', # RPL_LOCALUSERS
			'event 266' => 'redir mh_luserstats event 266', # RPL_GLOBALUSERS
			''          => 'event empty',                   # ignore everything else
		}
	);

	$serverrec->send_raw_now('LUSERS');

	return(1);
}

sub timeout_luserstats_next
{
	my @now_struct = localtime(); # sec, min, hour, mday, mon, year, wday, yday, isdst
	                              # 0    1    2     3     4    5     6     7     8

	# next timeout at next whole minute
	Irssi::timeout_add_once(sec2msec(secs_till_0($now_struct[0])), 'timeout_luserstats', undef);

	return(1);
}

##############################################################################
#
# irssi signal functions
#
##############################################################################

sub signal_redir_event_265_6
{
	my ($serverrec, $data, $nickname, $userhost) = @_;

	#
	# $nickname contains the servername and $userhost is empty (for numeric events)
	#

	if (not defined($nickname))
	{
		# should never happen, but lets play it safe
		$nickname = '<unknown>';
	}

	#
	# set the servername or make sure it is the same if already set
	#

	if (defined($state->{'servername'}))
	{
		if ($state->{'servername'} ne $nickname)
		{
			# this should never happen
			return(1);
		}
	}
	else
	{
		$state->{'servername'} = $nickname;
	}

	#
	# $data should be from one of:
	#
	# 265 RPL_LOCALUSERS  "nickname 123 456 :Current local users 123, max 456"
	# 266 RPL_GLOBALUSERS "nickname 123 456 :Current global users 123, max 456"
	#

	if ($data =~ m/^\S+\s+(\d+)\s+(\d+)\s+:Current (local|global)/)
	{
		$state->{$3}->{'current'} = int($1);
		$state->{$3}->{'max'}     = int($2);

		# crude, but 266 is our last event so this is where it ends
		if (defined($state->{'global'}))
		{
			luserstats(); # this is very we process the global $state data
			$state = {};
		}
	}

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
		'event 251' => 1, # RPL_LUSERCLIENT   (currently ignored)
		'event 252' => 1, # RPL_LUSEROP       (currently ignored)
		'event 253' => 1, # RPL_LUSERUNKNOWN  (currently ignored)
		'event 254' => 1, # RPL_LUSERCHANNELS (currently ignored)
		'event 255' => 1, # RPL_LUSERME       (currently ignored)
		'event 265' => 1, # RPL_LOCALUSERS    (this is where we get local user counts)
	},
	{  # stop events
		'event 266' => 1, # RPL_GLOBALUSERS   (this is where we get global user counts)
	},
	{  # optional events
	}
);

Irssi::signal_add('redir mh_luserstats event 265', 'signal_redir_event_265_6');
Irssi::signal_add('redir mh_luserstats event 266', 'signal_redir_event_265_6');

Irssi::timeout_add_once(100, 'timeout_luserstats_next', undef);

1;

##############################################################################
#
# eof mh_luserstats.pl
#
##############################################################################
