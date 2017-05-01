##############################################################################
#
# mh_iline.pl v0.07 (20170501)
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
# IRC frontend to the https://i-line.space/ IRCnet I-line lookup service by pbl
#
# *** updating from pre-v0.07 versions: *******************************
# ***                                                               ***
# *** you are likely to run into conflicting settings if you do not ***
# *** make sure the old ones are deleted from ~/.irssi/config       ***
# ***                                                               ***
# *** unfortunately that might require manual editing of the config ***
# ***                                                               ***
# *********************************************************************
#
# monitor (configured) channels, and optionally private message, for
# commands (default: !Iline, !About, !Version and !Help) and reply
# on channel or in private (commands are case insensitve)
#
# unless you only want to monitor private messages you need to set
# mh_iline_channels: /set mh_iline_channels network/#channel
#
# per default the client need to be +o, +h or +v on a configured
# channel to monitor for commands, this can be disabled with
# /set mh_iline_require_privs off
#
# commands:
#
#	!iline            | lookup I-lines for requester
#	!iline <IP(4/6)>  | lookup I-lines for the given ip
#	!iline <nickname> | lookup I-lines for any user on irc
#	!version          | show version
#	!help             | show help
#	!about            | show version, description and help
#
# webchat (mibbit only) users will have their real ip looked up if
# mh_iline_command_iline_test_webchat setting is enabled
# (it is per default)
#
# the !Iline command prefix codes (short and long) are as follows:
#
#	'A', 'Argument' | ip/nickname taken from command argument
#	'W', 'Webchat'  | ip found from webchat user
#	'P', 'Public'   | ip found from privmsg, irssi nicklist or whois
#	'L', 'Stats L'  | ip found from stats L
#	'N', 'Nick'     | looking up a nickname
#	'<', 'Reply'    | reply from backend
#	'!', 'Error'    | an error occured (with any of the above)
#	'T', 'Truncated'| backend reply was too long and got truncated
#	'G', 'Garbage'  | backend reply had unwanted characters that was stripped out
#
# settings:
#
#	mh_iline_channels (string, default: ''):
#		a comma-seperated list of case insensitive Network/Channel to monitor
#		for commands, #network is what irssi calles the server/network you connect
#		to and channel should #be selfexplanatory. ex.: ircnet/#i-line,ircnet/#channel
#
#	mh_iline_commandchar (string, default: '!'):
#		command prefix character
#
#	mh_iline_monitor_private (boolean, default: 0):
#		monitor and reply to commands in private
#
#	mh_iline_require_privs (boolean, default: 1):
#		require +o, +v or +h to enable monitoring configured channel(s)
#
#	mh_iline_reply_private (boolean, default: 0):
#		reply to public commands with a private message
#
#	mh_iline_reply_notice (boolean, default: 0):
#		reply to channel and private using notice instead of message
#
#	mh_iline_reply_prefix_nick (boolean, default: 1):
#		when replying in public, prefix lines with the nickname of the requester
#
#	mh_iline_reply_prefix_command (boolean, default: 1):
#		when replying, prefix lines with the command issued
#
#	mh_iline_lag_limit (integer, default: 5):
#		lag in seconds before we ignore any commands (until lag is below
#		this again), 0 disables lag limit
#
#	mh_iline_reply_extended_info (boolean, default: 1):
#		show extended information on some lines (mostly userhosts where
#		it might be usefull, also makes some errors more verbose)
#
#	mh_iline_command_iline (string, default: 'Iline'):
#		Iline command name /set -clear to disable
#
#	mh_iline_command_iline_url (string, default: 'https://api.i-line.space/index.php?q='):
#		I-line backend URL, you shouldnt need to change this
#
#	mh_iline_command_iline_hide_processing (boolean, default: 0):
#		dont send "Processing..." lines
#
#	mh_iline_command_iline_hide_looking (boolean, default: 0):
#		dont send "Looking up..." lines
#
#	mh_iline_command_iline_hide_looking_nick (boolean, default: 0):
#		dont send "Looking up nickname..." lines (will still show other
#		"Looking up..." lines, this setting is implied when you have
#		enabled mh_iline_command_iline_hide_looking)
#
#	mh_iline_command_iline_hide_prefix (boolean, default: 0):
#		hide the Iline command prefix codes
#
#	mh_iline_command_iline_prefix_long (boolean, default: 1):
#		use long Iline command prefix codes, disable this for the short
#		versions
#
#	mh_iline_command_iline_test_webchat (boolean, default: 1):
#		enable/disable looking up the real ip of webchat users
#
#	mh_iline_command_about (string, default: 'About'):
#		About command name /set -clear to disable
#
#	mh_iline_command_help (string, default: 'Help'):
#		Help command name /set -clear to disable
#
#	mh_iline_command_version (string, default: 'Version'):
#		Version command name /set -clear to disable
#
#	mh_iline_flood_count (integer, default: 5):
#		allow max this amount of commands in mh_iline_flood_timeout seconds
#		disable flood protection by setting both to 0
#
#	mh_iline_flood_timeout (integer, default 60)
#		allow max mh_iline_flood_count commands in this many seconds
#
# history:
#
#	v0.07 (20170501)
#		rewrite, older versions are just summarised below
#		can now look up ip for any user on irc, not just in the channel
#		added !about as a combined version, info and help command
#
#	v0.06 (20170323)
#	v0.05 (20170315)
#	v0.04 (20170312)
#	v0.03 (20170312)
#	v0.02 (20170311)
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

