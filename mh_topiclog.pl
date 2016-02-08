##############################################################################
#
# mh_topiclog.pl v1.01 (20160208)
#
# Copyright (c) 2015, 2016  Michael Hansen
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
# keep a log of channel topics
#
# use the command /TOPICLOG in a channel-window to show
# the topic log. see also /help TOPICLOG
#
# logs are saved in .irssi/mh_topiclog/network/channel.log
#
# history:
#
#	v1.01 (20160208)
#		code cleanup
#	v1.00 (20151222)
#		initial release
#

use v5.14.2;

use strict;
use File::Path qw(make_path remove_tree);

##############################################################################
#
# irssi head
#
##############################################################################

use Irssi 20100403;

{ package Irssi::Nick }

our $VERSION = '1.01';
our %IRSSI   =
(
	'name'        => 'mh_topiclog',
	'description' => 'keep a log of channel topics',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Mon Feb  8 19:01:34 CET 2016',
);

##############################################################################
#
# global variables
#
##############################################################################

our $topiclogs;

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

##############################################################################
#
# script functions
#
##############################################################################

sub savelog
{
	my ($servertag, $channelname) = @_;

	if (exists($topiclogs->{$servertag}))
	{
		if (exists($topiclogs->{$servertag}->{$channelname}))
		{
			if ($topiclogs->{$servertag}->{$channelname}->{'timeout'})
			{
				Irssi::timeout_remove($topiclogs->{$servertag}->{$channelname}->{'timeout'});
				$topiclogs->{$servertag}->{$channelname}->{'timeout'} = 0;
			}

			if (exists($topiclogs->{$servertag}->{$channelname}->{'topics'}))
			{
				my $filepath = Irssi::get_irssi_dir() . '/mh_topiclog/' . $servertag;

				make_path($filepath);

				my $filename = $filepath . '/' . $channelname . '.log';

				if (open(my $filehandle, '>>:encoding(UTF-8)', $filename))
				{
					for my $topic_time (sort(keys(%{$topiclogs->{$servertag}->{$channelname}->{'topics'}})))
					{
						print($filehandle $topic_time . ';' . $topiclogs->{$servertag}->{$channelname}->{'topics'}->{$topic_time}->{'topic_by'} . ';' . $topiclogs->{$servertag}->{$channelname}->{'topics'}->{$topic_time}->{'topic'} . "\n");
					}

					close($filehandle);
					delete($topiclogs->{$servertag}->{$channelname}->{'topics'});
				}
			}
		}
	}
}

sub loadlog
{
	my ($servertag, $channelname) = @_;

	if (exists($topiclogs->{$servertag}))
	{
		if (exists($topiclogs->{$servertag}->{$channelname}))
		{
			if ($topiclogs->{$servertag}->{$channelname}->{'timeout'})
			{
				savelog($servertag, $channelname);
			}
		}
	}

	my $filepath = Irssi::get_irssi_dir() . '/mh_topiclog/' . $servertag;
	my $filename = $filepath . '/' . $channelname . '.log';

	if (open(my $filehandle, '<:encoding(UTF-8)', $filename))
	{
		while (my $data = <$filehandle>)
		{
			chomp($data);

			my ($topic_time, $topic_by, $topic) = split(';', $data, 3);

			if ((not $topic_time) or ($topic_by eq '') or ($topic eq ''))
			{
				next;
			}

			$topiclogs->{$servertag}->{$channelname}->{'last_topic'}                          = $topic;
			$topiclogs->{$servertag}->{$channelname}->{'topics'}->{$topic_time}->{'topic'}    = $topic;
			$topiclogs->{$servertag}->{$channelname}->{'topics'}->{$topic_time}->{'topic_by'} = $topic_by;
		}

		close($filehandle);
	}
}

##############################################################################
#
# irssi timeouts
#
##############################################################################

