use warnings;
use strict;
use inc::Module::Install;

name     'Net-Trac';
all_from 'lib/Net/Trac.pm';
license  'perl';

requires 'Moose';
requires 'URI';
requires 'IO::Scalar';
requires 'XML::Feed';
requires 'Text::CSV_XS';
requires 'LWP::Simple';
requires 'Params::Validate';
requires 'WWW::Mechanize' => '1.52';

auto_install;
sign; 
WriteAll;

