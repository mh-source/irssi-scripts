##############################################################################
#
# mh_hilog.pl v1.10 (20170424)
#
# Copyright (c) 2015-2017  Michael Hansen
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
# keep a log of hilights and display/clear the log when you type /hilog
#
# there is also a statusbar item that will show [hilog: <count>] when
# the count is more than 0
#
# lines will be printed in the following format (subject to configuration):
# DD/MM HH:MM [<refnum>]{<Network>/<channel>} <text...>
#
# settings:
#
# mh_hilog_show_refnum (default ON): enable/disable showing the hilight
# window refnum part
#
# mh_hilog_show_network (default ON): enable/disable showing the hilight
# window network part
#
# mh_hilog_strip_colours (default OFF): enable/disable stripping colours
# from the logged text
#
# mh_hilog_prefix (default 'hilog: '): set on unset the text prefix
# in the statusbar item
#
# mh_hilog_ignore (default ''): comma-seperated list of "<network>/<channel>"
# to ignore when logging hilights.
#
# to configure irssi to show the new statusbar item in a default irssi
# installation type '/statusbar window add -after window_empty mh_sbhilog'.
# see '/help statusbar' for more details and do not forget to '/save'
#
# history:
#
#	v1.10 (20170424)
#		added 'sbitems' to irssi header for better scriptassist.pl support (github issue #1)
#
#	v1.09 (20160208)
#		minor comment change
#
#	v1.08 (20151230)
#		now ignores whitespace around _ignore entries
#		code cleanup
#
#	v1.07 (20151223)
#		added changed field to irssi header
#		added _strip_colours and supporting code
#
#	v1.06 (20151212)
#		added indents to /help
#
#	v1.05 (20151209)
#		now saving the hilog to a file, so they are still there after a restart
#
#	v1.04 (20151205)
#		month in timestamps were off by one, fixed
#
#	v1.03 (20151204)
#		added _ignore and supporting code
#
#	v1.02 (20151201)
#		added /help
#		added mh_hilog_show_refnum/mh_hilog_show_network and supporting code
#		will now print if the log is empty when doing /hilog
#
#	v1.01 (20151201)
#		added setting mh_hilog_prefix
#
#	v1.00 (20151130)
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
use Irssi::TextUI;

our $VERSION = '1.10';
our %IRSSI   =
(
	'name'        => 'mh_hilog',
	'description' => 'keep a log of hilights and display/clear the log when you type /hilog',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Mon Apr 24 11:44:13 CEST 2017',
	'sbitems'     => 'mh_sbhilog',
);

##############################################################################
#
# global variables
#
##############################################################################

our @hilog;
our $hilog_count = 0;
our $hilog_save_timeout;

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

sub hilog_scan
{
	my $filepath = Irssi::get_irssi_dir();
	my $filename = $filepath . '/mh_hilog.log';

	if (open(my $filehandle, '<:encoding(UTF-8)' , $filename))
	{
		while (my $data = <$filehandle>)
		{
			$hilog_count++;
		}

		close($filehandle);
	}

	Irssi::statusbar_items_redraw('mh_sbhilog');
}

sub hilog_load
{
	my $filepath = Irssi::get_irssi_dir();
	my $filename = $filepath . '/mh_hilog.log';

	if (open(my $filehandle, '<:encoding(UTF-8)' , $filename))
	{
		while (my $data = <$filehandle>)
		{
			chomp($data);
			push(@hilog, $data);
		}

		close($filehandle);
		unlink($filename);
	}

	Irssi::statusbar_items_redraw('mh_sbhilog');
}

