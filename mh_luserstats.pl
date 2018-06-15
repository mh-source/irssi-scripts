##############################################################################
#
# mh_luserstats.pl v0.12 (201806151944)
#
# Copyright (c) 2018  Michael Hansen
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
# OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
##############################################################################
#
# log server and network user stats
#
# please read the full instructions below before installing or updating
#
# *** IMPORTTANT NOTE if updating ******************************************
#
# neither logfiles nor settings from previous versions can be used. although
# logfiles are now stored in a different (but similiar) directory, you are
# strongly encouraged to make a backup of them. the old settings also do not
# conflict with the new, you are still adviced to start with a clean slate
#
# logfile path changed from '<irssi_dir>/mh_luserstats/data' to a plain
# '<irssi_dir>/mh_luserstats'
#
# the old setting 'mh_luserstats_server' is now just 'mh_luserstats' and all
# other settings are gone
#
# **************************************************************************
#
# this script will request user counts from the configured server every minute
# and store the values in a set of CSV files. it keeps track of current users,
# current maximum users, and all-time maximum users for the local server and
# the global network. this is done using the IRC command USERS in non-rfc mode
# as used on several ircds. written primarilly for IRCnet/irc.psychz.net to
# generate pretty graphs of users over time based on the stored user counts
#
# once loaded, the script will look for irssi connections to a server matching
# the setting 'mh_luserstats' (not set by default. you will have to set this
# before the script will work). if a connection is found it will send requests
# to the server and store the replies. you can see current status and lastlog
# of events/errors with the command '/mh_luserstats'. if copy-pasting from the
# connected servers in the command to the 'mh_luserstats' setting, do not copy
# the quotes too. the command to set the server setting should look something
# like '/set mh_luserstats IRCnet/irc.psychz.net'
#
# logfile dir: <irssi_dir>/mh_luserstats/<network>/<address>/<year>/<month>
#
# <irssi_dir> is usually '~/.irssi' but not necessarily. <year> and <month> in
# local time and <month> is zeropadded
#
# logfile name: <day of month>.csv
#
# <day of month> is zeropadded. file is automatically rolled over
# at midnight. in local time
#
# logfile CSV format: <time>,<l cur>,<l max>,<l mmx>,<g cur>,<g max>,<g mmx>
#
# <time> in UTC and ISO8601 format, then local and then global current users,
# maximum users and all-time maximum maximum users.
#
# commands:
#
#	/mh_luserstats
#
#		will show you the script version information, followed by a lastlog of
#		script events/errors. then user stats and status, possibly followed by
#		the server setting and/or active connections, if they do not match the
#		current user stats
#
# settings:
#
#	mh_luserstats (string, default "")
#		server to log user stats on, see connected servers in '/mh_luserstats'
#
# history:
#
#	v0.12 (201806151944) --mh
#		- alpha 2
#		- rewrite of previous version. only added is reading all-time max
#         value from older logfiles to keep it between server restarts
#		- old logfiles and settings can not be used. please backup files and
#		  start with a clean config if possible (no conflicts, just cleaner)
#
##############################################################################

use strict;
use warnings;

use File::Path ();
use IO::Handle ();
use Time::Local ();

##############################################################################
#
# Irssi header
#
##############################################################################

use Irssi ();

our $VERSION = '0.12';
our %IRSSI   =
(
	'name'        => 'mh_luserstats',
	'description' => 'log server and network user stats',
	'changed'     => '201806151944',
	'license'     => 'ISC/BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => '',
	'url'         => 'https://github.com/mh-source/irssi-scripts/',
	'commands'    => 'mh_luserstats',
	'modules'     => 'File::Path IO::Handle Time::Local',
);

##############################################################################
#
# global variables
#
##############################################################################

our $lastlog;         # lastlog messages structure
our $luserstats;      # luserstats information and collected data structure
our $luserstats_data; # luserstats in-progress data collection structure

our $lc_irssi_name = lc($IRSSI{'name'});

##############################################################################
#
# script functions
#
##############################################################################

