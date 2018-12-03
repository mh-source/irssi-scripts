###############################################################################
#
# mh_freekicknore.pl (2018-12-03T18:34:37Z)
# mh_freekicknore v0.03
# Copyright (c) 2018  Michael Hansen
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
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
# kick and/or ignore users if first public message matches regex
#
# when the script is enabled it will look for users whose first message to the
# channel matches a regular expression. if found, the user is ignored for a
# short period and if possible, kicked out (it will not try to match users with
# channel or server privileges (op, voice, oper))
#
# the regular expression is currently hardcoded (so are some other values) to
# deal with a specific ongoing spam-campaign
#
# you can find me on IRCnet channel #mh if you have feedback, questions, or
# want to follow updates --mh
#
# quickstart:
#
#   to enable the script you need to set the 'mh_freekicknore' setting to match
#   the channels you want to monitor. for example (in Irssi):
#
#     all channels on all servertags:
#       /set mh_freekicknore *
#
#     all channels on servertag NetA and #channel1 and #channel2 on NetB:
#       /set mh_freekicknore NetA NetB/#channel1,#channel2
#
#     disable on all channels and servertags:
#       /set -clear mh_freekicknore
#
# settings:
#
#   mh_freekicknore  (string, default: '')
#     a space-separated list of '<servertag>['/'<channel>[','<channel2>...]]'
#     entries for channels to monitor. accepts '*' as a wildcard
#
#   mh_freekicknore_log  (bool, default: OFF)
#     enable/disable logging to a file in .irssi/mh_freekicknore/
#
#   mh_freekicknore_match_ignore  (bool, default: ON)
#     enable/disable ignoring the client after a match is made
#
#   mh_freekicknore_match_ignore_time  (int, default: 40)
#     seconds to ignore the client after a match is made. a message about the
#     ignore will be printed, you can disable this using a negative value (ie.
#     -40 for silent ignore for 40 seconds). this is only in effect if the
#     mh_freekicknore_match_ignore setting is ON
#
#   mh_freekicknore_match_kick  (bool, default: ON)
#     enable/disable kicking the client after a match is made (if you are op)
#
#   mh_freekicknore_prune_delay  (int, default: 60)
#     seconds delay between pruning the cache of outdated data. you probably
#     dont need to change this
#
# todo:
#
#   * features
#     - allow matching ops/voice/halfop/oper
#     - ban/!kick/etc options in regex match
#     - flood protection
#
#   * log
#     - what needs logging and which details?
#     - log all ignored text?
#     - log file rollover at midnight
#     - log setting and fh reality can get out of sync on errors
#     - documentation (in log section and in /help)
#
#   * config
#     - persistent storage of per channel configuration
#
#   * cache
#     - setting for how long to wait before a client is forgotten. hardcoded to
#       60s (and not really adhered to) right now
#     - actually follow that setting and remove them if trying to get one
#     - cache matches temporarilly and check joins against them
#     - kick on all channels the client is on when matched somewhere
#
#   * regex
#     - in an array for priority in match loop
#     - per regex options
#     - configurable and stored persistently
#
#   * theme formats
#     - prettyfi, msglevels
#     - documentation (in 'theme formats' section and /help)
#
#   * settings
#     - global settings are currently just pushed down to all channels. should
#       be per channel/regex
#
#   * command /mh_freekicknore
#     - lastlog of "important" events
#     - config, current tags/channels matching config, and cache
#     - documentation (in 'commands' section and /help)
#
#   * command /help
#     - just a stub till it makes sense to put effort into writing it
#     - documentation (in 'commands' section)
#
#   * source code comments
#
# history:
#
#   v0.03 (2018-12-03T18:34:37Z)
#     * added setting mh_freekicknore_prune_delay
#     * some code comments added in a few places
#     * 'log opened' could be logged even when log was not opened. fixed
#     * typo in 'log opened' message fixed
#     * cosmetic code clean-ups
#
#   v0.02 (2018-12-02T21:35:53Z)
#     * added logging to a file and setting mh_freekicknore_log
#     * new setting mh_freekicknore_match_ignore
#     * new setting mh_freekicknore_match_ignore_time
#     * new setting mh_freekicknore_match_kick
#     * added theme format mh_freekicknore_match_ignore
#     * optional message when ignoring a client (via _ignore_time sign)
#     * added /help command stub
#     * added /mh_freekicknore command stub
#     * fixed minor (warning) issue with some 'constants' subs without ()
#     * added a todo/roadmap
#
#   v0.01 (2018-11-29T12:41:04Z)
#     first alpha release
#
###############################################################################

