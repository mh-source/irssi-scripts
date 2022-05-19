#!/usr/bin/env false
###############################################################################
#
# mh_ampclients.pl v0.01 (2022-05-19T19:05:22Z)
#
# Copyright (c) 2022  Michael Hansen
#
# Permission to use, copy, modify, and distribute this software for any purpose
# with or without fee is hereby granted, provided that the above copyright
# notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
###############################################################################
#
# Reformat server notices in IRCnet &CLIENTS
#
# Notes:
#
#   You will have to set 'mh_ampclients_server' so the script knows when to
#   look for &CLIENTS server notices. If you are not on a server matching
#   that setting, the notices will be ignored and Irssi left to deal with them.
#
#   To quickly set 'mh_ampclients_server' to the currently active server:
#
#     /eval set mh_ampclients_server $S
#
#   Or add it if you already have previously configured servers:
#
#     /eval set mh_ampclients_server $mh_ampclients_server $S
#
#   If for some reason you want to use the script and see the notices exactly
#   like standard Irssi/irc, the following commands will do just that:
#
#     /set mh_ampclients_hide_duplicate_ip off
#     /set mh_ampclients_stop_bleed_CONN off
#     /set mh_ampclients_stop_bleed_QUIT off
#     /set mh_ampclients_strip_colon_CONN off
#     /set mh_ampclients_strip_colon_QUIT off
#     /format mh_ampclients_CONN {servernotice $S}$*
#     /format mh_ampclients_QUIT {servernotice $S}$*
#     /format mh_ampclients_NICK {servernotice $S}$*
#
#   If you just do not like the way it looks by default, you can change the
#   theme formats (and settings). See the appropriate sections below and read
#   Irssi documentation for theme formatting details
#
#   Script assumes running on irc2.11.2p3 (or equivilant) with XLINE defined,
#   CLIENTS_CHANNEL defined, and CLIENTS_CHANNEL_LEVEL (CCL) bitmask of 0x1F
#   (but will ignore unknown notices and let Irssi deal with them)
#
#   You have manually join &CLIENTS, which requires you to be OPER'ed and have
#   ACL_CLIENTS O-line flag (&), the script only reformats the server notices
#
# Settings:
#
#   'mh_ampclients_hide_duplicate_ip':
#     Bool, default: on
#
#     Enable/disable replacing the IP with a * if same as host on CONN
#
#   'mh_ampclients_server':
#     String, default: ''
#
#     Space-separated string of server names to monitor &CLIENTS on. these can
#     be Irssi tag, Irssi network/chatnet name, or server hostname. Set to * to
#     match all connected servers.
#
#     Names are case-insensitive, but must match exactly otherwise
#
#     Examples:
#
#        /set mh_ampclients_server *
#          Monitor on any connected server
#
#        /set mh_ampclients_server irc.ATW-inter.net ssl.irc.ATW-inter.net
#          Monitor only on irc.atw-inter.net and ssl.irc.atw-inter.net
#
#        /set mh_ampclients_server Ircnet
#          Monitor any server on IRCnet chatnet (if configured in Irssi) and/or
#          any server Irssi has given the tag 'ircnet' (this will happen with
#          ex. irc.us.ircnet.net unless its configured to be in a differently
#          named chatnet in irssi)
#
#   'mh_ampclients_stop_bleed_CONN':
#     Bool, default: on
#
#     Enabled/disable ensuring colour/formatting is stopped from bleeding into
#     the following text for User2, user3, and Realname on CONN 
#
#   'mh_ampclients_stop_bleed_QUIT':
#     Bool, default: on
#
#     Enabled/disable ensuring colour/formatting is stopped from bleeding into
#     the following text for Quit reason on QUIT (handles user-supplied reasons
#     in quotes correctly too)
#
#   'mh_ampclients_strip_codes_CONN':
#     Bool, default: off
#
#     Enable/disable stripping colour/formatting from user2, user3, and
#     realname on CONN
#
#   'mh_ampclients_strip_codes_QUIT':
#     Bool, default: off
#
#     Enable/disable stripping colour/formatting from reason on QUIT
#
#   'mh_ampclients_strip_colon_CONN':
#     Bool, default: on
#
#     Enable/disable stripping :-prefix from realname on CONN
#
#   'mh_ampclients_strip_colon_QUIT':
#     Bool, default: on
#
#     Enable/disable stripping :-prefix from reason on QUIT
#
# Themes:
#
#   'mh_ampclients_CONN':
#     Format used for CONN type server notices
#
#     Parameters:
#
#       0-4: Common parameters listed below
#         5: IP
#         6: User1
#         7: User2
#         8: User3
#         9: Realname
#
#   'mh_ampclients_QUIT':
#     Format used for QUIT type server notices
#
#     Parameters:
#
#       0-4: Common parameters listed below
#         5: Quit exit code charater
#         6: Quit reason
#
#   'mh_ampclients_NICK':
#     Format used for NICK type server notices
#
#     Parameters:
#
#       0-4: Common parameters listed below
#         5: New nickname
#
#   Common parameters for 'mh_ampclients_CONN', 'QUIT', and 'NICK':
#
#     0: UID
#     1: Nickname
#     2: Username
#     3: Hostname
#     4: Type (CONN, QUIT, or NICK)
#
#   You may also find Irssi variable $S of use, it contains the servername
# 
# History:
#
#   v0.01 (2022-05-19T19:05:22Z)
#     Initial public alpha release
#
###############################################################################