our $VERSION = '0.07';
our %IRSSI   =
(
	'name'        => 'mh_iline',
	'description' => 'IRC frontend to the https://i-line.space/ IRCnet I-line lookup service by pbl',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Mon May  1 11:22:53 CEST 2017',
);

##############################################################################
#
# global variables
#
##############################################################################

our $busy = {};

our @iline_prefix_array =
(
	'' , ''         ,
	'A', 'Argument' , # ip/nickname taken from command argument
	'W', 'Webchat'  , # ip found from webchat user
	'P', 'Public'   , # ip found from privmsg, irssi nicklist or whois
	'L', 'Stats L'  , # ip found from stats L
	'N', 'Nick'     , # looking up a nickname
	'<', 'Reply'    , # reply from backend
	'!', 'Error'    , # an error occured (with any of the above)
	'T', 'Truncated', # backend reply was too long and got truncated
	'G', 'Garbage'  , # backend reply had unwanted characters that was stripped out
);

use constant
{
	ILINE_PREFIX_NONE            => 0,
	ILINE_PREFIX_ARGUMENT        => 1,
	ILINE_PREFIX_WEBCHAT         => 2,
	ILINE_PREFIX_PUBLIC          => 4,
	ILINE_PREFIX_STATSL          => 8,
	ILINE_PREFIX_NICK            => 16,
	ILINE_PREFIX_REPLY           => 32,
	ILINE_PREFIX_ERROR           => 64,
	ILINE_PREFIX_REPLY_TRUNCATED => 128,
	ILINE_PREFIX_REPLY_GARBAGE   => 256,
	ILINE_PREFIX_MAX             => 256,
};

our $flood_count = 0;

##############################################################################
#
# common support functions
#
##############################################################################

sub trim_space
{
	my ($string) = @_;

	if (defined($string))
	{
		$string =~ s/^\s+//g;
		$string =~ s/\s+$//g;

	} else
	{
		$string = '';
	}

	return($string);
}

sub is_odd
{
	my ($number) = @_;

	if ($number % 2 == 1)
	{
		return(1);
	}

	return(0);
}

##############################################################################
#
# script functions
#
##############################################################################