sub get_serverrecs
{
	#
	# returns an array of connected irc serverrecs
	#

	my @serverrecs;

	for my $serverrec (Irssi::servers())
	{
		if (ref($serverrec) ne 'Irssi::Irc::Server')
		{
			#
			# not an irc server
			#

			next;
		}

		if (not $serverrec->{'connected'})
		{
			#
			# server not connected
			#

			next;
		}

		push(@serverrecs, $serverrec);

		next;
	}

	return(@serverrecs);
}

sub get_serverrec_name
{
	#
	# returns server name of the given serverrec
	#
	my ($serverrec) = @_;

	if ($serverrec->{'chatnet'} eq '')
	{
		#
		# no chatnet for this server, use tag
		#

		return($serverrec->{'tag'} . '/' . $serverrec->{'real_address'});
	}

	return($serverrec->{'chatnet'} . '/' . $serverrec->{'real_address'});
}

##############################################################################
#
# script lastlog functions
#
##############################################################################

sub lastlog_reset
{
	#
	# reset global lastlog structure
	#
	# always returns true
	#

	$lastlog =
	{
		'max'      => 42,    # maximum number of messages kept (0 is unlimited)
		'messages' => undef, # array of messages
	};

	return(1);
}

sub lastlog_prune
{
	#
	# removes oldest messages if lastlog too long
	#
	# calls to this should be wrapped in 'if ($lastlog->{'max'})'
	#
	# always returns true
	#

	while (@{$lastlog->{'messages'}} > $lastlog->{'max'})
	{
		shift(@{$lastlog->{'messages'}});

		next;
	}

	return(1);
}

sub lastlog
{
	#
	# write a new message to the lastlog
	#
	# always returns true
	#
	my ($message) = @_;

	#
	# timestamp message
	#

	my @now_struct = localtime();
	my $message_ts = sprintf('%02d/%02d %02d:%02d:%02d: ', (1+$now_struct[4]), $now_struct[3], $now_struct[2], $now_struct[1], $now_struct[0]);
	#                         <MM>/<DD> <hh>:<mm>:<ss>:        month            day of month    hour            minute          second

	#
	# append timestamp and message to lastlog
	#

	push(@{$lastlog->{'messages'}}, $message_ts . $message);

	#
	# remove oldest messages if lastlog too long
	#

	if ($lastlog->{'max'})
	{
		lastlog_prune();
	}

	return(1);
}

##############################################################################
#
# script luserstats functions
#
##############################################################################

sub luserstats_reset_data
{
	#
	# reset global luserstats in-progress data structure and set the 'time'
	# field to now
	#
	# always returns true
	#

	$luserstats_data =
	{
		'time'   => time(), # time of data request
		'server' => '',     # server of data reply
		'local'  =>         # local usercount server now and server max from data reply
		{
			'now' => -1,
			'max' => -1,
		},
		'global' =>         # global usercount network now and server max from data reply
		{
			'now' => -1,
			'max' => -1,
		},
	};

	return(1);
}

sub luserstats_reset
{
	#
	# reset global luserstats structure
	#
	# always returns true
	#

	$luserstats =
	{
		'server' => undef, # server of current logfile and where data is expected from
		'fh'     => undef, # current file handle
		'mday'   => -1,    # day-of-month, for logfile name and daily rotation
		'fname'  => '',    # filename used in lastlog messages
		'local'  =>        # local usercount server now, server max, and maximum max
		{
			'now' => -1,
			'max' => -1,
			'mmx' => -1,
		},
		'global' =>        # global usercount server now, server max, and maximum max
		{
			'now' => -1,
			'max' => -1,
			'mmx' => -1,
		},
		'time'   => 0,
	};

	return(1);
}