sub hilog_save
{
	$hilog_save_timeout = 0;

	my $filepath = Irssi::get_irssi_dir();

	make_path($filepath);

	my $filename = $filepath . '/mh_hilog.log';

	if (open(my $filehandle, '>>:encoding(UTF-8)' , $filename))
	{
		for my $logentry (@hilog)
		{
			print($filehandle $logentry . "\n");
		}

		close($filehandle);
		@hilog = ();
	}

	Irssi::statusbar_items_redraw('mh_sbhilog');
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_print_text
{
	my ($textdest, $text, $stripped) = @_;

	if ($textdest->{'level'} & Irssi::MSGLEVEL_HILIGHT)
	{
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

		$min  = sprintf("%02d", $min);
		$hour = sprintf("%02d", $hour);
		$mday = sprintf("%02d", $mday);
		$mon  = sprintf("%02d", ($mon + 1));

		my $refnum = '';

		if (Irssi::settings_get_bool('mh_hilog_show_refnum'))
		{
			$refnum = '[' . $textdest->{'window'}->{'refnum'} . ']';
		}

		my $servertag = '';

		if (Irssi::settings_get_bool('mh_hilog_show_network') and $textdest->{'server'})
		{
			$servertag = $textdest->{'server'}->{'tag'} . '/';
		}

		my $ignore = 0;
		my $server_target = lc($textdest->{'server'}->{'tag'} . '/' . $textdest->{'target'});

		for my $server_target_ignore (split(',', Irssi::settings_get_str('mh_hilog_ignore')))
		{
			$server_target_ignore = lc(trim_space($server_target_ignore));

			if ($server_target_ignore eq $server_target)
			{
				$ignore = 1;
				last;
			}
		}

		if (not $ignore)
		{
			if (Irssi::settings_get_bool('mh_hilog_strip_colours'))
			{
				$text = Irssi::strip_codes($text);
			}

			push(@hilog, $mday . '/' . $mon . ' ' . $hour . ':' . $min . ' ' . $refnum . '{' . $servertag  . $textdest->{'target'} . '} ' . $text);
			$hilog_count++;

			Irssi::statusbar_items_redraw('mh_sbhilog');

			if ($hilog_save_timeout)
			{
				Irssi::timeout_remove($hilog_save_timeout);
			}

			$hilog_save_timeout = Irssi::timeout_add_once(60000, 'hilog_save', undef); # one minute grace-period
		}
	}
}

sub signal_setup_changed_last
{
	Irssi::statusbar_items_redraw('mh_sbhilog');
}

sub signal_gui_exit_last
{
	if ($hilog_save_timeout)
	{
		Irssi::timeout_remove($hilog_save_timeout);
		$hilog_save_timeout = 0;
	}

	hilog_save();
}

##############################################################################
#
# irssi command functions
#
##############################################################################

sub command_hilog
{
	my ($data, $server, $windowitem) = @_;

	hilog_load();

	for my $data (@hilog)
	{
		Irssi::active_win->print($data, Irssi::MSGLEVEL_NEVER);
	}

	if (not @hilog)
	{
		Irssi::active_win->print('Hilight log is empty', Irssi::MSGLEVEL_CRAP);
	}

	@hilog       = ();
	$hilog_count = 0;
	Irssi::statusbar_items_redraw('mh_sbhilog');
}

sub command_help
{
	my ($data, $server, $windowitem) = @_;

	$data = lc(trim_space($data));

	if ($data =~ m/^hilog$/i)
	{
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('HILOG', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('%|Shows the current hilight log and clears the counter.', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('See also: %|DEHILIGHT, HILIGHT, SET HILIGHT, SET ' . uc('mh_hilog'), Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);

		Irssi::signal_stop();
	}
}

##############################################################################
#
# statusbar item handlers
#
##############################################################################

sub statusbar_hilog
{
	my ($statusbaritem, $get_size_only) = @_;

	my $format = '';

	if ($hilog_count)
	{
		$format = Irssi::settings_get_str('mh_hilog_prefix') . $hilog_count;
	}

	$statusbaritem->default_handler($get_size_only, '{sb ' . $format . '}', '', 0);
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::settings_add_str('mh_hilog',  'mh_hilog_prefix',        'hilog: ');
Irssi::settings_add_bool('mh_hilog', 'mh_hilog_show_network',  1);
Irssi::settings_add_bool('mh_hilog', 'mh_hilog_show_refnum',   1);
Irssi::settings_add_bool('mh_hilog', 'mh_hilog_strip_colours', 0);
Irssi::settings_add_str('mh_hilog',  'mh_hilog_ignore',        '');

Irssi::statusbar_item_register('mh_sbhilog', '', 'statusbar_hilog');

Irssi::signal_add('print text',         'signal_print_text');
Irssi::signal_add_last('setup changed', 'signal_setup_changed_last');
Irssi::signal_add_last('gui exit',      'signal_gui_exit_last');
Irssi::command_bind('hilog',            'command_hilog', 'mh_hilog');
Irssi::command_bind('help',             'command_help');

hilog_scan();

1;

##############################################################################
#
# eof mh_hilog.pl
#
##############################################################################
