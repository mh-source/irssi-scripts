##############################################################################
#
# mh_iline.pl v0.01 (20170310)
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
# Irc frontend to the https://i-line.space IRCnet I-line lookup service by pbl
#
# A lot of unfolding nested ifs/sub-ifying and corner case, error checking and
# cosmetic things and instructions/comments to do, but it works and with the
# limited documentation below you should be able to get it running :)
#
# At a minimum you need to set mh_iline_channels as explained under settings
#
# the default command !iline will react as follows:
#
#	!iline          | lookup ip of command issuer, this supports mibbit webchat users
#	!iline ip(4/6)  | lookup the given ip
#	!iline nickname | lookup the given nicknames ip if it is on the channel
#
# Settings:
#
# mh_iline_channels (string, default: ''):
#	a comma-seperated list of Network/Channel to monitor for command
#	(ex. IRCnet/#i-line,IRCnet/#i-line2)
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
# mh_iline_url (string, default: 'http://i-line.space/opers/index.php?q='):
#	backend url to sent our requests to (argument is appended)
#
# mh_iline_require_privs (bool, default: on);
#	require +o, +v or +h to enable monitoring
#
# history:
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

our $VERSION = '0.01';
our %IRSSI   =
(
	'name'        => 'mh_iline',
	'description' => 'Irc frontend to the https://i-line.space IRCnet I-line lookup service by pbl',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Fri Mar 10 05:16:46 CET 2017',
);

##############################################################################
#
# global variables
#
##############################################################################

our $in_progress = 0;
our $in_progress_server;
our $in_progress_channel;
our $in_progress_nick;

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

sub lazy_is_webhost
{
	my ($data) = @_;

	if ($data)
	{
		if ($data =~ m/^.+\.mibbit\.com$/i)
		{
			return(1);
		}
	}

	return(0);
}

sub lazy_is_hexip
{
	my ($data) = @_;


	if ($data)
	{
		if ($data =~ m/^[~+\-^=]?[a-f0-9]{8}$/i)
		{
			return(1);
		}
	}

	return(0);
}

sub lazy_is_hostname
{
	my ($data) = @_;

	if ($data)
	{
		if ($data =~ m/^.+\.[a-z]+$/i)
		{
			return(1);
		}
	}

	return(0);
}

sub lazy_is_ip
{
	my ($data) = @_;

	if ($data)
	{
		if ($data =~ m/^([a-f0-9.:]){3,45}$/i)
		{
			if ($data =~ m/.*[.:].*/i) # require at least one . or : so DEAF is a nick, not an IP
			{
				if (not lazy_is_hostname($data))
				{
					return(1);
				}
			}
		}
	}

	return(0);

}

sub hex_to_ip
{
	my ($data) = @_;

	if ($data)
	{
		if ($data =~ m/^[~+\-^=]?([a-f0-9]{8})$/i)
		{
			$data = $1;

			my $oct1 = hex(substr($data, 0, 2));
			my $oct2 = hex(substr($data, 2, 2));
			my $oct3 = hex(substr($data, 4, 2));
			my $oct4 = hex(substr($data, 6, 2));

			return($oct1 . "." . $oct2 . "." . $oct3 . "." . $oct4);
		}
	}

	return('');
}

sub pipe_read
{
	my ($readh, $pipetag, $servertag, $channelname, $nickname) = @{$_[0]};

	my $reply = '';

	my $read_brake = 3;

	while (my $line = <$readh>)
	{
		chomp($line);
		$line = trim_space($line);
		$reply = $reply . ' ' . $line;
		$read_brake--;
		if (not $read_brake)
		{
			break;
		}
	}

	$reply = trim_space($reply);

	close($readh);
	Irssi::input_remove($$pipetag);

	my $server = Irssi::server_find_tag($servertag);

	if ($server)
	{
		my $channel = $server->channel_find($channelname);

		if ($channel)
		{
			if ($reply ne '')
			{
				$reply =~ s/<\/?[a-z]+?>//ig; # no more html tags (but allow < >)
				$reply = trim_space($reply);

				if ($reply !~ m/^[a-z0-9.:_\-<>,(\/) ]{1,300}$/i) 
				{
					$reply =~ s/[^a-z0-9.:_\-<>,(\/) ]*//ig;
					$reply = trim_space($reply);

					if (length($reply) > 300)
					{
						$reply = substr($reply, 0, 300);
						$channel->command('SAY ' . $nickname . ': [<T] ' . $reply);

					} else {

						$channel->command('SAY ' . $nickname . ': [<G] ' . $reply);
					}

				} else {

					$channel->command('SAY ' . $nickname . ': [<] ' . $reply);
				}

			} else {

				$channel->command('SAY ' . $nickname . ': [<!] ' . 'error, no reply');
			}
		}
	}

	$in_progress = 0;
}

