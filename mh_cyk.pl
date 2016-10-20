##############################################################################
#
# mh_cyk.pl v0.04 (20161020)
#
# Copyright (c) 2016  Michael Hansen
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
# -
#
# history:
#
#	v0.04 (20161020)
#		accept match/command on actions too (/me)
#		setting no_hilight to enable/disable not hilighting nicknames (longer than 1 char)
#		setting show_channelname to enable/disable showing the channelname in the top-list
#		setting show_count to enable/disable the wordcount next to each nick in top-list
#
#	v0.03 (20161018)
#		fix 'keys on reference is experimental' warnings
#
#	v0.02 (20161018)
#		accept own messages too
#		automatic save/load data to/from a plain text file (mh_cyk.data) in the irssi dir
#
#	v0.01 (20161017)
#		initial pre-release
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

our $VERSION = '0.04';
our %IRSSI   =
(
	'name'        => 'mh_cyk',
	'description' => '-',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Thu Oct 20 08:30:22 CEST 2016',
);

##############################################################################
#
# global variables
#
##############################################################################

our $list;
our $data_save_timeout = 0;

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

sub data_load
{
	my $filepath = Irssi::get_irssi_dir();
	my $filename = $filepath . '/mh_cyk.data';

	if ($data_save_timeout)
	{
		Irssi::timeout_remove($data_save_timeout);
		$data_save_timeout = 0;
	}

    if (open(my $filehandle, '<:encoding(UTF-8)' , $filename))
    {
		$list = undef;

        while (my $data = <$filehandle>)
        {
            chomp($data);

			if ($data =~ m/(..*);(..*);(..*);(..*);.*/)
			{
				my $nick_lc = lc($3);

				$list->{$1}->{$2}->{$nick_lc}->{'nick'}  = $3;
				$list->{$1}->{$2}->{$nick_lc}->{'count'} = int($4);
			}
		}

		close($filehandle);
	}

	return(1);
}