sub luserstats_reload
{
	#
	# see if theres any previously stored values to use for maximum maximum
	# number of users. this done by attempting to read the most recent CSV
	# logfile for the current server, if any can be found
	#
	# always returns true
	#

	my $filepath = Irssi::get_irssi_dir() . '/' . $lc_irssi_name;

	#
	# first see if we got a server subdirectory
	#

	my $fname    = $luserstats->{'server'};
	my $filename = $filepath . '/' . $fname;

	if (opendir(my $dh, $filename))
	{
		#
		# get a reverse sorted list of year subdirectories, then dive into them
		#

		my @subdirs_year = sort({ $b cmp $a } grep { /^[0-9]{4}$/ } readdir($dh));
		closedir($dh);

		for my $subdir_year (@subdirs_year)
		{
			$fname    = $luserstats->{'server'} . '/' . $subdir_year;
			$filename = $filepath . '/' . $fname;

			if (not -d $filename)
			{
				#
				# not a directory
				#

				next;
			}

			if (not opendir($dh, $filename))
			{
				#
				# couldnt open directory
				#

				next;
			}

			#
			# get a reverse sorted list of month subdirectories, then dive into them
			#

			my @subdirs_month = sort { $b cmp $a } grep { /^[0-9]{2}$/ } readdir($dh);
			closedir($dh);

			for my $subdir_month (@subdirs_month)
			{
				$fname    = $luserstats->{'server'} . '/' . $subdir_year . '/' . $subdir_month;
				$filename = $filepath . '/' . $fname;

				if (not -d $filename)
				{
					#
					# not a directory
					#

					next;
				}

				if (not opendir($dh, $filename))
				{
					#
					# couldnt open directory
					#

					next;
				}

				#
				# get a reverse sorted list of day-of-month CSV logfiles, then
				# try to data from them, return result on first hit if any
				#

				my @files_mday = sort { $b cmp $a } grep { /^[0-9]{2}.csv$/ } readdir($dh);
				closedir($dh);

				for my $file_mday (@files_mday)
				{
					$fname    = $luserstats->{'server'} . '/' . $subdir_year . '/' . $subdir_month . '/' . $file_mday;
					$filename = $filepath . '/' . $fname;

					#
					# try to open file, go to next on failure
					#

					if (not open($dh, '<:encoding(UTF-8)', $filename))
					{
						#
						# couldnt open file
						#

						next;
					}

					#
					# read the last line from the file and see if it contains usable data
					#

					my $line     = '';
					my $lastline = '';

					while (defined($line = readline($dh)))
					{
						chomp($line);
						$lastline = $line;

						next;
					}

					close($dh);

					if ($lastline =~ m/^[0-9TZ:-]{20},(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+)$/)
					{
						#
						# a match for our CSV data. update global luserstats
						# data structure and return
						#

						my $mmx =
						{
							'local'  => int($3),
							'global' => int($6),
						};

						for my $type ('local', 'global')
						{
							if ($luserstats->{$type}->{'mmx'} < $mmx->{$type})
							{
								$luserstats->{$type}->{'mmx'} = $mmx->{$type};
							}

							next;
						}

						return(1);
					}

					#
					# data in file didnt match, try next file
					#

					next;
				}

				#
				# nothing usable in this day-of-month directory, try the next one
				#

				next;
			}

			#
			# nothing usable in this year directory, try the next one
			#

			next;
		}
	}

	return(1);
}

sub luserstats_file_close
{
	#
	# close the luserstats file handle
	#
	# always returns true
	#

	close($luserstats->{'fh'});
	$luserstats->{'fh'} = undef;

	return(1);
}

sub luserstats_file_open
{
	#
	# open the luserstats file handle
	#
	# always returns true
	#

	my $filepath = Irssi::get_irssi_dir() . '/' . $lc_irssi_name . '/' . $luserstats->{'fname'};

	#
	# create stored data directory
	#

	File::Path::make_path $filepath; # 'mkdir -p', can fail but will be caught on open()

	#
	# set the logfile filename and open it
	#

	my $filename = sprintf("/%02d.csv", $luserstats->{'mday'});

	$luserstats->{'fname'} .= $filename;
	$filename               = $filepath . $filename;

	if (not open($luserstats->{'fh'}, '>>:encoding(UTF-8)', $filename))
	{
		#
		# open failed
		#

		lastlog('error! open failed "' . $luserstats->{'fname'} . '": ' . "$!");
		luserstats_file_close();

		return(1);
	}

	#
	# set the logfile to flush on every write
	#

	$luserstats->{'fh'}->autoflush(1);

	return(1);
}

