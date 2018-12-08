###############################################################################
#
# mh_freekicknore.pl (2018-12-08T00:39:38Z)
# mh_freekicknore v0.06
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
# channel within a short time matches a regular expression. if found, the user
# is ignored for a short period and if possible, kicked out (it will not try to
# match users with channel or server privileges (op, voice, oper))
#
# the regular expression is currently hardcoded to deal with a specific ongoing
# spam-campaign
#
# join IRCnet channel #mh for feedback, questions, or following script updates
#
# quickstart:
#
#   notice: if you are updating from v0.05 or ealier, the log filename and
#           directory structure changed in v0.06 so the previous log.txt file
#           in .irssi/freekicknore/ is now orphaned (it only exists if you
#           enabled logging at some point)
#
#   to enable the script set setting 'mh_freekicknore' to match servertags and
#   channels to be monitored
#
#   examples (in Irssi):
#
#     /SET mh_freekicknore *
#       all channels on all servertags
#
#     /SET mh_freekicknore NetA NetB/#channel1,#channel2
#       all channels on servertag NetA, and #channel1 and #channel2 on NetB
#
#     /SET -CLEAR mh_freekicknore
#       disable on all channels and servertags
#
#   to view most recent script events, including matched clients, use the
#   command /mh_freekicknore to see the lastlog
#
# settings:
#
#   mh_freekicknore  (string, default: '')
#     a space-separated list of '<servertag>['/'<channel>[','<channel2>...]]'
#     entries for channels to monitor. accepts '*' as a wildcard
#
#   mh_freekicknore_log  (bool, default: OFF)
#     enable/disable logging to a datestamped file structure YYYY/MM/DD.log
#     under .irssi/mh_freekicknore/log/
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
#   mh_freekicknore_match_join_time  (int, default: 20)
#     seconds to wait for joined clients' first message before forgetting them
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
#     - ban/!kick/etc alternatives to /kick
#     - flood protection
#     - catch "nick not on channel" errors when kicking and silence them
#       to reduce noise. esp when multiple ops run the script
#
#   * general
#     - move global variable initialisation into *_init() (also @REGEX)
#
#   * log
#     - nicer aligning log messages
#     - day-changed notice (not just vague 'log closed/opened')
#     - day-changed check as a separate sub()
#     - log-file day-changed check on a timeout so it happens a little more
#       frequent and timely (then we can use just ts_dom for both checks)
#     - lastlog size should be a setting
#     - lastlog prune could be done on timeout and before printing, theres no
#       need to remove (the preditable) 1 line on each log_last() call
#     - re-use log_last() timestamp in log_write(), etc
#     - lastlog with reduced info and full info in logfile - less noise in
#       client lastlog command
#     - log->{'last'} initialised to avoid issue mentioned in /mh_feekicknore
#     - log all ignored text?
#     - log setting and fh reality can get out of sync on errors
#     - documentation (in log section and in /HELP)
#
#   * config
#     - persistent storage of per channel configuration
#
#   * cache
#     - cache matches temporarilly and check joins against them
#     - kick on all channels the client is on when matched somewhere
#     - @REGEX copied into cache->... so we can have 'enabled' flag in @REGEX
#       that isnt copied into cache->@REGEX and wont slow down loop
#
#   * regex
#     - per regex options
#     - configurable and stored persistently
#
#   * ignore
#     - ignore-time of 0 should probably be allowed to ignore one-liners
#     - reset ignore timeout if client is re-matched while ignored
#
#   * theme formats
#     - prettyfi
#     - _match_ignore format doesnt need ! between nick and host in default
#       theme: 23:48 -!- mh_freekicknore: ignore mt![~mt@123.20.240.182] [spam]
#       (40s)
#     - formats for command output (ie. decent %| indent for lastlog messages)
#     - msglevels
#     - documentation (in 'theme formats' section and /HELP)
#
#   * settings
#     - global settings are currently just pushed down to all channels. should
#       be per channel/regex
#     - not much validation is done on setting values, so be careful
#
#   * command /mh_freekicknore
#     - config, current tags/channels matching config, and cache
#     - documentation (in 'commands' section and /HELP)
#
#   * command /HELP
#     - just a stub till it makes sense to put effort into writing it
#     - documentation (in 'commands' section)
#
#   * source code comments
#
# history:
#
#   v0.06 (2018-12-08T00:39:38Z)
#     * updated regex_matched() to log a few more events and details, also only
#       log matched message in logfile and not lastlog
#     * updated documentation for _log setting and change notice in quickstart
#     * changed so log-file now stored in datestamped structure YYYY/MM/DD.log
#       under .irssi/mh_freekicknore/log/ instead of one big log.txt, with
#       basic automatic day-change detection (very lazy) + a couple of cosmetic
#       code changes to log_*()
#     * updated signal_message_join_hm100() with cosmetic code change
#     * updated todo section as usual
#
#   v0.05 (2018-12-05T05:50:48Z)
#     * updated command /mh_freekicknore stub to show lastlog
#     * added lastlog, a log of the last (currently hardcoded to 50) script
#       events
#     * fixed config_init() prune_delay setting compared against wrong value
#       causing excessive re-inits
#
#   v0.04 (2018-12-04T23:40:00Z)
#     * documentation cleaned up a bit
#     * log structure handling cleaned up to make sure lastlog messages are
#       preserved when it is added
#     * clients removed per join-time and not just in cache_prune() timeout
#     * client join-time now updated on re-join if already cached
#     * added setting mh_freekicknore_match_join_time
#     * regexes now stored in an array instead of hash allowing priority in
#       match loop
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
#     * added /HELP command stub
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

