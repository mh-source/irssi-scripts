##############################################################################
#
# mh_sbqueryinfo.pl v1.01 (20151218)
#
# Copyright (c) 2015  Michael Hansen
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
# show information about queried nicks
#
# Adds a statusbar item showing ['<username>' [<idletime>] [<away>] [*]]
# for open queries (* is oper status). if the user leaves irc pr changes
# nickname it will show [<offline>]. It will also (optionaly inform you
# when a user goes away/back, oper/deoper, joins/leaves channels, goes
# idle/unidle and more
#
# to configure irssi to show the new statusbar item in a default irssi
# installation type '/statusbar window add -after window_empty mh_sbqueryinfo'.
# see '/help statusbar' for more details and do not forget to '/save'
#
# Adds the command /WHOQ that will show you an extended whois in queries, adding
# the field "shared" which shows channels you share with the user (and your modes
# on the channel)
#
# settings:
#
# mh_sbqueryinfo_delay (default 2): aproximate delay (in minutes) between updating
# (how often we call whois)
#
# mh_sbqueryinfo_lag_limit' (default 5): if lag is higher than this (in seconds)
# calls to whois will be skipped to avoid increasing lag
#
# mh_sbqueryinfo_show_realname (default ON): enable/disable showing realname changes
# in queries
#
# mh_sbqueryinfo_show_userhost (default ON): enable/disable showing userhost changes
# in queries
#
# mh_sbqueryinfo_show_server (default ON): enable/disable showing server changes
# in queries
#
# mh_sbqueryinfo_show_channel_join (default ON): enable/disable showing channel joins
# in queries
#
# mh_sbqueryinfo_show_channel_part (default ON): enable/disable showing channel parts
# in queries (technically a part can also be a kick, the channel becoming secret or
# you leaving a shared channel that is secret)
#
# mh_sbqueryinfo_show_gone (default ON): enable/disable showing when user goes away
#
# mh_sbqueryinfo_show_here (default ON): enable/disable showing when user comes back
# from away
#
# mh_sbqueryinfo_show_oper (default ON): enable/disable showing when a user opers
#
# mh_sbqueryinfo_show_deop (default ON): enable/disable showing when a user deopers
#
# mh_sbqueryinfo_show_online (default ON): enable/disable showing when a user comes
# back online
#
# mh_sbqueryinfo_show_offline (default ON): enable/disable showing when a user goes
# offline
#
# mh_sbqueryinfo_show_idle_here (default ON): enable/disable showing when a user is
# no longer idle
#
# mh_sbqueryinfo_show_idle_gone (default ON): enable/disable showing when a user is
# idle
#
# mh_sbqueryinfo_show_idle_minimum (default 300): idle time in seconds that triggers
# a user going idle
#
# mh_sbqueryinfo_detail_idle_minimum (default 300): minimum idle time in seconds before
# the idle counter is shown on the statusbar item
#
# mh_sbqueryinfo_show_detail_realname (default ON): enable/disable showing realname
# in the statusbar item
#
# this script is dedicated to Witch, without who i would not have bothered to follow
# through on this idea
#
# history:
#	v1.01 (20151218)
#		now updates statusbar item correctly when setup changes
#		added _show_detail_realname and supporting code
#	v1.00 (20151218)
#		initial release
#

use v5.14.2;

use strict;

##############################################################################
#
# irssi head
#
##############################################################################

use Irssi 20100403;
use Irssi::TextUI;

our $VERSION = '1.01';
our %IRSSI   =
(
	'name'        => 'mh_sbqueryinfo',
	'description' => 'show information about queried nicks',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Fri Dec 18 19:28:47 CET 2015',
);

##############################################################################
#
# global variables
#
##############################################################################

our $queries;

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

sub time_string
{
	my ($seconds) = @_;

	my $string    = '';
	my $seconds_h = int($seconds / 3600);
 	$seconds      = $seconds - ($seconds_h * 3600);
	my $seconds_m = int($seconds / 60);
	$seconds      = $seconds - ($seconds_m * 60);
	my $always    = 0;

	if ($seconds_h)
	{
		$string = $string . $seconds_h . 'h';
		$always = 1;
	}

	if ($seconds_m or $always)
	{
		$string = $string . $seconds_m . 'm';
		$always = 1;
	}

	if ($seconds or $always)
	{
		$string = $string . $seconds . 's';
	}

	return($string);
}

