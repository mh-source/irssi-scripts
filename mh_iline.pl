##############################################################################
#
# mh_iline.pl v0.06 (20170323)
#
# Copyright (c) 2017  Michael Hansen
#
# Permission to use, copy, modify, and distribute this software
# for any purpose with or without fee is hereby granted, provided
# that the above copyright notice and this permission notice
# appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL
# THE AUTHOR BE LIABLE FOR  ANY SPECIAL, DIRECT, INDIRECT, OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
# NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
##############################################################################
#
# IRC frontend to the https://i-line.space IRCnet I-line lookup service by pbl
#
# Will monitor channel(s) (and optionally private message) for the !iline command
# and return a list of IRCnet servers the given user/ip/nick can connect to.
#
# at a minimum you need to set mh_iline_channels as explained under settings
# with something like /set mh_iline_channels ircnet/#channel
#
# per default the client needs to be +v, +h or +o to monitor for commands, this can
# be disabled with /set mh_iline_require_privs off
#
# Please do read through the settings below. many things are configurable both with
# regards to look and behavior.
#
# the default command !iline will react as follows:
#
#	!iline          | lookup ip of command issuer
#	!iline ip(4/6)  | lookup the given ip v4 or v6, ex: !iline 127.0.0.1
#	!iline nickname | lookup the given nicknames ip if it is on the channel, ex: !iline mh
#	                  (nickname requires the user is on the channel)
#
# both '!iline' and '!iline nickname' supports looking up the real ip of a webchat user
# (currently mibbit only) if enabled (as it is per default)
#
# the script also supports !help and !version both without arguments
#
# The prefix codes means where the data/info comes from (eg [P]/[Public] means the IP was
# gotten from the requesters irc host in the privmsg, or for nicks from irssis internal nicklist)
#
# settings:
#
# mh_iline_channels (string, default: ''):
#	a comma-seperated list of case-insensitive Network/Channel to monitor for command,
#	network is what irssi calles the server/network you connect to and channel should
#	be selfexplanatory. ex.: IRCnet/#i-line,IRCnet/#i-line2
#
# mh_iline_command (string, default: 'Iline'):
#	name of command to monitor (prefixed by command_char)
#
# mh_iline_command_char (string, default: '!'):
#	command prefix character
#
# mh_iline_lag_limit (int, default: 5):
#	lag in seconds before we ignore any commands
#
# mh_iline_url (string, default: 'https://api.i-line.space/index.php?q='):
#	backend url to sent our requests to (argument is appended)
#
# mh_iline_require_privs (bool, default: on):
#	require +o, +v or +h to enable monitoring
#
# mh_iline_command_help (bool, default: on):
#	enable/disable !help support
#
# mh_iline_command_version (bool, default: on):
#	enable/disable !version support
#
# mh_iline_test_webchat (bool, default: on):
#	enable/disable looking up webchat hosts
#
# mh_iline_show_prefix_long (bool, default: on):
#	enable/disable showing prefix data in long format if enabled
#
# mh_iline_show_prefix (bool, default: on):
#	enable/disable showing prefix data (the [A]/[Argument] etc part)
#
# mh_iline_show_extended (bool, default: on):
#	enable/disable showing extended information in lines
#
# mh_iline_hide_processing (bool,  default: off):
#	dont show '...Processing...' lines at all
#
# mh_iline_hide_looking (bool,  default: off):
#	dont show '...looking up...' lines at all
#
# mh_iline_hide_looking_nicks (bool,  default: off):
#	dont show '...looking up...' for [N]/[Nick] when requested by another user (!iline <nick>)
#	(if _hide_looking is on, this setting is irrelevant (implied))
#
# mh_iline_flood_timeout (int,  default: 60):
#	allow _flood_count requests in _flood_timeout seconds, 0 to disable
#
# mh_iline_flood_count (int,  default: 5):
#	allow _flood_count requests in _flood_timeout seconds, 0 to disable
#
# mh_iline_reply_notice (bool, default: on):
#	send replies as notices, if off, use regular messages
#
# mh_iline_reply_private (bool, default: off):
#	send replies as notices, if off, use regular messages
#
# mh_iline_monitor_private (bool, default: off):
#	listen for commands in private and send reply in private
#
# mh_iline_command_version_short (bool, default: off):
#	use the short (script name and version only) !version reply
#
# history:
#
#	v0.06 (20170323)
#		added _command_version_short for a compact oneline !version reply
#		added _monitor_private (default off) which will listen for commands in private message and reply privately
#		added _reply_private (default off) which will make all public !commands reply in private notice/message instead of public
#		not longer allows spaces between command_char and command ('! help')
#		lazy_is_hostname now supports punycoded/idn hostnames (not that it matters, we only want ips right now, and its used only to exclude possible ip matches)
#		setting _show_iline removed, since it now shows the name of whichever command was called and is no longer optional
#		[Iline] now shows the current issued command instead of script name (to possibly support more commands in the future)
#		more code cleanup work, lots of spaghetti eaten, might have cooked some new though - i know that promised cleanup is taking its time, sowwy :)
#
#	v0.05 (20170315)
#		some minor code/comment/instructions work
#		added some more extended info to (hopefully never reached) error when unable to parse stats L and get an ip
#		moved flood checking to flood_check() (still that little -1 hack for recursive calls...)
#		slight optimisation of bitloop in send_line() for faster exit if all available bits checked already
#		added _reply_notice and supporting code
#		you can now disable floodprotection by setting either _flood_* setting to 0
#		moved help and version commands to cmd_help() and cmd_version()
#		moved lag checking to lag_check()
#		will now show correctly the url in extended info for server no reply errors
#		simplified signal_message_own_public*
#
#	v0.04 (20170312)
#		dont show extended (host) info for PREFIX_ARGUMENT, it likely doesnt match
#		fixed double signal handlers
#		added _require_privs default on info to documentation
#
#	v0.03 (20170312)
#		change [M]/[Message] to [P]/[Public] to account for nicks
#		cleaned up the bitmask parsing in send_line() and put short/long format in one array
#		added _show_extended and supporting code
#		added _hide_processing and supporting code
#		added _hide_looking and supporting code
#		added _hide_looking_nicks and supporting code
#		added simple flood protection via settings _flood_timeout and _flood_count
#
#	v0.02 (20170311)
#		use https instead of http when requesting lookup and changed the url
#		moved channel messages to send_line() instead of individual SAYs
#		added setting _show_iline and supporting code
#		added setting _command_help and supporting code
#		added setting _command_version and supporting code
#		added setting _test_webchat and supporting code
#		added setting _show_prefix and supporting code
#		added setting _show_prefix_long and supporting code
#
#	v0.01 (20170310)
#		initial concept test release
#