sub get_ilines
{
	my ($servertag, $channelname, $nickname, $data) = @_;

	if (pipe(my $readh, my $writeh))
	{
		my $pid = fork();

		if ($pid > 0) 
		{
			# parent

			close($writeh);
			Irssi::pidwait_add($pid);

			my $server = Irssi::server_find_tag($servertag);

			if ($server)
			{
				my $channel = $server->channel_find($channelname);

				if ($channel)
				{
					my $pipetag;
					my @args = ($readh, \$pipetag, $servertag, $channelname, $nickname);
					$pipetag = Irssi::input_add(fileno($readh), Irssi::INPUT_READ, 'pipe_read', \@args);
				}
			}

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
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_redir_event_211
{
	my ($server, $data, $sender) = @_;

	if (lc($server->{'tag'}) eq lc($in_progress_server))
	{
		my $channel = $server->channel_find($in_progress_channel);

		if ($channel)
		{
			$data =~ s/.*\[.*@(.*)\].*/$1/;
			$data = lc(trim_space($data));

			if (not lazy_is_ip($data))
			{
				$channel->command('SAY ' . $in_progress_nick . ': [!] You do not seem to have an IP');

			} else {

				$channel->command('SAY ' . $in_progress_nick . ': [L] Looking up ' . $data);
				get_ilines($in_progress_server, $in_progress_channel, $in_progress_nick, $data);
				return(1);
			}
		}

		$in_progress = 0;
	}
}

sub signal_redir_event_481
{
	my ($server, $data, $sender) = @_;

	$in_progress = 0;
}

sub signal_message_public_priority_low
{
	my ($server, $data, $nickname, $address, $target) = @_;

	if($in_progress)
	{
		if ($in_progress < 2) # 'just this once'-hack :)
		{
			return(0);
		}
	}

	if ($in_progress < 2) # 'just this once'-hack :)
	{
		my $lag_limit = Irssi::settings_get_int('mh_iline_lag_limit');

		if ($lag_limit)
		{
			$lag_limit = $lag_limit * 1000; # seconds to milliseconds

			if ($server->{'lag'} >= $lag_limit)
			{
				return(0);
			}
		}
	}

	my $servertag   = lc($server->{'tag'});
	my $channelname = lc($target);

	for my $serverchannel (split(',', Irssi::settings_get_str('mh_iline_channels')))
	{
		$serverchannel = lc(trim_space($serverchannel));

		if ($serverchannel eq $servertag . '/' . $channelname)
		{
			my $channel = $server->channel_find($channelname);

			if ($channel)
			{
				if (not $channel->{'synced'})
				{
					return(0);
				}

				if (Irssi::settings_get_bool('mh_iline_require_privs'))
				{
					my $selfnick = $channel->nick_find($server->{'nick'});

					if (not $selfnick)
					{
						last;
					}

					if (not ($selfnick->{'op'} or $selfnick->{'voice'} or $selfnick->{'halfop'}))
					{
						last;
					}
				}

				my $nick = $channel->nick_find($nickname);

				if ($nick)
				{
					my $command_char = Irssi::settings_get_str('mh_iline_command_char');

					if ($data =~ s/^\Q$command_char\E//)
					{
						(my $command, $data) = split(' ', $data, 2);
						$command = lc(trim_space($command));

						if ($command eq lc(trim_space(Irssi::settings_get_str('mh_iline_command'))))
						{
							$data = trim_space($data);

							if ($in_progress < 2) # 'just this once'-hack :)
							{
								$channel->command('SAY ' . $nickname . ': Processing...');
							}

							$in_progress = 1;
							$in_progress_server  = $servertag;
							$in_progress_channel = $channelname;
							$in_progress_nick    = $nickname;

							if ($data eq '')
							{
								(my $hexip, $data) = split ('@', $address, 2);

								if (lazy_is_webhost($data))
								{
									if (lazy_is_hexip($hexip))
									{
										$hexip = hex_to_ip($hexip);

										if (lazy_is_ip($hexip))
										{
											$channel->command('SAY ' . $nickname . ': [W] Looking up ' . $hexip);
											get_ilines($servertag, $channelname, $nickname, $hexip);
											last;
										}
									}
								}

								if (lazy_is_ip($data))
								{
									$data = lc($data);
									$channel->command('SAY ' . $nickname . ': [M] Looking up ' . $data);
									get_ilines($servertag, $channelname, $nickname, $data);
									last;
								}

								$server->redirect_event('mh_iline stats L',
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

								$server->send_raw('STATS L ' . $nickname);

							} else {

								$data = lc($data);

								if (not lazy_is_ip($data))
								{
									$nick = $channel->nick_find($data);

									if ($nick)
									{
										my $selfcommand = trim_space(Irssi::settings_get_str('mh_iline_command_char')) . trim_space(Irssi::settings_get_str('mh_iline_command'));

										if (lc($nick->{'nick'}) ne lc($nickname))
										{
											$channel->command('SAY ' . $nickname . ': [N] Looking up ' . $nick->{'nick'});
											$in_progress = 0;
											signal_message_public_priority_low($server, $selfcommand, $nick->{'nick'}, $nick->{'host'}, $target);
											last;
										}

										$in_progress = 2; # 'just this once'-hack :)
										signal_message_public_priority_low($server, $selfcommand, $nick->{'nick'}, $nick->{'host'}, $target);
										last;
									}

									$channel->command('SAY ' . $nickname . ': [!] Not an IP(4/6) address or nickname');
									$in_progress = 0;
									last;
								}

								$channel->command('SAY ' . $nickname . ': [A] Looking up ' . $data);
								get_ilines($servertag, $channelname, $nickname, $data);
							}

							last;
						}
					}
				}
			}

			last;
		}
	}
}

sub signal_message_own_public_priority_low
{
	my ($server, $data, $target) = @_;

	my $nickname = $server->{'nick'};
	my $address  = $server->{'userhost'};

	signal_message_public_priority_low($server, $data, $nickname, $address, $target);
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::settings_add_str('mh_iline', 'mh_iline_channels',       '');
Irssi::settings_add_str('mh_iline', 'mh_iline_command',        'Iline');
Irssi::settings_add_str('mh_iline', 'mh_iline_command_char',   '!');
Irssi::settings_add_int('mh_iline', 'mh_iline_lag_limit',      5);
Irssi::settings_add_str('mh_iline', 'mh_iline_url',            'http://i-line.space/opers/index.php?q=');
Irssi::settings_add_bool('mh_iline', 'mh_iline_require_privs', 1);

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

1;

##############################################################################
#
# eof mh_iline.pl
#
##############################################################################