sub channel_prefix
{
	my ($channel) = @_;

	my $nick = $channel->nick_find($channel->{'server'}->{'nick'});

	if ($nick)
	{
		if ($nick->{'op'})
		{
			return('@');

		} elsif ($nick->{'halfop'})
		{
			return('%');

		}  elsif ($nick->{'voice'})
		{
			return('+');
		}
	}

	return('');
}

##############################################################################
#
# irssi timeouts
#
##############################################################################

sub timeout_request_whois
{
	my ($args) = @_;
	my ($servertag, $nickname) = @{$args};

	if ($queries)
	{
		if (exists($queries->{$servertag}))
		{
			my $server = Irssi::server_find_tag($servertag);

			if ($server)
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					my $lag_limit = Irssi::settings_get_int('mh_sbqueryinfo_lag_limit');

					if ($lag_limit)
					{
						$lag_limit = $lag_limit * 1000; # seconds to milliseconds
					}

					if ((not $lag_limit) or ($lag_limit > $server->{'lag'}))
					{
						$server->redirect_event("whois",
							1,         # count
							$nickname, # arg
							1,         # remote
							'',        # failure signal
							{          # signals
								'event 301' => 'redir mh_sbqueryinfo event 301', # RPL_AWAY
								'event 311' => 'redir mh_sbqueryinfo event 311', # RPL_WHOISUSER
								'event 312' => 'redir mh_sbqueryinfo event 312', # RPL_WHOISSERVER
								'event 313' => 'redir mh_sbqueryinfo event 313', # RPL_WHOISOPERATOR
								'event 317' => 'redir mh_sbqueryinfo event 317', # RPL_WHOISIDLE
								'event 318' => 'redir mh_sbqueryinfo event 318', # RPL_ENDOFWHOIS
								'event 319' => 'redir mh_sbqueryinfo event 319', # RPL_WHOISCHANNELS
								'event 401' => 'redir mh_sbqueryinfo event 401', # ERR_NOSUCHNICK
								'event 402' => 'redir mh_sbqueryinfo event 401', # ERR_NOSUCHSERVER
								''          => 'event empty',
							}
						);

						$server->send_raw('WHOIS ' . $nickname . ' :' . $nickname);
					}

					my $delay = Irssi::settings_get_int('mh_sbqueryinfo_delay');

					if (not $delay)
					{
						$delay = 1;
					}

					$delay = $delay * 60000; # delay in minutes
					$delay = $delay + (int(rand(10000)) + 1);

					my @args = ($servertag, $nickname);
					$queries->{$servertag}->{$nickname}->{'timeout'} = Irssi::timeout_add_once($delay, 'timeout_request_whois', \@args);
				}
			}
		}
	}
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_query_created
{
	my ($query, $automatic) = @_;

	my $nickname  = lc($query->{'name'});
	my $servertag = lc($query->{'server_tag'});

	$queries->{$servertag}->{$nickname}->{'offline'}         = 0;
	$queries->{$servertag}->{$nickname}->{'realname'}        = '';
	$queries->{$servertag}->{$nickname}->{'oper'}            = 0;
	$queries->{$servertag}->{$nickname}->{'gone'}            = 0;
	$queries->{$servertag}->{$nickname}->{'gone_reason'}     = '';
	$queries->{$servertag}->{$nickname}->{'idle'}            = 0;
	$queries->{$servertag}->{$nickname}->{'signon'}          = 0;
	$queries->{$servertag}->{$nickname}->{'channels'}        = '';
	$queries->{$servertag}->{$nickname}->{'servername'}      = '';
	$queries->{$servertag}->{$nickname}->{'serverdesc'}      = '';
	$queries->{$servertag}->{$nickname}->{'userhost'}        = '';
	$queries->{$servertag}->{$nickname}->{'gone_old'}        = $queries->{$servertag}->{$nickname}->{'gone'};
	$queries->{$servertag}->{$nickname}->{'gone_reason_old'} = $queries->{$servertag}->{$nickname}->{'gone_reason'};
	$queries->{$servertag}->{$nickname}->{'oper_old'}        = $queries->{$servertag}->{$nickname}->{'oper'};

	my @args = ($servertag, $nickname);
	$queries->{$servertag}->{$nickname}->{'timeout'} = Irssi::timeout_add_once(100, 'timeout_request_whois', \@args);
}