use strict;
use warnings;
use utf8;

use File::Path ();
use IO::Handle ();
use Time::Local ();

###############################################################################
#
# irssi header
#
###############################################################################

our $VERSION = '0.03';
our %IRSSI   =
(
	'name'        => 'mh_freekicknore',
	'description' => 'kick and/or ignore users if first public message matches regex',
	'commands'    => 'mh_freekicknore',
	'modules'     => 'File::Path IO::Handle Time::Local',
	'url'         => 'https://github.com/mh-source/irssi-scripts/',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'license'     => 'ISC',
	'changed'     => '2018-12-03T18:34:37Z',
);

###############################################################################
#
# global variables
#
###############################################################################

our $log    = undef;
our $config = undef;
our $cache  = undef;
our $REGEX  =
{
	qr/^.?(\/|\341\234\265|\342\201\204|\342\210\225|\342\247\270|\357\274\217).+(\342\210\226|\342\247\265|\342\247\271|\357\271\250|\357\274\274|\\)$/
	=> 'spam',
};

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
# script functions
#
###############################################################################

sub config_init
{
	my $config_string            = Irssi::settings_get_str( $IRSSI{'name'});
	my $config_match_ignore      = Irssi::settings_get_bool($IRSSI{'name'} . '_match_ignore');
	my $config_match_ignore_time = Irssi::settings_get_int( $IRSSI{'name'} . '_match_ignore_time');
	my $config_match_kick        = Irssi::settings_get_bool($IRSSI{'name'} . '_match_kick');
	my $config_prune_delay       = Irssi::settings_get_int( $IRSSI{'name'} . '_prune_delay');

	if (defined($config))
	{
		if ($config_string ne $config->{'string'})
		{
			$config = undef;
		}
		elsif ($config_match_ignore != $config->{'match_ignore'})
		{
			$config = undef;
		}
		elsif ($config_match_ignore_time != $config->{'match_ignore_time'})
		{
			$config = undef;
		}
		elsif ($config_match_kick != $config->{'match_kick'})
		{
			$config = undef;
		}
		elsif ($config_prune_delay != $config->{'match_kick'})
		{
			$config = undef;
		}

		if (defined($config))
		{
			return(0);
		}
	}

	$config->{'string'}            = $config_string;
	$config->{'match_ignore'}      = $config_match_ignore;
	$config->{'match_ignore_time'} = $config_match_ignore_time;
	$config->{'match_kick'}        = $config_match_kick;
	$config->{'prune_delay'}       = $config_prune_delay;

	for my $config_lc (split(/\s/, lc($config_string)))
	{
		(my $servertag_lc, my $channelnames_lc) = split('/', $config_lc, 2);

		if (not $channelnames_lc)
		{
			$channelnames_lc = '*';
		}

		for my $channelname_lc (split(',', $channelnames_lc))
		{
			$config->{'server'}->{$servertag_lc}->{'channel'}->{$channelname_lc} =
			{
				'enabled'           => 1,
				'match_ignore'      => $config->{'match_ignore'},
				'match_ignore_time' => $config->{'match_ignore_time'},
				'match_kick'        => $config->{'match_kick'},
			};
		}
	}

	return(1);
}

sub config_get_channel
{
	my ($servertag_lc, $channelname_lc) = @_;

	for $servertag_lc ($servertag_lc, '*')
	{
		if (exists($config->{'server'}->{$servertag_lc}))
		{
			if (exists($config->{'server'}->{$servertag_lc}->{'channel'}->{$channelname_lc}))
			{
				return($config->{'server'}->{$servertag_lc}->{'channel'}->{$channelname_lc});
			}

			if (exists($config->{'server'}->{$servertag_lc}->{'channel'}->{'*'}))
			{
				return($config->{'server'}->{$servertag_lc}->{'channel'}->{'*'});
			}
		}
	}

	return(undef);
}

