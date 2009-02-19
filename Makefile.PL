use warnings;
use strict;
use inc::Module::Install;

name     'Net-Trac';
all_from 'lib/Net/Trac.pm';
license  'perl';

requires 'Any::Moose';
requires 'URI';
requires 'IO::Scalar';
requires 'Text::CSV_XS';
requires 'LWP::Simple';
requires 'Params::Validate';
requires 'WWW::Mechanize' => '1.52';
requires 'DateTime';
requires 'DateTime::Format::ISO8601';
requires 'HTTP::Date';
requires 'Lingua::EN::Inflect';
requires 'URI::Escape';

auto_install;
sign; 
WriteAll;