sub busy
{
	my ($busyvalue, $command, $servertag, $source, $nickname, $address, $data, $target) = @_;

	if (not defined($busyvalue)) # busy()
	{
		return($busy->{'busy'});
	}

	$busyvalue = int($busyvalue);

	if (not $busyvalue) # busy(0)
	{
		$busy->{'busy'}      = 0;  # are we busy?
		$busy->{'cmd'}       = ''; # command currently active
		$busy->{'servertag'} = ''; # servertag of active command
		$busy->{'source'}    = ''; # source of command (channel or nickname)
		$busy->{'nickname'}  = ''; # nickname of requester
		$busy->{'address'}   = ''; # address to look up
		$busy->{'data'}      = ''; # command data to look up
		$busy->{'target'}    = ''; # target ofr reply (channel or nickname) only when different from source/nickname

		return($busy->{'busy'});
	}

	# busy(1+, ...)

	$busy->{'busy'} = $busyvalue;

	if (defined($command))
	{
		$busy->{'cmd'} = '' . $command;
	}

	if (defined($servertag))
	{
		$busy->{'servertag'} = '' . $servertag;
	}

    if (defined($source))
    {
        $busy->{'source'} = '' . $source;
    }

    if (defined($nickname))
    {
        $busy->{'nickname'} = '' . $nickname;
    }

    if (defined($address))
    {
        $busy->{'address'} = '' . $address;
    }

    if (defined($data))
    {
        $busy->{'data'} = '' . $data;
    }

    if (defined($target))
    {
        $busy->{'target'} = '' . $target;
    }

    return($busy->{'busy'});

}

sub lag
{
	my ($server) = @_;

	my $lag_limit = Irssi::settings_get_int('mh_iline_lag_limit');

	if (not $lag_limit)
	{
		return(0);
	}

	$lag_limit = $lag_limit * 1000; # seconds to milliseconds

	if ($server->{'lag'} >= $lag_limit)
	{
		return(1);
	}

	return(0);
}

sub privs
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

	if (($nick->{'op'} or $nick->{'voice'} or $nick->{'halfop'}))
	{
		return(1);
	}

	return(0);
}

sub floodcountup
{
	if (not (Irssi::settings_get_int('mh_iline_flood_timeout') and Irssi::settings_get_int('mh_iline_flood_count')))
	{
		return(0);
	}

	if (not $flood_count)
	{
		my $timeout = int(Irssi::settings_get_int('mh_iline_flood_timeout')) * 1000; # timeout in seconds
		Irssi::timeout_add_once($timeout, 'timeout_flood_reset', undef);
	}

	$flood_count++;
}

