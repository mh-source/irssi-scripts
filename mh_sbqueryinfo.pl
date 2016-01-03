##############################################################################
#
# mh_sbqueryinfo.pl v1.10 (20160103)
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
# show information about queried nicks (realname, idletime, away, oper, offline, etc)
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
# mh_sbqueryinfo_lag_limit (default 5): if lag is higher than this (in seconds)
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
# mh_sbqueryinfo_show_offline_signoff (default ON): enable/disable showing signoff
# time of offline users
#
# mh_sbqueryinfo_show_idle_here (default ON): enable/disable showing when a user is
# no longer idle
#
# mh_sbqueryinfo_show_idle_here_time (default ON): enable/disable showing how long
# timer a user was idle when they come back (only when mh_sbqueryinfo_show_idle_here
# is enabled)
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
# mh_sbqueryinfo_strip_realname (default OFF): enable/disable stripping colour
# codes from the realname when printing it in a window
#
# mh_sbqueryinfo_strip_quit_reason (default OFF): enable/disable stripping colour
# codes from the quit reason when printing it in a window
#
# mh_sbqueryinfo_silent_when_away (default OFF): enable/disable showing any updates
# in the query when we are marked away (the statusbar item still updates, and so
# does automatic /WHOQ requests)
#
# mh_sbqueryinfo_whoq_when_away (default ON): enable/disable showing automatic
# /WHOQ requests when away (on create and on offline)
#
# mh_sbqueryinfo_whoq_on_create (default ON): enable/disable showing /WHOQ when
# a query is created
#
# mh_sbqueryinfo_whoq_on_offline (default ON): enable/disable showing /WHOQ when
# a query user quits
#
# mh_sbqueryinfo_idle_longformat (default ON): enable/disable showing the
# idletime in long format when printing "is no longer idle"
#
# mh_sbqueryinfo_detail_idle_longformat (default OFF): enable/disable showing
# the idletime in the statusbar in long format
#
# mh_sbqueryinfo_whoq_idle_longformat (default ON): enable/disable showing the
# idletime in /whoq in long format
#
# the following 'no_act' settings pairs with their 'show' counterparts and enables
# or disables channel activity for the given information, they all default to OFF
#
# mh_sbqueryinfo_no_act_realname
# mh_sbqueryinfo_no_act_userhost
# mh_sbqueryinfo_no_act_server
# mh_sbqueryinfo_no_act_channel_join
# mh_sbqueryinfo_no_act_channel_part
# mh_sbqueryinfo_no_act_gone
# mh_sbqueryinfo_no_act_here
# mh_sbqueryinfo_no_act_oper
# mh_sbqueryinfo_no_act_deop
# mh_sbqueryinfo_no_act_online
# mh_sbqueryinfo_no_act_offline
# mh_sbqueryinfo_no_act_offline_signoff
# mh_sbqueryinfo_no_act_idle_here
# mh_sbqueryinfo_no_act_idle_gone
#
# this script is dedicated to Witch, without who i would not have bothered to follow
# through on this idea
#
# history:
#	v1.09 (20160103)
#		other minor changes to make it react faster under certain circumstances
#		now prints quit-reason in whowas /whoq if it is known
#		added _whoq_when_away and supporting code
#		added _whoq_on_offline and supporting code
#		now shows old whois information in /whoq of quit users, if known
#	v1.09 (20160102)
#		added _idle_longformat, _detail_idle_longformat and whoq_idle_longformat and supporting code
#		fixed a bug in the idletime display
#	v1.08 (20160101)
#		now reacts to a user coming back online and messaging you, setting them online
#		no longer prints /whoq in every query on script load
#		added _strip_realname and supporting code
#		realname is now sanitised before being printed in the statusbar
#	v1.07 (20151229)
#		small fix to timestring output, it didnt always show correctly
#	v1.06 (20151228)
#		now reacts faster on notifylist changes
#		added days and weeks to idletime display
#		fixed issue with numerics containing :
#		now prints "is no longer idle" before the message that triggers unidle
#		code cleanup
#	v1.05 (20151221)
#		show "is idle/no longer idle" regardless of their away status
#		show idletime in /whoq even if it is 0
#		fixed /whoq to work on query instead of active window
#		added _whoq_on_create and supporting code
#	v1.04 (20151220)
#		added _no_act_* and supporting code
#		code cleanup and commenting
#	v1.03 (20151219)
#		added _silent_when_away and supporting code
#		clear some query variables when user goes offline ('gone', 'oper', etc)
#		no longer falsely report back from idle from soming coming back online
#		will now speed up checking of known joined/quitting queries when offline/online
#		will now speed up checking of known active queries which are idle
#		added _show_idle_here_time and supporting code
#		fixed whowas so it only returns 1 reply, removed old filterting code
#	v1.02 (20151219)
#		will now speed up checking of queries known to have quit
#		now tracks when query nicknames change
#		_show_offline_signoff and supporting code
#		will now do whowas on offline queries and give a different /whoq for them
#		now printe "(shared)" when a join/part is a shared channel
#		no longer prints "is idle" if the user is also away
#		removed "channel join" spam for every channel a nick is on when creating query
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

our $VERSION = '1.10';
our %IRSSI   =
(
	'name'        => 'mh_sbqueryinfo',
	'description' => 'show information about queried nicks (realname, idletime, away, oper, offline, etc)',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Sun Jan  3 09:51:03 CET 2016',
);

##############################################################################
#
# global variables
#
##############################################################################

our $queries;
our $on_load = 1;

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

sub time_string
{
	my ($seconds, $longformat) = @_;

	my $string    = '';

	my $seconds_w = int($seconds / 604800);
	$seconds      = $seconds - ($seconds_w * 604800);
	my $seconds_d = int($seconds / 86400);
	$seconds      = $seconds - ($seconds_d * 86400);
	my $seconds_h = int($seconds / 3600);
 	$seconds      = $seconds - ($seconds_h * 3600);
	my $seconds_m = int($seconds / 60);
	$seconds      = $seconds - ($seconds_m * 60);
	my $always    = 0;
	my $string_w  = 'w';
	my $string_d  = 'd';
	my $string_h  = 'h';
	my $string_m  = 'm';
	my $string_s  = 's';

	if ($longformat)
	{
		$string_w  = ' weeks ';
		$string_d  = ' days ';
		$string_h  = ' hours ';
		$string_m  = ' mins ';
		$string_s  = ' secs';
	}

	if ($seconds_w or $always)
	{
		$string = $string . $seconds_w . $string_w;
		$always = 1;
	}

	if ($seconds_d or $always)
	{
		$string = $string . $seconds_d . $string_d;
		$always = 1;
	}

	if ($seconds_h or $always)
	{
		$string = $string . $seconds_h . $string_h;
		$always = 1;
	}

	if ($seconds_m or $always)
	{
		$string = $string . $seconds_m . $string_m;
		$always = 1;
	}

	if ($seconds or $always)
	{
		$string = $string . $seconds . $string_s;

	} else
	{
		#
		# we have zero seconds
		#
		$string = '0s';
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

		} elsif ($nick->{'voice'})
		{
			return('+');
		}
	}

	return('');
}