use v5.14.2;

use strict;

##############################################################################
#
# irssi head
#
##############################################################################

use Irssi 20100403;

{ package Irssi::Nick }

our $VERSION = '0.06';
our %IRSSI   =
(
	'name'        => 'mh_iline',
	'description' => 'IRC frontend to the https://i-line.space IRCnet I-line lookup service by pbl',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Thu Mar 23 09:07:56 CET 2017',
);

##############################################################################
#
# global variables
#
##############################################################################

our $busy =
{
	'busy'    => 0 ,
	'cmd'     => '',
	'server'  => '',
	'channel' => '',
	'nick'    => '',
};

use constant
{
	PREFIX_NONE	           => 0,
	PREFIX_ARGUMENT        => 1,
	PREFIX_WEBCHAT         => 2,
	PREFIX_PUBLIC          => 4,
	PREFIX_STATSL          => 8,
	PREFIX_NICK            => 16,
	PREFIX_REPLY           => 32,
	PREFIX_ERROR           => 64,
	PREFIX_REPLY_TRUNCATED => 128,
	PREFIX_REPLY_GARBAGE   => 256,

	PREFIX_MAX             => 256,
};

our @prefix_array =
(
	'' , ''         ,
	'A', 'Argument' ,
	'W', 'Webchat'  ,
	'P', 'Public'   ,
	'L', 'Stats L'  ,
	'N', 'Nick'     ,
	'<', 'Reply'    ,
	'!', 'Error'    ,
	'T', 'Truncated',
	'G', 'Garbage'  ,
);