use v5.30.0;

use strict;
use warnings 'FATAL' => 'all';

use Irssi 20190829 ();

###############################################################################
#
# irssi script header
#
###############################################################################

our $VERSION = '0.01';
our %IRSSI   =
(
	'name'        => 'mh_ampclients',
	'description' => 'Reformat server notices in IRCnet &CLIENTS',
	'license'     => 'ISC',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh!_mh@mh.ircnet.io on IRCnet',
	'changed'     => '2022-05-19T19:05:22Z',
);

###############################################################################
#
# script global variables
#
###############################################################################

my $ampclients_type_dispatch =
{
	'CONN' => \&ampclients_parse_notice_CONN,
	'QUIT' => \&ampclients_parse_notice_QUIT,
	'NICK' => \&ampclients_parse_notice_NICK,
};

###############################################################################
#
# script onload function
#
###############################################################################

sub onload
{
	print('[mh_ampclients] Script loaded: mh_ampclients v0.01 (2022-05-19T19:05:22Z)');

	themes_init();
	settings_init();
	signals_init();

	return(1);
}

###############################################################################
#
# script functions
#
###############################################################################

sub ampclients_parse_notice
{
	my ($channelrec, $data) = @_;

	# split common parameters into @line, non-common parameters in last element
	my @line = split(' ', $data, 6);

	#
	# call appropriate type parser via the dispatch table
	#
	# type is in parameter 5 (array index 4)
	#

	if (not exists($ampclients_type_dispatch->{$line[4]}))
	{
		# unknown type, bail out
		return(1);
	}

	if ($ampclients_type_dispatch->{$line[4]}->($channelrec, @line))
	{
		# notice parsed, stop any further processing of this signal
		Irssi::signal_stop();
	}

	return(1);
}

sub ampclients_parse_notice_CONN
{
	my ($channelrec, @line) = @_;

	# split non-common parameters from last element back into @line
	push(@line, split(' ', pop(@line), 5));

	# @line:
	#   0: UID
	#   1: Nickname
	#   2: Username
	#   3: Hostname
	#   4: Type (CONN, QUIT, or NICK)
	#   5: IP
	#   6: User1
	#   7: User2
	#   8: User3
	#   9: Realname

	if (Irssi::settings_get_bool('mh_ampclients_strip_colon_CONN'))
	{
		# strip :-prefix from realname (last element in array)
		$line[-1] = irc_strip_colon($line[-1]);
	}

	if (Irssi::settings_get_bool('mh_ampclients_strip_codes_CONN'))
	{
		# strip colour/formatting from user2, user3, and realname (last element
		# in array)
		$line[7]  = Irssi::strip_codes($line[7]);
		$line[8]  = Irssi::strip_codes($line[8]);
		$line[-1] = Irssi::strip_codes($line[-1]);
	}
	else
	{
		if (Irssi::settings_get_bool('mh_ampclients_stop_bleed_CONN'))
		{
			# ensure colour/formatting is stopped from bleeding into the following
			# text for User2, User3, and Realname
			# - this is done by inserting an reset-format (\x{0f} code in the correct place
			$line[7]  = $line[7]  . "\x{0f}";
			$line[8]  = $line[8]  . "\x{0f}";
			$line[-1] = $line[-1] . "\x{0f}";
		}
	}

	if (Irssi::settings_get_bool('mh_ampclients_hide_duplicate_ip'))
	{
		# replace the IP with a * if same as host
		if ($line[3] eq $line[5])
		{
			$line[5] = '*';
		}
	}

	$channelrec->printformat(Irssi::MSGLEVEL_SNOTES(), 'mh_ampclients_CONN', @line);

	return(1);
}

