##############################################################################
#
# mh_lognames.pl v1.01 (20151121)
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
# print /NAMES on all channels every X (default 30) minutes (for logging)
#
# irssi is set by default with "log_level = all -crap -clientcrap -ctcps" to
# get /NAMES to show up in your log file you need to remove "-clientcrap".
# assuming you have the default log_level set (see "/set log_level") you issue
# the command "/SET log_level all -crap -ctcps"
#
# should the above be a big issue and I get enough requests to fix it, it is
# possible to catch the /NAMES reply and print it without the "clientcrap"
# level set. but i will leave it as-is for now.
#
# to change the delay, find the variable "$delay_minutes" below, and change
# the value. the default is "our $delay_minutes = 30;" which will issue
# /NAMES every 30 minutes.
#
# history:
#	v1.01 (20151121)
#		changed url to github and added basic instructions
#	v1.00 (20151121)
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

{ package Irssi::Nick }

our $VERSION = '1.01';
our %IRSSI   =
(
	'name'        => 'mh_lognames',
	'description' => 'print /NAMES on all channels every X (default 30) minutes (for logging)',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'https://github.com/mh-source/mh_lognames.pl',
);

##############################################################################
#
# global variables
#
##############################################################################

our $delay_minutes = 30; # delay in minutes, do not set to 0!

##############################################################################
#
# irssi timeouts
#
##############################################################################

sub timeout_lognames
{
	for my $channel (Irssi::channels())
	{
		$channel->command('/NAMES');
	}
}

Irssi::timeout_add(60000 * $delay_minutes, 'timeout_lognames', undef);

1;

##############################################################################
#
# eof mh_lognames.pl
#
##############################################################################