our $floodcount   = 0;
our $floodtimeout = 0;

##############################################################################
#
# common support functions
#
##############################################################################

sub is_odd
{
	my ($number) = @_;

	if ($number % 2 == 1)
	{
		return(1);
	}

	return(0);
}

sub trim_space
{
	my ($string) = @_;

	if (defined($string))
	{
		$string =~ s/^\s+//g;
		$string =~ s/\s+$//g;

	} else {

		$string = '';
	}

	return($string);
}

##############################################################################
#
# script functions
#
##############################################################################

sub lazy_is_webhost
{
	my ($data) = @_;

	if (not $data)
	{
		return(0);
	}

	if ($data =~ m/^.+\.mibbit\.com$/i)
	{
		return(1);
	}

	return(0);
}

sub lazy_is_hexip
{
	my ($data) = @_;

	if (not $data)
	{
		return(0);
	}

	if (not $data =~ m/^[~+\-^=]?[a-f0-9]{8}$/i)
	{
		return(0);
	}

	return(1);
}

sub lazy_is_hostname
{
	my ($data) = @_;

	if (not $data)
	{
		return(0);
	}

	if (not $data =~ m/^.+\.[a-z]+$/i) # any old *something.tld
	{
		if (not $data =~ m/^.+\.xn--[a-z0-9-]+$/i) # punycoded
		{
			return(0);
		}
	}

	return(1);
}

sub lazy_is_ip
{
	my ($data) = @_;

	if (not $data)
	{
		return(0);
	}

	if (not $data =~ m/^([a-f0-9.:]){3,45}$/i)
	{
		return(0);
	}

	if (not $data =~ m/.*[.:].*/i) # require at least one . or : so DEAF is a nick, not an IP
	{
		return(0);
	}

	if (lazy_is_hostname($data))
	{
		return(0);
	}

	return(1);
}

sub hex_to_ip
{
	my ($data) = @_;

	if (not $data)
	{
		return('');
	}

	if ($data =~ m/^[~+\-^=]?([a-f0-9]{8})$/i)
	{
		$data = $1;

		my $oct1 = hex(substr($data, 0, 2));
		my $oct2 = hex(substr($data, 2, 2));
		my $oct3 = hex(substr($data, 4, 2));
		my $oct4 = hex(substr($data, 6, 2));

		return($oct1 . "." . $oct2 . "." . $oct3 . "." . $oct4);
	}

	return('');
}

sub check_flood
{
	if (not (Irssi::settings_get_int('mh_iline_flood_timeout') and Irssi::settings_get_int('mh_iline_flood_count')))
	{
		return(1);
	}

	if (not $floodtimeout)
	{
		my $timeout = Irssi::settings_get_int('mh_iline_flood_timeout');

		$timeout      = int($timeout) * 1000; # timeout in seconds
		$floodtimeout = Irssi::timeout_add_once($timeout, 'timeout_flood_reset', undef);
		$floodcount   = 1;

	} else {

		if ($floodcount > Irssi::settings_get_int('mh_iline_flood_count'))
		{
			return(0);
		}
	}

	$floodcount++;
}

sub check_lag
{
	my ($server) = @_;

	my $lag_limit = Irssi::settings_get_int('mh_iline_lag_limit');

	if (not $lag_limit)
	{
		return(1);
	}

	$lag_limit = $lag_limit * 1000; # seconds to milliseconds

	if ($server->{'lag'} >= $lag_limit)
	{
		return(0);
	}

	return(1);
}

sub check_privs
{
	my ($channel) = @_;

	if (not Irssi::settings_get_bool('mh_iline_require_privs'))
	{
		return(1);
	}

	my $nick = $channel->nick_find($channel->{'server'}->{'nick'});

	if (not $nick)
	{
		return(0);
	}

	if (not ($nick->{'op'} or $nick->{'voice'} or $nick->{'halfop'}))
	{
		return(0);
	}

	return(1);
}