sub luserstats_serverrec
{
	#
	# get the serverrec matching current setting
	#
	# returns the Irssi serverrec on success or undef on failure
	#

	my $lc_setting = lc(Irssi::settings_get_str($lc_irssi_name));

	for my $serverrec (get_serverrecs())
	{
		if (lc(get_serverrec_name($serverrec)) ne $lc_setting)
		{
			#
			# wrong network/server
			#

			next;
		}

		#
		# we got a match
		#

		return($serverrec);
	}

	#
	# no match
	#

	return(undef);
}

sub luserstats_next_timeout
{
	#
	# calculate how long time until next timeout should occur and add an Irssi
	# timeout for it
	#
	# always returns true
	#

	my @now_struct   = localtime();
	my $timeout_secs = 60;

	#
	# next whole minute happens in...
	#

	if ($now_struct[0] < $timeout_secs)
	{
		$timeout_secs = $timeout_secs - $now_struct[0];
	}
	else
	{
		#
		# leapsecond
		#

		$timeout_secs = 1;
	}

	#
	# add next timeout_luserstats timeout to Irssi
	#

	Irssi::timeout_add_once(1000 * $timeout_secs, 'timeout_luserstats', undef);
	#                    in msec

	return(1);
}

sub luserstats
{
	#
	# this is called every time we have a new set of data collected
	#
	# always returns true
	#

	my @time_struct = localtime($luserstats_data->{'time'});

	#
	# do we have an open logfile that needs to be closed?
	#

	if ($luserstats->{'fh'})
	{
		if (lc($luserstats_data->{'server'}) ne lc($luserstats->{'server'}))
		{
			#
			# new data from a new server
			#

			luserstats_file_close();
			lastlog('log closed "' . $luserstats->{'fname'} . '": server changed');

			luserstats_reset();
		}
		elsif ($luserstats->{'mday'} != $time_struct[3])
		{
			#
			# local day changed
			#

			luserstats_file_close();
			lastlog('log closed "' . $luserstats->{'fname'} . '": day changed');
		}
	}

	#
	# open logfile if needed
	#

	if (not $luserstats->{'fh'})
	{
		if (defined($luserstats->{'server'}))
		{
			#
			# there is already data stored, make sure the new data is for the
			# same server
			#

			if (lc($luserstats_data->{'server'}) ne lc($luserstats->{'server'}))
			{
				#
				# new data from a new server, clear stored data
				#

				lastlog('server changed');
				luserstats_reset();
			}
		}

		#
		# initialise data
		#

		if (not defined($luserstats->{'server'}))
		{
			#
			# new server, see if we got stored maximum values
			#

			$luserstats->{'server'} = $luserstats_data->{'server'};
			luserstats_reload();
		}

		$luserstats->{'mday'}  = $time_struct[3];
		$luserstats->{'fname'} = $luserstats_data->{'server'} . '/' . (1900+$time_struct[5]) . '/'. sprintf('%02d', (1+$time_struct[4]));
		#                                                              year                          month (zeropadded)

		#
		# open logfile
		#

		luserstats_file_open();

		if (not $luserstats->{'fh'})
		{
			#
			# open failed
			#

			return(1);
		}

		lastlog('log opened "' . $luserstats->{'fname'} . '"');
	}

	#
	# create an UTC ISO8601 timestamp for new data
	#

	$luserstats->{'time'} = $luserstats_data->{'time'};
	@time_struct = gmtime($luserstats->{'time'});
	my $data_ts  = sprintf('%04d-%02d-%02dT%02d:%02d:%02dZ', (1900+$time_struct[5]), (1+$time_struct[4]), $time_struct[3], $time_struct[2], $time_struct[1], $time_struct[0]);
	#                     <YYYY>-<MM>-<DD>T<HH>:<mm>:<ss>Z          year                 month             day of month     hour             minute           second

	#
	# create a CSV string of current data after updating it with new data values
	#

	my $data = '';

	for my $type ('local', 'global')
	{
		$luserstats->{$type}->{'now'} = $luserstats_data->{$type}->{'now'};
		$luserstats->{$type}->{'max'} = $luserstats_data->{$type}->{'max'};

		if ($luserstats->{$type}->{'mmx'} < $luserstats_data->{$type}->{'max'})
		{
			#
			# maximum max increased
			#

			$luserstats->{$type}->{'mmx'} = $luserstats_data->{$type}->{'max'};
		}

		#
		# append values to string
		#

		$data .= ',' . $luserstats->{$type}->{'now'} . ',' . $luserstats->{$type}->{'max'} . ',' . $luserstats->{$type}->{'mmx'};

		next;
	}

	#
	# write timestamp and data to logfile
	#

	print( { $luserstats->{'fh'} } $data_ts . $data . "\n");

	return(1);
}