sub strip_format
{
	my ($string) = @_;

	if ($string)
	{
		$string =~ s/\$/\$\$/g;
		$string =~ s/%/%%/g;
		$string =~ s/{/%{/g;
		$string =~ s/}/%}/g;
	} else
	{
		$string = '';
	}

	return($string);
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
					#
					# lag-protect whois request
					#
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
								'event 301' => 'redir mh_sbqueryinfo event 301',   # RPL_AWAY
								'event 311' => 'redir mh_sbqueryinfo event 311',   # RPL_WHOISUSER
								'event 312' => 'redir mh_sbqueryinfo event 312wi', # RPL_WHOISSERVER
								'event 313' => 'redir mh_sbqueryinfo event 313',   # RPL_WHOISOPERATOR
								'event 317' => 'redir mh_sbqueryinfo event 317',   # RPL_WHOISIDLE
								'event 318' => 'redir mh_sbqueryinfo event 318',   # RPL_ENDOFWHOIS
								'event 319' => 'redir mh_sbqueryinfo event 319',   # RPL_WHOISCHANNELS
								'event 401' => 'redir mh_sbqueryinfo event 401',   # ERR_NOSUCHNICK
								'event 402' => 'redir mh_sbqueryinfo event 401',   # ERR_NOSUCHSERVER
								''          => 'event empty',
							}
						);

						$server->send_raw('WHOIS ' . $nickname . ' :' . $nickname);
					}

					#
					# start a new timeout
					#
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

sub timeout_request_whowas
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
					#
					# lag-protect whowas request
					#
					my $lag_limit = Irssi::settings_get_int('mh_sbqueryinfo_lag_limit');

					if ($lag_limit)
					{
						$lag_limit = $lag_limit * 1000; # seconds to milliseconds
					}

					if ((not $lag_limit) or ($lag_limit > $server->{'lag'}))
					{
						$server->redirect_event("whowas",
							1,         # count
							$nickname, # arg
							0,         # remote
							'',        # failure signal
							{          # signals
								'event 312' => 'redir mh_sbqueryinfo event 312ww', # RPL_WHOISSERVER
								'event 314' => 'redir mh_sbqueryinfo event 314',   # RPL_WHOWASUSER
								'event 369' => 'redir mh_sbqueryinfo event 369',   # RPL_ENDOFWHOWAS
								''          => 'event empty',
							}
						);

						$server->send_raw('WHOWAS ' . $nickname . ' :1');

					} else
					{
						#
						# whowas request skipped, start a new timeout
						#
						my $delay = Irssi::settings_get_int('mh_sbqueryinfo_delay');

						if (not $delay)
						{
							$delay = 1;
						}

						$delay = $delay * 60000; # delay in minutes
						$delay = $delay + (int(rand(10000)) + 1);

						my @args = ($servertag, $nickname);
						Irssi::timeout_add_once($delay, 'timeout_request_whowas', \@args);
					}
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

sub signal_redir_event_301
{
	my ($server, $data, $sender) = @_;

	if ($queries)
	{
		if ($data =~ m/^.*? (.*?) :(.*)$/)
		{
			my $servertag   = lc($server->{'tag'});
			my $nickname    = lc($1);
			my $gone_reason = trim_space($2);
			my $query       = $server->query_find($nickname);

			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					#
					# update away information
					#
					$queries->{$servertag}->{$nickname}->{'gone'}        = 1;
					$queries->{$servertag}->{$nickname}->{'gone_reason'} = $gone_reason;
				}
			}
		}
	}
}

sub signal_redir_event_311
{
	my ($server, $data, $sender) = @_;

	if ($queries)
	{
		if ($data =~ m/^.*?\s+(.*?)\s+(.*?)\s+(.*?)\s+.*?\s+:(.*)$/)
		{
			my $servertag = lc($server->{'tag'});
			my $nickname  = lc($1);
			my $username  = $2;
			my $hostname  = $3;
			my $userhost  = $username . '@' . $hostname;
			my $realname  = trim_space($4);
			my $query     = $server->query_find($nickname);
			my $silent    = (Irssi::settings_get_bool('mh_sbqueryinfo_silent_when_away') and $server->{'usermode_away'});

			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					#
					# print online
					#
					if (Irssi::settings_get_bool('mh_sbqueryinfo_show_online') and (not $silent))
					{
						if ($queries->{$servertag}->{$nickname}->{'offline'})
						{
							my $msglevel = Irssi::MSGLEVEL_CRAP;

							if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_online'))
							{
								$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
							}

							$query->printformat($msglevel, 'mh_sbqueryinfo_online', $query->{'name'});
						}
					}

					#
					# store old values for comparison in "end of whois"
					#
					$queries->{$servertag}->{$nickname}->{'gone_old'}        = $queries->{$servertag}->{$nickname}->{'gone'};
					$queries->{$servertag}->{$nickname}->{'gone_reason_old'} = $queries->{$servertag}->{$nickname}->{'gone_reason'};
					$queries->{$servertag}->{$nickname}->{'oper_old'}        = $queries->{$servertag}->{$nickname}->{'oper'};

					#
					# clean up query structure for this nick
					#
					$queries->{$servertag}->{$nickname}->{'offline'}         = 0;
					$queries->{$servertag}->{$nickname}->{'signon'}          = 0;
					$queries->{$servertag}->{$nickname}->{'gone'}            = 0;
					$queries->{$servertag}->{$nickname}->{'gone_reason'}     = '';
					$queries->{$servertag}->{$nickname}->{'quit_reason'}     = '';
					$queries->{$servertag}->{$nickname}->{'oper'}            = 0;
					$queries->{$servertag}->{$nickname}->{'whowas'}          = 0;
					$queries->{$servertag}->{$nickname}->{'whowas_realname'} = '';
					$queries->{$servertag}->{$nickname}->{'whowas_userhost'} = 0;
					$queries->{$servertag}->{$nickname}->{'whowas_server'}   = '';
					$queries->{$servertag}->{$nickname}->{'whowas_signoff'}  = '';

					#
					# print if userhost changed
					#
					if (Irssi::settings_get_bool('mh_sbqueryinfo_show_userhost') and (not $silent))
					{
						if ($query and ($queries->{$servertag}->{$nickname}->{'userhost'} ne ''))
						{
							if ($queries->{$servertag}->{$nickname}->{'userhost'} ne $userhost)
							{
								my $msglevel = Irssi::MSGLEVEL_CRAP;

								if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_userhost'))
								{
									$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
								}

								$query->printformat($msglevel, 'mh_sbqueryinfo_userhost', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'userhost'}, $userhost);
							}
						}
					}

					#
					# print if realname changed
					#
					if (Irssi::settings_get_bool('mh_sbqueryinfo_show_realname') and (not $silent))
					{
						if ($query and ($queries->{$servertag}->{$nickname}->{'realname'} ne ''))
						{
							if ($queries->{$servertag}->{$nickname}->{'realname'} ne $realname)
							{
								my $msglevel = Irssi::MSGLEVEL_CRAP;

								if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_realname'))
								{
									$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
								}

								if (Irssi::settings_get_bool('mh_sbqueryinfo_strip_realname'))
								{
									$query->printformat($msglevel, 'mh_sbqueryinfo_realname', $query->{'name'}, Irssi::strip_codes($queries->{$servertag}->{$nickname}->{'realname'}), Irssi::strip_codes($realname));

								} else
								{
									$query->printformat($msglevel, 'mh_sbqueryinfo_realname', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'realname'}, $realname);
								}

							}
						}
					}

					$queries->{$servertag}->{$nickname}->{'realname'} = $realname;
					$queries->{$servertag}->{$nickname}->{'userhost'} = $userhost;
				}
			}
		}
	}
}

