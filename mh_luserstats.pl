##############################################################################
#
# mh_luserstats.pl v0.05 (201804240615) Copyright (c) 2018  Michael Hansen
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
# 	probably very IRCnet specific
#
# 	make sure you set mh_luserstats_servertag in Irssi or the script will
# 	collect no data
#
# 	You can enable and disable debug output with the mh_luserstats_debug
# 	setting, OFF by default
#
# 	theres currently a hardcoded 1 minute delay between requests
#
# 	and it simply prints the data in Irssi, so it doenst even really collect
# 	data... yet
#
# 	the printed data format is:
# 	"luserstats: <servertag> <servername> <unixtime> <local>(<max>) <global>(<max>) <channels> <operators> <servers> <services>"
#
# settings:
#
# 	mh_luserstats_servertag (string, default: '')
# 		server tag of server we monitor. you must set this to whatever Irssi
# 		calls the connection you want monitor or the script will not work.
# 		f.ex.: /SET mh_luserstats_servertag IRCnet
#
# 	mh_luserstats_debug (boolean, default: OFF)
# 		enable/disable debug output
#
# history:
#
# 	v0.05 (201804240615) --mh
# 		- fixed showstopper bug in v0.04 (never finding a valid servertag)
# 		- irssi-info license name changed from MIT to the most correct i could
# 		  come up with ISC/BSD (being old ISC with "and" not "and/or")
# 		- minor cosmetic fixes to code and header, as usual
#
# 	v0.04 (201804240215) --mh
# 		- oops, missed a debug print line, messed up debug output
#
# 	v0.03 (201804240200) --mh
# 		- internal code cleanup, _shouldnt_ make functional difference
# 		- for ease of use, debug is now an Irssi setting _debug
# 		- cosmetic changes to some debug output
# 		- added a welcome banner of sorts, printed regardles of debug on/off
# 		- debug availability moved inside ifdefs for easy removal later
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

our $VERSION = '0.05';
our %IRSSI   =
(
	'name'        => 'mh_luserstats',
	'description' => 'collects server lusers stats',
	'changed'     => '201804240615',
	'license'     => 'ISC/BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => '-',
	'url'         => 'https://github.com/mh-source/irssi-scripts/',
);

##############################################################################
#
# script global variables
#
##############################################################################

our $debug_indent = 0; # internal use for indenting debug output

our $state = {}; # we need to store data globally inbetween signals

##############################################################################
#
# script debug functions
#
##############################################################################

sub print_dbg
{
	my ($data) = @_;

	if (Irssi::settings_get_bool($IRSSI{'name'} . '_debug'))
	{
		Irssi::print('dbg' . (' ' x $debug_indent) . $data,  Irssi::MSGLEVEL_CLIENTCRAP | Irssi::MSGLEVEL_NO_ACT | Irssi::MSGLEVEL_NOHILIGHT);
	}

	return(1);
}

##############################################################################
#
# script general functions
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

##############################################################################
#
# script functions
#
##############################################################################

sub state_clr
{
	$state = {};
	return(1);
}

sub state_new
{
	state_clr();
	$state->{'time'}                           = time(); # unix timestamp of current data
	$state->{'servertag'}                      = undef;  # servertag as set in mh_luserstats_servertag
	$state->{'servername'}                     = undef;  # servername as returned by the server
	$state->{'channels'}                       = -1;     # channels formed as returned by server
	$state->{'operators'}                      = -1;     # operators online as returned by server
	$state->{'services'}                       = -1;     # servers online as returned by server
	$state->{'servers'}                        = -1;     # services online as returned by server
	$state->{'users'}->{'global'}->{'current'} = -1;     # global usercount as returned by server
	$state->{'users'}->{'global'}->{'max'}     = -1;     # global max usercount as returned by server
	$state->{'users'}->{'local'}->{'current'}  = -1;     # local usercount as returned by server
	$state->{'users'}->{'local'}->{'max'}      = -1;     # local max usercount as returned by server
	return(1);
}

sub luserstats
{
	$debug_indent++; print_dbg('luserstats() called');

	#
	# this is called everytime we have a new set of data in $state
	#

	# print the data for debugging (and reference)
	irssi_print('luserstats: '
		. $state->{'servertag'}  . ' '
		. $state->{'servername'} . ' '
		. $state->{'time'}       . ' '
		. $state->{'users'}->{'local'}->{'current'}  . '('
		. $state->{'users'}->{'local'}->{'max'}      . ') '
		. $state->{'users'}->{'global'}->{'current'} . '('
		. $state->{'users'}->{'global'}->{'max'}     . ') '
		. $state->{'channels'}  . ' '
		. $state->{'operators'} . ' '
		. $state->{'servers'}   . ' '
		. $state->{'services'}
	);

	print_dbg('luserstats() done'); $debug_indent--;
	return(1);
}