sub ampclients_parse_notice_QUIT
{
	my ($channelrec, @line) = @_;

	# split non-common parameters from last element back into @line
	push(@line, split(' ', pop(@line), 2));

	# @line:
	#   0: UID
	#   1: Nickname
	#   2: Username
	#   3: Hostname
	#   4: Type (CONN, QUIT, or NICK)
	#   5: Quit exit code charater
	#   6: Quit reason

	if (Irssi::settings_get_bool('mh_ampclients_strip_colon_QUIT'))
	{
		# strip :-prefix from reason (last element in array)
		$line[-1] = irc_strip_colon($line[-1]);
	}

	if (Irssi::settings_get_bool('mh_ampclients_strip_codes_QUIT'))
	{
		# strip colour/formatting from reason (last element in array)
		$line[-1] = Irssi::strip_codes($line[-1]);
	}
	else
	{
		if (Irssi::settings_get_bool('mh_ampclients_stop_bleed_QUIT'))
		{
			# ensure colour/formatting is stopped from bleeding into the following
			# text for Quit reason (handles user-supplied reasons in quotes correctly too)
			# - this is done by inserting an reset-format (\x{0f} code in the correct place

			my $quote = '"';

			if (not Irssi::settings_get_bool('mh_ampclients_strip_colon_QUIT'))
			{
				# :-prefix not stripped, so we need it for the quote begin comparison
				$quote = ':' . $quote;
			}

			if ((index($line[-1], $quote) == 0) and (rindex($line[-1], '"') == (length($line[-1]) - 1)))
			{
				# quoted reason
				$line[-1] = substr($line[-1], 0, -1) . "\x{0f}" . '"';
			}
			else
			{
				# non-quoted reason
				$line[-1] = $line[-1] . "\x{0f}";
			}
		}
	}

	$channelrec->printformat(Irssi::MSGLEVEL_SNOTES(), 'mh_ampclients_QUIT', @line);

	return(1);
}

sub ampclients_parse_notice_NICK
{
	my ($channelrec, @line) = @_;

	# only one non-common parameter, no split of last element needed

	# @line:
	#   0: UID
	#   1: Nickname
	#   2: Username
	#   3: Hostname
	#   4: Type (CONN, QUIT, or NICK)
	#   5: New nickname

	$channelrec->printformat(Irssi::MSGLEVEL_SNOTES(), 'mh_ampclients_NICK', @line);

	return(1);
}

###############################################################################
#
# irssi signal handler functions
#
###############################################################################

sub signals_init
{
	Irssi::signal_add_priority('message irc notice', 'signal_message_irc_notice', Irssi::SIGNAL_PRIORITY_HIGH() - 50);

	return(1);
}