sub log_init
{
	if (Irssi::settings_get_bool($IRSSI{'name'} . '_log'))
	{
		if (not defined($log))
		{
			log_open();
		}

		return(1);
	}

	if (defined($log))
	{
		log_close();
	}

	return(1);
}

sub log_open
{
	my $filepath = Irssi::get_irssi_dir() . '/' . $IRSSI{'name'} . '/';
	my $filename = $filepath . 'log.txt';

	# our old pal 'mkdir -p'
	File::Path::make_path($filepath);

	if (not open($log->{'fh'}, '>>:encoding(UTF-8)', $filename))
	{
		log_close();

		return(0);
	}

	# enable automatic flush after each write to the filehandle
	$log->{'fh'}->autoflush(1);

	log_write('log opened');

	return(1);
}

sub log_close
{
	if (defined($log->{'fh'}))
	{
		log_write('log closed');
		close($log->{'fh'});
	}

	$log = undef;

	return(1);
}

sub log_write
{
	my ($string) = @_;

	if (not defined($log))
	{
		return(0);
	}

	if (not defined($log->{'fh'}))
	{
		return(0);
	}

	my @time_struct = localtime();
	my $string_ts   = sprintf('%04d-%02d-%02dT%02d:%02d:%02d: ',
		(1900+$time_struct[5]), # year
		(1+$time_struct[4]),    # month
		$time_struct[3],        # day of month
		$time_struct[2],        # hour
		$time_struct[1],        # minute
		$time_struct[0]         # second
	);

	print({$log->{'fh'}} $string_ts . $string . "\n");

	return(1);
}

sub cache_init
{
	if (defined($cache))
	{
		if (defined($cache->{'prune_tout'}))
		{
			Irssi::timeout_remove($cache->{'prune_tout'});
		}

		$cache = undef;
	}

	timeout_cache_prune();

	return(1);
}

sub cache_prune
{
	my $now = time();

	for my $servertag (keys(%{$cache->{'server'}}))
	{
		for my $channelname (keys(%{$cache->{'server'}->{$servertag}->{'channel'}}))
		{
			if ($cache->{'server'}->{$servertag}->{'channel'}->{$channelname}->{'enabled'})
			{
				for my $clientname (keys(%{$cache->{'server'}->{$servertag}->{'channel'}->{$channelname}->{'client'}}))
				{
					my $client = $cache->{'server'}->{$servertag}->{'channel'}->{$channelname}->{'client'}->{$clientname};

					if (($now - $client->{'join'}) > 60)
					{
						cache_channel_del_client($cache->{'server'}->{$servertag}->{'channel'}->{$channelname}, $client->{'nick'}, $client->{'host'});
					}
				}
			}
		}
	}

	return(1);
}

sub cache_get_channel
{
	my ($servertag_lc, $channelname_lc) = @_;

	if (exists($cache->{'server'}->{$servertag_lc}))
	{
		if (exists($cache->{'server'}->{$servertag_lc}->{'channel'}->{$channelname_lc}))
		{
			return($cache->{'server'}->{$servertag_lc}->{'channel'}->{$channelname_lc});
		}
	}

	return(undef);
}

sub cache_add_channel
{
	my ($servertag_lc, $channelname_lc) = @_;

	my $channel = cache_get_channel($servertag_lc, $channelname_lc);

	if (defined($channel))
	{
		return($channel);
	}

	$channel = config_get_channel($servertag_lc, $channelname_lc);

	if (defined($channel))
	{
		$channel =
		{
			'enabled'           => $channel->{'enabled'},
			'match_ignore'      => $channel->{'match_ignore'},
			'match_ignore_time' => $channel->{'match_ignore_time'},
			'match_kick'        => $channel->{'match_kick'},
		};
	}
	else
	{
		$channel =
		{
			'enabled' => 0,
		};
	}

	$channel->{'server'} = $servertag_lc;
	$channel->{'name'}   = $channelname_lc;

	$cache->{'server'}->{$servertag_lc}->{'channel'}->{$channelname_lc} = $channel;

	return($channel);
}

