##############################################################################
#
# mh_hilog.pl v1.00 (20151130)
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
# keep a log of hilights and display/clear the log when you type /hilog
#
# there is also a statusbar item that will show [hilog: <count>] when
# the count is more than 0
#
# to configure irssi to show the new statusbar item in a default irssi
# installation type '/statusbar window add -after window_empty mh_sbhilog'.
# see '/help statusbar' for more details and do not forget to '/save'
#
# history:
#	v1.00 (20151130)
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

our $VERSION = '1.00';
our %IRSSI   =
(
	'name'        => 'mh_hilog',
	'description' => 'keep a log of hilights and display/clear the log when you type /hilog',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'https://github.com/mh-source/irssi-scripts',
);

##############################################################################
#
# global variables
#
##############################################################################

our @hilog;

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
		$mon  = sprintf("%02d", $mon);

		push(@hilog, $mday . '/' . $mon . ' ' . $hour . ':' . $min . ' {' . $textdest->{'target'} . '} ' . $text);
		Irssi::statusbar_items_redraw('mh_sbhilog');
	}
}

##############################################################################
#
# irssi command functions
#
##############################################################################

sub command_hilog
{
	my ($data, $server, $windowitem) = @_;

	for my $data (@hilog)
	{
		Irssi::active_win->print($data, Irssi::MSGLEVEL_NEVER);
	}

	@hilog = ();
	Irssi::statusbar_items_redraw('mh_sbhilog');
}

##############################################################################
#
# statusbar item handlers
#
##############################################################################

sub statusbar_hilog
{
	my ($statusbaritem, $get_size_only) = @_;

	my $count  = scalar(@hilog);
	my $format = '';

	if ($count)
	{
		$format = 'hilog: ' . $count;
	}

	$statusbaritem->default_handler($get_size_only, '{sb ' . $format . '}', '', 0);
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::signal_add('print text', 'signal_print_text');

Irssi::statusbar_item_register('mh_sbhilog', '', 'statusbar_hilog');

Irssi::command_bind('hilog', 'command_hilog', 'mh_hilog');

1;

##############################################################################
#
# eof mh_hilog.pl
#
##############################################################################