our $VERSION = '0.06';
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
	'changed'     => '2018-12-08T00:39:38Z',
);

###############################################################################
#
# global variables
#
###############################################################################

our $log    =
{
	'fh'       => undef, # log-file handle when log enabled and file open
	'ts_year'  => 0,     # log-file timestamp year
	'ts_month' => 0,     # log-file timestamp month
	'ts_dom'   => 0,     # log-file timestamp day of month
	'last'     => undef, # array of lastlog messages
};
our $config = undef;
our $cache  = undef;
our @REGEX  =
(
	{
		'regex'  => qr/^.?(\/|\341\234\265|\342\201\204|\342\210\225|\342\247\270|\357\274\217).+(\342\210\226|\342\247\265|\342\247\271|\357\271\250|\357\274\274|\\)$/,
		'reason' => 'spam',
	},
);

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
	my $config_match_join_time   = Irssi::settings_get_int( $IRSSI{'name'} . '_match_join_time');
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
		elsif ($config_match_join_time != $config->{'match_join_time'})
		{
			$config = undef;
		}
		elsif ($config_match_kick != $config->{'match_kick'})
		{
			$config = undef;
		}
		elsif ($config_prune_delay != $config->{'prune_delay'})
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
	$config->{'match_join_time'}   = $config_match_join_time;
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
				'match_join_time'   => $config->{'match_join_time'},
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
		if (not defined($log->{'fh'}))
		{
			log_open();
		}
	}
	else
	{
		if (defined($log->{'fh'}))
		{
			log_close();
		}
	}

	return(1);
}

sub log_open
{
	my @time_struct    = localtime();
	$log->{'ts_year'}  = (1900+$time_struct[5]); # counting from 1900
	$log->{'ts_month'} = (1+$time_struct[4]);    # 0-based: 0-11
	$log->{'ts_dom'}   = $time_struct[3];        # day of month
	my $filepath_ts    = sprintf('%04d/%02d', $log->{'ts_year'}, $log->{'ts_month'});
	my $filename_ts    = sprintf('%02d', $log->{'ts_dom'});
	my $filepath       = Irssi::get_irssi_dir() . '/' . $IRSSI{'name'} . '/log/' . $filepath_ts . '/';
	my $filename       = $filepath . $filename_ts . '.log';

	# our old pal 'mkdir -p'
	File::Path::make_path($filepath);

	if (not open($log->{'fh'}, '>>:encoding(UTF-8)', $filename))
	{
		log_close();

		return(0);
	}

	# enable automatic flush after each write to the filehandle
	$log->{'fh'}->autoflush(1);

	log_last('log opened');

	return(1);
}

sub log_close
{
	# these need to be zeroed out before the call to log_write() (called in
	# log_last() below) so it does not try to detect day-changed if we are
	# logging a close in an already ongoing day-change
	$log->{'ts_year'}  = 0;
	$log->{'ts_month'} = 0;
	$log->{'ts_dom'}   = 0; # only this variable is actually used for
	                        # day-changed check in log_write() (all 3 are used
	                        # when this is non-zero)

	if (defined($log->{'fh'}))
	{
		log_last('log closed');
		close($log->{'fh'});
		$log->{'fh'} = undef;
	}

	return(1);
}

sub log_write
{
	my ($string) = @_;

	if (not defined($log->{'fh'}))
	{
		return(0);
	}

	my @time_struct = localtime();
	my $ts_year     = (1900+$time_struct[5]); # counting from 1900
	my $ts_month    = (1+$time_struct[4]);    # 0-based: 0-11
	my $ts_dom      = $time_struct[3];        # day of month

	# log-file day-changed check unless were already in an ongoing day-changed
	# and just want to log it (see log_close() for details)
	if ($log->{'ts_dom'} != 0)
	{
		if (($ts_dom != $log->{'ts_dom'}) or ($ts_month != $log->{'ts_month'}) or ($ts_year != $log->{'ts_year'}))
		{
			log_close();
			log_open();
		}
	}

	my $string_ts = sprintf('%04d-%02d-%02dT%02d:%02d:%02d: ',
		$ts_year,
		$ts_month,
		$ts_dom,
		$time_struct[2], # hour
		$time_struct[1], # minute
		$time_struct[0]  # second
	);

	print({$log->{'fh'}} $string_ts . $string . "\n");

	return(1);
}