sub signal_query_destroyed
{
	my ($query) = @_;

	my $nickname  = lc($query->{'name'});
	my $servertag = lc($query->{'server_tag'});

	if ($queries->{$servertag}->{$nickname}->{'timeout'})
	{
		Irssi::timeout_remove($queries->{$servertag}->{$nickname}->{'timeout'});
	}

	delete($queries->{$servertag}->{$nickname});
}

sub signal_window_changed
{
	my ($window) = @_;

	my $query = $window->{'active'};

	if (ref($query) eq 'Irssi::Irc::Query')
	{
		Irssi::statusbar_items_redraw('mh_sbqueryinfo');
	}
}

sub signal_setup_changed
{
	Irssi::statusbar_items_redraw('mh_sbqueryinfo');
}

sub signal_redir_event_301
{
	my ($server, $data, $sender) = @_;

	if ($data =~ m/^.* (.*) :(.*)$/)
	{
		my $servertag   = lc($server->{'tag'});
		my $nickname    = lc($1);
		my $gone_reason = trim_space($2);
		my $query       = $server->query_find($nickname);

		$queries->{$servertag}->{$nickname}->{'gone'}        = 1;
		$queries->{$servertag}->{$nickname}->{'gone_reason'} = $gone_reason;
	}
}

sub signal_redir_event_311
{
	my ($server, $data, $sender) = @_;

	if ($data =~ m/^.* (.*) (.*) (.*) .* :(.*)$/)
	{
		my $servertag = lc($server->{'tag'});
		my $nickname  = lc($1);
		my $username  = $2;
		my $hostname  = $3;
		my $realname  = trim_space($4);
		my $query     = $server->query_find($nickname);

		if (Irssi::settings_get_bool('mh_sbqueryinfo_show_online'))
		{
			if ($queries->{$servertag}->{$nickname}->{'offline'})
			{
				$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_online', $query->{'name'});
			}
		}

		$queries->{$servertag}->{$nickname}->{'offline'}         = 0;
		$queries->{$servertag}->{$nickname}->{'gone_old'}        = $queries->{$servertag}->{$nickname}->{'gone'};
		$queries->{$servertag}->{$nickname}->{'gone'}            = 0;
		$queries->{$servertag}->{$nickname}->{'gone_reason_old'} = $queries->{$servertag}->{$nickname}->{'gone_reason'};
		$queries->{$servertag}->{$nickname}->{'gone_reason'}     = '';
		$queries->{$servertag}->{$nickname}->{'oper_old'}        = $queries->{$servertag}->{$nickname}->{'oper'};
		$queries->{$servertag}->{$nickname}->{'oper'}            = 0;

		if (Irssi::settings_get_bool('mh_sbqueryinfo_show_realname'))
		{
			if ($query and ($queries->{$servertag}->{$nickname}->{'realname'} ne ''))
			{
				if ($queries->{$servertag}->{$nickname}->{'realname'} ne $realname)
				{
					$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_realname', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'realname'}, $realname);
				}
			}
		}

		$queries->{$servertag}->{$nickname}->{'realname'} = $realname;

		my $userhost = $username . '@' . $hostname;

		if (Irssi::settings_get_bool('mh_sbqueryinfo_show_userhost'))
		{
			if ($query and ($queries->{$servertag}->{$nickname}->{'userhost'} ne ''))
			{
				if ($queries->{$servertag}->{$nickname}->{'userhost'} ne $userhost)
				{
					$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_userhost', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'userhost'}, $userhost);
				}
			}
		}

		$queries->{$servertag}->{$nickname}->{'userhost'} = $userhost;
	}
}