sub luserstats_next_timeout
{
	$debug_indent++; print_dbg('luserstats_next_timeout() called');

	my @now_struct = localtime(); # sec, min, hour, mday, mon, year, wday, yday, isdst
	                              # 0    1    2     3     4    5     6     7     8
	# next timeout at next whole minute
	Irssi::timeout_add_once(sec2msec(secs_till_0($now_struct[0])), 'timeout_luserstats', undef);

	print_dbg('luserstats_next_timeout() done [next timeout_luserstats() in ' . secs_till_0($now_struct[0]) . ' secs]'); $debug_indent--; 
	return(1);
}

##############################################################################
#
# irssi general functions
#
##############################################################################

sub irssi_print
{
	my ($data) = @_;
	Irssi::print($data, Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NO_ACT | Irssi::MSGLEVEL_NOHILIGHT);
	return(1);
}

sub irssi_current_numeric
{
	# this returns the current numeric being processed by irssi
	return(Irssi::parse_special('$H'));
}

sub irssi_list_servertags
{
	my $string = '';

	for my $serverrec (sort { $a->{'tag'} cmp $b->{'tag'} } Irssi::servers())
	{
		if (ref($serverrec) eq 'Irssi::Irc::Server')
		{
			if ($string ne '')
			{
				$string .= ' '
			}
			$string .= '"' . $serverrec->{'tag'} . '"';
		}
	}

	if ($string eq '')
	{
		$string = "<none>";
	}

	return($string);
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
	state_new();
	luserstats_next_timeout();

	#
	# find the right server and see if it is connected
	#

	$state->{'servertag'} = Irssi::settings_get_str($IRSSI{'name'} . '_servertag');

	if ($state->{'servertag'} eq '')
	{
		# servertag not configured
		print_dbg('timeout_luserstats() done [warning: servertag not configured]');
		print_dbg('timeout_luserstats()      [active servertags: ' . irssi_list_servertags() . ']'); $debug_indent--;
		state_clr();
		return(1);
	}

	my $serverrec = Irssi::server_find_tag($state->{'servertag'});

	if (ref($serverrec) ne 'Irssi::Irc::Server')
	{
		# serverrec not found
		print_dbg('timeout_luserstats() done [warning: serverrec "' . $state->{'servertag'}  . '" not found]');
		print_dbg('timeout_luserstats()      [active servertags: ' . irssi_list_servertags() . ']'); $debug_indent--;
		state_clr();
		return(1);
	}

	if (not $serverrec->{'connected'})
	{
		# server not fully connected
		print_dbg('timeout_luserstats() done [warning: server "' . $state->{'servertag'}  . '" not fully connected]'); $debug_indent--;
		state_clr();
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
			'event 251' => 'redir ' . $IRSSI{'name'} . ' event numeric', # RPL_LUSERCLIENT
			'event 252' => 'redir ' . $IRSSI{'name'} . ' event numeric', # RPL_LUSEROP
			'event 254' => 'redir ' . $IRSSI{'name'} . ' event numeric', # RPL_LUSERCHANNELS
			'event 265' => 'redir ' . $IRSSI{'name'} . ' event numeric', # RPL_LOCALUSERS
			'event 266' => 'redir ' . $IRSSI{'name'} . ' event numeric', # RPL_GLOBALUSERS
			''          => 'event empty',                                # ignore everything else
		}
	);

	$serverrec->send_raw_now('LUSERS');

	print_dbg('timeout_luserstats() done [request sent]'); $debug_indent--;
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

	my $numeric = irssi_current_numeric();

	$debug_indent++; print_dbg('signal_redir_event_numeric() called [numeric: ' . $numeric . ']');

	#
	# $nickname contains the servername and $userhost is empty (for numeric events)
	#

	if (not defined($nickname))
	{
		# nickname not defined
		# should never happen, but lets play it safe
		$nickname = '<unknown>';
		print_dbg('signal_redir_event_numeric() warning: nickname not defined');
	}

	#
	# set the servername or make sure it is the same if already set
	#

	if (defined($state->{'servername'}))
	{
		if ($state->{'servername'} ne $nickname)
		{
			# nickname not same as servername
			# this should never happen, but would mess stats badly
			print_dbg('signal_redir_event_numeric() done [warning: nickname "' . $nickname  . '" not same as servername "' . $state->{'servername'}  . '"]'); $debug_indent--;
			return(1);
		}
	}
	else
	{
		$state->{'servername'} = $nickname;
	}

	if ($numeric == 251)
	{
		if ($data =~ m/^\S+\s+:There are (\d+) users and (\d+) services on (\d+) servers/)
		{
			# we also get a global user count, but it is (or should be) the same as in 266
			# so ignore it for now (but it is in $1 if needed)
			$state->{'services'} = int($2);
			$state->{'servers'}  = int($3);
			print_dbg('signal_redir_event_numeric() matched event ' . $numeric);
		}
		else
		{
			print_dbg('signal_redir_event_numeric() warning: matched event ' . $numeric . ' but not data "' . $data .'"');
		}
	}
	elsif ($numeric == 252)
	{
		if ($data =~ m/^\S+\s+(\d+)\s+:operators online/)
		{
			$state->{'operators'} = int($1);
			print_dbg('signal_redir_event_numeric() matched event ' . $numeric);
		}
		else
		{
			print_dbg('signal_redir_event_numeric() warning: matched event ' . $numeric . ' but not data "' . $data .'"');
		}
	}
	elsif ($numeric == 254)
	{
		if ($data =~ m/^\S+\s+(\d+)\s+:channels formed/)
		{
			$state->{'channels'} = int($1);
			print_dbg('signal_redir_event_numeric() matched event ' . $numeric);
		}
		else
		{
			print_dbg('signal_redir_event_numeric() warning: matched event ' . $numeric . ' but not data "' . $data .'"');
		}
	}
	elsif (($numeric == 265) or ($numeric == 266))
	{
		if ($data =~ m/^\S+\s+(\d+)\s+(\d+)\s+:Current (local|global)/)
		{
			$state->{'users'}->{$3}->{'current'} = int($1);
			$state->{'users'}->{$3}->{'max'}     = int($2);
			print_dbg('signal_redir_event_numeric() matched event ' . $numeric);

			if ($numeric == 266) # 266 is our last event so this is where it ends
			{
				luserstats(); # process the global $state data
				state_clr();
			}
		}
		else
		{
			print_dbg('signal_redir_event_numeric() warning: matched event ' . $numeric . ' but not data "' . $data .'"');
		}
	}

	print_dbg('signal_redir_event_numeric() done'); $debug_indent--;
	return(1);
}