sub hex_to_ip
{
	my ($data) = @_;

	if (not $data)
	{
		return('');
	}

	if ($data =~ m/^[~+\-^=]?([a-f0-9]{8}).*$/i)
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

sub lazy_is_nick
{
	my ($data) = @_;

	if (not $data)
	{
		return(0);
	}

	if ($data =~ m/^[a-zA-Z0-9_\-\\\[\]\{\}^`|]+$/i)
	{
		if ($data =~ m/^-.*$/i) # nicks can't start with a -
		{
			return(0);
		}

		if ($data =~ m/^[0-9].*$/i) # nicks can't start with a number
		{
			if ($data =~ m/^[0-9][0-9a-zA-Z]{8}$/i) # unless they are unique nicks on ircnet
			{
				return(1);
			}

			return(0);
		}

		return(1);
	}

	return(0);
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

sub lazy_is_webchat
{
	my ($data) = @_;

	if (not $data)
	{
		return(0);
	}

	if ($data =~ m/^.*([a-fA-F0-9]{8})@.*\.mibbit\.com$/i)
	{
		$data = hex_to_ip($1);

		if (lazy_is_ip($data))
		{
			return($data);
		}
	}

	return(0);
}

sub iline_prefix
{
	my ($prefixbits) = @_;

	if (not $prefixbits)
	{
		$prefixbits = ILINE_PREFIX_NONE;

	} else {

		$prefixbits = int($prefixbits);
	}

	if (Irssi::settings_get_bool('mh_iline_command_iline_hide_prefix') or (not $prefixbits))
	{
		return('');
	}

	my $prefix_id = 0; # even id is short version, uneven id is long version (0 is even)
	my $prefix    = '';

	if (Irssi::settings_get_bool('mh_iline_command_iline_prefix_long'))
	{
		$prefix_id = 1;
	}

	my $prefixbit = 1;

	while ($prefixbits and ($prefixbit <= ILINE_PREFIX_MAX))
	{
		$prefix_id += 2;

		if ($prefixbits & $prefixbit)
		{
			$prefix .= $iline_prefix_array[$prefix_id];

			if (is_odd($prefix_id)) # space between words in long prefix mode
			{
				$prefix .= ' ';
			}

			$prefixbits -= $prefixbit; # remove bit from bits
		}

		$prefixbit = $prefixbit << 1; # next bit
	}

	return('[' . trim_space($prefix) . '] ');
}

sub iline_pipe_read
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

	$reply     = trim_space($reply);
	my $prefix = ILINE_PREFIX_REPLY;

	if ($reply ne '')
	{
		$reply =~ s/<\/?[a-z]+?>//ig; # no more html tags (but allow < >)
		$reply = trim_space($reply);


		if (length($reply) > 300)
		{
			$reply   = trim_space(substr($reply, 0, 300));
			$prefix += ILINE_PREFIX_REPLY_TRUNCATED;
		}

		if ($reply !~ m/^[a-z0-9.:_\-<>,(\/) ]{1,300}$/i)
		{
			$reply   =~ s/[^a-z0-9.:_\-<>,(\/) ]*//ig;
			$reply   = trim_space($reply);
			$prefix += ILINE_PREFIX_REPLY_GARBAGE;
		}

		if (Irssi::settings_get_bool('mh_iline_reply_extended_info'))
		{
			$reply = lc($busy->{'data'}) . ' == ' . $reply;
		}

	} else {

		my $extended = '';

		if (Irssi::settings_get_bool('mh_iline_reply_extended_info'))
		{
			my $url = trim_space('' . Irssi::settings_get_str('mh_iline_command_iline_url'));

			if ($url ne '')
			{
				if ($url =~ s/^((https?:\/\/.*?\/).*=)$/$2 ($1)/i)
				{
					if ($1 eq $2) # no need to repeat ourself
					{
						$url = $1;

					}

					$extended = ' from ' . $url;

				} else {

					$extended = ' from (broken url?) ' . $url;
				}

			} else {

				$extended = ' (iline url not set)';
			}
		}

		$reply  = 'No reply' . $extended;
		$prefix += ILINE_PREFIX_ERROR;
	}

	send_line(iline_prefix($prefix) . $reply);
	busy(0);
}

sub iline_get
{
	my ($data) = @_;

	my $readh;
	my $writeh;

	my $extended = '';
	my $url = '' . Irssi::settings_get_str('mh_iline_command_iline_url');

	if (not ($url =~ m/^https?:\/\/.*?\/.*=$/i))
	{
		if (Irssi::settings_get_bool('mh_iline_reply_extended_info'))
		{
			if ($url)
			{
				$extended = ' (' . $url . ')';
			}
		}

		send_line(iline_prefix(ILINE_PREFIX_REPLY + ILINE_PREFIX_ERROR) . 'Broken url?' . $extended);
		busy(0);
		return(0);
	}

	if (not pipe($readh, $writeh))
	{
		send_line(iline_prefix(ILINE_PREFIX_REPLY + ILINE_PREFIX_ERROR) . 'Failed to create pipe');
		busy(0);
		return(0);
	}

	my $pid = fork();

	$busy->{'data'} = $data;

	if ($pid > 0)
	{
		# parent

		close($writeh);
		Irssi::pidwait_add($pid);

		my $pipetag;
		my @args = ($readh, \$pipetag);
		$pipetag = Irssi::input_add(fileno($readh), Irssi::INPUT_READ, 'iline_pipe_read', \@args);

		return(1);

	} else {

		# child

		use LWP::Simple;
		use POSIX;

		$data = $url . $data;

		my $reply = LWP::Simple::get($data);

		eval
		{
			print($writeh $reply);
			close($writeh);
		};

		POSIX::_exit(1);
	}

	return(0);
}

sub iline_webchat_check
{
	if (Irssi::settings_get_bool('mh_iline_command_iline_test_webchat'))
	{
		my $hexip = lazy_is_webchat($busy->{'address'});

		if ($hexip)
		{

			if (not Irssi::settings_get_bool('mh_iline_command_iline_hide_looking'))
			{
				my $extended = '';

				if (Irssi::settings_get_bool('mh_iline_reply_extended_info'))
				{
					$extended = ' (' . lc($busy->{'data'} . '!' . $busy->{'address'}) . ')';
				}

				send_line(iline_prefix(ILINE_PREFIX_WEBCHAT) . 'Looking up: ' . lc($hexip) . $extended);
			}

			return(iline_get($hexip));
		}
	}

	return(0);
}

sub iline_public_check
{
	(undef, my $data) = split('@', $busy->{'address'}, 2);

	if (lazy_is_ip($data))
	{
		if (not Irssi::settings_get_bool('mh_iline_command_iline_hide_looking'))
		{
			my $extended = '';

			if (Irssi::settings_get_bool('mh_iline_reply_extended_info'))
			{
				$extended = ' (' . lc($busy->{'data'} . '!' . $busy->{'address'}) . ')';
			}

			send_line(iline_prefix(ILINE_PREFIX_PUBLIC) . 'Looking up: ' . lc($data) . $extended);
		}

		return(iline_get($data));
	}

	return(0);
}

sub iline_statsl_check
{
	my ($nickname) = @_;

	if (not $nickname)
	{
		$nickname = $busy->{'nickname'};
	}

	my $server = Irssi::server_find_tag($busy->{'servertag'});

	if ($server and $nickname)
	{
		$server->redirect_event('mh_iline iline stats L',
			1,         # count
			$nickname, # arg
			-1,        # remote
			'',        # failure signal
			{          # signals
				'event 211' => 'redir mh_iline iline event 211', # RPL_STATSLINKINFO
				'event 481' => 'redir mh_iline iline event 481', # ERR_NOPRIVILEGES
				''          => 'event empty',
			}
		);

		$server->send_raw('STATS L ' . $nickname);
		return(1);
	}

	return(0);
}

sub iline_argument_ip_check
{
	if (lazy_is_ip($busy->{'data'}))
	{
		if (not Irssi::settings_get_bool('mh_iline_command_iline_hide_looking'))
		{
			send_line(iline_prefix(ILINE_PREFIX_ARGUMENT) . 'Looking up: ' . lc($busy->{'data'}));
		}

		return(iline_get($busy->{'data'}));
	}

	return(0);
}

sub iline_argument_nick_whois_check
{
	if (not $busy->{'data'})
	{
		return(0);
	}

	my $server = Irssi::server_find_tag($busy->{'servertag'});

	if (not $server)
	{
		return(0);
	}

	$server->redirect_event('whois',
		1,               # count
		$busy->{'data'}, # arg
		-1,              # remote
		'',              # failure signal
		{                # signals
			'event 311' => 'redir mh_iline iline event 311', # RPL_WHOISUSER
			'event 401' => 'redir mh_iline iline event 401', # ERR_NOSUCHNICK
			''          => 'event empty',
		}
	);

	$server->send_raw('WHOIS ' . $busy->{'data'});

	return(1);
}

sub iline_argument_nick_check
{
	if (not lazy_is_nick($busy->{'data'}))
	{
		return(0);
	}

	if (not (Irssi::settings_get_bool('mh_iline_command_iline_hide_looking') or Irssi::settings_get_bool('mh_iline_command_iline_hide_looking_nick')))
	{
		send_line(iline_prefix(ILINE_PREFIX_NICK) . 'Looking up nickname: ' . lc($busy->{'data'}));
	}

	my $server = Irssi::server_find_tag($busy->{'servertag'});

	if (not $server)
	{
		return(0);
	}

	my $address = '';

	for my $item ($server->nicks_get_same($busy->{'data'}))
	{
		if (ref($item) eq 'Irssi::Irc::Nick')
		{
			$address = $item->{'host'};
			last;
		}
	}

	if (not $address)
	{
		if (iline_argument_nick_whois_check())
		{
			return(1);
		}

		return(0);
	}

	$busy->{'address'} = $address;
	busy(2); # to avoid printing "processing..." again in cmd_iline()
	return(cmd_iline());
}

sub cmd_iline
{
	my $extended = '';

	if (not Irssi::settings_get_bool('mh_iline_command_iline_hide_processing'))
	{
		if (busy() < 2)
		{
			if (Irssi::settings_get_bool('mh_iline_reply_extended_info'))
			{
				$extended = ' request by: ' . lc($busy->{'nickname'} . '!' . $busy->{'address'});
			}

			send_line('Processing' . $extended . '...' );
			$extended = '';
		}
	}

	if ($busy->{'data'})
	{
		if (lc($busy->{'data'}) eq lc($busy->{'nickname'})) # no reason for a nick lookup of yourself, its already in 'address'
		{
			$busy->{'data'} = '';
		}
	}

	my $prefixbits = ILINE_PREFIX_ERROR;

	if (($busy->{'data'} eq '') or (busy() > 1)) # $data is the nickname on recursive calls
	{
		if ($busy->{'data'} eq '')
		{
			$busy->{'data'} = $busy->{'nickname'};
		}

		if (iline_webchat_check())
		{
			return(1);
		}

		if (iline_public_check())
		{
			return(1);
		}

		if (iline_statsl_check($busy->{'data'}))
		{
			return(1);
		}

	} else {

		$prefixbits += ILINE_PREFIX_ARGUMENT;

		if (iline_argument_ip_check())
		{
			return(1);
		}

		if (iline_argument_nick_check())
		{
			return(1);
		}

	}

	send_line(iline_prefix($prefixbits) . 'IP(4/6) or nickname not found');
	busy(0);
	return(0);
}

sub cmd_about
{
	cmd_version();
	send_line('IRC frontend to the https://i-line.space/ IRCnet I-line lookup service by pbl');
	send_line('Download for Irssi at https://github.com/mh-source/irssi-scripts');
	cmd_help();

	return(1);
}

sub cmd_version
{
	send_line('mh_iline.pl v0.07 Copyright (c) 2017  Michael Hansen');

	return(1);
}

sub cmd_help
{
	my $commandchar     = Irssi::settings_get_str('mh_iline_commandchar');
	my $command_iline   = trim_space(Irssi::settings_get_str('mh_iline_command_iline'));
	my $command_help    = trim_space(Irssi::settings_get_str('mh_iline_command_help'));
	my $command_version = trim_space(Irssi::settings_get_str('mh_iline_command_version'));
	my $command_about   = trim_space(Irssi::settings_get_str('mh_iline_command_about'));

	my $line = '';

	if ($command_iline ne '')
	{
		$line .= $commandchar . $command_iline . ' [<IP(4/6)>|<nickname>]';
	}

	if ($command_about ne '')
	{
		if ($line ne '')
		{
			$line .= ', ';
		}

		$line .= $commandchar . $command_about;
	}

	if ($command_version ne '')
	{
		if ($line ne '')
		{
			$line .= ', ';
		}

		$line .= $commandchar . $command_version;
	}

	if ($command_help ne '')
	{
		if ($line ne '')
		{
			$line .= ' & ';
		}

		$line .= $commandchar . $command_help;
	}

	if ($line ne '')
	{
		$line = 'Available commands: ' . $line;
		send_line($line);
	}

	return(1);
}

sub cmd
{
	my ($server, $source, $nickname, $address, $data) = @_;

	my $commandchar = Irssi::settings_get_str('mh_iline_commandchar');

	if (not ($data =~ s/^(\Q$commandchar\E)([^\s]+)/$2/i))
	{
		return(0);
	}

	(my $command, $data) = split(' ', $data, 2);
	$command = lc(trim_space($command));

	if (not $command)
	{
		return(0);
	}

	my $command_word = trim_space(Irssi::settings_get_str('mh_iline_command_iline'));

	if ($command eq lc($command_word))
	{
		floodcountup();
		$data = trim_space($data);
		busy(1, $command_word, $server->{'tag'}, $source, $nickname, $address, $data);
		return(cmd_iline());
	}

	$command_word = trim_space(Irssi::settings_get_str('mh_iline_command_version'));

	if ($command eq lc($command_word))
	{
		floodcountup();
		busy(1, $command_word, $server->{'tag'}, $source, $nickname);
		cmd_version();
		busy(0);
		return(1);
	}

	$command_word = trim_space(Irssi::settings_get_str('mh_iline_command_about'));

	if ($command eq lc($command_word))
	{
		floodcountup();
		busy(1, $command_word, $server->{'tag'}, $source, $nickname);
		cmd_about();
		busy(0);
		return(1);
	}

	$command_word = trim_space(Irssi::settings_get_str('mh_iline_command_help'));

	if ($command eq lc($command_word))
	{
		floodcountup();
		busy(1, $command_word, $server->{'tag'}, $source, $nickname);
		cmd_help();
		busy(0);
		return(1);
	}

	return(0);
}

sub send_line
{
	my ($data) = @_;

	my $server = $busy->{'servertag'};

	if (not $server)
	{
		return(0);
	}

	$server = Irssi::server_find_tag($server);

	if (not $server)
	{
		return(0);
	}

	my $line = 'MSG ';

	if (Irssi::settings_get_bool('mh_iline_reply_notice'))
	{
		$line = 'NOTICE ';
	}

	my $target = $busy->{'target'};

	if ($target eq '')
	{
		if (Irssi::settings_get_bool('mh_iline_reply_private'))
		{
			$target = $busy->{'nickname'};

		} else {

			$target = $busy->{'source'};
		}
	}

	if ($target eq '')
	{
		return(0);
	}

	$line .= $target . ' ';

	if ($server->ischannel($target) and Irssi::settings_get_bool('mh_iline_reply_prefix_nick'))
	{
		$line .= $busy->{'nickname'} . ': ';
	}

	if (Irssi::settings_get_bool('mh_iline_reply_prefix_command'))
	{
		$line .= '[' . $busy->{'cmd'} . '] ';
	}

	$server->command($line . trim_space($data));

	return(1);
}

##############################################################################
#
# irssi timeouts
#
##############################################################################

sub timeout_flood_reset
{
	$flood_count = 0;
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_redir_iline_event_211
{
	my ($server, $data, $sender) = @_;

	if (lc($server->{'tag'}) ne lc($busy->{'servertag'}))
	{
		return(0);
	}

	$data =~ s/.*\[.*@(.*)\].*/$1/; # ip/hostname part of stats L/l
	$data = lc(trim_space($data));

	my $extended = '';

	if (not lazy_is_ip($data))
	{
		if (Irssi::settings_get_bool('mh_iline_reply_extended_info'))
		{
			$extended = ' (' . lc($busy->{'data'} . '!' . $busy->{'address'}) . ')';
		}

		send_line(iline_prefix(ILINE_PREFIX_STATSL + ILINE_PREFIX_ERROR) . 'No IP(4/6) found' . $extended);
		busy(0);
		return(0);
	}

	if (not Irssi::settings_get_bool('mh_iline_command_iline_hide_looking'))
	{
		if (Irssi::settings_get_bool('mh_iline_reply_extended_info'))
		{
			$extended = ' (' . lc($busy->{'data'} . '!' . $busy->{'address'}) . ')';
		}

		send_line(iline_prefix(ILINE_PREFIX_STATSL) . 'Looking up: ' . $data . $extended);
	}

	return(iline_get($data));
}

sub signal_redir_iline_event_311
{
	my ($server, $data, $sender) = @_;

	if (lc($server->{'tag'}) ne lc($busy->{'servertag'}))
	{
		return(0);
	}

	$data =~ s/^\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+\*\s+:.*$/$2\@$3/; # ip/hostname part of whois and nick in $1
	my $nick = trim_space($1);
	$data = trim_space($data);

	if ((not $data) or (not $nick))
	{
		return(0);
	}

	$busy->{'address'} = $data;
	$busy->{'data'}    = $nick;
	busy(2); # to avoid printing "processing..." again in cmd_iline()
    return(cmd_iline());
}

sub signal_redir_iline_event_401
{
	my ($server, $data, $sender) = @_;

	if (lc($server->{'tag'}) ne lc($busy->{'servertag'}))
	{
		return(0);
	}

	my $extended = '';

	if (Irssi::settings_get_bool('mh_iline_reply_extended_info'))
	{
		$extended = ': ' . lc($busy->{'data'});
	}

	send_line(iline_prefix(ILINE_PREFIX_NICK + ILINE_PREFIX_ERROR) . 'Nickname not found' . $extended);
	busy(0);
	return(1);
}

sub signal_redir_iline_event_481
{
	my ($server, $data, $sender) = @_;

	if (lc($server->{'tag'}) ne lc($busy->{'servertag'}))
	{
		return(0);
	}

	busy(0);
	return(1);
}

sub signal_message_public_priority_low
{
	my ($server, $data, $nickname, $address, $target) = @_;

	if (busy())
	{
		return(0);
	}

	if (lag($server))
	{
		return(0);
	}

	if ($flood_count >= Irssi::settings_get_int('mh_iline_flood_count'))
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
		return(cmd($server, $nickname, $nickname, $address, $data));
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

		if (not privs($channel))
		{
			last;
		}

		return(cmd($server, $channel->{'name'}, $nickname, $address, $data));
	}

	return(0);
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

Irssi::settings_add_str('mh_iline',  'mh_iline_channels',                        '');
Irssi::settings_add_str('mh_iline',  'mh_iline_commandchar',                     '!');
Irssi::settings_add_bool('mh_iline', 'mh_iline_monitor_private',                 0);
Irssi::settings_add_bool('mh_iline', 'mh_iline_require_privs',                   1);
Irssi::settings_add_bool('mh_iline', 'mh_iline_reply_private',                   0);
Irssi::settings_add_bool('mh_iline', 'mh_iline_reply_notice',                    0);
Irssi::settings_add_bool('mh_iline', 'mh_iline_reply_prefix_nick',               1);
Irssi::settings_add_bool('mh_iline', 'mh_iline_reply_prefix_command',            1);
Irssi::settings_add_int('mh_iline',  'mh_iline_lag_limit',                       5);
Irssi::settings_add_bool('mh_iline', 'mh_iline_reply_extended_info',             1);
Irssi::settings_add_str('mh_iline',  'mh_iline_command_iline',                   'Iline');
Irssi::settings_add_str('mh_iline',  'mh_iline_command_iline_url',               'https://api.i-line.space/index.php?q=');
Irssi::settings_add_bool('mh_iline', 'mh_iline_command_iline_hide_processing',   0);
Irssi::settings_add_bool('mh_iline', 'mh_iline_command_iline_hide_looking',      0);
Irssi::settings_add_bool('mh_iline', 'mh_iline_command_iline_hide_looking_nick', 0);
Irssi::settings_add_bool('mh_iline', 'mh_iline_command_iline_hide_prefix',       0);
Irssi::settings_add_bool('mh_iline', 'mh_iline_command_iline_prefix_long',       1);
Irssi::settings_add_bool('mh_iline', 'mh_iline_command_iline_test_webchat',      1);
Irssi::settings_add_str('mh_iline',  'mh_iline_command_about',                   'About');
Irssi::settings_add_str('mh_iline',  'mh_iline_command_help',                    'Help');
Irssi::settings_add_str('mh_iline',  'mh_iline_command_version',                 'Version');
Irssi::settings_add_int('mh_iline',  'mh_iline_flood_count',                     5);
Irssi::settings_add_int('mh_iline',  'mh_iline_flood_timeout',                   60);

Irssi::Irc::Server::redirect_register('mh_iline iline stats L',
	1, # remote
	0, # timeout
	{  # start signals
		'event 211' => -1, # RPL_STATSLINKINFO
		'event 481' => -1, # ERR_NOPRIVILEGES
	},
	{  # stop signals
		'event 219' => -1, # RPL_ENDOFSTATS
	},
	undef # optional signals
);

Irssi::signal_add('redir mh_iline iline event 211', 'signal_redir_iline_event_211');
Irssi::signal_add('redir mh_iline iline event 311', 'signal_redir_iline_event_311');
Irssi::signal_add('redir mh_iline iline event 401', 'signal_redir_iline_event_401');
Irssi::signal_add('redir mh_iline iline event 481', 'signal_redir_iline_event_481');
Irssi::signal_add_priority('message public',        'signal_message_public_priority_low',     Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_priority('message own_public',    'signal_message_own_public_priority_low', Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_priority('message private',       'signal_message_public_priority_low',     Irssi::SIGNAL_PRIORITY_LOW + 1);

busy(0);

1;

##############################################################################
#
# eof mh_iline.pl
#
##############################################################################