sub signal_redir_event_312
{
	my ($server, $data, $sender) = @_;

	if ($data =~ m/^.* (.*) (.*) :(.*)$/)
	{
		my $servertag   = lc($server->{'tag'});
		my $nickname    = lc($1);
		my $servername  = trim_space($2);
		my $serverdesc  = trim_space($3);

		if (Irssi::settings_get_bool('mh_sbqueryinfo_show_server'))
		{
			if ($queries->{$servertag}->{$nickname}->{'servername'} ne '')
			{
				if ($queries->{$servertag}->{$nickname}->{'servername'} ne $servername)
				{
					my $query = $server->query_find($nickname);

					if ($query)
					{
						$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_server', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'servername'}, $servername, $serverdesc);
					}
				}
			}
		}

		$queries->{$servertag}->{$nickname}->{'servername'} = $servername;
		$queries->{$servertag}->{$nickname}->{'serverdesc'} = $serverdesc;
	}
}

sub signal_redir_event_313
{
	my ($server, $data, $sender) = @_;

	if ($data =~ m/^.* (.*) :.*$/)
	{
		my $servertag = lc($server->{'tag'});
		my $nickname  = lc($1);

		$queries->{$servertag}->{$nickname}->{'oper'} = 1;
	}
}

sub signal_redir_event_317
{
	my ($server, $data, $sender) = @_;

	if ($data =~ m/^.* (.*) ([0-9]+) ([0-9]+) :.*$/)
	{
		my $servertag = lc($server->{'tag'});
		my $nickname  = lc($1);
		my $idle      = $2;
		my $signon    = $3;

		if ($queries)
		{
			my $query = $server->query_find($nickname);

			if ($query)
			{
				if ($queries->{$servertag}->{$nickname}->{'idle'} >= Irssi::settings_get_int('mh_sbqueryinfo_show_idle_minimum'))
				{
					if ($queries->{$servertag}->{$nickname}->{'idle'} > $idle)
					{
						if (Irssi::settings_get_bool('mh_sbqueryinfo_show_idle_here'))
						{
							$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_idle_here', $query->{'name'});
						}
					}
				} else {

					if ($idle >= Irssi::settings_get_int('mh_sbqueryinfo_show_idle_minimum'))
					{
						if (Irssi::settings_get_bool('mh_sbqueryinfo_show_idle_gone'))
						{
							$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_idle_gone', $query->{'name'});
						}
					}
				}
			}
		}

		$queries->{$servertag}->{$nickname}->{'idle'}   = $idle;
		$queries->{$servertag}->{$nickname}->{'signon'} = $signon;
	}
}

sub signal_redir_event_318
{
	my ($server, $data, $sender) = @_;

	if ($data =~ m/^.* (.*) :.*$/)
	{
		my $servertag = lc($server->{'tag'});
		my $nickname  = lc($1);
		my $query     = $server->query_find($nickname);

		if ($query)
		{
			if (($queries->{$servertag}->{$nickname}->{'gone_old'}) and (not $queries->{$servertag}->{$nickname}->{'gone'}))
			{
				if (Irssi::settings_get_bool('mh_sbqueryinfo_show_here'))
				{
					$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_here', $query->{'name'});
				}

			} elsif ((not $queries->{$servertag}->{$nickname}->{'gone_old'}) and ($queries->{$servertag}->{$nickname}->{'gone'}))
			{
				if (Irssi::settings_get_bool('mh_sbqueryinfo_show_gone'))
				{
					$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_gone', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'gone_reason'});
				}

			} elsif ($queries->{$servertag}->{$nickname}->{'gone_reason'} ne $queries->{$servertag}->{$nickname}->{'gone_reason_old'})
			{
				if (Irssi::settings_get_bool('mh_sbqueryinfo_show_gone'))
				{
					$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_gone', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'gone_reason'});
				}
			}

			if (($queries->{$servertag}->{$nickname}->{'oper_old'}) and (not $queries->{$servertag}->{$nickname}->{'oper'}))
			{
				if (Irssi::settings_get_bool('mh_sbqueryinfo_show_deop'))
				{
					$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_deop', $query->{'name'});
				}

			} elsif ((not $queries->{$servertag}->{$nickname}->{'oper_old'}) and ($queries->{$servertag}->{$nickname}->{'oper'}))
			{
				if (Irssi::settings_get_bool('mh_sbqueryinfo_show_deop'))
				{
					$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_oper', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'gone_reason'});
				}
			}
		}

		my $window = Irssi::active_win();
		$query  = $window->{'active'};

		if (ref($query) eq 'Irssi::Irc::Query')
		{
			if (lc($query->{'server_tag'}) eq $servertag)
			{
				if (lc($query->{'name'}) eq $nickname)
				{
					Irssi::statusbar_items_redraw('mh_sbqueryinfo');
				}
			}
		}
	}
}