##############################################################################
#
# script on load
#
##############################################################################

# welcome banner
irssi_print('mh_luserstats.pl v' . $VERSION . ' (' . $IRSSI{'changed'} . ') Copyright (c) 2018  Michael Hansen');

# irssi settings
Irssi::settings_add_str( $IRSSI{'name'}, $IRSSI{'name'} . '_servertag', ''); # server tag of server we monitor
Irssi::settings_add_bool($IRSSI{'name'}, $IRSSI{'name'} . '_debug',     0);  # debug disabled/enabled

# print irssi settings
irssi_print($IRSSI{'name'} . '_servertag = "' . Irssi::settings_get_str( $IRSSI{'name'} . '_servertag') . '"');
irssi_print($IRSSI{'name'} . '_debug     = '  . Irssi::settings_get_bool($IRSSI{'name'} . '_debug'));

# irssi signals
Irssi::signal_add('redir ' . $IRSSI{'name'} . ' event numeric', 'signal_redir_event_numeric');

# irssi command redirection for 'LUSERS'
Irssi::Irc::Server::redirect_register($IRSSI{'name'} . ' lusers',
	0, # remote
	0, # remote timeout
	{  # start events
		'event 251' => 1, # RPL_LUSERCLIENT
		'event 252' => 1, # RPL_LUSEROP
		'event 253' => 1, # RPL_LUSERUNKNOWN
		'event 254' => 1, # RPL_LUSERCHANNELS
		'event 255' => 1, # RPL_LUSERME
		'event 265' => 1, # RPL_LOCALUSERS
	},
	{  # stop events
		'event 266' => 1, # RPL_GLOBALUSERS
	},
	{  # optional events
	}
);

irssi_print('active servertags       : ' . irssi_list_servertags());

Irssi::timeout_add_once(100, 'luserstats_next_timeout', undef);

1;

##############################################################################
#
# eof mh_luserstats.pl
#
##############################################################################