sub signal_redir_event_312wi
{
	my ($server, $data, $sender) = @_;

	if ($queries)
	{
		if ($data =~ m/^.*? (.*?) (.*?) :(.*)$/)
		{
			my $servertag   = lc($server->{'tag'});
			my $nickname    = lc($1);
			my $servername  = trim_space($2);
			my $serverdesc  = trim_space($3);
			my $silent      = (Irssi::settings_get_bool('mh_sbqueryinfo_silent_when_away') and $server->{'usermode_away'});

			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					#
					# print if server changed
					#
					if (Irssi::settings_get_bool('mh_sbqueryinfo_show_server') and (not $silent))
					{
						if ($queries->{$servertag}->{$nickname}->{'servername'} ne '')
						{
							if ($queries->{$servertag}->{$nickname}->{'servername'} ne $servername)
							{
								my $query = $server->query_find($nickname);

								if ($query)
								{
									my $msglevel = Irssi::MSGLEVEL_CRAP;

									if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_server'))
									{
										$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
									}

									$query->printformat($msglevel, 'mh_sbqueryinfo_server', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'servername'}, $servername, $serverdesc);
								}
							}
						}
					}

					#
					# update server info
					#
					$queries->{$servertag}->{$nickname}->{'servername'} = $servername;
					$queries->{$servertag}->{$nickname}->{'serverdesc'} = $serverdesc;
				}
			}
		}
	}
}

sub signal_redir_event_312ww
{
	my ($server, $data, $sender) = @_;

	if ($queries)
	{
		if ($data =~ m/^.*? (.*?) (.*?) :(.*)$/)
		{
			my $servertag   = lc($server->{'tag'});
			my $nickname    = lc($1);
			my $servername  = trim_space($2);
			my $signoff     = trim_space($3);
			my $silent      = (Irssi::settings_get_bool('mh_sbqueryinfo_silent_when_away') and $server->{'usermode_away'});

			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					#
					# print offline signoff time
					#
					if (Irssi::settings_get_bool('mh_sbqueryinfo_show_offline_signoff') and (not $silent))
					{
						if ($queries)
						{
							my $query = $server->query_find($nickname);

							if ($query)
							{
								my $msglevel = Irssi::MSGLEVEL_CRAP;

								if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_offline_signoff'))
								{
									$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
								}

								$query->printformat($msglevel, 'mh_sbqueryinfo_offline_signoff', $query->{'name'}, $servername, $signoff);
							}
						}
					}

					#
					# update whowas information
					#
					$queries->{$servertag}->{$nickname}->{'whowas_server'}  = $servername;
					$queries->{$servertag}->{$nickname}->{'whowas_signoff'} = $signoff;
				}
			}
		}
	}
}

sub signal_redir_event_313
{
	my ($server, $data, $sender) = @_;

	if ($queries)
	{
		if ($data =~ m/^.*? (.*?) :.*$/)
		{
			my $servertag = lc($server->{'tag'});
			my $nickname  = lc($1);

			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					#
					# update oper information
					#
					$queries->{$servertag}->{$nickname}->{'oper'} = 1;
				}
			}
		}
	}
}

sub signal_redir_event_314
{
	my ($server, $data, $sender) = @_;

	if ($queries)
	{
		if ($data =~ m/^.*? (.*?) (.*?) (.*?) .*? :(.*)$/)
		{
			my $servertag = lc($server->{'tag'});
			my $nickname  = lc($1);
			my $username  = $2;
			my $hostname  = $3;
			my $userhost  = $username . '@' . $hostname;
			my $realname  = trim_space($4);

			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					#
					# update user whowas information
					#
					$queries->{$servertag}->{$nickname}->{'whowas_realname'} = $realname;
					$queries->{$servertag}->{$nickname}->{'whowas_userhost'} = $userhost;
				}
			}
		}
	}
}