sub signal_redir_event_319
{
	my ($server, $data, $sender) = @_;

	if ($data =~ m/^.* (.*) :(.*)$/)
	{
		my $servertag  = lc($server->{'tag'});
		my $nickname   = lc($1);
		my $channels   = trim_space($2);
		my $query      = $server->query_find($nickname);

		if ($query)
		{
			if (Irssi::settings_get_bool('mh_sbqueryinfo_show_channel_part'))
			{
				my $channellist;

				for my $channelname (split(' ', $queries->{$servertag}->{$nickname}->{'channels'}))
				{
					$channelname                 =~ s/^([@%+])//;
					my $channelprefix            = trim_space($1);
					$channelname                 = lc($channelname);
					$channellist->{$channelname} = $channelprefix;
				}

				for my $channelname (split(' ', $channels))
				{
					$channelname =~ s/^[@%+]//;
					$channelname = lc($channelname);

					if (exists($channellist->{$channelname}))
					{
						delete($channellist->{$channelname});
					}
				}

				for my $channelname (keys(%{$channellist}))
				{
					$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_channel_part', $query->{'name'}, $channelname);
				}
			}

			if (Irssi::settings_get_bool('mh_sbqueryinfo_show_channel_join'))
			{
				my $channellist;

				for my $channelname (split(' ', $channels))
				{
					$channelname                 =~ s/^([@%+])//;
					my $channelprefix            = trim_space($1);
					$channelname                 = lc($channelname);
					$channellist->{$channelname} = $channelprefix;
				}

				for my $channelname (split(' ', $queries->{$servertag}->{$nickname}->{'channels'}))
				{
					$channelname =~ s/^[@%+]//;
					$channelname = lc($channelname);

					if (exists($channellist->{$channelname}))
					{
						delete($channellist->{$channelname});
					}
				}

				for my $channelname (keys(%{$channellist}))
				{
					$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_channel_join', $query->{'name'}, $channelname);
				}
			}
		}

		$queries->{$servertag}->{$nickname}->{'channels'} = $channels;
	}
}