sub cache_channel_get_client
{
	my ($channel, $clientnick, $clienthost) = @_;

	my $clientname = $clientnick . '!' . $clienthost;

	if (exists($channel->{'client'}->{$clientname}))
	{
		return($channel->{'client'}->{$clientname});
	}

	return(undef);
}

sub cache_channel_add_client
{
	my ($channel, $clientnick, $clienthost) = @_;

	my $client = cache_channel_get_client($channel, $clientnick, $clienthost);

	if (defined($client))
	{
		return($client);
	}

	$client =
	{
		'join' => time(),
		'nick' => $clientnick,
		'host' => $clienthost,
	};

	my $clientname = $clientnick . '!' . $clienthost;

	$channel->{'client'}->{$clientname} = $client;

	return($client);
}

sub cache_channel_del_client
{
	my ($channel, $clientnick, $clienthost) = @_;

	my $clientname = $clientnick . '!' . $clienthost;

	if (exists($channel->{'client'}->{$clientname}))
	{
		delete($channel->{'client'}->{$clientname});

		return(1);
	}

	return(0);
}

sub regex_matched
{
	my ($channelrec, $channel, $client, $regex, $message) = @_;

	log_write('match ' . $channel->{'server'} . '/' . $channel->{'name'} . ' ' . $client->{'nick'} . ' ' . $client->{'host'} . ' [' . $regex . ']: "' . $message . '"');

	if ($channel->{'match_kick'})
	{
		if ($channelrec->{'chanop'})
		{
			$channelrec->command('^KICK ' . $channel->{'name'} . ' ' . $client->{'nick'} . ' ' . $regex);
		}
	}

	if ($channel->{'match_ignore'})
	{
		if ($channelrec->{'server'}->ignore_check($client->{'nick'}, $client->{'host'}, $channel->{'name'}, $message, Irssi::level2bits('PUBLIC')))
		{
			return(1);
		}

		my $config_match_ignore_time_abs = abs($channel->{'match_ignore_time'});

		if ($config_match_ignore_time_abs)
		{
			my $clientname = $client->{'nick'} . '!' . $client->{'host'};

			$channelrec->command('^IGNORE -time ' . (2 + $config_match_ignore_time_abs) . ' ' . $clientname . ' PUBLIC');
			Irssi::timeout_add_once((1000 * $config_match_ignore_time_abs), sub
			{
				$channelrec->command('^UNIGNORE ' . $clientname);

				return(1);

			}, undef);

			if ($config_match_ignore_time_abs == $channel->{'match_ignore_time'})
			{
				$channelrec->printformat(Irssi::MSGLEVEL_CRAP() | Irssi::MSGLEVEL_NOHILIGHT(), $IRSSI{'name'} . '_match_ignore', $client->{'nick'}, $client->{'host'}, $regex, $config_match_ignore_time_abs . 's');
			}
		}
	}

	return(1);
}

sub onload
{
	Irssi::theme_register
	([
		$IRSSI{'name'} . '_match_ignore', $IRSSI{'name'} . ': ignore {channick_hilight $0}!{chanhost_hilight $1} {reason $2} ($3)', # nick, host, reason, timeout
	]);

	Irssi::settings_add_str( $IRSSI{'name'}, $IRSSI{'name'},                       '');
	Irssi::settings_add_bool($IRSSI{'name'}, $IRSSI{'name'} . '_log',               0);
	Irssi::settings_add_bool($IRSSI{'name'}, $IRSSI{'name'} . '_match_ignore',      1);
	Irssi::settings_add_int( $IRSSI{'name'}, $IRSSI{'name'} . '_match_ignore_time', 40);
	Irssi::settings_add_bool($IRSSI{'name'}, $IRSSI{'name'} . '_match_kick',        1);
	Irssi::settings_add_int( $IRSSI{'name'}, $IRSSI{'name'} . '_prune_delay',       60);

	Irssi::command_bind('help',             'command_help');
	Irssi::command_bind(lc($IRSSI{'name'}), 'command_mh_freekicknore', $IRSSI{'name'});

	signal_setup_changed();

	Irssi::signal_add(         'setup changed',  'signal_setup_changed');
	Irssi::signal_add_priority('message join',   'signal_message_join_hm100',   Irssi::SIGNAL_PRIORITY_HIGH() - 100);
	Irssi::signal_add_priority('message public', 'signal_message_public_hm100', Irssi::SIGNAL_PRIORITY_HIGH() - 100);

	return(1);
}