sub signal_redir_event_317
{
	my ($server, $data, $sender) = @_;

	if ($queries)
	{
		if ($data =~ m/^.*? (.*?) ([0-9]+) ([0-9]+) :.*$/)
		{
			my $servertag = lc($server->{'tag'});
			my $nickname  = lc($1);
			my $idle      = $2;
			my $signon    = $3;
			my $silent    = (Irssi::settings_get_bool('mh_sbqueryinfo_silent_when_away') and $server->{'usermode_away'});

			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					#
					# print idle time
					#
					if ($queries and (not $silent))
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
										my $msglevel = Irssi::MSGLEVEL_CRAP;

										if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_idle_here'))
										{
											$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
										}

										if (Irssi::settings_get_bool('mh_sbqueryinfo_show_idle_here_time'))
										{
											$query->printformat($msglevel, 'mh_sbqueryinfo_idle_here_time', $query->{'name'}, time_string($queries->{$servertag}->{$nickname}->{'idle'}, Irssi::settings_get_bool('mh_sbqueryinfo_idle_longformat')));

										} else
										{
											$query->printformat($msglevel, 'mh_sbqueryinfo_idle_here', $query->{'name'});
										}
									}
								}

							} else
							{
								if ($idle >= Irssi::settings_get_int('mh_sbqueryinfo_show_idle_minimum'))
								{
									if (Irssi::settings_get_bool('mh_sbqueryinfo_show_idle_gone'))
									{
										my $msglevel = Irssi::MSGLEVEL_CRAP;

										if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_idle_gone'))
										{
											$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
										}

										$query->printformat($msglevel, 'mh_sbqueryinfo_idle_gone', $query->{'name'});
									}
								}
							}
						}
					}

					#
					# update time information
					#
					$queries->{$servertag}->{$nickname}->{'idle'}   = $idle;
					$queries->{$servertag}->{$nickname}->{'signon'} = $signon;
				}
			}
		}
	}
}

sub signal_redir_event_318
{
	my ($server, $data, $sender) = @_;

	if ($queries)
	{
		if ($data =~ m/^.*? (.*?) :.*$/)
		{
			my $servertag = lc($server->{'tag'});
			my $nickname  = lc($1);
			my $query     = $server->query_find($nickname);
			my $silent    = (Irssi::settings_get_bool('mh_sbqueryinfo_silent_when_away') and $server->{'usermode_away'});

			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					if ($query and (not $silent))
					{
						#
						# print away information if state changed
						#
						if (($queries->{$servertag}->{$nickname}->{'gone_old'}) and (not $queries->{$servertag}->{$nickname}->{'gone'}))
						{
							if (Irssi::settings_get_bool('mh_sbqueryinfo_show_here'))
							{
								my $msglevel = Irssi::MSGLEVEL_CRAP;

								if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_here'))
								{
									$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
								}

								$query->printformat($msglevel, 'mh_sbqueryinfo_here', $query->{'name'});
							}

						} elsif ((not $queries->{$servertag}->{$nickname}->{'gone_old'}) and ($queries->{$servertag}->{$nickname}->{'gone'}))
						{
							if (Irssi::settings_get_bool('mh_sbqueryinfo_show_gone'))
							{
								my $msglevel = Irssi::MSGLEVEL_CRAP;

								if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_gone'))
								{
									$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
								}

								$query->printformat($msglevel, 'mh_sbqueryinfo_gone', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'gone_reason'});
							}

						} elsif ($queries->{$servertag}->{$nickname}->{'gone_reason'} ne $queries->{$servertag}->{$nickname}->{'gone_reason_old'})
						{
							#
							# user changed away message but not away status
							#
							if (Irssi::settings_get_bool('mh_sbqueryinfo_show_gone'))
							{
								my $msglevel = Irssi::MSGLEVEL_CRAP;

								if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_gone'))
								{
									$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
								}

								$query->printformat($msglevel, 'mh_sbqueryinfo_gone', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'gone_reason'});
							}
						}

						#
						# print oper information if state changed
						#
						if (($queries->{$servertag}->{$nickname}->{'oper_old'}) and (not $queries->{$servertag}->{$nickname}->{'oper'}))
						{
							if (Irssi::settings_get_bool('mh_sbqueryinfo_show_deop'))
							{
								my $msglevel = Irssi::MSGLEVEL_CRAP;

								if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_deop'))
								{
									$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
								}

								$query->printformat($msglevel, 'mh_sbqueryinfo_deop', $query->{'name'});
							}

						} elsif ((not $queries->{$servertag}->{$nickname}->{'oper_old'}) and ($queries->{$servertag}->{$nickname}->{'oper'}))
						{
							if (Irssi::settings_get_bool('mh_sbqueryinfo_show_oper'))
							{
								my $msglevel = Irssi::MSGLEVEL_CRAP;

								if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_oper'))
								{
									$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
								}

								$query->printformat($msglevel, 'mh_sbqueryinfo_oper', $query->{'name'}, $queries->{$servertag}->{$nickname}->{'gone_reason'});
							}
						}
					}

					#
					# print whoq if first time
					#
					if (($queries->{$servertag}->{$nickname}->{'firsttime'} == 2) and Irssi::settings_get_bool('mh_sbqueryinfo_whoq_on_create'))
					{
						if ((not $server->{'usermode_away'}) or ($server->{'usermode_away'} and Irssi::settings_get_bool('mh_sbqueryinfo_whoq_when_away')))
						{
							$query->command('WHOQ');
						}
					}

					#
					# update statusbar item if this is the active query
					#
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


					$queries->{$servertag}->{$nickname}->{'firsttime'} = 0;
				}
			}
		}
	}
}

sub signal_redir_event_319
{
	my ($server, $data, $sender) = @_;

	if ($queries)
	{
		if ($data =~ m/^.*? (.*?) :(.*)$/)
		{
			my $servertag  = lc($server->{'tag'});
			my $nickname   = lc($1);
			my $channels   = trim_space($2);
			my $query      = $server->query_find($nickname);
			my $silent     = (Irssi::settings_get_bool('mh_sbqueryinfo_silent_when_away') and $server->{'usermode_away'});

			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					#
					# print channel changes
					#
					if ($query and (not $queries->{$servertag}->{$nickname}->{'firsttime'}) and (not $silent))
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
								my $msglevel = Irssi::MSGLEVEL_CRAP;

								if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_channel_part'))
								{
									$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
								}

								if ($server->channel_find($channelname))
								{
									$query->printformat($msglevel, 'mh_sbqueryinfo_channel_part_shared', $query->{'name'}, $channelname);

								} else {

									$query->printformat($msglevel, 'mh_sbqueryinfo_channel_part', $query->{'name'}, $channelname);
								}
							}
						}

						if (Irssi::settings_get_bool('mh_sbqueryinfo_show_channel_join') and not ($silent))
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
								my $msglevel = Irssi::MSGLEVEL_CRAP;

								if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_channel_join'))
								{
									$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
								}

								if ($server->channel_find($channelname))
								{
									$query->printformat($msglevel, 'mh_sbqueryinfo_channel_join_shared', $query->{'name'}, $channelname);

								} else
								{
									$query->printformat($msglevel, 'mh_sbqueryinfo_channel_join', $query->{'name'}, $channelname);
								}
							}
						}
					}

					#
					# update channel information
					#
					$queries->{$servertag}->{$nickname}->{'channels'} = $channels;
				}
			}
		}
	}
}

