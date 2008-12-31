use warnings;
use strict;
use inc::Module::Install;

name     'Net-Trac';
all_from 'lib/Net/Trac.pm';
license  'perl';

requires 'Moose';
requires 'Moose::Util::TypeConstraints';
requires 'URI';
requires 'IO::Scalar';
requires 'XML::Feed';
requires 'Text::CSV_XS';
requires 'LWP::Simple';
requires 'Params::Validate';
requires 'WWW::Mechanize' => '1.52';
requires 'DateTime::Format::ISO8601';

auto_install;
sign; 
WriteAll;