sub busy
{
	my ($busyvalue, $command, $server, $channel, $nickname) = @_;

	if (not defined($busyvalue)) # busy();
	{
		return($busy->{'busy'});
	}

	$busyvalue = int($busyvalue);

	if (not $busyvalue) # busy(0);
	{
		$busy->{'busy'}     = 0;
		$busy->{'cmd'}      = '';
		$busy->{'server'}   = '';
		$busy->{'channel'}  = '';
		$busy->{'nick'}     = '';

		return($busy->{'busy'});
	}

	$busy->{'busy'} = $busyvalue;

	if (defined($command))
	{
		$busy->{'cmd'} = '' . $command;
	}

	if (defined($server))
	{
		$busy->{'server'} = '' . $server;
	}

	if (defined($channel))
	{
		$busy->{'channel'} = '' . $channel;
	}

	if (defined($nickname))
	{
		$busy->{'nick'} = '' . $nickname;
	}

	return($busy->{'busy'});
}

sub send_line
{
	my ($channel, $data, $prefixbits) = @_;

	if (ref($channel) ne 'Irssi::Irc::Channel')
	{
		if (ref($channel) ne 'Irssi::Irc::Server')
		{
			return(0);
		}
	}

	my $prefix  = '';
	my $banner  = '';

	if (not (Irssi::settings_get_bool('mh_iline_reply_private') or ref($channel) eq 'Irssi::Irc::Server'))
	{
		if ($busy->{'nick'} ne '')
		{
			$banner .= $busy->{'nick'} . ': ';
		}
	}

	if ($busy->{'cmd'} ne '')
	{
		$banner .= '[' . $busy->{'cmd'} . '] ';
	}

	if (not $prefixbits)
	{
		$prefixbits = PREFIX_NONE;

	} else {

		$prefixbits = int($prefixbits);
	}

	if (Irssi::settings_get_bool('mh_iline_show_prefix') and $prefixbits)
	{
		my $prefix_id = 0; # even id is short version, uneven id is long version (0 is even)

		if (Irssi::settings_get_bool('mh_iline_show_prefix_long'))
		{
			$prefix_id = 1;
		}

		my $prefixbit = 1;

		while ($prefixbits and ($prefixbit <= PREFIX_MAX))
		{
			$prefix_id += 2;

			if ($prefixbits & $prefixbit)
			{
				$prefix .= $prefix_array[$prefix_id];

				if (is_odd($prefix_id)) # space between words in long prefix mode
				{
					$prefix .= ' ';
				}

				$prefixbits -= $prefixbit; # remove bit from bits
			}

			$prefixbit = $prefixbit << 1; # next bit
		}

		$prefix = '[' . trim_space($prefix) . '] ';
	}

	my $reply_command = 'MSG ';

	if (Irssi::settings_get_bool('mh_iline_reply_notice'))
	{
		$reply_command = 'NOTICE ';
	}

	if (Irssi::settings_get_bool('mh_iline_reply_private') or (ref($channel) eq 'Irssi::Irc::Server'))
	{
		$reply_command .= $busy->{'nick'};

	} else {

		$reply_command .= $channel->{'name'};
	}

	$reply_command .= ' ';

	$channel->command($reply_command . $banner . $prefix . trim_space($data));

	return(1);
}