##############################################################################
#
# Irssi command handlers
#
##############################################################################

sub command_luserstats
{
	#
	# print script version and other information
	#
	# always returns true
	#
	my ($data, $server, $witem) = @_;

	Irssi::print('mh_luserstats.pl v' . $VERSION . ' (' . $IRSSI{'changed'} . ') Copyright (c) 2018  Michael Hansen', Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);

	#
	# print lastlog messages
	#

	if (@{$lastlog->{'messages'}})
	{
		Irssi::print(' lastlog', Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);

		for my $message (@{$lastlog->{'messages'}})
		{
			Irssi::print('  ' . $message, Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);

			next;
		}
	}

	#
	# print userstats data and/or server and connections status
	#

	my @servers = get_serverrecs();

	if (@servers)
	{
		#
		# first put all servers in a hash to avoid duplicates in the list
		#

		my $servernames = {};

		for my $serverrec (@servers)
		{
			my $servername = get_serverrec_name($serverrec);
			$servernames->{lc($servername)} = $servername;

			next;
		}

		#
		# make the sorted server list
		#

		@servers = ();

		for my $server (sort { $a cmp $b } keys(%{$servernames}))
		{
			push(@servers, $servernames->{$server});

			next;
		}
	}

	my $serversetting    = Irssi::settings_get_str($lc_irssi_name);
	my $serverrec        = luserstats_serverrec();
	my $server_matchdata = 0;

	if (defined($luserstats->{'server'}))
	{
		if (lc($luserstats->{'server'}) eq lc($serversetting))
		{
			#
			# server setting matches data server
			#

			$server_matchdata  = 1;
		}
	}

	Irssi::print(' userstats', Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);

	#
	# print data if available
	#

	my $serverstring = '';

	if (defined($luserstats->{'server'}))
	{
		#
		# print logfile name if available, otherwise server name
		#

		if (defined($luserstats->{'fname'}) and $luserstats->{'fh'})
		{
			if ($serverrec and $server_matchdata)
			{
				$serverstring = ' "' . $luserstats->{'fname'} . '"';
			}
			else
			{
				#
				# logfile is active, but server is...
				#

				if (not $server_matchdata)
				{
					$serverstring = ' "' . $luserstats->{'fname'} . '" (server mismatch)';
				}
				else
				{
					$serverstring = ' "' . $luserstats->{'fname'} . '" (not connected)';
				}
			}
		}
		else
		{
			#
			# print the server name
			#

			if ($serverrec)
			{
				#
				# there is a connected server
				#

				if (not $server_matchdata)
				{
					#
					# data server doesnt match connnected server
					#

					$serverstring = ' "' . $luserstats->{'server'} . '" (server mismatch)';
				}
				else
				{
					#
					# data server match connnected server
					#

					$serverstring = ' "' . $luserstats->{'server'} . '"';
				}
			}
			else
			{
				#
				# no connected server
				#

				if (not $server_matchdata)
				{
					#
					# data server doesnt match connnected server
					#

					$serverstring = ' "' . $luserstats->{'server'} . '" (server mismatch)';
				}
				else
				{
					$serverstring = ' "' . $luserstats->{'server'} . '" (not connected)';
				}
			}
		}

		#
		# print time of last data reply
		#

		if ($luserstats->{'time'})
		{
			#
			# add the timestamp
			#

			my $time_diff_str = '';

			if ((my $time_diff = (time() - $luserstats->{'time'})) > 60)
			{
				#
				# turn seconds since data was collected into readable format
				#

				my $value      = 0;
				$time_diff_str = ' [';

				if ($time_diff >= 3600)
				{
					#
					# hours
					#

					$value          = int($time_diff / 3600);
					$time_diff      = $time_diff - ($value * 3600);
					$time_diff_str .= $value . 'h';
				}

				if (($time_diff >= 60) or ($value))
				{
					#
					# minutes
					#

					$value          = int($time_diff / 60);
					$time_diff      = $time_diff - ($value * 60);
					$time_diff_str .= $value . 'm';
				}

				if (($time_diff) or ($value))
				{
					#
					# seconds
					#

					$time_diff_str .= $time_diff . 's';
				}

				$time_diff_str .= ' ago]';
			}

			#
			# print timestamp and possibly time difference if needed
			#

			my @now_struct = localtime($luserstats->{'time'});
			my $data_ts    = sprintf('%02d/%02d %02d:%02d:%02d:', (1+$now_struct[4]), $now_struct[3], $now_struct[2], $now_struct[1], $now_struct[0]);
			#                         <MM>/<DD> <hh>:<mm>:<ss>:        month            day of month    hour            minute          seconds
			Irssi::print('  ' . $data_ts . $time_diff_str . $serverstring, Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);
		}
		else
		{
			#
			# no timestamp
			#

			Irssi::print(' ' . $serverstring, Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);
		}

		#
		# print data values
		#

		my $maxlen = length($luserstats->{'global'}->{'mmx'});
		# assume network alltime max is the largest number. used for alignment

		if ($luserstats->{'local'}->{'max'} ==  $luserstats->{'local'}->{'mmx'})
		{
			Irssi::print('  local  ' . sprintf('%' . $maxlen . 'd %' . $maxlen . 'd', $luserstats->{'local'}->{'now'},  $luserstats->{'local'}->{'max'}),  Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);
		}
		else
		{
			Irssi::print('  local  ' . sprintf('%' . $maxlen . 'd %' . $maxlen . 'd %' . $maxlen . 'd', $luserstats->{'local'}->{'now'},  $luserstats->{'local'}->{'max'},  $luserstats->{'local'}->{'mmx'}),  Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);
		}

		if ($luserstats->{'global'}->{'max'} ==  $luserstats->{'global'}->{'mmx'})
		{
			Irssi::print('  global ' . sprintf('%' . $maxlen . 'd %' . $maxlen . 'd', $luserstats->{'global'}->{'now'}, $luserstats->{'global'}->{'max'}), Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);
		}
		else
		{
			Irssi::print('  global ' . sprintf('%' . $maxlen . 'd %' . $maxlen . 'd %' . $maxlen . 'd', $luserstats->{'global'}->{'now'}, $luserstats->{'global'}->{'max'}, $luserstats->{'global'}->{'mmx'}), Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);
		}
	}
	else
	{
		#
		# no recent data yet
		#

		Irssi::print('  <no data>', Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);
	}

	#
	# print server setting if needed
	#

	if (not $server_matchdata)
	{
		Irssi::print(' server', Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);

		if ($serversetting ne '')
		{
			if (not $serverrec)
			{
				Irssi::print('  "' . $serversetting . '" (not connected)', Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);
			}
			else
			{
				Irssi::print('  "' . $serversetting . '" (connected)', Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);
			}
		}
		else
		{
			Irssi::print('  <none set>', Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);
		}
	}

	#
	# print connected servers if needed
	#

	if (not $serverrec)
	{
		Irssi::print(' connections', Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);

		if(@servers)
		{
			for my $server (@servers)
			{
				Irssi::print('  "' . $server . '"', Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);

				next;
			}
		}
		else
		{
			Irssi::print('  <none>', Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NOHILIGHT | Irssi::MSGLEVEL_NO_ACT);
		}
	}

	return(1);
}