sub data_save
{
	my $filepath = Irssi::get_irssi_dir();

	make_path($filepath);

	my $filename = $filepath . '/mh_cyk.data';

	if ($data_save_timeout)
	{
		Irssi::timeout_remove($data_save_timeout);
		$data_save_timeout = 0;
	}

	if (open(my $filehandle, '>:encoding(UTF-8)' , $filename))
	{
		for my $server (keys(%{$list}))
		{
			for my $channel (keys(%{$list->{$server}}))
			{

				for my $nick_lc (keys(%{$list->{$server}->{$channel}}))
				{
					my $nick  = $list->{$server}->{$channel}->{$nick_lc}->{'nick'};
					my $count = $list->{$server}->{$channel}->{$nick_lc}->{'count'};

					print($filehandle $server . ';' . $channel . ';' . $nick . ';' . $count  . ";\n");
				}
			}
		}

		close($filehandle);
    }

	return(1);
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_message_public_priority_low
{
	my ($server, $data, $nick, $address, $target) = @_;

	my $command = Irssi::settings_get_str('mh_cyk_match');

	if (not ($data =~ m/.*\b\Q$command\E\b.*/i))
	{
		$command = Irssi::settings_get_str('mh_cyk_command_list');

		if (not ($data =~ m/^\Q$command\E.*/i))
		{
			return(0);
		}
	}

	my $servertag   = lc($server->{'tag'});
	my $channelname = lc($target);
	my $nick_lc     = lc($nick);

	for my $serverchannel (split(',', Irssi::settings_get_str('mh_cyk_channels')))
	{
		$serverchannel = lc(trim_space($serverchannel));

		if ($serverchannel eq $servertag . '/' . $channelname)
		{
			if ($command eq Irssi::settings_get_str('mh_cyk_match'))
			{
				if (exists($list->{$servertag}->{$channelname}->{$nick_lc}))
				{
					$list->{$servertag}->{$channelname}->{$nick_lc}->{'count'} = $list->{$servertag}->{$channelname}->{$nick_lc}->{'count'} + 1;

				} else {

					$list->{$servertag}->{$channelname}->{$nick_lc}->{'nick'} = $nick;
					$list->{$servertag}->{$channelname}->{$nick_lc}->{'count'} = 1;
				}

				if (not $data_save_timeout)
				{
					$data_save_timeout = Irssi::timeout_add_once(5*60000, 'data_save', undef);
				}

				return(1);
			}

			if ($command eq Irssi::settings_get_str('mh_cyk_command_list'))
			{
				my $channel = $server->channel_find($channelname);
				my $reply   = '[Top 10 drunks on ' . $channelname . ': Not enough data]';

				if (exists($list->{$servertag}->{$channelname}))
				{
					my $users     = '';
					my $count     = 0;
					my $count_max = 10;

					for my $user (sort { $list->{$servertag}->{$channelname}->{$b}->{'count'} <=>
					                     $list->{$servertag}->{$channelname}->{$a}->{'count'} }
					                     keys(%{$list->{$servertag}->{$channelname}}))
					{
						if ($count > 0)
						{
							$users .= ','
						}

						$count++;

						my $nickname = $list->{$servertag}->{$channelname}->{$user}->{'nick'};

						if (Irssi::settings_get_bool('mh_cyk_no_hilight'))
						{
							$nickname =~ s/(.)(.*)?/$1\x02\x02$2/;
						}

						$users .= ' ' . chr(0x02) . $count . '. ' . chr(0x02) . $nickname;

						if (Irssi::settings_get_bool('mh_cyk_show_count'))
						{
							$users .= ' (' . $list->{$servertag}->{$channelname}->{$user}->{'count'} . ')';
						}

						if ($count == $count_max)
						{
							break;
						}
					}

					if (Irssi::settings_get_bool('mh_cyk_show_channelname'))
					{


						$reply = '[Top 10 drunks on ' . $channelname . ':' . $users . ']';

					} else {

						$reply = '[Top 10 drunks:' . $users . ']';
					}
				}

				$channel->command('SAY ' . $reply);

				return(1);
			}
		}
	}
}

sub signal_message_irc_action_priority_low
{
	my ($server, $data, $nick, $address, $target) = @_;

	return(signal_message_public_priority_low($server, $data, $nick, $address, $target));
}

sub signal_message_own_public_priority_low
{
	my ($server, $data, $target) = @_;

	return(signal_message_public_priority_low($server, $data, $server->{'nick'}, undef, $target));
}

sub signal_message_irc_own_action_priority_low
{
	my ($server, $data, $target) = @_;

	return(signal_message_public_priority_low($server, $data, $server->{'nick'}, undef, $target));
}

sub signal_gui_exit_last
{
	if ($list)
	{
		if ($data_save_timeout)
		{
			data_save();
		}
	}
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::settings_add_str('mh_cyk',  'mh_cyk_match',            'cyk');
Irssi::settings_add_str('mh_cyk',  'mh_cyk_command_list',     '!drunks');
Irssi::settings_add_str('mh_cyk',  'mh_cyk_channels',         '');
Irssi::settings_add_bool('mh_cyk', 'mh_cyk_no_hilight',       0);
Irssi::settings_add_bool('mh_cyk', 'mh_cyk_show_channelname', 1);
Irssi::settings_add_bool('mh_cyk', 'mh_cyk_show_count',       1);

Irssi::signal_add_priority('message public',         'signal_message_public_priority_low',         Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_priority('message irc action',     'signal_message_irc_action_priority_low',     Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_priority('message own_public',     'signal_message_own_public_priority_low',     Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_priority('message irc own_action', 'signal_message_irc_own_action_priority_low', Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_last('gui exit',                   'signal_gui_exit_last');

data_load();

1;

##############################################################################
#
# eof mh_cyk.pl
#
##############################################################################