sub ilines_pipe_read
{
	my ($readh, $pipetag) = @{$_[0]};

	my $reply      = '';
	my $read_brake = 3;

	while (my $line = <$readh>)
	{
		if (not $read_brake--)
		{
			break;
		}

		chomp($line);
		$line  = trim_space($line);
		$reply = $reply . ' ' . $line;
	}

	close($readh);
	Irssi::input_remove($$pipetag);

	my $server = Irssi::server_find_tag($busy->{'server'});

	if (not $server)
	{
		busy(0);
		return(0)
	}

	my $channel = $server->channel_find($busy->{'channel'});

	if (not $channel)
	{
		if (lc($busy->{'channel'}) ne lc($busy->{'nick'}))
		{
			busy(0);
			return(0);
		}

		$channel = $server;
	}

	$reply = trim_space($reply);

	if ($reply ne '')
	{
		$reply =~ s/<\/?[a-z]+?>//ig; # no more html tags (but allow < >)
		$reply = trim_space($reply);

		my $prefix = PREFIX_REPLY;

		if (length($reply) > 300)
		{
			$reply   = trim_space(substr($reply, 0, 300));
			$prefix += PREFIX_REPLY_TRUNCATED;
		}

		if ($reply !~ m/^[a-z0-9.:_\-<>,(\/) ]{1,300}$/i)
		{
			$reply   =~ s/[^a-z0-9.:_\-<>,(\/) ]*//ig;
			$reply   = trim_space($reply);
			$prefix += PREFIX_REPLY_GARBAGE;
		}

		send_line($channel, $reply, $prefix);

	} else {

		$reply = 'No reply';

		if (Irssi::settings_get_bool('mh_iline_show_extended'))
		{
			$reply .= ' (' . Irssi::settings_get_str('mh_iline_url') . ')';
		}

		send_line($channel, $reply, PREFIX_REPLY + PREFIX_ERROR);
	}

	busy(0);
}

sub ilines_get
{
	my ($data) = @_;

	my $readh;
	my $writeh;

	if (not pipe($readh, $writeh))
	{
		busy(0);
		return(0);
	}

	my $pid = fork();

	if ($pid > 0)
	{
		# parent

		close($writeh);
		Irssi::pidwait_add($pid);

		my $pipetag;
		my @args = ($readh, \$pipetag);
		$pipetag = Irssi::input_add(fileno($readh), Irssi::INPUT_READ, 'ilines_pipe_read', \@args);

	} else {

		# child

		use LWP::Simple;
		use POSIX;

		$data = Irssi::settings_get_str('mh_iline_url') . $data;

		my $reply = LWP::Simple::get($data);

		eval
		{
			print($writeh $reply);
			close($writeh);
		};

		POSIX::_exit(1);
	}
}