sub signal_message_irc_notice
{
	my ($serverrec, $data, $nickname, $userhost, $target) = @_;

	if (uc($target) ne '&CLIENTS')
	{
		# not &CLIENTS channel, bail out
		return(1);
	}

	if (not defined($serverrec))
	{
		# undefined $serverrec, bail out
		# (this check is probably not needed)
		return(0);
	}

	# see if $serverrec matches any of our configured servers
	for my $match (split(' ', Irssi::settings_get_str('mh_ampclients_server')))
	{
		$match = string_trim_space($match);

		# a * matches any server, otherwise it will check if the string matches
		# any of the serverrecs names (tag, network, hostname...)
		if (($match eq '*') or (irssi_serverrec_match_name($serverrec, $match)))
		{
			# got a match
			my $channelrec = $serverrec->channel_find($target);

			if (not defined($channelrec))
			{
				# channel not found in Irssi
				# (this check is probably not needed)
				return(0);
			}

			return(ampclients_parse_notice($channelrec, $data));
		}

		next; # $match
	}

	# $serverrec did not match configured setting(s)

	return(1);
}

###############################################################################
#
# irssi settings functions
#
###############################################################################

sub settings_init
{
	Irssi::settings_add_bool('mh_ampclients', 'mh_ampclients_hide_duplicate_ip', 1);
	Irssi::settings_add_str( 'mh_ampclients', 'mh_ampclients_server',            '');
	Irssi::settings_add_bool('mh_ampclients', 'mh_ampclients_stop_bleed_CONN',   1);
	Irssi::settings_add_bool('mh_ampclients', 'mh_ampclients_stop_bleed_QUIT',   1);
	Irssi::settings_add_bool('mh_ampclients', 'mh_ampclients_strip_codes_CONN',  0);
	Irssi::settings_add_bool('mh_ampclients', 'mh_ampclients_strip_codes_QUIT',  0);
	Irssi::settings_add_bool('mh_ampclients', 'mh_ampclients_strip_colon_CONN',  1);
	Irssi::settings_add_bool('mh_ampclients', 'mh_ampclients_strip_colon_QUIT',  1);

	return(1);
}

###############################################################################
#
# irssi theme functions
#
###############################################################################

sub themes_init
{
	Irssi::theme_register(
	[
		'mh_ampclients_CONN', '{servernotice $S}%w$0%n %G$4%n %|$1%w!$2@$3%n %K$5%n %n%w$6%n %w$7%n %w$8%n %K:%n$9%n',
		'mh_ampclients_QUIT', '{servernotice $S}%w$0%n %r$4%n %|$1%w!$2@$3%n %Y$5%n %K:%n$6%n',
		'mh_ampclients_NICK', '{servernotice $S}%w$0%n %B$4%n %|$1 %w>%n $5%w!$2@$3%n',
	]);

	return(1);
}

###############################################################################
#
# common IRC functions
#
###############################################################################

sub irc_strip_colon
{
	my ($string) = @_;

	if (not length($string))
	{
		return('');
	}

	if (index($string, ':') == 0)
	{
		return(substr($string, 1));
	}

	return($string);
}

###############################################################################
#
# common Irssi functions
#
###############################################################################

sub irssi_serverrec_names
{
	my ($serverrec) = @_;

	my @names = ();

	if (defined($serverrec))
	{
		for my $key ('tag', 'chatnet', 'real_address', 'address')
		{
			if (not exists($serverrec->{$key}))
			{
				next; # $key
			}

			if (not length($serverrec->{$key}))
			{
				next; # $key
			}

			push(@names, $serverrec->{$key});

			next; # $key
		}
	}

	return(@names);
}

sub irssi_serverrec_match_name
{
	my ($serverrec, $match) = @_;

	if (not defined($serverrec))
	{
		return(0);
	}

	if (not length($match))
	{
		return(0);
	}

	$match = lc($match);

	for my $name (irssi_serverrec_names($serverrec))
	{
		if ($match eq lc($name))
		{
			return(1);
		}

		next; # $name
	}

	return(0);
}

###############################################################################
#
# common string functions
#
###############################################################################

sub string_trim_space
{
	my ($string) = @_;

	if (not length($string))
	{
		return('');
	}

	$string =~ s/^\s+//g; # remove prefixed spaces, etc
	$string =~ s/\s+$//g; # remove suffixed spaces, etc

	return($string);
}

###############################################################################
#
# irssi script on load
#
###############################################################################

if (not Irssi::timeout_add_once(100, 'onload', undef))
{
	die();
}

1;

###############################################################################
#
# eof mh_ampclients.pl
#
###############################################################################