sub timeout_savelog
{
	my ($args) = @_;
	my ($servertag, $channelname) = @{$args};

	if (exists($topiclogs->{$servertag}))
	{
		if (exists($topiclogs->{$servertag}->{$channelname}))
		{
			$topiclogs->{$servertag}->{$channelname}->{'timeout'} = 0;
			savelog($servertag, $channelname);
		}
	}
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_channel_created_last
{
	my ($channel) = @_;

	my $servertag   = lc($channel->{'server'}->{'tag'});
	my $channelname = lc($channel->{'visible_name'});

	if (exists($topiclogs->{$servertag}))
	{
		if (exists($topiclogs->{$servertag}->{$channelname}))
		{
			return(0);
		}
	}

	$topiclogs->{$servertag}->{$channelname}->{'last_topic'} = '';
	$topiclogs->{$servertag}->{$channelname}->{'timeout'}    = 0;

	loadlog($servertag, $channelname);
	delete($topiclogs->{$servertag}->{$channelname}->{'topics'});
}

sub signal_channel_topic_changed_last
{
	my ($channel) = @_;

	my $topic_time = $channel->{'topic_time'};

	if ($topic_time)
	{
		my $topic = $channel->{'topic'};

		if ($topic ne '')
		{
			my $servertag   = lc($channel->{'server'}->{'tag'});
			my $channelname = lc($channel->{'visible_name'});

			if ($topiclogs)
			{
				if (exists($topiclogs->{$servertag}))
				{
					if (exists($topiclogs->{$servertag}->{$channelname}))
					{
						if ($topic eq $topiclogs->{$servertag}->{$channelname}->{'last_topic'})
						{
							return(0);
						}

						if ($topiclogs->{$servertag}->{$channelname}->{'timeout'})
						{
							Irssi::timeout_remove($topiclogs->{$servertag}->{$channelname}->{'timeout'});
							$topiclogs->{$servertag}->{$channelname}->{'timeout'} = 0;

							return(0);
						}
					}
				}
			}

			my $topic_by = $channel->{'topic_by'};

			$topiclogs->{$servertag}->{$channelname}->{'last_topic'}                          = $topic;
			$topiclogs->{$servertag}->{$channelname}->{'topics'}->{$topic_time}->{'topic'}    = $topic;
			$topiclogs->{$servertag}->{$channelname}->{'topics'}->{$topic_time}->{'topic_by'} = $topic_by;

			my @args = ($servertag, $channelname);
			$topiclogs->{$servertag}->{$channelname}->{'timeout'} = Irssi::timeout_add_once(60000, 'timeout_savelog', \@args);
		}
	}
}

sub signal_gui_exit_last
{
	if ($topiclogs)
	{
		for my $servertag (keys(%{$topiclogs}))
		{
			for my $channelname (keys(%{$topiclogs->{$servertag}}))
			{
				if ($topiclogs->{$servertag}->{$channelname}->{'timeout'})
				{
					savelog($servertag, $channelname);
				}
			}
		}
	}
}

##############################################################################
#
# irssi command functions
#
##############################################################################

sub command_topiclog
{
	my ($data, $server, $windowitem) = @_;

	$data           = trim_space($data);
	my $servertag   = '';
	my $channelname = '';

	if (ref($windowitem) eq 'Irssi::Irc::Channel')
	{
		$server      = $windowitem->{'server'};
		$servertag   = lc($server->{'tag'});
		$channelname = lc($windowitem->{'visible_name'});
	}

	if (($servertag eq '') or ($channelname eq ''))
	{
		Irssi::active_win()->printformat(Irssi::MSGLEVEL_CRAP, 'mh_topiclog_error', 'Not a channel window');
		return(0);
	}

	my $mask  = '';
	my $match = '';

	if ($data ne '')
	{
		($mask, $match) = split(' ', $data, 2);
		$mask           = trim_space($mask);
		$match          = trim_space($match);
	}

	if ($topiclogs)
	{
		if (exists($topiclogs->{$servertag}))
		{
			if (exists($topiclogs->{$servertag}->{$channelname}))
			{
				if ($topiclogs->{$servertag}->{$channelname}->{'timeout'})
				{
					savelog($servertag, $channelname);
				}

				loadlog($servertag, $channelname);

				my $topic_count = 0;

				if (exists($topiclogs->{$servertag}->{$channelname}->{'topics'}))
				{
					for my $topic_time (keys(%{$topiclogs->{$servertag}->{$channelname}->{'topics'}}))
					{
						my $topic    = $topiclogs->{$servertag}->{$channelname}->{'topics'}->{$topic_time}->{'topic'};
						my $topic_by = $topiclogs->{$servertag}->{$channelname}->{'topics'}->{$topic_time}->{'topic_by'};

						my ($topic_by_nick, $topic_by_userhost) = split('!', $topic_by, 2);
						my ($topic_by_user, $topic_by_host)     = split('@', $topic_by_userhost, 2);

						if ($mask ne '')
						{
							if (not Irssi::mask_match($mask, $topic_by_nick, $topic_by_user, $topic_by_host))
							{
								next;
							}
						}

						if ($match ne '')
						{
							if (not $topic =~ m/\Q$match\E/ig)
							{
								next;
							}
						}

						$topic_count++;
						Irssi::active_win()->printformat(Irssi::MSGLEVEL_CRAP, 'mh_topiclog_entry_topic', $topic);
						Irssi::active_win()->printformat(Irssi::MSGLEVEL_CRAP, 'mh_topiclog_entry_data', '' . localtime($topic_time), $topic_by_nick, $topic_by_userhost);
					}

					delete($topiclogs->{$servertag}->{$channelname}->{'topics'});
				}

				Irssi::active_win()->printformat(Irssi::MSGLEVEL_CRAP, 'mh_topiclog_entries_count', $topic_count, $mask, $match);
				return(1);
			}
		}
	}

	Irssi::active_win()->printformat(Irssi::MSGLEVEL_CRAP, 'mh_topiclog_error', 'No logs for ' . $channelname . ' on ' . $servertag);
	return(0);
}

sub command_help
{
	my ($data, $server, $windowitem) = @_;

	$data = lc(trim_space($data));

	if ($data =~ m/^topiclog$/i)
	{
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('TOPICLOG %|[<mask> [<text...>]]', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('%|Show topiclog for current channel, optionally matching mask and topic text.', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('mask : %|Match mask against nick!user@host of topic setter', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('text : %|Match text (case insensitive) against topic', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('Examples:', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('  /TOPICLOG %|* http://', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('  /TOPICLOG %|nick!*@*', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('See also: %|TOPIC', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);

		Irssi::signal_stop();
	}
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::theme_register([
	'mh_topiclog_entry_topic',   '%|$0',
	'mh_topiclog_entry_data',    '   %|By {nick $1} {nickhost $2} on $0',
	'mh_topiclog_entries_count', '$0 topics found {comment mask: \'$1\'} {comment match: \'$2\'}',
	'mh_topiclog_error',         '{error $0}',
]);

Irssi::signal_add_last('channel created',       'signal_channel_created_last');
Irssi::signal_add_last('channel topic changed', 'signal_channel_topic_changed_last');
Irssi::signal_add_last('gui exit',              'signal_gui_exit_last');

Irssi::command_bind('topiclog', 'command_topiclog', 'mh_topiclog');
Irssi::command_bind('help',     'command_help');

for my $channel (Irssi::channels())
{
	signal_channel_created_last($channel);
	signal_channel_topic_changed_last($channel);
}

1;

##############################################################################
#
# eof mh_topiclog.pl
#
##############################################################################