##############################################################################
#
# Irssi signal handlers
#
##############################################################################

sub signal_redir_event_numeric
{
	#
	# numeric signal handler for 'USERS' redirected command replies. collects
	# data, and when all data is collected sends it for processing
	#
	# always returns true
	#
	my ($serverrec, $data, $nickname, $userhost) = @_;

	if (not $nickname)
	{
		#
		# the server address is in $nickname for numeric events. if it isnt,
		# bail out. this really shouldnt happen though
		#

		lastlog('error! numeric event reply without server nickname');

		return(1);
	}

	#
	# is this reply from the expected server?
	#

	my $servername = get_serverrec_name($serverrec);

	if (lc($servername) ne lc($luserstats_data->{'server'}))
	{
		lastlog('error! numeric event reply from wrong server');

		return(1);
	}

	if (lc($nickname) ne lc($serverrec->{'real_address'}))
	{
		lastlog('error! numeric event reply from wrong server address');

		return(1);
	}

	#
	# numeric replies 265 and 266 are very similiar, so we use a little magic to catch both
	#

	if ($data =~ m/^\S+\s+(\d+)\s+(\d+)\s+:Current (local|global)/)
	{
		my $type                           = lc($3);  # $3 is either 'local' for 265 or 'global' for 266
		$luserstats_data->{$type}->{'now'} = int($1); # current user count
		$luserstats_data->{$type}->{'max'} = int($2); # highest user count seen

		if ($type eq 'global')
		{
			#
			# 'global' numeric 266 is our last expected event, so process collected data
			#

			luserstats();
		}
	}
	else
	{
		lastlog('error! numeric event reply data did not match');
	}

	return(1);
}