sub cmd_iline
{
	my ($channel, $nickname, $address, $data) = @_;

	if (not check_flood())
	{
		busy(0);
		return(0);
	}

	if (busy() < 2) # 'just this once'-hack :)
	{
		if (not Irssi::settings_get_bool('mh_iline_hide_processing'))
		{
			send_line($channel, 'Processing...');
		}
	}

	my $extended = '';

	if (Irssi::settings_get_bool('mh_iline_show_extended'))
	{
		$extended = ' (' . $nickname . '!' . $address . ')';
	}

	$data = trim_space($data);

	if ($data eq '')
	{
		(my $hexip, $data) = split('@', $address, 2);

		if (Irssi::settings_get_bool('mh_iline_test_webchat'))
		{
			if (lazy_is_webhost($data))
			{
				if (lazy_is_hexip($hexip))
				{
					$hexip = hex_to_ip($hexip);

					if (lazy_is_ip($hexip))
					{
						if (not Irssi::settings_get_bool('mh_iline_hide_looking'))
						{
							send_line($channel, 'Looking up ' . $hexip . $extended, PREFIX_WEBCHAT);
						}

						ilines_get($hexip);
						return(1);
					}
				}
			}
		}

		if (lazy_is_ip($data))
		{
			$data = lc($data);

			if (not Irssi::settings_get_bool('mh_iline_hide_looking'))
			{
				send_line($channel, 'Looking up ' . $data . $extended, PREFIX_PUBLIC);
			}

			ilines_get($data);
			return(1);
		}

		if (ref($channel) eq 'Irssi::Irc::Channel')
		{
			$channel = $channel->{'server'};
		}

		if (ref($channel) ne 'Irssi::Irc::Server')
		{
			busy(0);
			return(0);
		}

		$channel->redirect_event('mh_iline stats L',
			1,         # count
			$nickname, # arg
			-1,        # remote
			'',        # failure signal
			{          # signals
				'event 211' => 'redir mh_iline event 211', # RPL_STATSLINKINFO
				'event 481' => 'redir mh_iline event 481', # ERR_NOPRIVILEGES
				''          => 'event empty',
			}
   		);

		$channel->send_raw('STATS L ' . $nickname);
		return(1);

	} else {

		$data = lc($data);

		if (not lazy_is_ip($data))
		{
			my $nick = '';

			if (ref($channel) eq 'Irssi::Irc::Channel')
			{
				$nick = $channel->nick_find($data);
			}

			if (ref($nick) ne 'Irssi::Irc::Nick')
			{
				send_line($channel, 'Not an IP(4/6) address or nickname ', PREFIX_ERROR);
				busy(0);
				return(1);
			}

			if ($floodcount)
			{
				$floodcount--; # recursive request isnt counted in flood
			}

			if (lc($nick->{'nick'}) eq lc($nickname))
			{
				busy(2); # 'just this once'-hack :) - to avoid printing processing... twice if $nick is yourself
				return(cmd_iline($channel, $nickname, $address, ''));
			}

			if (not (Irssi::settings_get_bool('mh_iline_hide_looking') or Irssi::settings_get_bool('mh_iline_hide_looking_nicks')))
			{
				send_line($channel, 'Looking up ' . $nick->{'nick'}, PREFIX_NICK);
			}

			if (not Irssi::settings_get_bool('mh_iline_reply_private'))
			{
				busy(busy(), undef, undef, undef, $nick->{'nick'});
			}
			return(cmd_iline($channel, $nick->{'nick'}, $nick->{'host'}, ''));
		}

		if (not Irssi::settings_get_bool('mh_iline_hide_looking'))
		{
			send_line($channel, 'Looking up ' . $data, PREFIX_ARGUMENT);
		}

		ilines_get($data);
		return(1);
	}
}

sub cmd_help
{
	my ($channel) = @_;

	if (not Irssi::settings_get_bool('mh_iline_command_help'))
	{
		busy(0);
		return(0);
	}

	if (not check_flood())
	{
		busy(0);
		return(0);
	}

	my $command_char = Irssi::settings_get_str('mh_iline_command_char');
	my $command      = lc(trim_space(Irssi::settings_get_str('mh_iline_command')));

	if (Irssi::settings_get_bool('mh_iline_command_version'))
	{
		send_line($channel, 'Commands: ' . $command_char . $command . ', ' . $command_char . 'help' . ' & ' . $command_char . 'version' );

	} else {

		send_line($channel, 'Commands: ' . $command_char . $command . ' & ' . $command_char . 'help');
	}

	send_line($channel, 'Syntax  : ' . $command_char . $command . ' [<IP(4/6)>|<nickname>]');

	busy(0);
	return(1)
}

sub cmd_version
{
	my ($channel) = @_;

	if (not Irssi::settings_get_bool('mh_iline_command_version'))
	{
		busy(0);
		return(0);
	}

	if (not check_flood())
	{
		busy(0);
		return(0);
	}

	my $line = 'mh_iline.pl v0.06';

	if (Irssi::settings_get_bool('mh_iline_command_version_short'))
	{
		send_line($channel, $line);

	} else {

		send_line($channel, $line . ' Copyright (C) 2017  Michael Hansen');
		send_line($channel, 'IRC frontend to the https://i-line.space IRCnet I-line lookup service by pbl');
		send_line($channel, 'Download for Irssi at https://github.com/mh-source/irssi-scripts');
	}

	busy(0);
	return(1);
}

##############################################################################
#
# irssi timeouts
#
##############################################################################