sub signal_redir_event_369
{
	my ($server, $data, $sender) = @_;

	if (Irssi::settings_get_bool('mh_sbqueryinfo_whoq_on_offline'))
	{
		if ((not $server->{'usermode_away'}) or ($server->{'usermode_away'} and Irssi::settings_get_bool('mh_sbqueryinfo_whoq_when_away')))
		{
			if ($queries)
			{
				if ($data =~ m/^.*? (.*?) :.*$/)
				{
					my $servertag = lc($server->{'tag'});
					my $nickname  = lc($1);
					my $query     = $server->query_find($nickname);

					if (exists($queries->{$servertag}))
					{
						if (exists($queries->{$servertag}->{$nickname}))
						{
							if ($query)
							{
								$query->command('WHOQ');
							}
						}
					}
				}
			}
		}
	}
}

sub signal_redir_event_401
{
	my ($server, $data, $sender) = @_;

	if ($queries)
	{
		if ($data =~ m/^.*? (.*?) :.*$/)
		{
			my $servertag = lc($server->{'tag'});
			my $nickname  = lc($1);
			my $silent    = (Irssi::settings_get_bool('mh_sbqueryinfo_silent_when_away') and $server->{'usermode_away'});

			if (exists($queries->{$servertag}))
			{
				if (exists($queries->{$servertag}->{$nickname}))
				{
					if (not $queries->{$servertag}->{$nickname}->{'offline'})
					{
						Irssi::signal_stop(); # if this is a wild 'event 401' we dont want it to print

						#
						# print offline
						#
						if (not $silent)
						{
							if (Irssi::settings_get_bool('mh_sbqueryinfo_show_offline'))
							{
								my $query = $server->query_find($nickname);

								if ($query)
								{
									my $msglevel = Irssi::MSGLEVEL_CRAP;

									if (Irssi::settings_get_bool('mh_sbqueryinfo_no_act_offline'))
									{
										$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
									}

									$query->printformat($msglevel, 'mh_sbqueryinfo_offline', $query->{'name'});
								}
							}
						}
					}

					#
					# update query structure for this nick
					#
					$queries->{$servertag}->{$nickname}->{'offline'}         = 1;
					$queries->{$servertag}->{$nickname}->{'gone_old'}        = 0;
                    $queries->{$servertag}->{$nickname}->{'gone_reason_old'} = '';
                    $queries->{$servertag}->{$nickname}->{'oper_old'}        = 0;

					#
					# update statusbar item if this is the active query
					#
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

				if (not $queries->{$servertag}->{$nickname}->{'firsttime'})
				{
					$queries->{$servertag}->{$nickname}->{'firsttime'} = 1;
				}

				if (not $queries->{$servertag}->{$nickname}->{'whowas'})
				{
					$queries->{$servertag}->{$nickname}->{'whowas'} = 1;

					#
					# start whowas timeout
					#
					my @args = ($servertag, $nickname);
					Irssi::timeout_add_once(100, 'timeout_request_whowas', \@args);
				}
			}
		}
	}
}

sub signal_channel_sync
{
	my ($channel) = @_;

	if ($queries)
	{
		my $server    = $channel->{'server'};
		my $servertag = lc($server->{'tag'});

		if (exists($queries->{$servertag}))
		{
			for my $nick ($channel->nicks())
			{
				my $nickname = lc($nick->{'nick'});

				if (exists($queries->{$servertag}->{$nickname}))
				{
					#
					# start a new fast timeout
					#
					if ($queries->{$servertag}->{$nickname}->{'timeout'})
					{
						Irssi::timeout_remove($queries->{$servertag}->{$nickname}->{'timeout'});
					}

					my @args = ($servertag, $nickname);
					$queries->{$servertag}->{$nickname}->{'timeout'} = Irssi::timeout_add_once(100, 'timeout_request_whois', \@args);
				}
			}
		}
	}
}

sub signal_message_join
{
	my ($server, $channel, $nickname, $address) = @_;

	if ($queries)
	{
		my $servertag = lc($server->{'tag'});

		if (exists($queries->{$servertag}))
		{
			$nickname = lc($nickname);

			if (exists($queries->{$servertag}->{$nickname}))
			{
				#
				# start a new fast timeout
				#
				if ($queries->{$servertag}->{$nickname}->{'timeout'})
				{
					Irssi::timeout_remove($queries->{$servertag}->{$nickname}->{'timeout'});
				}

				my @args = ($servertag, $nickname);
				$queries->{$servertag}->{$nickname}->{'timeout'} = Irssi::timeout_add_once(100, 'timeout_request_whois', \@args);
			}
		}
	}
}

sub signal_message_private
{
	my ($server, $data, $nickname, $address, $target) = @_;

	if ($queries)
	{
		my $servertag = lc($server->{'tag'});

		if (exists($queries->{$servertag}))
		{
			$nickname = lc($nickname);

			if (exists($queries->{$servertag}->{$nickname}))
			{
				#
				# start a new fast timeout if this query is offline
				#
				if ($queries->{$servertag}->{$nickname}->{'offline'})
				{
					my @args = ($servertag, $nickname);
					$queries->{$servertag}->{$nickname}->{'timeout'} = Irssi::timeout_add_once(100, 'timeout_request_whois', \@args);
				}

				#
				# unset idle and start a new fast timeout if this query is idle
				#
				signal_redir_event_317($server, $server->{'nick'} . ' ' . $nickname . ' ' . '0 ' . $queries->{$servertag}->{$nickname}->{'signon'} . ' :seconds idle, signon time', $queries->{$servertag}->{$nickname}->{'servername'});

				if ($queries->{$servertag}->{$nickname}->{'idle'} >= Irssi::settings_get_int('mh_sbqueryinfo_show_idle_minimum'))
				{
					if ($queries->{$servertag}->{$nickname}->{'timeout'})
					{
						Irssi::timeout_remove($queries->{$servertag}->{$nickname}->{'timeout'});
					}

					my @args = ($servertag, $nickname);
					$queries->{$servertag}->{$nickname}->{'timeout'} = Irssi::timeout_add_once(100, 'timeout_request_whois', \@args);
				}

				#
				# update statusbar item if this is the active query
				#
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
}

sub signal_message_quit
{
	my ($server, $nickname, $address, $reason) = @_;

	if ($queries)
	{
		my $servertag = lc($server->{'tag'});

		if (exists($queries->{$servertag}))
		{
			$nickname = lc($nickname);

			if (exists($queries->{$servertag}->{$nickname}))
			{
				$queries->{$servertag}->{$nickname}->{'quit_reason'} = $reason;

				#
				# start a new fast timeout for this query
				#
				if ($queries->{$servertag}->{$nickname}->{'timeout'})
				{
					Irssi::timeout_remove($queries->{$servertag}->{$nickname}->{'timeout'});
				}

				my @args = ($servertag, $nickname);
				$queries->{$servertag}->{$nickname}->{'timeout'} = Irssi::timeout_add_once(100, 'timeout_request_whois', \@args);
			}
		}
	}
}

sub signal_query_created
{
	my ($query, $automatic) = @_;

	my $nickname  = lc($query->{'name'});
	my $servertag = lc($query->{'server_tag'});

	#
	# initialise query structure
	#
	$queries->{$servertag}->{$nickname}->{'firsttime'}       = 2 - $on_load;
	$queries->{$servertag}->{$nickname}->{'offline'}         = 0;
	$queries->{$servertag}->{$nickname}->{'quit_reason'}     = '';
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
	$queries->{$servertag}->{$nickname}->{'whowas'}          = 0;
	$queries->{$servertag}->{$nickname}->{'whowas_userhost'} = '';
	$queries->{$servertag}->{$nickname}->{'whowas_realname'} = '';
	$queries->{$servertag}->{$nickname}->{'whowas_server'}   = '';
	$queries->{$servertag}->{$nickname}->{'whowas_signoff'}  = '';
	$queries->{$servertag}->{$nickname}->{'gone_old'}        = $queries->{$servertag}->{$nickname}->{'gone'};
	$queries->{$servertag}->{$nickname}->{'gone_reason_old'} = $queries->{$servertag}->{$nickname}->{'gone_reason'};
	$queries->{$servertag}->{$nickname}->{'oper_old'}        = $queries->{$servertag}->{$nickname}->{'oper'};

	#
	# start timeout for query
	#
	my @args = ($servertag, $nickname);
	$queries->{$servertag}->{$nickname}->{'timeout'} = Irssi::timeout_add_once(100, 'timeout_request_whois', \@args);
}

sub signal_query_nick_changed
{
	my ($query, $nickname_old) = @_;

	if ($queries)
	{
		my $servertag = lc($query->{'server'}->{'tag'});

		if (exists($queries->{$servertag}))
		{
			my $nickname_orig = $nickname_old; # needed for printing
			$nickname_old     = lc($nickname_old);

			if (exists($queries->{$servertag}->{$nickname_old}))
			{
				my $nickname = lc($query->{'name'});

				#
				# stop old nicks timeout
				#
				if ($queries->{$servertag}->{$nickname_old}->{'timeout'})
				{
					Irssi::timeout_remove($queries->{$servertag}->{$nickname_old}->{'timeout'});
				}

				#
				# move query information to new nick
				#
				for my $key (keys(%{$queries->{$servertag}->{$nickname_old}}))
				{
					$queries->{$servertag}->{$nickname}->{$key} = $queries->{$servertag}->{$nickname_old}->{$key};
				}

				delete($queries->{$servertag}->{$nickname_old});

				#
				# start new nicks timeout
				#
				my $delay = Irssi::settings_get_int('mh_sbqueryinfo_delay');

				if (not $delay)
				{
					$delay = 1;
				}

				$delay = $delay * 60000; # delay in minutes
				$delay = $delay + (int(rand(10000)) + 1);

				my @args = ($servertag, $nickname);
				$queries->{$servertag}->{$nickname}->{'timeout'} = Irssi::timeout_add_once($delay, 'timeout_request_whois', \@args);

				#
				# update statusbar item if this is the active query
				#
				my $window = Irssi::active_win();
				$query     = $window->{'active'};

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
}

sub signal_query_destroyed
{
	my ($query) = @_;

	if ($queries)
	{
		my $servertag = lc($query->{'server_tag'});

		if (exists($queries->{$servertag}))
		{
			my $nickname  = lc($query->{'name'});

			if (exists($queries->{$servertag}->{$nickname}))
			{
				#
				# stop timeout and remove query
				#
				if ($queries->{$servertag}->{$nickname}->{'timeout'})
				{
					Irssi::timeout_remove($queries->{$servertag}->{$nickname}->{'timeout'});
				}

				delete($queries->{$servertag}->{$nickname});
			}
		}
	}
}

sub signal_notifylist_joined
{
	my ($server, $nickname, $username, $hostname, $realname, $away_reason) = @_;

	if ($queries)
	{
		my $servertag = lc($server->{'tag'});

		if (exists($queries->{$servertag}))
		{
			$nickname = lc($nickname);

			if (exists($queries->{$servertag}->{$nickname}))
			{
				#
				# start a new fast timeout for this query
				#
				if ($queries->{$servertag}->{$nickname}->{'timeout'})
				{
					Irssi::timeout_remove($queries->{$servertag}->{$nickname}->{'timeout'});
				}

				my @args = ($servertag, $nickname);
				$queries->{$servertag}->{$nickname}->{'timeout'} = Irssi::timeout_add_once(100, 'timeout_request_whois', \@args);
			}
		}
	}
}

sub signal_setup_changed
{
	Irssi::statusbar_items_redraw('mh_sbqueryinfo');
}

sub signal_window_changed
{
	my ($window) = @_;

	if (ref($window->{'active'}) eq 'Irssi::Irc::Query')
	{
		Irssi::statusbar_items_redraw('mh_sbqueryinfo');
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

			if (exists($queries->{$servertag}))
			{
				my $nickname = lc($windowitem->{'name'});

				if (exists($queries->{$servertag}->{$nickname}))
				{
					$found = 1;

					if (not $queries->{$servertag}->{$nickname}->{'whowas'})
					{
						#
						# print cached whois information
						#
						$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_user', $windowitem->{'name'}, $queries->{$servertag}->{$nickname}->{'userhost'});

						if (Irssi::settings_get_bool('mh_sbqueryinfo_strip_realname'))
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_realname', Irssi::strip_codes($queries->{$servertag}->{$nickname}->{'realname'}));

						} else
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_realname', $queries->{$servertag}->{$nickname}->{'realname'});
						}

						$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_server', $queries->{$servertag}->{$nickname}->{'servername'}, $queries->{$servertag}->{$nickname}->{'serverdesc'});

						if ($queries->{$servertag}->{$nickname}->{'signon'})
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_signon', '' . localtime($queries->{$servertag}->{$nickname}->{'signon'}));
						}

						if ($queries->{$servertag}->{$nickname}->{'oper'})
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_oper');
						}

						if ($queries->{$servertag}->{$nickname}->{'channels'} ne '')
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_channels', $queries->{$servertag}->{$nickname}->{'channels'});
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
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_shared', $channels_shared);
						}

						if ($queries->{$servertag}->{$nickname}->{'gone'})
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_gone', $queries->{$servertag}->{$nickname}->{'gone_reason'});
						}

						$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_idle', time_string($queries->{$servertag}->{$nickname}->{'idle'}, Irssi::settings_get_bool('mh_sbqueryinfo_whoq_idle_longformat')));

					} else {

						#
						# print cached whowas information
						#
						$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_user_whowas',     $windowitem->{'name'}, $queries->{$servertag}->{$nickname}->{'whowas_userhost'});
						$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_realname_whowas', $queries->{$servertag}->{$nickname}->{'whowas_realname'});

						if ($queries->{$servertag}->{$nickname}->{'servername'} eq '')
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_server_whowas', $queries->{$servertag}->{$nickname}->{'whowas_server'});

						} else
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_server2_whowas', $queries->{$servertag}->{$nickname}->{'whowas_server'}, $queries->{$servertag}->{$nickname}->{'servername'}, $queries->{$servertag}->{$nickname}->{'serverdesc'});
						}

						if ($queries->{$servertag}->{$nickname}->{'signon'})
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_signon_whowas', '' . localtime($queries->{$servertag}->{$nickname}->{'signon'}));
						}

						$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_signoff_whowas', $queries->{$servertag}->{$nickname}->{'whowas_signoff'});

						if ($queries->{$servertag}->{$nickname}->{'oper'})
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_oper_whowas');
						}

						if ($queries->{$servertag}->{$nickname}->{'channels'} ne '')
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_channels_whowas', $queries->{$servertag}->{$nickname}->{'channels'});
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
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_shared_whowas', $channels_shared);
						}

						if ($queries->{$servertag}->{$nickname}->{'gone'})
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_gone_whowas', $queries->{$servertag}->{$nickname}->{'gone_reason'});
						}

						if ($queries->{$servertag}->{$nickname}->{'idle'})
						{
							$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_idle_whowas', time_string($queries->{$servertag}->{$nickname}->{'idle'}, Irssi::settings_get_bool('mh_sbqueryinfo_whoq_idle_longformat')));
						}

						if ($queries->{$servertag}->{$nickname}->{'quit_reason'} ne '')
						{
							if (Irssi::settings_get_bool('mh_sbqueryinfo_strip_quit_reason'))
							{
								$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_quit_whowas', Irssi::strip_codes($queries->{$servertag}->{$nickname}->{'quit_reason'}));
							} else
							{
								$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_whoq_quit_whowas', $queries->{$servertag}->{$nickname}->{'quit_reason'});
							}
						}

					}
				}
			}
		}

		if (not $found)
		{
			Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_sbqueryinfo_error', 'No WHOQ for this query');
		}

	} else
	{
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
		Irssi::print('%|Show whois or whowas information of current query', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('See also: %|QUERY, SET ' . uc('mh_sbqueryinfo') . ', WHOIS, WHOWAS' , Irssi::MSGLEVEL_CLIENTCRAP);
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
	my $query  = Irssi::active_win()->{'active'};

	if (ref($query) eq 'Irssi::Irc::Query')
	{
		if ($queries)
		{
			my $servertag = lc($query->{'server_tag'});

			if (exists($queries->{$servertag}))
			{
				my $nickname  = lc($query->{'name'});

				if (exists($queries->{$servertag}->{$nickname}))
				{
					#
					# add realname
					#
					if (Irssi::settings_get_bool('mh_sbqueryinfo_show_detail_realname'))
					{
						if ($queries->{$servertag}->{$nickname}->{'realname'} ne '')
						{
							$format = $format . '\'' . Irssi::strip_codes(strip_format($queries->{$servertag}->{$nickname}->{'realname'})) . '\'';
						}
					}

					#
					# add if offline
					#
					if ($queries->{$servertag}->{$nickname}->{'offline'})
					{
						$format = $format . ' <offline>';

					} else
					{
						#
						# add idletime
						#
						if ($queries->{$servertag}->{$nickname}->{'idle'} >= Irssi::settings_get_int('mh_sbqueryinfo_detail_idle_minimum'))
						{
							$format = $format . ' ' . time_string($queries->{$servertag}->{$nickname}->{'idle'}, Irssi::settings_get_bool('mh_sbqueryinfo_detail_idle_longformat'));
						}

						#
						# add away status
						#
						if ($queries->{$servertag}->{$nickname}->{'gone'})
						{
							$format = $format . ' <gone>';
						}

						#
						# add oper status
						#
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
	'mh_sbqueryinfo_error',                '{error $0}',
	'mh_sbqueryinfo_gone',                 '{nick $0} is {hilight gone} {comment $1}',
	'mh_sbqueryinfo_here',                 '{nick $0} is {hilight here}',
	'mh_sbqueryinfo_idle_gone',            '{nick $0} is {hilight idle}',
	'mh_sbqueryinfo_idle_here',            '{nick $0} is no longer {hilight idle}',
	'mh_sbqueryinfo_idle_here_time',       '{nick $0} is no longer {hilight idle} after $1%n',
	'mh_sbqueryinfo_realname',             '{nick $0} changed realname from "$1%n" to "$2%n"',
	'mh_sbqueryinfo_userhost',             '{nick $0} changed userhost from {nickhost $1} to {nickhost $2}',
	'mh_sbqueryinfo_oper',                 '{nick $0} is {hilight oper}',
	'mh_sbqueryinfo_deop',                 '{nick $0} is no longer {hilight oper}',
	'mh_sbqueryinfo_offline',              '{nick $0} is {hilight offline}',
	'mh_sbqueryinfo_online',               '{nick $0} is {hilight online}',
	'mh_sbqueryinfo_channel_join',         '{nick $0} joined {channelhilight $1}',
	'mh_sbqueryinfo_channel_part',         '{nick $0} left {channelhilight $1}',
	'mh_sbqueryinfo_channel_join_shared',  '{nick $0} joined {channelhilight $1} (shared)',
	'mh_sbqueryinfo_channel_part_shared',  '{nick $0} left {channelhilight $1} (shared)',
	'mh_sbqueryinfo_server',               '{nick $0} changed server from {server $1} to {server $2} {comment $3}',
	'mh_sbqueryinfo_offline_signoff',      '{nick $0} disconnected from {server $1} $2%n',
	'mh_sbqueryinfo_whoq_user',            '{nick $0} {nickhost $1}',
	'mh_sbqueryinfo_whoq_realname',        ' realname : $0%n',
	'mh_sbqueryinfo_whoq_server',          ' server   : $0%n {comment $1}',
	'mh_sbqueryinfo_whoq_signon',          ' signon   : $0%n',
	'mh_sbqueryinfo_whoq_oper',            ' oper     : {hilight Is an IRC operator}',
	'mh_sbqueryinfo_whoq_channels',        ' channels : $0%n',
	'mh_sbqueryinfo_whoq_shared',          ' shared   :$0%n',
	'mh_sbqueryinfo_whoq_gone',            ' gone     : $0%n',
	'mh_sbqueryinfo_whoq_idle',            ' idle     : $0%n',
	'mh_sbqueryinfo_whoq_user_whowas',     '{nick $0} was {nickhost $1}',
	'mh_sbqueryinfo_whoq_realname_whowas', ' realname : $0%n',
	'mh_sbqueryinfo_whoq_server_whowas',   ' server   : $0%n',
	'mh_sbqueryinfo_whoq_server2_whowas',  ' server   : $0%n ($1%n {comment $2})',
	'mh_sbqueryinfo_whoq_signon_whowas',   ' signon   : $0%n',
	'mh_sbqueryinfo_whoq_signoff_whowas',  ' signoff  : $0%n',
	'mh_sbqueryinfo_whoq_oper_whowas',     ' was oper : {hilight Was an IRC operator}',
	'mh_sbqueryinfo_whoq_channels_whowas', ' channels : $0%n',
	'mh_sbqueryinfo_whoq_shared_whowas',   ' shared   :$0%n',
	'mh_sbqueryinfo_whoq_gone_whowas',     ' was gone : $0%n',
	'mh_sbqueryinfo_whoq_idle_whowas',     ' was idle : $0%n',
	'mh_sbqueryinfo_whoq_quit_whowas',     ' quit     : $0%n',
]);

Irssi::settings_add_int('mh_sbqueryinfo',  'mh_sbqueryinfo_delay',                   2);
Irssi::settings_add_int('mh_sbqueryinfo',  'mh_sbqueryinfo_lag_limit',               5);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_realname',           1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_userhost',           1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_server',             1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_channel_join',       1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_channel_part',       1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_gone',               1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_here',               1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_oper',               1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_deop',               1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_online',             1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_offline',            1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_offline_signoff',    1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_idle_here',          1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_idle_here_time',     1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_idle_gone',          1);
Irssi::settings_add_int('mh_sbqueryinfo',  'mh_sbqueryinfo_show_idle_minimum',       300);
Irssi::settings_add_int('mh_sbqueryinfo',  'mh_sbqueryinfo_detail_idle_minimum',     300);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_show_detail_realname',    1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_silent_when_away',        0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_whoq_when_away',          1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_realname',         0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_userhost',         0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_server',           0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_channel_join',     0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_channel_part',     0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_gone',             0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_here',             0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_oper',             0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_deop',             0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_online',           0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_offline',          0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_offline_signoff',  0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_idle_here',        0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_no_act_idle_gone',        0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_whoq_on_create',          1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_whoq_on_offline',         1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_strip_realname',          0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_strip_quit_reason',       0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_idle_longformat',         1);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_detail_idle_longformat',  0);
Irssi::settings_add_bool('mh_sbqueryinfo', 'mh_sbqueryinfo_whoq_idle_longformat',    1);

Irssi::statusbar_item_register('mh_sbqueryinfo', '', 'statusbar_queryinfo');

Irssi::signal_add('redir mh_sbqueryinfo event 301',   'signal_redir_event_301');
Irssi::signal_add('redir mh_sbqueryinfo event 311',   'signal_redir_event_311');
Irssi::signal_add('redir mh_sbqueryinfo event 312wi', 'signal_redir_event_312wi');
Irssi::signal_add('redir mh_sbqueryinfo event 312ww', 'signal_redir_event_312ww');
Irssi::signal_add('redir mh_sbqueryinfo event 313',   'signal_redir_event_313');
Irssi::signal_add('redir mh_sbqueryinfo event 314',   'signal_redir_event_314');
Irssi::signal_add('redir mh_sbqueryinfo event 317',   'signal_redir_event_317');
Irssi::signal_add('redir mh_sbqueryinfo event 318',   'signal_redir_event_318');
Irssi::signal_add('redir mh_sbqueryinfo event 319',   'signal_redir_event_319');
Irssi::signal_add('redir mh_sbqueryinfo event 369',   'signal_redir_event_369');
Irssi::signal_add('redir mh_sbqueryinfo event 401',   'signal_redir_event_401');
Irssi::signal_add('event 401',                        'signal_redir_event_401');
Irssi::signal_add('channel sync',                     'signal_channel_sync');
Irssi::signal_add('message join',                     'signal_message_join');
Irssi::signal_add('message private',                  'signal_message_private');
Irssi::signal_add('message public',                   'signal_message_private');
Irssi::signal_add('message irc action',               'signal_message_private');
Irssi::signal_add('message irc notice',               'signal_message_private');
Irssi::signal_add('message quit',                     'signal_message_quit');
Irssi::signal_add('query created',                    'signal_query_created');
Irssi::signal_add('query nick changed',               'signal_query_nick_changed');
Irssi::signal_add('query destroyed',                  'signal_query_destroyed');
Irssi::signal_add('notifylist joined',                'signal_notifylist_joined');
Irssi::signal_add('notifylist away changed',          'signal_notifylist_joined');
Irssi::signal_add('notifylist left',                  'signal_notifylist_joined');
Irssi::signal_add('setup changed',                    'signal_setup_changed');
Irssi::signal_add('window changed',                   'signal_window_changed');

Irssi::command_bind('whoq', 'command_whoq', 'mh_sbqueryinfo');
Irssi::command_bind('help', 'command_help');

for my $query (Irssi::queries())
{
	signal_query_created($query);
}

$on_load = 0;

1;

##############################################################################
#
# eof mh_sbqueryinfo.pl
#
##############################################################################