sub signal_redir_event_401
{
	my ($server, $data, $sender) = @_;

	if ($data =~ m/^.* (.*) :.*$/)
	{
		my $servertag = lc($server->{'tag'});
		my $nickname  = lc($1);

		if (not $queries->{$servertag}->{$nickname}->{'offline'})
		{
			if (Irssi::settings_get_bool('mh_sbqueryinfo_show_offline'))
			{
				my $query = $server->query_find($nickname);

				if ($query)
				{
					$query->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_offline', $query->{'name'});
				}
			}

			$queries->{$servertag}->{$nickname}->{'offline'} = 1;

			my $window = Irssi::active_win();
			my $query  = $window->{'active'};

			if (ref($query) eq 'Irssi::Irc::Query')
			{
				if (lc($query->{'server_tag'}) eq $servertag)
				{
					if (lc($query->{'name'}) eq $nickname)
					{
						Irssi::statusbar_items_redraw('mh_sbqueryinfo');
					}
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

sub command_whoq
{
	my ($data, $server, $windowitem) = @_;

	if (ref($windowitem) eq 'Irssi::Irc::Query')
	{
		my $found = 0;

		if ($queries)
		{
			my $servertag = lc($windowitem->{'server_tag'});
			my $nickname  = lc($windowitem->{'name'});

			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					$found = 1;

					Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_user',     $windowitem->{'name'}, $queries->{$servertag}->{$nickname}->{'userhost'});
					Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_realname', $queries->{$servertag}->{$nickname}->{'realname'});
					Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_server',   $queries->{$servertag}->{$nickname}->{'servername'}, $queries->{$servertag}->{$nickname}->{'serverdesc'});
					Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_signon',   '' . localtime($queries->{$servertag}->{$nickname}->{'signon'}));

					if ($queries->{$servertag}->{$nickname}->{'oper'})
					{
						Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_oper');
					}

					if ($queries->{$servertag}->{$nickname}->{'channels'} ne '')
					{
						Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_channels', $queries->{$servertag}->{$nickname}->{'channels'});
					}

					my $channels_shared = '';

					for my $channelname (split(' ', $queries->{$servertag}->{$nickname}->{'channels'}))
					{
						$channelname =~ s/^[@%+]//;

						my $channel = $server->channel_find($channelname);

						if ($channel)
						{
							$channels_shared = $channels_shared . ' ' . channel_prefix($channel) . $channel->{'name'};
						}
					}

					if ($channels_shared ne '')
					{
						Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_shared', $channels_shared);
					}


					if ($queries->{$servertag}->{$nickname}->{'gone'})
					{
						Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_gone', $queries->{$servertag}->{$nickname}->{'gone_reason'});
					}

					if ($queries->{$servertag}->{$nickname}->{'idle'})
					{
						Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_idle', time_string($queries->{$servertag}->{$nickname}->{'idle'}));
					}
				}
			}
		}

		if (not $found)
		{
			Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_error', 'No WHOQ for this query');
		}

	} else {

		Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_error', 'Not a query');
	}

}

sub command_help
{
	my ($data, $server, $windowitem) = @_;

	$data = lc(trim_space($data));

	if ($data =~ m/^whoq$/i)
	{
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('WHOQ', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('%|Show whois information of current query', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('See also: %|QUERY, SET ' . uc('mh_sbqueryinfo') . ', WHOIS' , Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);

		Irssi::signal_stop();
	}
}

##############################################################################
#
# statusbar item handlers
#
##############################################################################

sub statusbar_queryinfo
{
	my ($statusbaritem, $get_size_only) = @_;

	my $format = '';

	my $query = Irssi::active_win()->{'active'};

	if (ref($query) eq 'Irssi::Irc::Query')
	{
		my $servertag = lc($query->{'server_tag'});
		my $nickname  = lc($query->{'name'});

		if ($queries)
		{
			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					if (Irssi::settings_get_bool('mh_sbqueryinfo_show_detail_realname'))
					{
						if ($queries->{$servertag}->{$nickname}->{'realname'} ne '')
						{
							$format = $format . '\'' . Irssi::strip_codes($queries->{$servertag}->{$nickname}->{'realname'}) . '\'';
						}
					}

					if ($queries->{$servertag}->{$nickname}->{'offline'})
					{
						$format = $format . ' <offline>';

					} else {

						if ($queries->{$servertag}->{$nickname}->{'idle'} and ($queries->{$servertag}->{$nickname}->{'idle'} >= Irssi::settings_get_int('mh_sbqueryinfo_detail_idle_minimum')))
						{
							$format = $format . ' ' . time_string($queries->{$servertag}->{$nickname}->{'idle'});
						}

						if ($queries->{$servertag}->{$nickname}->{'gone'})
						{
							$format = $format . ' <gone>';
						}

						if ($queries->{$servertag}->{$nickname}->{'oper'})
						{
							$format = $format . ' *';
						}
					}

					$format = trim_space($format);
				}
			}
		}
	}

	$statusbaritem->default_handler($get_size_only, '{sb ' . $format . '}', '', 0);
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::theme_register([
	'mh_sbqueryinfo_error',         '{error $0}',
	'mh_sbqueryinfo_gone',          '{nick $0} is {hilight gone} {comment $1}',
	'mh_sbqueryinfo_here',          '{nick $0} is {hilight here}',
	'mh_sbqueryinfo_idle_gone',     '{nick $0} is {hilight idle}',
	'mh_sbqueryinfo_idle_here',     '{nick $0} is no longer {hilight idle}',
	'mh_sbqueryinfo_realname',      '{nick $0} changed realname from "$1%n" to "$2%n"',
	'mh_sbqueryinfo_userhost',      '{nick $0} changed userhost from {nickhost $1} to {nickhost $2}',
	'mh_sbqueryinfo_oper',          '{nick $0} is {hilight oper}',
	'mh_sbqueryinfo_deop',          '{nick $0} is no longer {hilight oper}',
	'mh_sbqueryinfo_offline',       '{nick $0} is {hilight offline}',
	'mh_sbqueryinfo_online',        '{nick $0} is {hilight online}',
	'mh_sbqueryinfo_channel_join',  '{nick $0} joined {channelhilight $1}',
	'mh_sbqueryinfo_channel_part',  '{nick $0} left {channelhilight $1}',
	'mh_sbqueryinfo_server',        '{nick $0} changed server from {server $1} to {server $2} {comment $3}',
	'mh_sbqueryinfo_whoq_user',     '{nick $0} {nickhost $1}',
	'mh_sbqueryinfo_whoq_realname', ' realname : $0%n',
	'mh_sbqueryinfo_whoq_server',   ' server   : $0%n {comment $1}',
	'mh_sbqueryinfo_whoq_signon',   ' signon   : $0%n',
	'mh_sbqueryinfo_whoq_oper',     ' oper     : {hilight Is an IRC operator}',
	'mh_sbqueryinfo_whoq_channels', ' channels : $0%n',
	'mh_sbqueryinfo_whoq_shared',   ' shared   :$0%n',
	'mh_sbqueryinfo_whoq_gone',     ' gone     : $0%n',
	'mh_sbqueryinfo_whoq_idle',     ' idle     : $0%n',
]);

Irssi::settings_add_int('mh_sbqueryinfo',  'mh_sbqueryinfo_delay',                2);
Irssi::settings_add_int('mh_sbqueryinfo',  'mh_sbqueryinfo_lag_limit',            5);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_realname',        1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_userhost',        1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_server',          1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_channel_join',    1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_channel_part',    1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_gone',            1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_here',            1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_oper',            1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_deop',            1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_online',          1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_offline',         1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_idle_here',       1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_idle_gone',       1);
Irssi::settings_add_int('mh_sbqueryinfo',  'mh_sbqueryinfo_show_idle_minimum',    300);
Irssi::settings_add_int('mh_sbqueryinfo',  'mh_sbqueryinfo_detail_idle_minimum',  300);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_detail_realname', 1);

Irssi::statusbar_item_register('mh_sbqueryinfo', '', 'statusbar_queryinfo');

Irssi::signal_add('query created',                  'signal_query_created');
Irssi::signal_add('query destroyed',                'signal_query_destroyed');
Irssi::signal_add('window changed',                 'signal_window_changed');
Irssi::signal_add('setup changed',                  'signal_setup_changed');
Irssi::signal_add('redir mh_sbqueryinfo event 301', 'signal_redir_event_301');
Irssi::signal_add('redir mh_sbqueryinfo event 311', 'signal_redir_event_311');
Irssi::signal_add('redir mh_sbqueryinfo event 312', 'signal_redir_event_312');
Irssi::signal_add('redir mh_sbqueryinfo event 313', 'signal_redir_event_313');
Irssi::signal_add('redir mh_sbqueryinfo event 317', 'signal_redir_event_317');
Irssi::signal_add('redir mh_sbqueryinfo event 318', 'signal_redir_event_318');
Irssi::signal_add('redir mh_sbqueryinfo event 319', 'signal_redir_event_319');
Irssi::signal_add('redir mh_sbqueryinfo event 401', 'signal_redir_event_401');

Irssi::command_bind('whoq', 'command_whoq', 'mh_sbqueryinfo');
Irssi::command_bind('help', 'command_help');

for my $query (Irssi::queries())
{
	signal_query_created($query);
}

1;

##############################################################################
#
# eof mh_sbqueryinfo.pl
#
##############################################################################