sub timeout_flood_reset
{
	$floodcount   = 0;
	$floodtimeout = 0;
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_redir_event_211
{
	my ($server, $data, $sender) = @_;

	if (lc($server->{'tag'}) ne lc($busy->{'server'}))
	{
		return(0);
	}

	my $channel = $server->channel_find($busy->{'channel'});

	if (ref($channel) ne 'Irssi::Irc::Channel')
	{
		$channel = $server;
	}

	my $extended_statsl = $data;
	$data               =~ s/.*\[.*@(.*)\].*/$1/; # ip/hostname part of stats L/l
	$data               = lc(trim_space($data));
	my $extended        = '';

	if (Irssi::settings_get_bool('mh_iline_show_extended'))
	{
		if (ref($channel) eq 'Irssi::Irc::Channel')
		{
			my $nick = $channel->nick_find($busy->{'nick'});

			if ($nick)
			{
				$extended = ' (' . $nick->{'nick'} . '!' . $nick->{'host'} . ')';

			} else {

				$extended = ' (' . $busy->{'nick'} . ' not found)';
			}
		}
	}

	if (not lazy_is_ip($data))
	{
		send_line($channel, 'You do not seem to have an IP' . $extended, PREFIX_ERROR);

		if (Irssi::settings_get_bool('mh_iline_show_extended'))
		{
			my $nickname     = lc($server->{'nick'});
			$extended_statsl =~ s/^(\Q$nickname\E\s+)?(.*)/$2/i; # strip prefixed (own) nickname if present
			$extended_statsl = trim_space($extended_statsl);
			send_line($channel, 'Stats L reply: ' . $extended_statsl, PREFIX_ERROR);
		}

		busy(0);
		return(0);
	}

	if (not Irssi::settings_get_bool('mh_iline_hide_looking'))
	{
		send_line($channel, 'Looking up ' . $data . $extended, PREFIX_STATSL);
	}

	ilines_get($data);
}

sub signal_redir_event_481
{
	my ($server, $data, $sender) = @_;

	if (lc($server->{'tag'}) ne lc($busy->{'server'}))
	{
		return(0);
	}

	busy(0);
	return(1);
}

sub signal_message_public_priority_low
{
	my ($server, $data, $nickname, $address, $target) = @_;

	if(busy())
	{
		return(0);
	}

	if (not check_lag($server))
	{
		return(0);
	}

	if (not $target)
	{
		# there was an api change in irssi signal 'message private' sometime after v0.8.15 (20100403 1617)
		# the $target field was added, to support those older versions we add it if missing
		$target = $server->{'nick'};
	}

	if (Irssi::settings_get_bool('mh_iline_monitor_private') and (lc($target) eq lc($server->{'nick'})))
	{
		# yeah, this is copied from below, will detangle later :-)
		my $command_char = Irssi::settings_get_str('mh_iline_command_char');

		if (not ($data =~ s/^(\Q$command_char\E)([^\s]+)/$2/i))
		{
			return(0);
		}

		(my $command, $data) = split(' ', $data, 2);
		$command = lc(trim_space($command));

		if (not $command)
		{
			return(0);
		}

		if ($command eq lc(trim_space(Irssi::settings_get_str('mh_iline_command'))))
		{
			busy(1, 'Iline', $server->{'tag'}, $nickname, $nickname);
			cmd_iline($server, $nickname, $address, $data);
			return(1);
		}

		if ($command eq 'help')
		{
			busy(1, 'Help', $server->{'tag'}, $nickname, $nickname);
			cmd_help($server);
			return(1);
		}

		if ($command eq 'version')
		{
			busy(1, 'Version', $server->{'tag'}, $nickname, $nickname);
			cmd_version($server);
			return(1);
		}

		return(0);
	}

	for my $serverchannel (split(',', lc(Irssi::settings_get_str('mh_iline_channels'))))
	{
		if (trim_space($serverchannel) ne lc($server->{'tag'} . '/' . $target))
		{
			next;
		}

		my $channel = $server->channel_find($target);

		if (not $channel)
		{
			last;
		}

		if (not $channel->{'synced'})
		{
			last;
		}

		if (not check_privs($channel))
		{
			last;
		}

		my $command_char = Irssi::settings_get_str('mh_iline_command_char');

		if (not ($data =~ s/^(\Q$command_char\E)([^\s]+)/$2/i))
		{
			last;
		}

		(my $command, $data) = split(' ', $data, 2);
		$command = lc(trim_space($command));

		if (not $command)
		{
			last;
		}

		if ($command eq lc(trim_space(Irssi::settings_get_str('mh_iline_command'))))
		{
			busy(1, 'Iline', $channel->{'server'}->{'tag'}, $channel->{'name'}, $nickname);
			cmd_iline($channel, $nickname, $address, $data);
			last;
		}

		if ($command eq 'help')
		{
			busy(1, 'Help', $channel->{'server'}->{'tag'}, $channel->{'name'}, $nickname);
			cmd_help($channel);
			last;
		}

		if ($command eq 'version')
		{
			busy(1, 'Version', $channel->{'server'}->{'tag'}, $channel->{'name'}, $nickname);
			cmd_version($channel);
			last;
		}

		last;
	}
}

sub signal_message_own_public_priority_low
{
	my ($server, $data, $target) = @_;

	signal_message_public_priority_low($server, $data, $server->{'nick'}, $server->{'userhost'}, $target);
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::settings_add_str('mh_iline', 'mh_iline_channels',               '');
Irssi::settings_add_str('mh_iline', 'mh_iline_command_char',           '!');
Irssi::settings_add_int('mh_iline', 'mh_iline_lag_limit',              5);
Irssi::settings_add_bool('mh_iline', 'mh_iline_require_privs',         1);
Irssi::settings_add_bool('mh_iline', 'mh_iline_command_help',          1);
Irssi::settings_add_bool('mh_iline', 'mh_iline_command_version',       1);
Irssi::settings_add_str('mh_iline', 'mh_iline_command',                'Iline');
Irssi::settings_add_str('mh_iline', 'mh_iline_url',                    'https://api.i-line.space/index.php?q=');
Irssi::settings_add_bool('mh_iline', 'mh_iline_show_prefix_long',      1);
Irssi::settings_add_bool('mh_iline', 'mh_iline_show_prefix',           1);
Irssi::settings_add_bool('mh_iline', 'mh_iline_show_extended',         1);
Irssi::settings_add_bool('mh_iline', 'mh_iline_hide_processing',       0);
Irssi::settings_add_bool('mh_iline', 'mh_iline_hide_looking',          0);
Irssi::settings_add_bool('mh_iline', 'mh_iline_hide_looking_nicks',    0);
Irssi::settings_add_int('mh_iline', 'mh_iline_flood_timeout',          60);
Irssi::settings_add_int('mh_iline', 'mh_iline_flood_count',            5);
Irssi::settings_add_bool('mh_iline', 'mh_iline_test_webchat',          1);
Irssi::settings_add_bool('mh_iline', 'mh_iline_reply_notice',          1);
Irssi::settings_add_bool('mh_iline', 'mh_iline_reply_private',         0);
Irssi::settings_add_bool('mh_iline', 'mh_iline_monitor_private',       0);
Irssi::settings_add_bool('mh_iline', 'mh_iline_command_version_short', 0);

Irssi::settings_remove('mh_iline_show_iline');

Irssi::Irc::Server::redirect_register('mh_iline stats L',
    1, # remote
    0, # timeout
    {  # start signals
        'event 211' => -1, # RPL_STATSLINKINFO
        'event 481' => -1, # ERR_NOPRIVILEGES
    },
    {  # stop signals
        'event 219' => -1, # RPL_ENDOFSTATS end of stats
    },
    undef # optional signals
);

Irssi::signal_add('redir mh_iline event 211', 'signal_redir_event_211');
Irssi::signal_add('redir mh_iline event 481', 'signal_redir_event_481');
Irssi::signal_add_priority('message public', 'signal_message_public_priority_low', Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_priority('message own_public', 'signal_message_own_public_priority_low', Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_priority('message private', 'signal_message_public_priority_low', Irssi::SIGNAL_PRIORITY_LOW + 1);

1;

##############################################################################
#
# eof mh_iline.pl
#
##############################################################################