##############################################################################
#
# Irssi timeout handlers
#
##############################################################################

sub timeout_luserstats
{
	#
	# main timeout running in the background requesting data from the server
	#
	# always returns true
	#

	luserstats_reset_data();

	my $serverrec = luserstats_serverrec();

	if (defined($serverrec))
	{
		$luserstats_data->{'server'} = get_serverrec_name($serverrec);

		$serverrec->redirect_event($lc_irssi_name . ' USERS',
			1,  # stop events count
			'', # comparison argument
			-1, # remote (-1: use default)
			'', # failure signal
			{   # signals
				'event 265' => 'redir ' . $lc_irssi_name . ' event numeric', # RPL_LOCALUSERS
				'event 266' => 'redir ' . $lc_irssi_name . ' event numeric', # RPL_GLOBALUSERS
				''          => 'event empty',                                # ignore everything else
			}
		);

		$serverrec->send_raw_now('USERS');
	}
	else
	{
		#
		# no server found
		#

		if ($luserstats->{'fh'})
		{
			luserstats_file_close();
			lastlog('log closed "' . $luserstats->{'fname'} . '": connection lost');
		}
	}

	luserstats_next_timeout();

	return(1);
}

##############################################################################
#
# on load
#
##############################################################################

#
# add irssi settings
#

Irssi::settings_add_str($IRSSI{'name'}, $lc_irssi_name, '');

#
# register Irssi command redirections
#

Irssi::Irc::Server::redirect_register($lc_irssi_name . ' USERS',
	0, # is command remote
	0, # remote timeout
	{  # start events
		'event 265' => 1, # RPL_LOCALUSERS
	},
	{  # stop events
		'event 266' => 1, # RPL_GLOBALUSERS
	},
	{  # optional events
	}
);

#
# register Irssi signals
#

Irssi::signal_add('redir ' . $lc_irssi_name . ' event numeric', 'signal_redir_event_numeric');

#
# register Irssi commands
#

Irssi::command_bind($lc_irssi_name, 'command_luserstats', $IRSSI{'name'});

#
# initialise lastlog and luserstats
#

lastlog_reset();
luserstats_reset();

#
# start first luserstats timeout
#

Irssi::timeout_add_once(100, 'luserstats_next_timeout', undef);

#
# done
#

lastlog('script loaded');

1;

##############################################################################
#
# eof mh_luserstats.pl
#
##############################################################################