###############################################################################
#
# irssi signal handlers
#
###############################################################################

sub signal_setup_changed
{
	log_init();

	if (config_init())
	{
		cache_init();
	}

	return(1);
}

sub signal_message_join_hm100
{
	my ($serverrec, $channelname, $nickname, $userhost) = @_;

	my $channelrec = $serverrec->channel_find($channelname);

	if (not defined($channelrec))
	{
		return(1);
	}

	if (not $channelrec->{'synced'})
	{
		return(1);
	}

	my $servertag_lc   = lc($channelrec->{'server'}->{'tag'});
	my $channelname_lc = lc($channelrec->{'name'});

	my $channel = cache_add_channel($servertag_lc, $channelname_lc);

	if (not defined($channel))
	{
		return(1);
	}

	if (not $channel->{'enabled'})
	{
		return(1);
	}

	my $nickrec = $channelrec->nick_find($nickname);

	if (not defined($nickrec))
	{
		return(1);
	}

	cache_channel_add_client($channel, $nickrec->{'nick'}, $nickrec->{'host'});

	return(1);
}

sub signal_message_public_hm100
{
	my ($serverrec, $message, $nickname, $userhost, $target) = @_;

	my $channelrec = $serverrec->channel_find($target);

	if (not defined($channelrec))
	{
		return(1);
	}

	if (not $channelrec->{'synced'})
	{
		return(1);
	}

	my $servertag_lc   = lc($channelrec->{'server'}->{'tag'});
	my $channelname_lc = lc($channelrec->{'name'});

	my $channel = cache_get_channel($servertag_lc, $channelname_lc);

	if (not defined($channel))
	{
		return(1);
	}

	if (not $channel->{'enabled'})
	{
		return(1);
	}

	my $nickrec = $channelrec->nick_find($nickname);

	if (not defined($nickrec))
	{
		return(1);
	}

	my $client = cache_channel_get_client($channel, $nickrec->{'nick'}, $nickrec->{'host'});

	if (not defined($client))
	{
		return(1);
	}

	cache_channel_del_client($channel, $nickrec->{'nick'}, $nickrec->{'host'});

	if ($nickrec->{'op'} or $nickrec->{'voice'} or $nickrec->{'halfop'} or $nickrec->{'serverop'})
	{
		return(1);
	}

	for my $regex (keys(%{$REGEX}))
	{
		if ($message =~ $regex)
		{
			regex_matched($channelrec, $channel, $client, $REGEX->{$regex}, $message);

			last;
		}
	}

	return(1);
}

###############################################################################
#
# irssi timeout handlers
#
###############################################################################

sub timeout_cache_prune
{
	cache_prune();

	$cache->{'prune_tout'} = Irssi::timeout_add_once(1000 * $config->{'prune_delay'}, 'timeout_cache_prune', undef);

	return(1);
}

###############################################################################
#
# irssi command handlers
#
###############################################################################

sub command_help
{
	my ($data, $server, $witem) = @_;

	my ($data_keyword, $data_more) = split(/\s/, string_trim_space($data), 2);

	if (lc($data_keyword) eq lc($IRSSI{'name'}))
	{
		Irssi::signal_stop();
		Irssi::print('Help for ' . $IRSSI{'name'} . ' not available yet. Read the script file for instructions.' . "\n");
	}

	return(1);
}

sub command_mh_freekicknore
{
	my ($data, $server, $witem) = @_;

	Irssi::print('mh_freekicknore v0.03 Copyright (c) 2018  Michael Hansen');
	Irssi::print(' Sorry, I am just a stub.');

	return(1);
}

###############################################################################
#
# script on load
#
###############################################################################

# initialise script on a timeout so any printing in onload() happens after
# irssi prints 'loaded script...'
#
# i believe newer irssi can use a timeout minimum of 10ms but use 100ms for
# backwards compatibility
Irssi::timeout_add_once(100, 'onload', undef);

1;

###############################################################################
#
# eof mh_freekicknore.pl
#
###############################################################################
