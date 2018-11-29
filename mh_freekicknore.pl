###############################################################################
#
# mh_freekicknore.pl (2018-11-29T12:41:04Z)
# mh_freekicknore v0.01
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
# quickstart:
#
#   this is an early alpha release so quickstart is all you get for now
#
#   the regular expression is currently hardcoded (so are most other values) to
#   deal with a specific ongoing spam-campaign
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
#   when the script is enabled it will look for users whose first message to
#   the channel matches a regular expression. if found, the user is ignored for
#   a short period and if possible, kicked out
#
# settings:
#
#   mh_freekicknore  (string, default: '')
#     a space-separated list of '<servertag>['/'<channel>[','<channel2>...]]'
#     entries for channels to monitor. accepts '*' as a wildcard
#
# history:
#
#   v0.01 (2018-11-29T12:41:04Z)
#     first alpha release
#
###############################################################################

use strict;
use warnings;
use utf8;

###############################################################################
#
# irssi header
#
###############################################################################

our $VERSION = '0.01';
our %IRSSI   =
(
	'name'        => 'mh_freekicknore',
	'description' => 'kick and/or ignore users if first public message matches regex',
	'license'     => 'ISC',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'https://github.com/mh-source/irssi-scripts/',
	'changed'     => '2018-11-29T12:41:04Z',
);

###############################################################################
#
# global variables
#
###############################################################################

our $REGEX =
{
	qr/^.?(\/|\341\234\265|\342\201\204|\342\210\225|\342\247\270|\357\274\217).+(\342\210\226|\342\247\265|\342\247\271|\357\271\250|\357\274\274|\\)$/
	=> 'spam',
};

our $config = undef;
our $cache  = undef;

###############################################################################
#
# script functions
#
###############################################################################

sub config_init
{
	my $config_string = Irssi::settings_get_str($IRSSI{'name'});

	if (defined($config))
	{
		if ($config_string eq $config->{'string'})
		{
			return(0);
		}

		$config = undef;
	}

	$config->{'string'} = $config_string;

	for my $config_lc (split(' ', lc($config_string)))
	{
		(my $servertag_lc, my $channelnames_lc) = split('/', $config_lc, 2);

		if (not $channelnames_lc)
		{
			$channelnames_lc = '*';
		}

		for my $channelname_lc (split(',', $channelnames_lc))
		{
			$config->{'server'}->{$servertag_lc}->{'channel'}->{$channelname_lc} = { };
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

sub cache_init
{
	if (defined($cache))
	{
		if (defined($cache->{'tout'}))
		{
			Irssi::timeout_remove($cache->{'tout'});
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
		$channel = { 'enabled' => 1 };
	}
	else
	{
		$channel = { 'enabled' => 0 };
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

	if ($channelrec->{'chanop'})
	{
		$channelrec->command('^KICK ' . $channel->{'name'} . ' ' . $client->{'nick'} . ' ' . $regex);
	}

	if ($channelrec->{'server'}->ignore_check($client->{'nick'}, $client->{'host'}, $channel->{'name'}, $message, Irssi::level2bits('PUBLIC')))
	{
		return(1);
	}

	my $clientname = $client->{'nick'} . '!' . $client->{'host'};

	$channelrec->command('^IGNORE -time 42 ' . $clientname . ' PUBLIC');
	Irssi::timeout_add_once(40000, sub
	{
			$channelrec->command('^UNIGNORE ' . $clientname);

		return(1);
	}, undef);

	return(1);
}

sub onload
{
	Irssi::settings_add_str($IRSSI{'name'}, $IRSSI{'name'}, '');

	signal_setup_changed();

	Irssi::signal_add('setup changed', 'signal_setup_changed');
	Irssi::signal_add_priority('message join',   'signal_message_join_hm100',   Irssi::SIGNAL_PRIORITY_HIGH - 100);
	Irssi::signal_add_priority('message public', 'signal_message_public_hm100', Irssi::SIGNAL_PRIORITY_HIGH - 100);

	return(1);
}

###############################################################################
#
# irssi signal handlers
#
###############################################################################

sub signal_setup_changed
{
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

	$cache->{'tout'} = Irssi::timeout_add_once(60000, 'timeout_cache_prune', undef);

	return(1);
}

###############################################################################
#
# script on load
#
###############################################################################

Irssi::timeout_add_once(100, 'onload', undef);

1;

###############################################################################
#
# eof mh_freekicknore.pl
#
###############################################################################