sub log_last
{
	my ($string) = @_;

	log_write($string);

	my @time_struct = localtime();
	my $string_ts   = sprintf('%02d/%02d %02d:%02d:%02d: ',
		(1+$time_struct[4]), # month (0-based: 0-11)
		$time_struct[3],     # day of month
		$time_struct[2],     # hour
		$time_struct[1],     # minute
		$time_struct[0]      # second
	);

	push(@{$log->{'last'}}, $string_ts . $string);

	log_last_prune();

	return(1);
}

sub log_last_prune
{
	while (@{$log->{'last'}} > 50)
	{
		shift(@{$log->{'last'}});

		next;
	}

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
			my $channel = $cache->{'server'}->{$servertag}->{'channel'}->{$channelname};

			if ($channel->{'enabled'})
			{
				for my $clientname (keys(%{$channel->{'client'}}))
				{
					my $client = $channel->{'client'}->{$clientname};

					if (($now - $client->{'join'}) > $channel->{'match_join_time'})
					{
						cache_channel_del_client($channel, $client->{'nick'}, $client->{'host'});
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
			'match_join_time'   => $channel->{'match_join_time'},
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
		$client->{'join'} = time();

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

	log_last( 'match ' . $client->{'nick'} . '!' . $client->{'host'} . ' [' . $regex->{'reason'} . '] on ' . $channel->{'server'} . '/' . $channel->{'name'});
	log_write('match ' . $client->{'nick'} . '!' . $client->{'host'} . ' [' . $regex->{'reason'} . '] on ' . $channel->{'server'} . '/' . $channel->{'name'} . ': "' . $message . '"');

	if ($channel->{'match_kick'})
	{
		if ($channelrec->{'chanop'})
		{
			log_last('kick ' . $client->{'nick'} . '!' . $client->{'host'} . ' [' . $regex->{'reason'} . '] on ' . $channel->{'server'} . '/' . $channel->{'name'});
			$channelrec->command('^KICK ' . $channel->{'name'} . ' ' . $client->{'nick'} . ' ' . $regex->{'reason'});
		}
	}

	if ($channel->{'match_ignore'})
	{
		if ($channelrec->{'server'}->ignore_check($client->{'nick'}, $client->{'host'}, $channel->{'name'}, $message, Irssi::level2bits('PUBLIC')))
		{
			log_last('ignored already ' . $client->{'nick'} . '!' . $client->{'host'});
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
				log_last('unignored ' . $client->{'nick'} . '!' . $client->{'host'} . ' (after ' . $config_match_ignore_time_abs . 's)');

				return(1);

			}, undef);

			log_last('ignored ' . $client->{'nick'} . '!' . $client->{'host'} . ' (' . $config_match_ignore_time_abs . 's)');

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
	Irssi::settings_add_int( $IRSSI{'name'}, $IRSSI{'name'} . '_match_join_time',   20);
	Irssi::settings_add_bool($IRSSI{'name'}, $IRSSI{'name'} . '_match_kick',        1);
	Irssi::settings_add_int( $IRSSI{'name'}, $IRSSI{'name'} . '_prune_delay',       60);

	signal_setup_changed();

	Irssi::signal_add(         'setup changed',  'signal_setup_changed');
	Irssi::signal_add_priority('message join',   'signal_message_join_hm100',   Irssi::SIGNAL_PRIORITY_HIGH() - 100);
	Irssi::signal_add_priority('message public', 'signal_message_public_hm100', Irssi::SIGNAL_PRIORITY_HIGH() - 100);

	Irssi::command_bind('help',             'command_help');
	Irssi::command_bind(lc($IRSSI{'name'}), 'command_mh_freekicknore', $IRSSI{'name'});

	log_last('script loaded');

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

	my $client = cache_channel_add_client($channel, $nickrec->{'nick'}, $nickrec->{'host'});

	if (not defined($client))
	{
		return(1);
	}

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

	if ((time() - $client->{'join'}) > $channel->{'match_join_time'})
	{
		return(1);
	}

	if ($nickrec->{'op'} or $nickrec->{'voice'} or $nickrec->{'halfop'} or $nickrec->{'serverop'})
	{
		return(1);
	}

	for my $regex (@REGEX)
	{
		if ($message =~ $regex->{'regex'})
		{
			regex_matched($channelrec, $channel, $client, $regex, $message);

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

	Irssi::print('mh_freekicknore v0.06 Copyright (c) 2018  Michael Hansen');

	# print lastlog messages
	#
	# wrap in check for if (defined($log->{'last'})) if this can be called with
	# $log->{'last'} undefined, otherwise we get the warning: 'Can't use an
	# undefined value as an ARRAY reference'. there should always be at least
	# 'script loaded' in our lastlog, so we do not check
	if (@{$log->{'last'}})
	{
		Irssi::print(' lastlog:');

		for my $string (@{$log->{'last'}})
		{
			Irssi::print('  ' . $string);

			next;
		}
	}
	else
	{
		Irssi::print(' lastlog: empty');
	}

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
